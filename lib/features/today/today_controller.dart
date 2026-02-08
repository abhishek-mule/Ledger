import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ledger/app/routes.dart';
import 'package:ledger/features/today/today_models.dart';
import 'package:ledger/features/today/today_widgets.dart';
import 'package:ledger/shared/colors.dart';
import 'package:ledger/shared/text_styles.dart';

// TodayController - Business logic with state machine and day constraints
// =======================================================================
//
// This controller enforces both task-level and day-level rules:
//
// Task-level transitions (intrinsic validity checked by TaskItem):
//   planned -> active    (user starts task)
//   active -> completed  (user finishes with sufficient time)
//   active -> abandoned  (user quits during work)
//
// Day-level constraints (enforced here, not in TaskItem):
//   - Max 3 tasks per day
//   - Only one active task at a time
//   - Day lock prevents any modifications
//
// Error handling strategy:
//   - Debug mode (kDebugMode=true): throw exceptions to surface bugs quickly
//   - Release mode: return TransitionFailure for graceful handling

class TodayController extends ChangeNotifier {
  final List<TaskItem> _tasks = [];
  DayState _dayState = DayState.open;

  // Debug mode detection - uses Flutter's kDebugMode
  bool get _debugMode => kDebugMode;

  // Public getters
  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  int get taskCount => _tasks.length;
  bool get canAddTask => _tasks.length < 3 && _dayState == DayState.open;
  bool get hasActiveTask => _tasks.any((t) => t.state == TaskState.active);
  DayState get dayState => _dayState;
  bool get isDayLocked => _dayState == DayState.locked;

  // Task Management
  // =============

  /// Create a new task (starts in planned state)
  /// Rules:
  ///   - Day must be open
  ///   - Max 3 tasks per day
  ///   - Task name must not be empty
  ///   - Estimate must be positive
  void addTask({
    required String name,
    required int estimatedMinutes,
  }) {
    _checkDayOpen();

    if (!canAddTask) {
      _throwOrReturn('Cannot add task: already at maximum of 3 tasks');
    }
    if (name.trim().isEmpty) {
      _throwOrReturn('Task name cannot be empty');
    }
    if (estimatedMinutes <= 0) {
      _throwOrReturn('Estimate must be positive');
    }

    final newTask = TaskItem.create(
      name: name.trim(),
      estimatedMinutes: estimatedMinutes,
    );

    _tasks.add(newTask);
    notifyListeners();
  }

  /// Transition task from planned to active
  /// Rules:
  ///   - Day must be open
  ///   - Only one task can be active at a time (auto-abandon current)
  ///   - Task must be in planned state (checked by TaskItem)
  void startTask(int index) {
    _checkDayOpen();
    final task = _validateIndex(index);

    // Auto-abandon any currently active task
    for (var t in _tasks) {
      if (t.state == TaskState.active) {
        final result = t.abandon(reason: 'Switched to another task');
        _handleTransitionFailure(result);
      }
    }

    final result = task.start();
    _handleTransitionFailure(result);

    notifyListeners();
  }

  /// Transition task from active to completed
  /// Rules:
  ///   - Day must be open
  ///   - Task must be active (checked by TaskItem)
  void completeTask(int index, {required int actualMinutes}) {
    _checkDayOpen();
    final task = _validateIndex(index);

    final result = task.complete(actualMinutes: actualMinutes);
    _handleTransitionFailure(result);

    notifyListeners();
  }

  /// Transition task from active to abandoned
  /// Rules:
  ///   - Day must be open
  ///   - Task must be active (checked by TaskItem)
  void abandonTask(int index, {required String reason}) {
    _checkDayOpen();
    final task = _validateIndex(index);

    final result = task.abandon(reason: reason);
    _handleTransitionFailure(result);

    notifyListeners();
  }

  /// Lock the day - no further modifications allowed
  /// Rules:
  ///   - All planned tasks automatically expire
  ///   - Day state transitions from open to locked
  void sealDay() {
    if (_dayState == DayState.locked) {
      _throwOrReturn('Day is already locked');
    }

    // Expire all planned tasks (never started)
    for (var task in _tasks) {
      if (task.state == TaskState.planned) {
        final result = task.expire();
        _handleTransitionFailure(result);
      }
    }

    _dayState = DayState.locked;
    notifyListeners();
  }

  /// Set reflection data after completion/abandonment
  void setReflection({
    required int taskIndex,
    String? whatWorked,
    String? impediment,
  }) {
    final task = _validateIndex(taskIndex);

    if (task.whatWorked == null) {
      task.setReflection(whatWorked: whatWorked);
    }
    if (task.impediment == null) {
      task.setReflection(impediment: impediment);
    }

    notifyListeners();
  }

  // Query Methods
  TaskItem? getActiveTask() {
    try {
      return _tasks.firstWhere((t) => t.state == TaskState.active);
    } catch (e) {
      return null;
    }
  }

  List<TaskItem> getPlannedTasks() {
    return _tasks.where((t) => t.state == TaskState.planned).toList();
  }

  List<TaskItem> getCompletedTasks() {
    return _tasks.where((t) => t.state == TaskState.completed).toList();
  }

  List<TaskItem> getAbandonedTasks() {
    return _tasks.where((t) => t.state == TaskState.abandoned).toList();
  }

  // Validation Helpers
  TaskItem _validateIndex(int index) {
    if (index < 0 || index >= _tasks.length) {
      _throwOrReturn('Task index out of range: $index');
    }
    return _tasks[index];
  }

  void _checkDayOpen() {
    if (_dayState == DayState.locked) {
      _throwOrReturn('Cannot modify tasks: day is locked');
    }
  }

  // Error handling strategy
  void _throwOrReturn(String message) {
    if (_debugMode) {
      throw StateError(message);
    }
    // In release mode, this would return TransitionFailure
    // For now, we still throw but documentation clarifies the strategy
    throw StateError('[Release Mode] $message');
  }

  void _handleTransitionFailure(TransitionResult result) {
    if (result is TransitionFailure) {
      if (_debugMode) {
        throw StateError('Invalid transition: $result');
      }
      // In release mode, log and ignore gracefully
      debugPrint('Transition failed: $result');
    }
  }
}
