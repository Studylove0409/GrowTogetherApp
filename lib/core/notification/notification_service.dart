import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);
  }

  static Future<void> schedulePlanReminder({
    required String planId,
    required String planTitle,
    required int hour,
    required int minute,
  }) async {
    try {
      await _plugin.cancel(planId.hashCode);

      const androidDetails = AndroidNotificationDetails(
        'plan_reminders',
        '计划提醒',
        channelDescription: '每日计划打卡提醒',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.zonedSchedule(
        planId.hashCode,
        '⏰ 该打卡啦',
        '「$planTitle」今天还没有完成哦～',
        _nextTime(hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // 测试环境或平台通道不可用时静默跳过
    }
  }

  static Future<void> cancelPlanReminder(String planId) async {
    try {
      await _plugin.cancel(planId.hashCode);
    } catch (_) {}
  }

  /// 收到伴侣提醒时触发通知
  static Future<void> showReminderReceived({
    required String reminderId,
    required String senderName,
    required String content,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'partner_reminders',
        '伴侣提醒',
        channelDescription: '伴侣发来的提醒消息',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        reminderId.hashCode,
        '$senderName 提醒你',
        content,
        details,
      );
    } catch (_) {}
  }

  static tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, hour, minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
