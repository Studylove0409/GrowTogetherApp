package com.growtogether.grow_together

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.AlarmClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "grow_together/system_reminders",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setDailyAlarm" -> {
                    val title = call.argument<String>("title") ?: "一起进步呀计划提醒"
                    val hour = call.argument<Int>("hour")
                    val minute = call.argument<Int>("minute")

                    if (hour == null || minute == null) {
                        result.error("invalid_arguments", "hour and minute are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        setDailyAlarm(title, hour, minute)
                        result.success(null)
                    } catch (error: ActivityNotFoundException) {
                        result.error("alarm_app_not_found", "No alarm app can handle SET_ALARM", null)
                    } catch (error: Exception) {
                        result.error("alarm_setup_failed", error.message, null)
                    }
                }

                "setOneTimeAlarm" -> {
                    val title = call.argument<String>("title") ?: "一起进步呀计划提醒"
                    val hour = call.argument<Int>("hour")
                    val minute = call.argument<Int>("minute")

                    if (hour == null || minute == null) {
                        result.error("invalid_arguments", "hour and minute are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        setOneTimeAlarm(title, hour, minute)
                        result.success(null)
                    } catch (error: ActivityNotFoundException) {
                        result.error("alarm_app_not_found", "No alarm app can handle SET_ALARM", null)
                    } catch (error: Exception) {
                        result.error("alarm_setup_failed", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun setDailyAlarm(title: String, hour: Int, minute: Int) {
        val days = arrayListOf(
            Calendar.MONDAY,
            Calendar.TUESDAY,
            Calendar.WEDNESDAY,
            Calendar.THURSDAY,
            Calendar.FRIDAY,
            Calendar.SATURDAY,
            Calendar.SUNDAY,
        )
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_MESSAGE, title)
            putExtra(AlarmClock.EXTRA_HOUR, hour)
            putExtra(AlarmClock.EXTRA_MINUTES, minute)
            putExtra(AlarmClock.EXTRA_DAYS, days)
            putExtra(AlarmClock.EXTRA_SKIP_UI, true)
        }

        startActivity(intent)
    }

    private fun setOneTimeAlarm(title: String, hour: Int, minute: Int) {
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_MESSAGE, title)
            putExtra(AlarmClock.EXTRA_HOUR, hour)
            putExtra(AlarmClock.EXTRA_MINUTES, minute)
            putExtra(AlarmClock.EXTRA_SKIP_UI, true)
        }

        startActivity(intent)
    }
}
