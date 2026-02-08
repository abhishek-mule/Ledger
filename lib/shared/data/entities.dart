import 'dart:convert';

// =============================================================================
// DATA MODELS - Immutable records for persistence
// =============================================================================
//
// These entities are stored in SharedPreferences as JSON.
// Once written, they can only be read or transitioned through valid state changes.
// No deletes, no edits to sealed data.

/// Entity representing a task as stored in persistence
class TaskEntity {
  final String id;
  final String name;
  final int estimatedMinutes;
  final int? actualMinutes;
  final String state;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? whatWorked;
  final String? impediment;

  const TaskEntity({
    required this.id,
    required this.name,
    required this.estimatedMinutes,
    this.actualMinutes,
    required this.state,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.whatWorked,
    this.impediment,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'estimatedMinutes': estimatedMinutes,
      'actualMinutes': actualMinutes,
      'state': state,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'whatWorked': whatWorked,
      'impediment': impediment,
    };
  }

  /// Create from JSON
  factory TaskEntity.fromJson(Map<String, dynamic> json) {
    return TaskEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      estimatedMinutes: json['estimatedMinutes'] as int,
      actualMinutes: json['actualMinutes'] as int?,
      state: json['state'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      whatWorked: json['whatWorked'] as String?,
      impediment: json['impediment'] as String?,
    );
  }

  /// Clone with modifications
  TaskEntity copyWith({
    String? id,
    String? name,
    int? estimatedMinutes,
    int? actualMinutes,
    String? state,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? whatWorked,
    String? impediment,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      whatWorked: whatWorked ?? this.whatWorked,
      impediment: impediment ?? this.impediment,
    );
  }

  /// Calculate time delta
  int get timeDelta {
    if (actualMinutes == null) return 0;
    return actualMinutes! - estimatedMinutes;
  }

  /// Check if task is terminal
  bool get isTerminal {
    return state == 'completed' || state == 'abandoned';
  }
}

/// Entity representing a day as stored in persistence
class DayEntity {
  final String date; // ISO date string YYYY-MM-DD
  final String state; // 'open' or 'locked'
  final List<String> taskIds; // References to tasks
  final DateTime createdAt;
  final DateTime? lockedAt;

  const DayEntity({
    required this.date,
    required this.state,
    required this.taskIds,
    required this.createdAt,
    this.lockedAt,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'state': state,
      'taskIds': taskIds,
      'createdAt': createdAt.toIso8601String(),
      'lockedAt': lockedAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory DayEntity.fromJson(Map<String, dynamic> json) {
    return DayEntity(
      date: json['date'] as String,
      state: json['state'] as String,
      taskIds: List<String>.from(json['taskIds'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lockedAt: json['lockedAt'] != null
          ? DateTime.parse(json['lockedAt'] as String)
          : null,
    );
  }

  /// Clone with modifications
  DayEntity copyWith({
    String? date,
    String? state,
    List<String>? taskIds,
    DateTime? createdAt,
    DateTime? lockedAt,
  }) {
    return DayEntity(
      date: date ?? this.date,
      state: state ?? this.state,
      taskIds: taskIds ?? this.taskIds,
      createdAt: createdAt ?? this.createdAt,
      lockedAt: lockedAt ?? this.lockedAt,
    );
  }

  bool get isLocked => state == 'locked';
  bool get isOpen => state == 'open';
}

/// Current session data for handling app kill/resume
class SessionState {
  final String? activeTaskId;
  final DateTime? sessionStartedAt;
  final DateTime? lastHeartbeat;

  const SessionState({
    this.activeTaskId,
    this.sessionStartedAt,
    this.lastHeartbeat,
  });

  Map<String, dynamic> toJson() {
    return {
      'activeTaskId': activeTaskId,
      'sessionStartedAt': sessionStartedAt?.toIso8601String(),
      'lastHeartbeat': lastHeartbeat?.toIso8601String(),
    };
  }

  factory SessionState.fromJson(Map<String, dynamic> json) {
    return SessionState(
      activeTaskId: json['activeTaskId'] as String?,
      sessionStartedAt: json['sessionStartedAt'] != null
          ? DateTime.parse(json['sessionStartedAt'] as String)
          : null,
      lastHeartbeat: json['lastHeartbeat'] != null
          ? DateTime.parse(json['lastHeartbeat'] as String)
          : null,
    );
  }

  bool get hasActiveTask => activeTaskId != null;

  /// Calculate elapsed time in minutes
  int getElapsedMinutes() {
    if (sessionStartedAt == null) return 0;
    return DateTime.now().difference(sessionStartedAt!).inMinutes;
  }
}
