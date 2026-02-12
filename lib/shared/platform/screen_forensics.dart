import 'dart:async';
import 'package:flutter/services.dart';

class ScreenForensicsResult {
  final int unlockCount;
  final int screenOnMinutes;
  final List<Map<String, dynamic>> topApps;

  ScreenForensicsResult({
    required this.unlockCount,
    required this.screenOnMinutes,
    required this.topApps,
  });

  factory ScreenForensicsResult.fromMap(Map<dynamic, dynamic> map) {
    return ScreenForensicsResult(
      unlockCount: map['unlockCount'] as int? ?? 0,
      screenOnMinutes: map['screenOnMinutes'] as int? ?? 0,
      topApps: ((map['topApps'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

class ScreenForensics {
  static const MethodChannel _channel = MethodChannel('ledger/screen_forensics');

  /// Capture forensic metrics for a time window (start/end in milliseconds since epoch)
  /// Returns best-effort metrics. On platforms where metrics aren't available, returns zeros.
  static Future<ScreenForensicsResult> capture({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final result = await _channel.invokeMethod('capture', {
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
      });

      if (result is Map) {
        return ScreenForensicsResult.fromMap(result);
      }
    } catch (e) {
      // Graceful fallback - return zeros
    }

    return ScreenForensicsResult(unlockCount: 0, screenOnMinutes: 0, topApps: []);
  }
}

