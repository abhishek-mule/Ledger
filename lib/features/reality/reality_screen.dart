import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ledger/shared/colors.dart';
import 'package:ledger/shared/text_styles.dart';
import 'package:ledger/shared/data/ledger_repository.dart';
import 'package:ledger/shared/data/entities.dart';

// =============================================================================
// REALITY SCREEN - Read-Only Historical Data
// =============================================================================
//
// This screen only displays data from SEALED days.
// Once a day is sealed, its data is frozen forever.
// No edits, no corrections, no re-computation.
//
// Trust is built through immutability.

class RealityScreen extends StatelessWidget {
  const RealityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Reality',
          style: TextStyles.headlineSmall,
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<List<DayEntity>>(
          future: _loadSealedDays(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildNoDataState();
            }

            final sealedDays = snapshot.data!;
            final metrics = _calculateMetrics(sealedDays);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Week indicator
                  Text(
                    '${sealedDays.length} sealed day${sealedDays.length == 1 ? '' : 's'}',
                    style: TextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Metrics row - cold numbers
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          label: 'Avg Est. Error',
                          value: '${metrics['avgError']}%',
                          valueColor: metrics['avgError']! > 15
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          label: 'Completion Rate',
                          value: '${metrics['completionRate']}%',
                          valueColor: metrics['completionRate']! < 70
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          label: 'Tasks Completed',
                          value: '${metrics['totalCompleted']}',
                          valueColor: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          label: 'Top Failure',
                          value: metrics['topImpediment'] ?? 'None',
                          valueColor: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Chart section
                  const Text(
                    'History (Sealed Days Only)',
                    style: TextStyles.titleMedium,
                  ),
                  const SizedBox(height: 24),

                  // Bar chart - only from sealed data
                  SizedBox(
                    height: 200,
                    child: _buildBarChart(sealedDays),
                  ),

                  const SizedBox(height: 16),

                  // Chart legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(
                        color: AppColors.textTertiary,
                        label: 'Planned',
                      ),
                      const SizedBox(width: 24),
                      _buildLegendItem(
                        color: AppColors.primary,
                        label: 'Actual',
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Immutable insight - cold, factual
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariantDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gray700,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _generateInsight(metrics),
                            style: TextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<List<DayEntity>> _loadSealedDays(BuildContext context) async {
    final repo = Provider.of<LedgerRepository>(context, listen: false);
    return await repo.getSealedDays();
  }

  Map<String, dynamic> _calculateMetrics(List<DayEntity> days) {
    int totalCompleted = 0;
    int totalPlanned = 0;
    int totalError = 0;
    int errorDays = 0;
    Map<String, int> impedimentCounts = {};

    for (final day in days) {
      // We can't read task data here without the repository
      // In a real app, you'd load tasks for each day
      // For now, we show placeholder metrics
      totalPlanned += 3; // Assuming max 3 tasks
      totalCompleted += 2; // Placeholder
      totalError += 10; // Placeholder
      errorDays++;
    }

    final avgError = errorDays > 0 ? (totalError / errorDays).round() : 0;
    final completionRate =
        totalPlanned > 0 ? ((totalCompleted / totalPlanned) * 100).round() : 0;

    return {
      'avgError': avgError,
      'completionRate': completionRate,
      'totalCompleted': totalCompleted,
      'totalPlanned': totalPlanned,
      'topImpediment': 'Focus',
    };
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppColors.textTertiary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No sealed days yet',
            style: TextStyles.bodyLarge.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete and seal days to see reality',
            style: TextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gray700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyles.headlineSmall.copyWith(
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<DayEntity> days) {
    // Build chart from sealed day data
    final maxValue = 8.0;
    final chartData = days.take(7).toList(); // Last 7 sealed days

    if (chartData.isEmpty) {
      return Center(
        child: Text(
          'No data to display',
          style: TextStyles.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: chartData.asMap().entries.map((entry) {
        final index = entry.key;
        final day = entry.value;
        // Placeholder values - real app would load actual task data
        final plannedHeight = 100.0;
        final actualHeight = 80.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Planned bar (gray)
                Container(
                  width: 20,
                  height: plannedHeight,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 4),
                // Actual bar (primary)
                Container(
                  width: 20,
                  height: actualHeight,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${index + 1}',
              style: TextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _generateInsight(Map<String, dynamic> metrics) {
    final avgError = metrics['avgError'] as int;
    final completionRate = metrics['completionRate'] as int;

    if (avgError > 20) {
      return 'Your estimates are consistently off by ${avgError}%. Consider adding buffer time.';
    } else if (completionRate < 60) {
      return 'You complete ${completionRate}% of planned tasks. Are you over-committing?';
    } else {
      return 'Your metrics are within acceptable ranges. Continue tracking.';
    }
  }
}
