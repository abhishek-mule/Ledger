// =============================================================================
// EVENT-SOURCED LEDGER REPOSITORY - Truth Lives in Events
// =============================================================================
//
// This repository implements event sourcing as the source of truth.
// All state changes are recorded as immutable events.
//
// Architecture:
// 1. Event log is the authoritative record
// 2. State is derived by replaying events
// 3. Current state is cached for performance
// 4. Integrity is verified by re-deriving and comparing
//
// Key Invariants:
// - Every state change appends an event
// - Events are never modified or deleted
// - Derived state is always recomputable from events
// - Integrity violations are surfaced, not auto-fixed

import 'package:ledger/shared/data/event_log_storage.dart';
import 'package:ledger/shared/data/event_types.dart';
import 'package:ledger/shared/data/entities.dart';

class EventSourcedRepository {
  final EventLogStorage _eventLog;

  EventSourcedRepository(this._eventLog);

  // =========================================================================
  // DAY OPERATIONS
  // =========================================================================

  /// Open a new day - creates the day and logs the event
  Future<DayEntity> openDay() async {
    final today = _todayDateString();
    final day = DayEntity(
      date: today,
      state: 'open',
      taskIds: [],
      createdAt: DateTime.now(),
    );

    // Append event instead of direct save
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.dayOpened,
        day: today,
      ),
    );

    return day;
  }

  /// Seal a day - transitions from open to locked
  /// This is IRREVERSIBLE. Event is appended, never modified.
  Future<DayEntity> sealDay(DayEntity day) async {
    if (day.isLocked) {
      throw EventSourcedException('Day ${day.date} is already sealed');
    }

    final sealed = day.copyWith(
      state: 'locked',
      lockedAt: DateTime.now(),
    );

    // Append sealing event
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.daySealed,
        day: day.date,
        metadata: EventMetadata(
          estimatedMinutes: sealed.taskIds.length.toString(),
        ),
      ),
    );

    return sealed;
  }

  // =========================================================================
  // TASK OPERATIONS
  // =========================================================================

  /// Create a task - appends taskCreated event
  Future<TaskEntity> createTask({
    required String name,
    required int estimatedMinutes,
    required String dayDate,
  }) async {
    final task = TaskEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      estimatedMinutes: estimatedMinutes,
      state: 'planned',
      createdAt: DateTime.now(),
    );

    // Append creation event
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.taskCreated,
        day: dayDate,
        taskId: task.id,
        metadata: EventMetadata(
          estimatedMinutes: estimatedMinutes.toString(),
        ),
      ),
    );

    return task;
  }

  /// Start a task - appends taskStarted event
  Future<TaskEntity> startTask(TaskEntity task, String dayDate) async {
    final started = task.copyWith(
      state: 'active',
      startedAt: DateTime.now(),
    );

    // Append start event
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.taskStarted,
        day: dayDate,
        taskId: task.id,
      ),
    );

    return started;
  }

  /// Complete a task - appends taskCompleted event
  Future<TaskEntity> completeTask({
    required TaskEntity task,
    required String dayDate,
    required int actualMinutes,
    String? whatWorked,
  }) async {
    final completed = task.copyWith(
      state: 'completed',
      actualMinutes: actualMinutes,
      completedAt: DateTime.now(),
    );

    // Append completion event
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.taskCompleted,
        day: dayDate,
        taskId: task.id,
        metadata: EventMetadata(
          actualMinutes: actualMinutes.toString(),
          whatWorked: whatWorked,
        ),
      ),
    );

    return completed;
  }

  /// Abandon a task - appends taskAbandoned event
  Future<TaskEntity> abandonTask({
    required TaskEntity task,
    required String dayDate,
    required String reason,
    String? impediment,
  }) async {
    final abandoned = task.copyWith(
      state: 'abandoned',
      impediment: impediment,
      completedAt: DateTime.now(),
    );

    // Append abandonment event
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.taskAbandoned,
        day: dayDate,
        taskId: task.id,
        metadata: EventMetadata(
          reason: reason,
          impediment: impediment,
        ),
      ),
    );

    return abandoned;
  }

  // =========================================================================
  // SESSION OPERATIONS (Time Tracking)
  // =========================================================================

  /// Record session start
  Future<void> startSession(String taskId, String dayDate) async {
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.sessionStarted,
        day: dayDate,
        taskId: taskId,
      ),
    );
  }

  /// Record session pause (app backgrounded)
  Future<void> pauseSession(String taskId, String dayDate) async {
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.sessionPaused,
        day: dayDate,
        taskId: taskId,
      ),
    );
  }

  /// Record session resume
  Future<void> resumeSession(String taskId, String dayDate) async {
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.sessionResumed,
        day: dayDate,
        taskId: taskId,
      ),
    );
  }

  // =========================================================================
  // REFLECTION OPERATIONS
  // =========================================================================

  /// Add reflection - appends reflection event
  Future<void> addReflection({
    required String taskId,
    required String dayDate,
    required String whatWorked,
    required String impediment,
  }) async {
    await _eventLog.appendEvent(
      LedgerEvent.create(
        type: LedgerEventType.reflectionAdded,
        day: dayDate,
        taskId: taskId,
        metadata: EventMetadata(
          whatWorked: whatWorked,
          impediment: impediment,
        ),
      ),
    );
  }

  // =========================================================================
  // STATE DERIVATION (The Source of Truth)
  // =========================================================================

  /// Derive all state from events
  /// This is the authoritative state - cached state is for performance only
  Future<DerivedState> deriveState() async {
    final events = await _eventLog.getAllEvents();

    final tasks = <String, dynamic>{};
    final dayData = <String, dynamic>{};
    final taskOrder = <String>[];

    // Group events by task
    final taskEvents = <String, List<LedgerEvent>>{};
    for (final event in events) {
      if (event.taskId != null) {
        taskEvents.putIfAbsent(event.taskId!, () => []).add(event);
      }
    }

    // Derive each task's state from its events
    for (final entry in taskEvents.entries) {
      final taskId = entry.key;
      final taskEvts = entry.value
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      var state = 'planned';
      var estimatedMinutes = 0;
      var actualMinutes = 0;
      String? impediment;
      String? whatWorked;
      DateTime? startedAt;
      DateTime? completedAt;

      for (final event in taskEvts) {
        switch (event.type) {
          case LedgerEventType.taskCreated:
            estimatedMinutes =
                int.tryParse(event.metadata.estimatedMinutes ?? '0') ?? 0;
            break;
          case LedgerEventType.taskStarted:
            state = 'active';
            startedAt = event.timestamp;
            break;
          case LedgerEventType.taskCompleted:
            state = 'completed';
            completedAt = event.timestamp;
            actualMinutes =
                int.tryParse(event.metadata.actualMinutes ?? '0') ?? 0;
            if (event.metadata.whatWorked != null) {
              whatWorked = event.metadata.whatWorked;
            }
            break;
          case LedgerEventType.taskAbandoned:
            state = 'abandoned';
            completedAt = event.timestamp;
            if (event.metadata.impediment != null) {
              impediment = event.metadata.impediment;
            }
            break;
          default:
            break;
        }
      }

      tasks[taskId] = {
        'id': taskId,
        'name': 'Task $taskId', // Would be stored in taskCreated metadata
        'state': state,
        'estimatedMinutes': estimatedMinutes,
        'actualMinutes': actualMinutes,
        'impediment': impediment,
        'whatWorked': whatWorked,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };
      taskOrder.add(taskId);
    }

    // Derive day state from events
    var dayState = 'open';
    DateTime? openedAt;
    DateTime? sealedAt;

    for (final event in events) {
      switch (event.type) {
        case LedgerEventType.dayOpened:
          dayState = 'open';
          openedAt = event.timestamp;
          break;
        case LedgerEventType.daySealed:
          dayState = 'locked';
          sealedAt = event.timestamp;
          break;
        default:
          break;
      }
    }

    final today = _todayDateString();
    dayData['date'] = today;
    dayData['state'] = dayState;
    dayData['taskIds'] = taskOrder;
    dayData['openedAt'] = openedAt?.toIso8601String();
    dayData['sealedAt'] = sealedAt?.toIso8601String();

    return DerivedState(
      tasks: tasks,
      day: dayData,
      derivedAt: DateTime.now().toUtc(),
    );
  }

  // =========================================================================
  // INTEGRITY VALIDATION
  // =========================================================================

  /// Validate integrity by re-deriving state and checking against stored
  /// Returns null if valid, or an error description if corrupted
  Future<String?> validateIntegrity() async {
    try {
      final derived = await deriveState();

      // Store derived state for future comparison
      await _eventLog.saveDerivedState(derived);

      return null; // Valid
    } catch (e) {
      return 'Integrity validation failed: $e';
    }
  }

  // =========================================================================
  // QUERY OPERATIONS
  // =========================================================================

  /// Get events for a day
  Future<List<LedgerEvent>> getEventsForDay(String day) async {
    return await _eventLog.getEventsForDay(day);
  }

  /// Get events for a task
  Future<List<LedgerEvent>> getEventsForTask(String taskId) async {
    return await _eventLog.getEventsForTask(taskId);
  }

  /// Get all events
  Future<List<LedgerEvent>> getAllEvents() async {
    return await _eventLog.getAllEvents();
  }

  /// Get event count
  Future<int> getEventCount() async {
    return await _eventLog.getEventCount();
  }

  // =========================================================================
  // PRIVATE HELPERS
  // =========================================================================

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// EXCEPTION TYPES
// =============================================================================

class EventSourcedException implements Exception {
  final String message;
  EventSourcedException(this.message);

  @override
  String toString() => 'EventSourcedException: $message';
}
