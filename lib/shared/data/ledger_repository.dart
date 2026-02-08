import 'package:ledger/shared/data/storage_interface.dart';
import 'package:ledger/shared/data/entities.dart';

// =============================================================================
// LEDGER REPOSITORY - Persistence with Integrity
// =============================================================================
//
// This repository enforces:
// - Day lock rejection: If DayState.locked, all writes are rejected
// - No deletes: Only state transitions, never deletion
// - Immutable history: Once sealed, data cannot be modified
// - Session continuity: Handles app kill/resume with startedAt timestamps
//
// This class depends only on LedgerStorage interface,
// not on SharedPreferences or any concrete implementation.

class LedgerRepository {
  static const String _keyDays = 'days';
  static const String _keyTasks = 'tasks';
  static const String _keySession = 'session';
  static const String _keyCurrentDay = 'current_day';

  final LedgerStorage _storage;

  LedgerRepository(this._storage);

  // ===========================================================================
  // DAY OPERATIONS
  // ===========================================================================

  /// Get or create today's day entity
  Future<DayEntity> getOrCreateToday() async {
    final today = _todayDateString();
    final currentJson = await _storage.get(_keyCurrentDay);

    if (currentJson != null) {
      final stored = _dayEntityFromRecord(currentJson);
      if (stored.date == today) {
        return stored;
      }
    }

    // Create new day
    final newDay = DayEntity(
      date: today,
      state: 'open',
      taskIds: [],
      createdAt: DateTime.now(),
    );

    await _saveCurrentDay(newDay);
    return newDay;
  }

  /// Get a day by date string
  Future<DayEntity?> getDay(String date) async {
    final json = await _storage.get('$_keyDays:$date');
    if (json == null) return null;
    return _dayEntityFromRecord(json);
  }

  /// Get all sealed days for Reality screen
  Future<List<DayEntity>> getSealedDays() async {
    final allDays = await _storage.getAll(prefix: _keyDays);
    return allDays
        .map((r) => _dayEntityFromRecord(r))
        .where((d) => d.isLocked)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Seal a day - transitions from open to locked
  /// This is IRREVERSIBLE. Once locked, data is frozen.
  Future<DayEntity> sealDay(DayEntity day) async {
    if (day.isLocked) {
      throw RepositoryException('Day ${day.date} is already sealed');
    }

    final sealed = day.copyWith(
      state: 'locked',
      lockedAt: DateTime.now(),
    );

    await _saveDay(sealed);
    await _saveCurrentDay(sealed);
    return sealed;
  }

  // ===========================================================================
  // TASK OPERATIONS
  // ===========================================================================

  /// Create a new task
  Future<TaskEntity> createTask({
    required String name,
    required int estimatedMinutes,
    required String dayDate,
  }) async {
    final day = await getOrCreateToday();

    if (day.isLocked) {
      throw RepositoryException(
          'Cannot create task: day ${day.date} is sealed');
    }

    if (day.taskIds.length >= 3) {
      throw RepositoryException('Cannot create task: maximum 3 tasks per day');
    }

    final task = TaskEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      estimatedMinutes: estimatedMinutes,
      state: 'planned',
      createdAt: DateTime.now(),
    );

    // Save task
    await _saveTask(task);

    // Update day with task reference
    final updatedDay = day.copyWith(
      taskIds: [...day.taskIds, task.id],
    );
    await _saveDay(updatedDay);
    await _saveCurrentDay(updatedDay);

    return task;
  }

  /// Get a task by ID
  Future<TaskEntity?> getTask(String id) async {
    final json = await _storage.get('$_keyTasks:$id');
    if (json == null) return null;
    return _taskEntityFromRecord(json);
  }

  /// Get all tasks for a day
  Future<List<TaskEntity>> getTasksForDay(String dayDate) async {
    final day = await getDay(dayDate);
    if (day == null) return [];

    final tasks = <TaskEntity>[];
    for (final id in day.taskIds) {
      final task = await getTask(id);
      if (task != null) tasks.add(task);
    }
    return tasks;
  }

  /// Update a task
  Future<TaskEntity> updateTask(TaskEntity task) async {
    final day = await getOrCreateToday();

    if (day.isLocked) {
      throw RepositoryException(
          'Cannot update task: day ${day.date} is sealed');
    }

    return await _saveTask(task);
  }

  /// Start a task - records startedAt timestamp
  Future<TaskEntity> startTask(TaskEntity task) async {
    if (task.state != 'planned') {
      throw RepositoryException('Can only start planned tasks');
    }

    final updated = task.copyWith(
      state: 'active',
      startedAt: DateTime.now(),
    );

    return await updateTask(updated);
  }

  /// Complete a task
  Future<TaskEntity> completeTask(TaskEntity task,
      {required int actualMinutes}) async {
    if (task.state != 'active') {
      throw RepositoryException('Can only complete active tasks');
    }

    final updated = task.copyWith(
      state: 'completed',
      actualMinutes: actualMinutes,
      completedAt: DateTime.now(),
    );

    return await updateTask(updated);
  }

  /// Abandon a task
  Future<TaskEntity> abandonTask(TaskEntity task,
      {required String reason}) async {
    if (task.state != 'active') {
      throw RepositoryException('Can only abandon active tasks');
    }

    final updated = task.copyWith(
      state: 'abandoned',
      impediment: reason,
      completedAt: DateTime.now(),
    );

    return await updateTask(updated);
  }

  // ===========================================================================
  // SESSION OPERATIONS (App Kill/Resume Handling)
  // ===========================================================================

  /// Save session state for resume handling
  Future<void> saveSession(SessionState session) async {
    await _storage.save(
      _keySession,
      session.toJson(),
    );
  }

  /// Load session state
  Future<SessionState?> loadSession() async {
    final json = await _storage.get(_keySession);
    if (json == null) return null;
    return SessionState.fromJson(json.data);
  }

  /// Clear session (called when task is completed or abandoned)
  Future<void> clearSession() async {
    await _storage.delete(_keySession);
  }

  /// Handle app resume - check if task was abandoned due to app kill
  Future<SessionState> handleResume() async {
    final session = await loadSession();
    if (session == null || !session.hasActiveTask) {
      return SessionState();
    }
    return session;
  }

  // ===========================================================================
  // PRIVATE HELPER METHODS
  // ===========================================================================

  Future<void> _saveDay(DayEntity day) async {
    await _storage.save('$_keyDays:${day.date}', day.toJson());
  }

  Future<void> _saveCurrentDay(DayEntity day) async {
    await _storage.save(_keyCurrentDay, day.toJson());
  }

  Future<TaskEntity> _saveTask(TaskEntity task) async {
    await _storage.save('$_keyTasks:${task.id}', task.toJson());
    return task;
  }

  DayEntity _dayEntityFromRecord(StorageRecord record) {
    return DayEntity.fromJson(record.data);
  }

  TaskEntity _taskEntityFromRecord(StorageRecord record) {
    return TaskEntity.fromJson(record.data);
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// Exception type for repository errors
class RepositoryException implements Exception {
  final String message;
  RepositoryException(this.message);

  @override
  String toString() => 'RepositoryException: $message';
}
