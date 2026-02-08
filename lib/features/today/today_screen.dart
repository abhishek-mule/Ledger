import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ledger/app/routes.dart';
import 'package:ledger/features/today/today_models.dart';
import 'package:ledger/features/today/today_controller.dart';
import 'package:ledger/features/today/today_widgets.dart';
import 'package:ledger/shared/colors.dart';
import 'package:ledger/shared/text_styles.dart';
import 'package:ledger/shared/data/ledger_repository.dart';
import 'package:ledger/shared/data/entities.dart';

// =============================================================================
// TODAY SCREEN - Daily Commitment Interface
// =============================================================================
//
// Maximum 3 non-negotiable tasks per day.
// Clear, minimal interface. No fluff.
//
// Microcopy is direct and accountability-focused.

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TodayController(),
      child: const _TodayView(),
    );
  }
}

class _TodayView extends StatelessWidget {
  const _TodayView();

  void _startTask(BuildContext context, int index) {
    final controller = Provider.of<TodayController>(context, listen: false);
    controller.startTask(index);
    Navigator.pushNamed(context, Routes.activeTask);
  }

  void _addTask(BuildContext context) {
    // TODO: Show task input dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add task dialog - TODO'),
      ),
    );
  }

  void _sealDay(BuildContext context) async {
    final repo = Provider.of<LedgerRepository>(context, listen: false);
    final controller = Provider.of<TodayController>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Seal Day?',
          style: TextStyles.titleLarge,
        ),
        content: const Text(
          'This will:\n'
          '• Lock all remaining tasks\n'
          '• Mark unattempted tasks as missed\n'
          '• Freeze this day forever\n\n'
          'This cannot be undone.',
          style: TextStyles.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'SEAL DAY',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      controller.sealDay();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day sealed. History is now immutable.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<TodayController>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Today',
          style: TextStyles.headlineMedium,
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current date
              Text(
                _formatDate(DateTime.now()),
                style: TextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Task count - direct numbers
              Row(
                children: [
                  Text(
                    '${controller.taskCount}/3 tasks',
                    style: TextStyles.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (controller.taskCount > 0)
                    TextButton(
                      onPressed: () => _sealDay(context),
                      child: const Text(
                        'SEAL DAY',
                        style: TextStyle(color: AppColors.warning),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Task list
              Expanded(
                child: controller.tasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        itemCount: controller.tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return TaskCard(
                            task: controller.tasks[index],
                            onStart: () => _startTask(context, index),
                          );
                        },
                      ),
              ),

              // Add task button
              if (controller.canAddTask)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addTask(context),
                    icon: const Icon(Icons.add),
                    label: const Text('ADD TASK'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}';
  }

  String _weekday(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  String _month(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 64,
            color: AppColors.textTertiary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks committed',
            style: TextStyles.bodyLarge.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Max 3 non-negotiable tasks',
            style: TextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
