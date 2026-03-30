// FILE: android/app/src/main/kotlin/com/example/vida_app/DeviceUsagePlugin.kt
package com.example.vida_app

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

object DeviceUsagePlugin {
  private const val CHANNEL = "vida_app/device_usage"

  fun register(flutterEngine: FlutterEngine, context: Context) {
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        try {
          when (call.method) {
            "hasUsageAccess" -> result.success(hasUsageAccess(context))
            "openUsageAccessSettings" -> {
              openUsageAccessSettings(context)
              result.success(null)
            }
            "getTodayScreenTimeMinutes" -> result.success(getTodayScreenTimeMinutes(context))
            "getTodaySocialMediaMinutes" -> {
              val args = call.arguments as? Map<*, *>
              val pkgs = (args?.get("packages") as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
              result.success(getTodaySocialMediaMinutes(context, pkgs))
            }
            "getTodayNightUseMinutes" -> {
              val args = call.arguments as? Map<*, *>
              val startHour = (args?.get("startHour") as? Int) ?: 19
              val endHour = (args?.get("endHour") as? Int) ?: 4
              result.success(getTodayNightUseMinutes(context, startHour, endHour))
            }
            else -> result.notImplemented()
          }
        } catch (t: Throwable) {
          result.error("DEVICE_USAGE_ERROR", t.message, null)
        }
      }
  }

  private fun openUsageAccessSettings(context: Context) {
    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    context.startActivity(intent)
  }

  private fun hasUsageAccess(context: Context): Boolean {
    val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      appOps.unsafeCheckOpNoThrow(
        AppOpsManager.OPSTR_GET_USAGE_STATS,
        android.os.Process.myUid(),
        context.packageName
      )
    } else {
      @Suppress("DEPRECATION")
      appOps.checkOpNoThrow(
        AppOpsManager.OPSTR_GET_USAGE_STATS,
        android.os.Process.myUid(),
        context.packageName
      )
    }
    return mode == AppOpsManager.MODE_ALLOWED
  }

  private fun getTodayRangeMillis(): Pair<Long, Long> {
    val cal = Calendar.getInstance()
    val end = cal.timeInMillis
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    val start = cal.timeInMillis
    return Pair(start, end)
  }

  private fun queryMinutes(
    context: Context,
    startMillis: Long,
    endMillis: Long,
    allowPackages: Set<String>? = null
  ): Int? {
    if (!hasUsageAccess(context)) return null

    val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    val stats: List<UsageStats> = usm.queryUsageStats(
      UsageStatsManager.INTERVAL_DAILY,
      startMillis,
      endMillis
    ) ?: return null

    var totalMs = 0L
    for (s in stats) {
      val pkg = s.packageName ?: continue
      if (allowPackages != null && !allowPackages.contains(pkg)) continue
      totalMs += s.totalTimeInForeground
    }
    val minutes = (totalMs / 60000L).toInt()
    return if (minutes < 0) 0 else minutes
  }

  private fun getTodayScreenTimeMinutes(context: Context): Int? {
    val (start, end) = getTodayRangeMillis()
    return queryMinutes(context, start, end, null)
  }

  private fun getTodaySocialMediaMinutes(context: Context, packages: List<String>): Int? {
    val (start, end) = getTodayRangeMillis()
    val allow = packages.toSet()
    return queryMinutes(context, start, end, allow)
  }

  // Night window may cross midnight (e.g. 19 -> 4)
  private fun getTodayNightUseMinutes(context: Context, startHour: Int, endHour: Int): Int? {
    if (!hasUsageAccess(context)) return null

    val now = Calendar.getInstance()

    fun at(hour: Int, minute: Int, second: Int): Calendar {
      val c = Calendar.getInstance()
      c.set(Calendar.YEAR, now.get(Calendar.YEAR))
      c.set(Calendar.MONTH, now.get(Calendar.MONTH))
      c.set(Calendar.DAY_OF_MONTH, now.get(Calendar.DAY_OF_MONTH))
      c.set(Calendar.HOUR_OF_DAY, hour)
      c.set(Calendar.MINUTE, minute)
      c.set(Calendar.SECOND, second)
      c.set(Calendar.MILLISECOND, 0)
      return c
    }

    // Window parts:
    // Part A: today startHour -> 23:59:59
    // Part B: today 00:00:00 -> endHour (only if endHour < startHour)
    val startA = at(startHour, 0, 0).timeInMillis
    val endA = at(23, 59, 59).timeInMillis

    val partA = queryMinutes(context, startA, endA, null) ?: 0

    if (endHour >= startHour) {
      // same-day window (rare)
      val endSameDay = at(endHour, 0, 0).timeInMillis
      val sameDay = queryMinutes(context, startA, endSameDay, null) ?: 0
      return sameDay
    }

    val startB = at(0, 0, 0).timeInMillis
    val endB = at(endHour, 0, 0).timeInMillis
    val partB = queryMinutes(context, startB, endB, null) ?: 0

    return partA + partB
  }
}