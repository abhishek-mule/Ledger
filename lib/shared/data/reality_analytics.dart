import 'package:ledger/shared/data/ledger_event.dart';

// =============================================================================
// REALITY ANALYTICS ENGINE - Phase 7
// =============================================================================
//
// CRITICAL DISTINCTION:
// - Time Committed: App was active (user interaction or background)
// - Time Focused: User actively interacting (keyboard, mouse, screen on)
// - Time Idle: App running but locked
//
// Current implementation measures "Time Committed" (start → resume).
// This is CORRECT for accountability but MUST be labeled as such.
//
// Analytics Goals:
// 1. Which tasks are systematically underestimated?
// 2. Which transitions lead to abandonment?
// 3. Where does actual > estimated the most?
// 4. How many sessions per task?
// 5. Average task completion rate by category
//
// Uses: The append-only event log (source of truth)

class RealityAnalytics {
  final LedgerEventLog _eventLog;

  RealityAnalytics({required LedgerEventLog eventLog}) : _eventLog = eventLog;

  // ===========================================================================
  // TASK ANALYSIS
  // ===========================================================================

  /// Analyze a single task's history
  Future<TaskAnalysis> analyzeTask(String taskId) async {
    final events = await _eventLog.getEventsForTask(taskId);

    if (events.isEmpty) {
      throw AnalyticsException('No events for task $taskId');
    }

    // Extract metadata from events
    int estimatedMinutes = 0;
    int actualMinutes = 0;
    int sessionCount = 0;
    DateTime? startedAt;
    DateTime? completedAt;
    String finalState = 'planned';
    final abandonReasons = <String>[];
    final interruptions = <SessionInterruption>[];

    for (final event in events) {
      switch (event.eventType) {
        case 'task_started':
          sessionCount++;
          startedAt = event.timestamp;
          finalState = 'active';
          break;

        case 'task_completed':
          actualMinutes = event.metadata?['actualMinutes'] as int? ?? 0;
          completedAt = event.timestamp;
          finalState = 'completed';
          break;

        case 'task_abandoned':
          final reason = event.metadata?['reason'] as String? ?? 'unknown';
          abandonReasons.add(reason);
          finalState = 'abandoned';
          break;

        case 'session_interrupted':
          interruptions.add(
            SessionInterruption(
              reason: event.metadata?['reason'] as String? ?? 'unknown',
              timestamp: event.timestamp,
            ),
          );
          break;

        default:
          break;
      }
    }

    // Calculate metrics
    final accuracy = estimatedMinutes > 0
        ? ((actualMinutes / estimatedMinutes) * 100).toStringAsFixed(1) + '%'
        : 'N/A';

    final varianceMinutes = actualMinutes - estimatedMinutes;

    return TaskAnalysis(
      taskId: taskId,
      estimatedMinutes: estimatedMinutes,
      actualMinutes: actualMinutes,
      varianceMinutes: varianceMinutes,
      accuracyPercent: accuracy,
      state: finalState,
      sessionCount: sessionCount,
      startedAt: startedAt,
      completedAt: completedAt,
      interruptionCount: interruptions.length,
      interruptions: interruptions,
      abandonReasons: abandonReasons,
      createdAt: events.first.timestamp,
    );
  }

  /// Analyze all tasks for a day
  Future<DayAnalysis> analyzeDay(String dayDate) async {
    final dayEvents = await _eventLog.getEventsForDay(dayDate);

    // Get unique task IDs for this day
    final taskIds = <String>{};
    for (final event in dayEvents) {
      if (event.taskId != null &&
          ['task_started', 'task_completed', 'task_abandoned'].contains(event.eventType)) {
        taskIds.add(event.taskId!);
      }
    }

    // Analyze each task
    final taskAnalyses = <TaskAnalysis>[];
    for (final taskId in taskIds) {
      try {
        final analysis = await analyzeTask(taskId);
        taskAnalyses.add(analysis);
      } catch (e) {
        // Skip tasks with errors
      }
    }

    // Calculate day-level metrics
    final completedTasks = taskAnalyses.where((t) => t.state == 'completed').length;
    final abandonedTasks = taskAnalyses.where((t) => t.state == 'abandoned').length;
    final totalEstimated = taskAnalyses.fold<int>(0, (sum, t) => sum + t.estimatedMinutes);
    final totalActual = taskAnalyses.fold<int>(0, (sum, t) => sum + t.actualMinutes);
    final totalVariance = totalActual - totalEstimated;

    // Find when day was sealed
    final sealedEvents = dayEvents.where((e) => e.eventType == 'day_sealed').toList();
    final sealedAt = sealedEvents.isNotEmpty ? sealedEvents.first.timestamp : null;

    return DayAnalysis(
      date: dayDate,
      taskCount: taskAnalyses.length,
      completedCount: completedTasks,
      abandonedCount: abandonedTasks,
      estimatedTotalMinutes: totalEstimated,
      actualTotalMinutes: totalActual,
      varianceTotalMinutes: totalVariance,
      tasks: taskAnalyses,
      sealed: sealedAt != null,
      sealedAt: sealedAt,
      metrics: DayMetrics(
        completionRate: taskAnalyses.isNotEmpty
            ? ((completedTasks / taskAnalyses.length) * 100).toStringAsFixed(1) + '%'
            : 'N/A',
        variancePercent: totalEstimated > 0
            ? ((totalVariance / totalEstimated) * 100).toStringAsFixed(1) + '%'
            : 'N/A',
      ),
    );
  }

  // ===========================================================================
  // PATTERN ANALYSIS
  // ===========================================================================

  /// Find tasks that are systematically underestimated
  Future<UnderestimationPattern> analyzeUnderestimation(List<String> taskIds) async {
    final analyses = <TaskAnalysis>[];
    for (final id in taskIds) {
      try {
        analyses.add(await analyzeTask(id));
      } catch (e) {
        // Skip
      }
    }

    // Group by variance
    analyses.sort((a, b) => b.varianceMinutes.compareTo(a.varianceMinutes));

    final worstUnderestimated = analyses
        .where((t) => t.varianceMinutes > 0)
        .take(10)
        .toList();

    final averageVariance = analyses.isNotEmpty
        ? (analyses.fold<int>(0, (sum, t) => sum + t.varianceMinutes) / analyses.length)
            .toStringAsFixed(1)
        : '0';

    return UnderestimationPattern(
      totalTasks: analyses.length,
      underestimatedTasks: analyses.where((t) => t.varianceMinutes > 0).length,
      overestimatedTasks: analyses.where((t) => t.varianceMinutes < 0).length,
      averageVarianceMinutes: double.parse(averageVariance),
      worstUnderestimated: worstUnderestimated,
    );
  }

  /// Find abandonment patterns
  Future<AbandonmentPattern> analyzeAbandonment(List<String> dayDates) async {
    final dayAnalyses = <DayAnalysis>[];
    for (final date in dayDates) {
      try {
        dayAnalyses.add(await analyzeDay(date));
      } catch (e) {
        // Skip
      }
    }

    // Collect all tasks
    final allTasks = <TaskAnalysis>[];
    final abandonReasons = <String, int>{};

    for (final day in dayAnalyses) {
      allTasks.addAll(day.tasks);
      for (final task in day.tasks) {
        for (final reason in task.abandonReasons) {
          abandonReasons[reason] = (abandonReasons[reason] ?? 0) + 1;
        }
      }
    }

    final abandonedTasks = allTasks.where((t) => t.state == 'abandoned').toList();
    final abandonmentRate = allTasks.isNotEmpty
        ? ((abandonedTasks.length / allTasks.length) * 100).toStringAsFixed(1) + '%'
        : 'N/A';

    return AbandonmentPattern(
      totalTasks: allTasks.length,
      abandonedTasks: abandonedTasks.length,
      abandonmentRate: abandonmentRate,
      reasonCounts: abandonReasons,
      mostCommonReason: abandonReasons.isEmpty
          ? 'None'
          : abandonReasons.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key,
    );
  }

  /// Find session patterns (how many times do users pick up a task?)
  Future<SessionPattern> analyzeSessionPatterns(List<String> taskIds) async {
    final analyses = <TaskAnalysis>[];
    for (final id in taskIds) {
      try {
        analyses.add(await analyzeTask(id));
      } catch (e) {
        // Skip
      }
    }

    final singleSessionTasks = analyses.where((t) => t.sessionCount == 1).length;
    final multiSessionTasks = analyses.where((t) => t.sessionCount > 1).length;
    final averageSessions = analyses.isNotEmpty
        ? (analyses.fold<int>(0, (sum, t) => sum + t.sessionCount) / analyses.length)
            .toStringAsFixed(1)
        : '0';

    return SessionPattern(
      totalTasks: analyses.length,
      singleSessionTasks: singleSessionTasks,
      multiSessionTasks: multiSessionTasks,
      averageSessionsPerTask: double.parse(averageSessions),
    );
  }

  // ===========================================================================
  // TIME ANALYSIS (The Critical Distinction)
  // ===========================================================================

  /// Analyze committed vs focused time
  /// COMMITTED: App was active (start to resume)
  /// FOCUSED: User actively interacting
  /// IDLE: App running but phone locked
  Future<TimeAnalysis> analyzeTime(String taskId) async {
    final events = await _eventLog.getEventsForTask(taskId);

    if (events.isEmpty) {
      throw AnalyticsException('No events for task $taskId');
    }

    int committedMinutes = 0;
    int interruptionCount = 0;
    DateTime? lastStarted;

    for (final event in events) {
      if (event.eventType == 'task_started') {
        lastStarted = event.timestamp;
      } else if (event.eventType == 'session_interrupted' && lastStarted != null) {
        final duration = event.timestamp.difference(lastStarted);
        committedMinutes += duration.inMinutes;
        interruptionCount++;
      }
    }

    return TimeAnalysis(
      taskId: taskId,
      committedMinutes: committedMinutes,
      interruptionCount: interruptionCount,
      note: 'COMMITTED TIME: App was active. User may have been idle (phone locked, etc.)',
    );
  }
}

// =============================================================================
// ANALYSIS RESULTS
// =============================================================================

class TaskAnalysis {
  final String taskId;
  final int estimatedMinutes;
  final int actualMinutes;
  final int varianceMinutes;
  final String accuracyPercent;
  final String state;
  final int sessionCount;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int interruptionCount;
  final List<SessionInterruption> interruptions;
  final List<String> abandonReasons;
  final DateTime createdAt;

  TaskAnalysis({
    required this.taskId,
    required this.estimatedMinutes,
    required this.actualMinutes,
    required this.varianceMinutes,
    required this.accuracyPercent,
    required this.state,
    required this.sessionCount,
    this.startedAt,
    this.completedAt,
    required this.interruptionCount,
    required this.interruptions,
    required this.abandonReasons,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'estimatedMinutes': estimatedMinutes,
      'actualMinutes': actualMinutes,
      'varianceMinutes': varianceMinutes,
      'accuracyPercent': accuracyPercent,
      'state': state,
      'sessionCount': sessionCount,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'interruptionCount': interruptionCount,
      'abandonReasons': abandonReasons,
    };
  }
}

class DayAnalysis {
  final String date;
  final int taskCount;
  final int completedCount;
  final int abandonedCount;
  final int estimatedTotalMinutes;
  final int actualTotalMinutes;
  final int varianceTotalMinutes;
  final List<TaskAnalysis> tasks;
  final bool sealed;
  final DateTime? sealedAt;
  final DayMetrics metrics;

  DayAnalysis({
    required this.date,
    required this.taskCount,
    required this.completedCount,
    required this.abandonedCount,
    required this.estimatedTotalMinutes,
    required this.actualTotalMinutes,
    required this.varianceTotalMinutes,
    required this.tasks,
    required this.sealed,
    this.sealedAt,
    required this.metrics,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'taskCount': taskCount,
      'completedCount': completedCount,
      'abandonedCount': abandonedCount,
      'estimatedTotalMinutes': estimatedTotalMinutes,
      'actualTotalMinutes': actualTotalMinutes,
      'varianceTotalMinutes': varianceTotalMinutes,
      'sealed': sealed,
      'sealedAt': sealedAt?.toIso8601String(),
      'metrics': metrics.toJson(),
    };
  }
}

class DayMetrics {
  final String completionRate;
  final String variancePercent;

  DayMetrics({
    required this.completionRate,
    required this.variancePercent,
  });

  Map<String, dynamic> toJson() {
    return {
      'completionRate': completionRate,
      'variancePercent': variancePercent,
    };
  }
}

class UnderestimationPattern {
  final int totalTasks;
  final int underestimatedTasks;
  final int overestimatedTasks;
  final double averageVarianceMinutes;
  final List<TaskAnalysis> worstUnderestimated;

  UnderestimationPattern({
    required this.totalTasks,
    required this.underestimatedTasks,
    required this.overestimatedTasks,
    required this.averageVarianceMinutes,
    required this.worstUnderestimated,
  });
}

class AbandonmentPattern {
  final int totalTasks;
  final int abandonedTasks;
  final String abandonmentRate;
  final Map<String, int> reasonCounts;
  final String mostCommonReason;

  AbandonmentPattern({
    required this.totalTasks,
    required this.abandonedTasks,
    required this.abandonmentRate,
    required this.reasonCounts,
    required this.mostCommonReason,
  });
}

class SessionPattern {
  final int totalTasks;
  final int singleSessionTasks;
  final int multiSessionTasks;
  final double averageSessionsPerTask;

  SessionPattern({
    required this.totalTasks,
    required this.singleSessionTasks,
    required this.multiSessionTasks,
    required this.averageSessionsPerTask,
  });
}

class SessionInterruption {
  final String reason;
  final DateTime timestamp;

  SessionInterruption({
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class TimeAnalysis {
  final String taskId;
  final int committedMinutes;
  final int interruptionCount;
  final String note;

  TimeAnalysis({
    required this.taskId,
    required this.committedMinutes,
    required this.interruptionCount,
    required this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'committedMinutes': committedMinutes,
      'interruptionCount': interruptionCount,
      'note': note,
    };
  }
}

// =============================================================================
// EXCEPTION
// =============================================================================

class AnalyticsException implements Exception {
  final String message;

  AnalyticsException(this.message);

  @override
  String toString() => 'AnalyticsException: $message';
}

