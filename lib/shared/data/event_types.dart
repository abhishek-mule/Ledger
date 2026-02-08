// =============================================================================
// EVENT LOG FOUNDATION - The Source of Truth
// =============================================================================
//
// This module defines the event structure and event types for the ledger.
// All state changes are recorded as immutable events in an append-only log.
//
// Core Principles:
// 1. Truth lives in events - stored state is derived convenience
// 2. Append-only - events cannot be modified or deleted
// 3. Events are self-describing - contain all context needed for derivation
// 4. Integrity is verifiable - replay events to validate stored state

import 'package:uuid/uuid.dart';

// Event types representing all meaningful state transitions
enum LedgerEventType {
  // Task lifecycle events
  taskCreated,
  taskStarted,
  taskCompleted,
  taskAbandoned,

  // Day lifecycle events
  dayOpened,
  daySealed,

  // Session events for time tracking
  sessionStarted,
  sessionPaused,
  sessionResumed,

  // Reflection events
  reflectionAdded,

  // Correction events (for audit trail, not modification)
  correctionApplied,
}

// Event metadata - additional context for specific event types
class EventMetadata {
  final String? estimatedMinutes;
  final String? actualMinutes;
  final String? reason;
  final String? impediment;
  final String? whatWorked;
  final String? correctionNote;

  const EventMetadata({
    this.estimatedMinutes,
    this.actualMinutes,
    this.reason,
    this.impediment,
    this.whatWorked,
    this.correctionNote,
  });

  Map<String, dynamic> toJson() {
    return {
      if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
      if (actualMinutes != null) 'actualMinutes': actualMinutes,
      if (reason != null) 'reason': reason,
      if (impediment != null) 'impediment': impediment,
      if (whatWorked != null) 'whatWorked': whatWorked,
      if (correctionNote != null) 'correctionNote': correctionNote,
    };
  }

  factory EventMetadata.fromJson(Map<String, dynamic> json) {
    return EventMetadata(
      estimatedMinutes: json['estimatedMinutes'] as String?,
      actualMinutes: json['actualMinutes'] as String?,
      reason: json['reason'] as String?,
      impediment: json['impediment'] as String?,
      whatWorked: json['whatWorked'] as String?,
      correctionNote: json['correctionNote'] as String?,
    );
  }
}

// The immutable event record - append-only, never modified
class LedgerEvent {
  final String id;
  final DateTime timestamp;
  final LedgerEventType type;
  final String day;
  final String? taskId;
  final EventMetadata metadata;

  LedgerEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.day,
    this.taskId,
    required this.metadata,
  });

  // Create a new event with auto-generated ID and timestamp
  factory LedgerEvent.create({
    required LedgerEventType type,
    required String day,
    String? taskId,
    EventMetadata? metadata,
  }) {
    return LedgerEvent(
      id: const Uuid().v4(),
      timestamp: DateTime.now().toUtc(),
      type: type,
      day: day,
      taskId: taskId,
      metadata: metadata ?? const EventMetadata(),
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'day': day,
      if (taskId != null) 'taskId': taskId,
      'metadata': metadata.toJson(),
    };
  }

  // Create from JSON (for reading, not writing)
  factory LedgerEvent.fromJson(Map<String, dynamic> json) {
    return LedgerEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: LedgerEventType.values.byName(json['type'] as String),
      day: json['day'] as String,
      taskId: json['taskId'] as String?,
      metadata: EventMetadata.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map),
      ),
    );
  }

  // Human-readable description for debugging/UI
  String get description {
    final taskRef = taskId != null ? ' task:$taskId' : '';
    final meta = _formatMetadata();
    return '${type.name}$taskRef$meta';
  }

  String _formatMetadata() {
    final parts = <String>[];
    if (metadata.estimatedMinutes != null) {
      parts.add('est:${metadata.estimatedMinutes}m');
    }
    if (metadata.actualMinutes != null) {
      parts.add('actual:${metadata.actualMinutes}m');
    }
    if (metadata.reason != null) {
      parts.add('reason:${metadata.reason}');
    }
    return parts.isEmpty ? '' : ' (${parts.join(', ')})';
  }
}

// Derived state snapshots (for performance, not truth)
class DerivedState {
  final Map<String, dynamic> tasks;
  final Map<String, dynamic> day;
  final DateTime derivedAt;

  DerivedState({
    required this.tasks,
    required this.day,
    required this.derivedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'tasks': tasks,
      'day': day,
      'derivedAt': derivedAt.toIso8601String(),
    };
  }

  factory DerivedState.fromJson(Map<String, dynamic> json) {
    return DerivedState(
      tasks: Map<String, dynamic>.from(json['tasks'] as Map),
      day: Map<String, dynamic>.from(json['day'] as Map),
      derivedAt: DateTime.parse(json['derivedAt'] as String),
    );
  }
}
