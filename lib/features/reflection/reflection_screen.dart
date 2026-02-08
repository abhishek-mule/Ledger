import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ledger/app/routes.dart';
import 'package:ledger/shared/colors.dart';
import 'package:ledger/shared/text_styles.dart';
import 'package:ledger/features/today/today_controller.dart';
import 'package:ledger/features/today/today_models.dart';

// =============================================================================
// REFLECTION SCREEN - Post-Mortem Quality Enforcement
// =============================================================================
//
// This screen forces honest reflection after task completion.
// Minimum character counts prevent lazy answers.
// If actual > estimated, failure reason is required.
//
// Microcopy is intentionally uncomfortable to reinforce accountability.

class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({super.key});

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  final TextEditingController _whatWorkedController = TextEditingController();
  final TextEditingController _impedimentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Minimum character counts for quality enforcement
  static const int _minWhatWorkedLength = 20;
  static const int _minImpedimentLength = 20;

  // Get data from previous screen (passed via route arguments)
  TaskItem? _task;
  int _actualMinutes = 0;

  @override
  void dispose() {
    _whatWorkedController.dispose();
    _impedimentController.dispose();
    super.dispose();
  }

  void _completeReflection() {
    if (!_formKey.currentState!.validate()) return;

    final controller = Provider.of<TodayController>(context, listen: false);
    final taskIndex = _findTaskIndex(controller);

    if (taskIndex >= 0) {
      controller.setReflection(
        taskIndex: taskIndex,
        whatWorked: _whatWorkedController.text,
        impediment: _impedimentController.text,
      );
    }

    Navigator.pushReplacementNamed(context, Routes.today);
  }

  int _findTaskIndex(TodayController controller) {
    // Find the task that was just completed
    for (int i = 0; i < controller.tasks.length; i++) {
      if (controller.tasks[i].state == TaskState.completed) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    // Get data from arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      _task = args['task'] as TaskItem?;
      _actualMinutes = args['actualMinutes'] ?? 0;
    }

    final estimatedMinutes = _task?.estimatedMinutes ?? 60;
    final timeDelta = _actualMinutes - estimatedMinutes;
    final isOver = timeDelta > 0;
    final percentError = estimatedMinutes > 0
        ? ((timeDelta.abs() / estimatedMinutes) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Post-Mortem',
          style: TextStyles.titleMedium,
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time comparison - cold numbers, no judgment
                Center(
                  child: Column(
                    children: [
                      // Estimated
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Planned',
                            style: TextStyles.labelMedium,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$estimatedMinutes min',
                            style: TextStyles.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Actual
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color:
                                  isOver ? AppColors.error : AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Actual',
                            style: TextStyles.labelMedium,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$_actualMinutes min',
                            style: TextStyles.titleLarge.copyWith(
                              color:
                                  isOver ? AppColors.error : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Error indicator - red when bad
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isOver
                              ? AppColors.error.withOpacity(0.1)
                              : AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOver ? AppColors.error : AppColors.success,
                          ),
                        ),
                        child: Text(
                          '${isOver ? 'Over' : 'Under'}: ${timeDelta.abs()} min ($percentError%)',
                          style: TextStyles.labelLarge.copyWith(
                            color: isOver ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // What worked - minimum character count
                const Text(
                  'What worked?',
                  style: TextStyles.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _whatWorkedController,
                  decoration: const InputDecoration(
                    hintText: 'Be specific. What actually helped?',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                  ),
                  style: TextStyles.bodyLarge,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required. Cannot be empty.';
                    }
                    if (value.trim().length < _minWhatWorkedLength) {
                      return 'Minimum $_minWhatWorkedLength characters. Quality matters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '$_minWhatWorkedLength minimum characters',
                  style: TextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 24),

                // What caused friction
                const Text(
                  'What went wrong?',
                  style: TextStyles.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _impedimentController,
                  decoration: const InputDecoration(
                    hintText: 'Be honest. What got in the way?',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                  ),
                  style: TextStyles.bodyLarge,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required. Cannot be empty.';
                    }
                    if (value.trim().length < _minImpedimentLength) {
                      return 'Minimum $_minImpedimentLength characters. Quality matters.';
                    }
                    // If over time, require explanation
                    if (isOver && value.trim().length < 50) {
                      return 'You went over estimate. Explain why (50+ chars).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '$_minImpedimentLength minimum characters${isOver ? ' (50+ if over estimate)' : ''}',
                  style: TextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 40),

                // Commit outcome button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _completeReflection,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text(
                      'COMMIT OUTCOME',
                      style: TextStyles.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
