import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _initFuture;

  static Future<void> init() async {
    _initFuture ??= _init();
    await _initFuture;
  }

  static Future<void> _init() async {
    tz.initializeTimeZones();
    await _setLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    try {
      await _plugin.initialize(settings);
      await _configureAndroid();
    } catch (error, stackTrace) {
      debugPrint('Local notification setup skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> schedulePlanReminder({
    required String planId,
    required String planTitle,
    required int hour,
    required int minute,
    bool syncSystemAlarm = false,
  }) async {
    try {
      await init();
      await _plugin.cancel(planId.hashCode);

      const androidDetails = AndroidNotificationDetails(
        'plan_reminders',
        '计划提醒',
        channelDescription: '每日计划打卡提醒',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
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

    // Do not create Android Clock alarms here. They cannot be reliably
    // cancelled by plan id, so date-bounded plans would keep ringing after
    // their end date. Cancellable local notifications are used instead.
  }

  static Future<void> cancelPlanReminder(String planId) async {
    try {
      await init();
      await _plugin.cancel(planId.hashCode);
    } catch (_) {}
  }

  static Future<void> showPushNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await init();
      const androidDetails = AndroidNotificationDetails(
        'partner_reminders',
        '伴侣提醒',
        channelDescription: '伴侣发来的提醒消息',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }

  static tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> _setLocalTimeZone() async {
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } catch (error) {
      debugPrint('Local timezone setup skipped: $error');
    }
  }

  static Future<void> _configureAndroid() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    await androidPlugin.requestNotificationsPermission();

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'plan_reminders',
        '计划提醒',
        description: '每日计划打卡提醒',
        importance: Importance.high,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'partner_reminders',
        '伴侣提醒',
        description: '伴侣发来的提醒消息',
        importance: Importance.high,
      ),
    );
  }
}
