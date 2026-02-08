// Task State Machine
// =================
//
// This file defines domain models for tasks. TaskItem only knows about
// its own lifecycle. Global constraints (max tasks, day lock) are
// enforced by TodayController.
//
// Task States (intrinsic to task):
//   - planned: Task created, waiting to be activated
//   - active: Task timer is running
//   - completed: Task finished with sufficient time
//   - abandoned: Task was active and deliberately quit
//
// Valid Transitions (intrinsic to task):
//   planned -> active    (user starts task)
//   active -> completed  (user finishes)
//   active -> abandoned  (user quits)
//   planned -> expired   (never started, day locked - handled by controller)
//
// Invalid Transitions:
//   planned -> completed (must pass through active)
//   planned -> abandoned (must start first)
//   any -> planned (not allowed)
//   completed/abandoned -> any (terminal states)

import 'package:flutter/foundation.dart';

/// All possible states a task can occupy
/// Only intrinsic states - day-level constraints handled by TodayController
enum TaskState {
  planned(
    canTransitionTo: [TaskState.active],
  ),
  active(
    canTransitionTo: [TaskState.completed, TaskState.abandoned],
  ),
  completed(
    canTransitionTo: [], // Terminal state
  ),
  abandoned(
    canTransitionTo: [], // Terminal state
  );

  final List<TaskState> canTransitionTo;

  const TaskState({required this.canTransitionTo});

  /// Check if transition to target state is valid (intrinsic validity only)
  bool canTransitionToState(TaskState target) {
    return canTransitionTo.contains(target);
  }

  /// Display name for UI
  String get displayName {
    return switch (this) {
      TaskState.planned => 'Planned',
      TaskState.active => 'Active',
      TaskState.completed => 'Completed',
      TaskState.abandoned => 'Abandoned',
    };
  }
}

/// Day-level state - separate from task state
enum DayState {
  open,
  locked; // Day sealed, no modifications allowed

  bool get isLocked => this == locked;
}

/// Result type for state transitions
sealed class TransitionResult {
  const TransitionResult();
}

final class TransitionSuccess extends TransitionResult {
  final TaskState previousState;
  final TaskState newState;

  const TransitionSuccess(this.previousState, this.newState);
}

final class TransitionFailure extends TransitionResult {
  final TaskState currentState;
  final TaskState attemptedState;
  final String reason;

  const TransitionFailure(
    this.currentState,
    this.attemptedState,
    this.reason,
  );

  @override
  String toString() {
    return 'Cannot transition from $currentState to $attemptedState: $reason';
  }
}

/// Domain model for a single task
/// Only knows about its own lifecycle - no awareness of global constraints
class TaskItem {
  final String id;
  final String name;
  final int estimatedMinutes;
  int? _actualMinutes;
  TaskState _state;

  // Immutable timestamps
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  // Reflection data (populated after completion/abandonment)
  String? _whatWorked;
  String? _impediment;

  TaskItem({
    required this.id,
    required this.name,
    required this.estimatedMinutes,
    int? actualMinutes,
    required TaskState state,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    String? whatWorked,
    String? impediment,
  })  : _actualMinutes = actualMinutes,
        _state = state,
        _whatWorked = whatWorked,
        _impediment = impediment {
    assert(
      state == TaskState.planned,
      'New tasks must start as planned',
    );
  }

  // Getters for state queries
  TaskState get state => _state;
  int? get actualMinutes => _actualMinutes;
  String? get whatWorked => _whatWorked;
  String? get impediment => _impediment;
  bool get isTerminal =>
      _state == TaskState.completed || _state == TaskState.abandoned;
  bool get canStart => _state == TaskState.planned;
  bool get canFinish => _state == TaskState.active;
  bool get canAbandon => _state == TaskState.active;

  // Time calculations
  int getTimeDelta() {
    if (_actualMinutes == null) return 0;
    return _actualMinutes! - estimatedMinutes;
  }

  double getErrorPercentage() {
    if (_actualMinutes == null || _actualMinutes == 0) return 0;
    return (getTimeDelta().abs() / estimatedMinutes) * 100;
  }

  // Controlled state transitions (intrinsic validity only)
  // Global constraints handled by TodayController before calling these

  /// Transition: planned -> active
  /// Preconditions: Task must be planned
  TransitionResult start() {
    if (!canStart) {
      return TransitionFailure(
        _state,
        TaskState.active,
        'Only planned tasks can be started',
      );
    }

    _state = TaskState.active;
    return TransitionSuccess(TaskState.planned, _state);
  }

  /// Transition: active -> completed
  /// Preconditions: Task must be active
  TransitionResult complete({required int actualMinutes}) {
    if (!canFinish) {
      return TransitionFailure(
        _state,
        TaskState.completed,
        'Only active tasks can be completed',
      );
    }

    _actualMinutes = actualMinutes;
    _state = TaskState.completed;
    return TransitionSuccess(TaskState.active, _state);
  }

  /// Transition: active -> abandoned
  /// Preconditions: Task must be active (must have started first)
  TransitionResult abandon({required String reason}) {
    if (!canAbandon) {
      return TransitionFailure(
        _state,
        TaskState.abandoned,
        'Only active tasks can be abandoned',
      );
    }

    _impediment = reason;
    _state = TaskState.abandoned;
    return TransitionSuccess(TaskState.active, _state);
  }

  /// Transition: planned -> expired
  /// Used when day locks with unattempted planned tasks
  /// Preconditions: Task must be planned
  TransitionResult expire() {
    if (_state != TaskState.planned) {
      return TransitionFailure(
        _state,
        TaskState.abandoned,
        'Only planned tasks can expire',
      );
    }

    // Expiration is similar to abandonment but different semantic
    // Mark as abandoned with "never started" reason
    _impediment = 'Never started (day locked)';
    _state = TaskState.abandoned;
    return TransitionSuccess(TaskState.planned, _state);
  }

  // Reflection data can only be set once
  void setReflection({String? whatWorked, String? impediment}) {
    if (_whatWorked == null) {
      _whatWorked = whatWorked;
    }
    if (_impediment == null) {
      _impediment = impediment;
    }
  }

  // Factory for creating new tasks
  factory TaskItem.create({
    required String name,
    required int estimatedMinutes,
  }) {
    return TaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      estimatedMinutes: estimatedMinutes,
      state: TaskState.planned,
      createdAt: DateTime.now(),
      startedAt: null,
      completedAt: null,
    );
  }

  // Copy with modifications
  TaskItem copyWith({
    String? name,
    int? estimatedMinutes,
    int? actualMinutes,
    String? whatWorked,
    String? impediment,
  }) {
    return TaskItem(
      id: id,
      name: name ?? this.name,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? _actualMinutes,
      state: _state,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      whatWorked: whatWorked ?? _whatWorked,
      impediment: impediment ?? _impediment,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
