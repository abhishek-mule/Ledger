package com.example.ledger

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "ledger/screen_forensics"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      if (call.method == "capture") {
        val args = call.arguments as? Map<*, *>
        val startMillis = (args?.get("startMillis") as? Number)?.toLong() ?: 0L
        val endMillis = (args?.get("endMillis") as? Number)?.toLong() ?: 0L

        val data = captureForensics(startMillis, endMillis)
        result.success(data)
      } else {
        result.notImplemented()
      }
    }
  }

  private fun captureForensics(startMillis: Long, endMillis: Long): Map<String, Any> {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
      // UsageStats APIs not available
      return mapOf(
        "unlockCount" to 0,
        "screenOnMinutes" to 0,
        "topApps" to listOf<Map<String, Any>>()
      )
    }

    val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
      ?: return mapOf(
        "unlockCount" to 0,
        "screenOnMinutes" to 0,
        "topApps" to listOf<Map<String, Any>>()
      )

    try {
      val events = usageStatsManager.queryEvents(startMillis, endMillis)
      val packageCount = mutableMapOf<String, Long>()
      var unlockCount = 0

      val event = UsageEvents.Event()
      while (events.hasNextEvent()) {
        events.getNextEvent(event)
        val pkg = event.packageName
        val eventType = event.eventType
        // Count MOVE_TO_FOREGROUND as a proxy for unlock/user resumption
        if (eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
          unlockCount += 1
          packageCount[pkg] = (packageCount[pkg] ?: 0L) + 1L
        }
      }

      // Build top apps list (top 5 by count)
      val topApps = packageCount.entries
        .sortedByDescending { it.value }
        .take(5)
        .map { mapOf("package" to it.key, "count" to it.value) }

      // screenOnMinutes is hard to get reliably without permissions; return 0 as conservative value
      val screenOnMinutes = 0

      return mapOf(
        "unlockCount" to unlockCount,
        "screenOnMinutes" to screenOnMinutes,
        "topApps" to topApps
      )
    } catch (e: Exception) {
      return mapOf(
        "unlockCount" to 0,
        "screenOnMinutes" to 0,
        "topApps" to listOf<Map<String, Any>>()
      )
    }
  }
}
