import 'package:flutter/material.dart';
import 'package:ledger/features/today/today_models.dart';
import 'package:ledger/shared/colors.dart';
import 'package:ledger/shared/text_styles.dart';

// TaskCard - Pure UI component, knows nothing about business logic
// ==============================================================
// Visual representation of a task based on its TaskState.
// Receives TaskItem and callbacks - no knowledge of state machine rules.

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onStart;

  const TaskCard({
    super.key,
    required this.task,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: task.canStart ? onStart : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor,
              ),
            ),
            const SizedBox(width: 12),

            // Task info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: TextStyles.titleMedium.copyWith(
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${task.estimatedMinutes} min estimate',
                    style: TextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Start button (only when planned)
            if (task.canStart)
              ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 0),
                ),
                child: const Text('Start'),
              ),
          ],
        ),
      ),
    );
  }

  Color get _backgroundColor {
    return switch (task.state) {
      TaskState.active => AppColors.primary.withOpacity(0.1),
      TaskState.completed => AppColors.success.withOpacity(0.1),
      TaskState.abandoned => AppColors.error.withOpacity(0.1),
      TaskState.planned => AppColors.surfaceDark,
    };
  }

  Color get _borderColor {
    return switch (task.state) {
      TaskState.active => AppColors.primary,
      TaskState.completed => AppColors.success,
      TaskState.abandoned => AppColors.error,
      TaskState.planned => AppColors.gray700,
    };
  }

  Color get _statusColor {
    return switch (task.state) {
      TaskState.active => AppColors.primary,
      TaskState.completed => AppColors.success,
      TaskState.abandoned => AppColors.error,
      TaskState.planned => AppColors.textTertiary,
    };
  }

  Color get _textColor {
    return switch (task.state) {
      TaskState.active => AppColors.textPrimary,
      TaskState.completed || TaskState.abandoned => AppColors.textSecondary,
      TaskState.planned => AppColors.textPrimary,
    };
  }
}
