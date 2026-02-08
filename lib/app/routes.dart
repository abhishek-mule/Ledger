import 'package:flutter/material.dart';
import 'package:ledger/features/today/today_screen.dart';
import 'package:ledger/features/active_task/active_task_screen.dart';
import 'package:ledger/features/reflection/reflection_screen.dart';
import 'package:ledger/features/reality/reality_screen.dart';

class Routes {
  static const String today = '/today';
  static const String activeTask = '/active-task';
  static const String reflection = '/reflection';
  static const String reality = '/reality';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case today:
        return MaterialPageRoute(
          builder: (_) => const TodayScreen(),
          settings: const RouteSettings(name: today),
        );
      case activeTask:
        return MaterialPageRoute(
          builder: (_) => const ActiveTaskScreen(),
          settings: const RouteSettings(name: activeTask),
        );
      case reflection:
        return MaterialPageRoute(
          builder: (_) => const ReflectionScreen(),
          settings: const RouteSettings(name: reflection),
        );
      case reality:
        return MaterialPageRoute(
          builder: (_) => const RealityScreen(),
          settings: const RouteSettings(name: reality),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            body: Center(
              child: Text(
                'Route not found: ${settings.name}',
                style: const TextStyle(
                  color: Color(0xFFE8E8E8),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
    }
  }
}
