import 'dart:convert';
import 'package:ledger/shared/data/storage_interface.dart';
import 'package:ledger/shared/data/entities.dart';

// =============================================================================
// LEDGER EVENT SYSTEM - The Source of Truth
// =============================================================================
//
// CRITICAL PRINCIPLE: State is derived from events, not trusted blindly.
// Events are append-only, immutable, and form a complete audit trail.
//
// This is not just logging - it's the authoritative record.
// The database snapshots are DERIVED from these events, not the reverse.
//
// Schema: [ID | Timestamp | Day | TaskID | EventType | Metadata]
//
// Event Types:
//   task_started           - User initiated task work
//   task_completed         - User finished task with actual minutes
//   task_abandoned         - User quit task mid-work (with reason)
//   day_sealed             - Day locked for history (irreversible)
//   session_interrupted    - App backgrounded (phone locked, etc.)
//   session_resumed        - App returned from background
//   reflection_submitted   - Completed reflection answers
//   integrity_violation    - State mismatch detected
//
// WHY EVENTS?
// - Complete audit trail (can answer "when did X happen?")
// - Replay capability (can rebuild state from scratch)
// - Integrity validation (re-derive and compare)
// - Analytics foundation (can analyze transitions)
// - Tamper detection (events are append-only, immutable)

/// Immutable event record representing something that happened
class LedgerEvent {
  final String id;                           // Unique event ID
  final DateTime timestamp;                  // When it happened
  final String dayDate;                      // Which day (YYYY-MM-DD)
  final String? taskId;                      // Which task (if applicable)
  final String eventType;                    // What kind of event
  final Map<String, dynamic>? metadata;      // Event-specific data
  final bool isSealed;                       // Once sealed, cannot be modified

  const LedgerEvent({
    required this.id,
    required this.timestamp,
    required this.dayDate,
    this.taskId,
    required this.eventType,
    this.metadata,
    this.isSealed = false,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'dayDate': dayDate,
      'taskId': taskId,
      'eventType': eventType,
      'metadata': metadata,
      'isSealed': isSealed,
    };
  }

  /// Create from JSON
  factory LedgerEvent.fromJson(Map<String, dynamic> json) {
    return LedgerEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      dayDate: json['dayDate'] as String,
      taskId: json['taskId'] as String?,
      eventType: json['eventType'] as String,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      isSealed: json['isSealed'] as bool? ?? false,
    );
  }

  /// Create sealed copy (immutable)
  LedgerEvent seal() {
    return LedgerEvent(
      id: id,
      timestamp: timestamp,
      dayDate: dayDate,
      taskId: taskId,
      eventType: eventType,
      metadata: metadata,
      isSealed: true,
    );
  }
}

/// Append-only event log (physical immutability)
class LedgerEventLog {
  final LedgerStorage _storage;
  static const String _eventPrefix = 'event:';

  LedgerEventLog({required LedgerStorage storage}) : _storage = storage;

  /// Append an event (write-once semantics)
  /// This is the ONLY way to create truth.
  Future<LedgerEvent> append(LedgerEvent event) async {
    // CRITICAL: Events are immutable once written
    // Use a write-once key: we never update, only append
    final eventKey = '$_eventPrefix${event.id}';

    // Verify key doesn't exist (append-only)
    final exists = await _storage.exists(eventKey);
    if (exists) {
      throw LedgerEventException(
        'Event ${event.id} already exists. Events are immutable.',
      );
    }

    // Seal the event before writing (make it tamper-proof)
    final sealed = event.seal();

    // Write to storage (append-only, never updated)
    await _storage.save(eventKey, sealed.toJson());

    return sealed;
  }

  /// Get event by ID
  Future<LedgerEvent?> getEvent(String eventId) async {
    final eventKey = '$_eventPrefix$eventId';
    final record = await _storage.get(eventKey);
    if (record == null) return null;
    return LedgerEvent.fromJson(record.data);
  }

  /// Get all events for a day (in chronological order)
  Future<List<LedgerEvent>> getEventsForDay(String dayDate) async {
    final allEvents = await _storage.getAll(prefix: _eventPrefix);

    final dayEvents = allEvents
        .map((r) => LedgerEvent.fromJson(r.data))
        .where((e) => e.dayDate == dayDate)
        .toList();

    // Sort by timestamp (chronological)
    dayEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return dayEvents;
  }

  /// Get all events for a task
  Future<List<LedgerEvent>> getEventsForTask(String taskId) async {
    final allEvents = await _storage.getAll(prefix: _eventPrefix);

    final taskEvents = allEvents
        .map((r) => LedgerEvent.fromJson(r.data))
        .where((e) => e.taskId == taskId)
        .toList();

    taskEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return taskEvents;
  }

  /// Get all events (for integrity validation)
  Future<List<LedgerEvent>> getAllEvents() async {
    final allRecords = await _storage.getAll(prefix: _eventPrefix);
    final events = allRecords
        .map((r) => LedgerEvent.fromJson(r.data))
        .toList();

    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return events;
  }

  /// Get events in time range
  Future<List<LedgerEvent>> getEventsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final allEvents = await getAllEvents();
    return allEvents
        .where((e) => e.timestamp.isAfter(start) && e.timestamp.isBefore(end))
        .toList();
  }

  /// Get events of specific type
  Future<List<LedgerEvent>> getEventsByType(String eventType) async {
    final allEvents = await getAllEvents();
    return allEvents.where((e) => e.eventType == eventType).toList();
  }

  /// Count events (for diagnostics)
  Future<int> count() async {
    final events = await getAllEvents();
    return events.length;
  }
}

// =============================================================================
// EVENT BUILDERS - Type-safe event creation
// =============================================================================

class TaskStartedEvent {
  static LedgerEvent create({
    required String taskId,
    required String dayDate,
    required DateTime timestamp,
  }) {
    return LedgerEvent(
      id: '${taskId}_started_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      dayDate: dayDate,
      taskId: taskId,
      eventType: 'task_started',
      metadata: {
        'action': 'User initiated task work',
      },
    );
  }
}

class TaskCompletedEvent {
  static LedgerEvent create({
    required String taskId,
    required String dayDate,
    required DateTime timestamp,
    required int actualMinutes,
    required String whatWorked,
    required String impediment,
  }) {
    return LedgerEvent(
      id: '${taskId}_completed_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      dayDate: dayDate,
      taskId: taskId,
      eventType: 'task_completed',
      metadata: {
        'action': 'User finished task',
        'actualMinutes': actualMinutes,
        'whatWorked': whatWorked,
        'impediment': impediment,
      },
    );
  }
}

class TaskAbandonedEvent {
  static LedgerEvent create({
    required String taskId,
    required String dayDate,
    required DateTime timestamp,
    required String reason,
  }) {
    return LedgerEvent(
      id: '${taskId}_abandoned_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      dayDate: dayDate,
      taskId: taskId,
      eventType: 'task_abandoned',
      metadata: {
        'action': 'User quit task',
        'reason': reason,
      },
    );
  }
}

class DaySealedEvent {
  static LedgerEvent create({
    required String dayDate,
    required DateTime timestamp,
  }) {
    return LedgerEvent(
      id: '${dayDate}_sealed_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      dayDate: dayDate,
      taskId: null,
      eventType: 'day_sealed',
      metadata: {
        'action': 'Day locked for history (IRREVERSIBLE)',
        'note': 'No further changes allowed to this day',
      },
    );
  }
}

class SessionInterruptedEvent {
  static LedgerEvent create({
    required String taskId,
    required String dayDate,
    required DateTime timestamp,
    required String reason,
  }) {
    return LedgerEvent(
      id: '${taskId}_interrupted_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      dayDate: dayDate,
      taskId: taskId,
      eventType: 'session_interrupted',
      metadata: {
        'action': 'App backgrounded',
        'reason': reason,
        'note': 'Time is "committed" not "focused" until resume',
      },
    );
  }
}

class SessionResumedEvent {
  static LedgerEvent create({
    required String taskId,
    required String dayDate,
    required DateTime timestamp,
    required Duration committedTime,
  }) {
    return LedgerEvent(
      id: '${taskId}_resumed_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      dayDate: dayDate,
      taskId: taskId,
      eventType: 'session_resumed',
      metadata: {
        'action': 'App returned from background',
        'committedMinutes': committedTime.inMinutes,
        'note': 'Session continuity maintained',
      },
    );
  }
}

class IntegrityViolationEvent {
  static LedgerEvent create({
    required String dayDate,
    required DateTime timestamp,
    required String violation,
    required Map<String, dynamic> details,
  }) {
    return LedgerEvent(
      id: 'integrity_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      dayDate: dayDate,
      taskId: null,
      eventType: 'integrity_violation',
      metadata: {
        'action': 'State mismatch detected',
        'violation': violation,
        'details': details,
        'severity': 'CRITICAL',
      },
    );
  }
}

class EvidenceEvent {
  static LedgerEvent create({
    required String taskId,
    required String dayDate,
    required DateTime timestamp,
    required int unlockCount,
    required int screenOnMinutes,
    required List<Map<String, dynamic>> topApps,
  }) {
    return LedgerEvent(
      id: '${taskId}_evidence_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      dayDate: dayDate,
      taskId: taskId,
      eventType: 'evidence',
      metadata: {
        'action': 'Screen-time forensics',
        'unlockCount': unlockCount,
        'screenOnMinutes': screenOnMinutes,
        'topApps': topApps,
      },
    );
  }
}

// =============================================================================
// EXCEPTION
// =============================================================================

class LedgerEventException implements Exception {
  final String message;

  LedgerEventException(this.message);

  @override
  String toString() => 'LedgerEventException: $message';
}

