import 'package:ledger/shared/data/ledger_event.dart';
import 'package:ledger/shared/data/entities.dart';

// =============================================================================
// STATE DERIVATION ENGINE - Phase 6
// =============================================================================
//
// CRITICAL PRINCIPLE: State is DERIVED from events, not trusted.
//
// Workflow:
// 1. Load all events for a day
// 2. Replay events in chronological order
// 3. Build current state from scratch
// 4. Compare with stored state
// 5. If mismatch, flag integrity violation
//
// This ensures:
// - State is always consistent with history
// - Bugs can be replayed and understood
// - Corruption is detected at startup
// - Truth is rebuild-able, not permanent
//
// Think of it like a Git repository:
// - Events = commits (immutable history)
// - State = working directory (derived, verifiable)
// - Validation = "git fsck" (integrity check)

class StateDerivationEngine {
  final LedgerEventLog _eventLog;

  StateDerivationEngine({required LedgerEventLog eventLog}) : _eventLog = eventLog;

  // ===========================================================================
  // STATE DERIVATION
  // ===========================================================================

  /// Rebuild a task's state from its events (ground truth)
  Future<TaskEntity> deriveTaskState(String taskId) async {
    final events = await _eventLog.getEventsForTask(taskId);

    if (events.isEmpty) {
      throw StateDerivationException('No events found for task $taskId');
    }

    // Start from task creation event
    final firstEvent = events.first;
    if (firstEvent.eventType != 'task_started') {
      throw StateDerivationException(
        'Task $taskId: first event must be task_started, got ${firstEvent.eventType}',
      );
    }

    // Initialize state from first event
    String state = 'planned';
    int actualMinutes = 0;
    DateTime? startedAt;
    DateTime? completedAt;
    String? whatWorked;
    String? impediment;

    // Replay each event in order
    for (final event in events) {
      switch (event.eventType) {
        case 'task_started':
          state = 'active';
          startedAt = event.timestamp;
          break;

        case 'task_completed':
          state = 'completed';
          actualMinutes = event.metadata?['actualMinutes'] as int? ?? 0;
          whatWorked = event.metadata?['whatWorked'] as String?;
          impediment = event.metadata?['impediment'] as String?;
          completedAt = event.timestamp;
          break;

        case 'task_abandoned':
          state = 'abandoned';
          // Keep startedAt for reference
          break;

        case 'integrity_violation':
          // Log but don't let it affect state
          // (violation is recorded, not merged)
          break;

        default:
          // Unknown event type - flag for concern
          throw StateDerivationException(
            'Unknown event type for task: ${event.eventType}',
          );
      }
    }

    // Reconstruct task entity from derived state
    final taskEvents = await _eventLog.getEventsForTask(taskId);
    final firstTaskEvent = taskEvents.first;

    return TaskEntity(
      id: taskId,
      name: '', // Name not tracked in events (stored separately)
      estimatedMinutes: 0, // Estimate not in events
      actualMinutes: actualMinutes,
      state: state,
      createdAt: firstTaskEvent.timestamp,
      startedAt: startedAt,
      completedAt: completedAt,
      whatWorked: whatWorked,
      impediment: impediment,
    );
  }

  /// Rebuild a day's state from its events
  Future<DayEntity> deriveDayState(String dayDate) async {
    final events = await _eventLog.getEventsForDay(dayDate);

    if (events.isEmpty) {
      throw StateDerivationException('No events found for day $dayDate');
    }

    String state = 'open';
    DateTime? lockedAt;
    final taskIds = <String>[];

    // Replay events
    for (final event in events) {
      switch (event.eventType) {
        case 'task_started':
        case 'task_completed':
        case 'task_abandoned':
          // Collect task IDs
          if (event.taskId != null && !taskIds.contains(event.taskId)) {
            taskIds.add(event.taskId!);
          }
          break;

        case 'day_sealed':
          state = 'locked';
          lockedAt = event.timestamp;
          break;

        default:
          break;
      }
    }

    return DayEntity(
      date: dayDate,
      state: state,
      taskIds: taskIds,
      createdAt: events.first.timestamp,
      lockedAt: lockedAt,
    );
  }
}

// =============================================================================
// INTEGRITY VALIDATOR - Phase 6 Validation
// =============================================================================
//
// On startup, validate that stored state matches derived state.
// If not, something corrupted the database outside the normal flow.

class IntegrityValidator {
  final LedgerEventLog _eventLog;
  final StateDerivationEngine _derivationEngine;

  IntegrityValidator({
    required LedgerEventLog eventLog,
    required StateDerivationEngine derivationEngine,
  })  : _eventLog = eventLog,
        _derivationEngine = derivationEngine;

  /// Validate a task's state against its event log
  Future<IntegrityValidationResult> validateTask(
    String taskId,
    TaskEntity? storedState,
  ) async {
    try {
      final derived = await _derivationEngine.deriveTaskState(taskId);

      // Compare states
      if (storedState == null) {
        return IntegrityValidationResult(
          isValid: false,
          taskId: taskId,
          issue: 'Task has events but no stored state',
          storedState: null,
          derivedState: derived,
        );
      }

      // Check critical fields
      if (derived.state != storedState.state) {
        return IntegrityValidationResult(
          isValid: false,
          taskId: taskId,
          issue: 'State mismatch: derived=${derived.state}, stored=${storedState.state}',
          storedState: storedState,
          derivedState: derived,
        );
      }

      if (derived.actualMinutes != storedState.actualMinutes) {
        return IntegrityValidationResult(
          isValid: false,
          taskId: taskId,
          issue: 'Actual minutes mismatch: derived=${derived.actualMinutes}, stored=${storedState.actualMinutes}',
          storedState: storedState,
          derivedState: derived,
        );
      }

      return IntegrityValidationResult(
        isValid: true,
        taskId: taskId,
        issue: null,
        storedState: storedState,
        derivedState: derived,
      );
    } catch (e) {
      return IntegrityValidationResult(
        isValid: false,
        taskId: taskId,
        issue: 'Derivation error: $e',
        storedState: storedState,
        derivedState: null,
      );
    }
  }

  /// Validate a day's state
  Future<IntegrityValidationResult> validateDay(
    String dayDate,
    DayEntity? storedState,
  ) async {
    try {
      final derived = await _derivationEngine.deriveDayState(dayDate);

      if (storedState == null) {
        return IntegrityValidationResult(
          isValid: false,
          dayDate: dayDate,
          issue: 'Day has events but no stored state',
          storedState: null,
          derivedState: derived,
        );
      }

      if (derived.state != storedState.state) {
        return IntegrityValidationResult(
          isValid: false,
          dayDate: dayDate,
          issue: 'State mismatch: derived=${derived.state}, stored=${storedState.state}',
          storedState: storedState,
          derivedState: derived,
        );
      }

      if (derived.taskIds.length != storedState.taskIds.length) {
        return IntegrityValidationResult(
          isValid: false,
          dayDate: dayDate,
          issue: 'Task count mismatch: derived=${derived.taskIds.length}, stored=${storedState.taskIds.length}',
          storedState: storedState,
          derivedState: derived,
        );
      }

      return IntegrityValidationResult(
        isValid: true,
        dayDate: dayDate,
        issue: null,
        storedState: storedState,
        derivedState: derived,
      );
    } catch (e) {
      return IntegrityValidationResult(
        isValid: false,
        dayDate: dayDate,
        issue: 'Derivation error: $e',
        storedState: storedState,
        derivedState: null,
      );
    }
  }

  /// Validate entire system (run on app startup)
  Future<SystemIntegrityReport> validateSystem() async {
    final violations = <IntegrityValidationResult>[];
    final validations = <IntegrityValidationResult>[];

    try {
      // Get all events
      final allEvents = await _eventLog.getAllEvents();

      // Group by day
      final eventsByDay = <String, List<LedgerEvent>>{};
      for (final event in allEvents) {
        eventsByDay.putIfAbsent(event.dayDate, () => []).add(event);
      }

      // Validate each day
      for (final dayDate in eventsByDay.keys) {
        // TODO: In real implementation, load storedState from repository
        final result = await validateDay(dayDate, null);
        if (result.isValid) {
          validations.add(result);
        } else {
          violations.add(result);
        }
      }

      return SystemIntegrityReport(
        isHealthy: violations.isEmpty,
        totalChecks: validations.length + violations.length,
        passedChecks: validations.length,
        failedChecks: violations.length,
        violations: violations,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return SystemIntegrityReport(
        isHealthy: false,
        totalChecks: 0,
        passedChecks: 0,
        failedChecks: 1,
        violations: [],
        timestamp: DateTime.now(),
        error: 'System validation failed: $e',
      );
    }
  }
}

// =============================================================================
// VALIDATION RESULTS
// =============================================================================

class IntegrityValidationResult {
  final bool isValid;
  final String? taskId;
  final String? dayDate;
  final String? issue;
  final dynamic storedState;
  final dynamic derivedState;

  IntegrityValidationResult({
    required this.isValid,
    this.taskId,
    this.dayDate,
    this.issue,
    this.storedState,
    this.derivedState,
  });

  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'taskId': taskId,
      'dayDate': dayDate,
      'issue': issue,
      'storedState': storedState,
      'derivedState': derivedState,
    };
  }
}

class SystemIntegrityReport {
  final bool isHealthy;
  final int totalChecks;
  final int passedChecks;
  final int failedChecks;
  final List<IntegrityValidationResult> violations;
  final DateTime timestamp;
  final String? error;

  SystemIntegrityReport({
    required this.isHealthy,
    required this.totalChecks,
    required this.passedChecks,
    required this.failedChecks,
    required this.violations,
    required this.timestamp,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'isHealthy': isHealthy,
      'totalChecks': totalChecks,
      'passedChecks': passedChecks,
      'failedChecks': failedChecks,
      'violations': violations.map((v) => v.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'error': error,
    };
  }
}

// =============================================================================
// EXCEPTIONS
// =============================================================================

class StateDerivationException implements Exception {
  final String message;

  StateDerivationException(this.message);

  @override
  String toString() => 'StateDerivationException: $message';
}

