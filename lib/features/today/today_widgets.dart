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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Status indicator with enhanced visual
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor,
                boxShadow: [
                  BoxShadow(
                    color: _statusColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Task info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: TextStyles.titleMedium.copyWith(
                      color: _textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${task.estimatedMinutes} min',
                        style: TextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Start button (only when planned)
            if (task.canStart)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else if (task.state == TaskState.completed)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              )
            else if (task.state == TaskState.abandoned)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(
                  Icons.cancel_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
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
