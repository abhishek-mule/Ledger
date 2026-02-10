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
    // TodayController is provided at the app level (in LedgerApp), so simply
    // return the view. The controller is available via Provider.of<TodayController>(context).
    return const _TodayView();
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
    final nameController = TextEditingController();
    final minutesController = TextEditingController(text: '30');

    // Capture controller from the surrounding context BEFORE opening a dialog.
    // Dialog builder gets a new BuildContext that may not include the provider,
    // so using Provider.of inside the dialog can fail with ProviderNotFoundException.
    final controller = Provider.of<TodayController>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Add Task',
          style: TextStyles.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'What needs to be done?',
                labelStyle: TextStyles.bodyLarge,
              ),
              style: TextStyles.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated minutes',
                labelStyle: TextStyles.bodyLarge,
              ),
              style: TextStyles.bodyLarge,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final minutes = int.tryParse(minutesController.text) ?? 30;

              if (name.isNotEmpty) {
                // Use the controller captured from the outer context instead of
                // calling Provider.of inside the dialog's context.
                controller.addTask(name: name, estimatedMinutes: minutes);
                Navigator.pop(context);
              }
            },
            child: const Text('ADD'),
          ),
        ],
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
        title: const Text('Today'),
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and status
              _buildHeader(context, controller),
              const SizedBox(height: 32),

              // Task count indicator
              _buildTaskIndicator(controller),
              const SizedBox(height: 20),

              // Task list
              Expanded(
                child: controller.tasks.isEmpty
                    ? _buildEmptyState()
                    : _buildTaskList(context, controller),
              ),

              // Add task button
              if (controller.canAddTask)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _addTask(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Task'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TodayController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDate(DateTime.now()),
          style: TextStyles.labelMedium.copyWith(
            color: AppColors.textTertiary,
            fontSize: 12,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Daily Commitments',
          style: TextStyles.headlineLarge.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskIndicator(TodayController controller) {
    final progress = controller.taskCount / 3.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.surfaceVariantDark,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${controller.taskCount} of 3 tasks',
                style: TextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariantDark,
              valueColor: AlwaysStoppedAnimation<Color>(
                controller.taskCount >= 3 ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, TodayController controller) {
    return ListView.separated(
      itemCount: controller.tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return TaskCard(
          task: controller.tasks[index],
          onStart: () => _startTask(context, index),
        );
      },
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
