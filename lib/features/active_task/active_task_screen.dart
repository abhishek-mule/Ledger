import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ledger/app/routes.dart';
import 'package:ledger/shared/colors.dart';
import 'package:ledger/shared/text_styles.dart';
import 'package:ledger/shared/data/entities.dart';
import 'package:ledger/shared/data/ledger_repository.dart';

// =============================================================================
// ACTIVE TASK SCREEN - Focus Enforcement
// =============================================================================
//
// Distraction-free timer. No secondary actions.
// Session is saved to handle app kill/resume.
//
// Microcopy is minimal and functional.

class ActiveTaskScreen extends StatefulWidget {
  const ActiveTaskScreen({super.key});

  @override
  State<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends State<ActiveTaskScreen> {
  bool _isRunning = false;
  int _elapsedSeconds = 0;
  String? _taskId;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final repo = Provider.of<LedgerRepository>(context, listen: false);
    final session = await repo.loadSession();

    if (session != null && session.hasActiveTask) {
      setState(() {
        _taskId = session.activeTaskId;
        _elapsedSeconds = session.getElapsedMinutes() * 60;
      });
    }
  }

  Future<void> _saveSession() async {
    final repo = Provider.of<LedgerRepository>(context, listen: false);
    await repo.saveSession(
      SessionState(
        activeTaskId: _taskId,
        sessionStartedAt:
            DateTime.now().subtract(Duration(seconds: _elapsedSeconds)),
        lastHeartbeat: DateTime.now(),
      ),
    );
  }

  void _toggleTimer() {
    setState(() {
      _isRunning = !_isRunning;
    });

    if (_isRunning) {
      _saveSession();
      _startTimer();
    }
  }

  void _startTimer() {
    // Simple timer - in production, use background isolate
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_isRunning) {
        setState(() {
          _elapsedSeconds++;
        });
      }
      return _isRunning;
    });
  }

  void _finishTask() {
    final actualMinutes = (_elapsedSeconds / 60).round();

    Navigator.pushReplacementNamed(
      context,
      Routes.reflection,
      arguments: {
        'taskId': _taskId,
        'actualMinutes': actualMinutes,
      },
    );
  }

  void _abandonTask() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Abandon Task',
          style: TextStyles.titleLarge,
        ),
        content: const Text(
          'Why are you abandoning? This will be recorded.',
          style: TextStyles.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeAbandonment('Lost focus');
            },
            child: const Text(
              'Lost Focus',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeAbandonment('Wrong estimate');
            },
            child: const Text(
              'Wrong Estimate',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeAbandonment(String reason) async {
    final repo = Provider.of<LedgerRepository>(context, listen: false);
    final task = await repo.getTask(_taskId!);
    if (task == null) return;

    await repo.abandonTask(task, reason: reason);
    await repo.clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, Routes.today);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Active',
          style: TextStyles.titleMedium,
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _abandonTask,
            child: const Text(
              'ABANDON',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Task name placeholder
              const Text(
                'Write Documentation',
                style: TextStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '60 min planned',
                style: TextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 64),

              // Large static timer
              Text(
                _formatTime(_elapsedSeconds),
                style: TextStyles.timerDisplay,
              ),
              const SizedBox(height: 64),

              // Start/Pause button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _toggleTimer,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: Text(
                    _isRunning ? 'PAUSE' : 'START',
                    style: TextStyles.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Finish button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _finishTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: const Text(
                    'FINISH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
