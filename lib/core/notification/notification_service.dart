import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _systemReminderChannel = MethodChannel(
    'grow_together/system_reminders',
  );
  static Future<void>? _initFuture;
  static bool _localNotificationsReady = false;

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
      _localNotificationsReady = true;
    } catch (error, stackTrace) {
      _localNotificationsReady = false;
      debugPrint('Local notification setup skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> schedulePlanReminder({
    required String planId,
    required String planTitle,
    required int hour,
    required int minute,
    DateTime? scheduledDate,
    bool repeatsDaily = true,
    bool syncSystemAlarm = false,
  }) async {
    final scheduledAt = _scheduledTime(hour, minute, scheduledDate);
    if (scheduledAt == null) {
      await cancelPlanReminder(planId);
      return;
    }

    try {
      await init();
      if (_localNotificationsReady) {
        await _cancelNotificationIds(planId);

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
          _notificationId(planId),
          '⏰ 该打卡啦',
          '「$planTitle」今天还没有完成哦～',
          scheduledAt,
          details,
          androidScheduleMode: await _androidScheduleMode(),
          matchDateTimeComponents: repeatsDaily
              ? DateTimeComponents.time
              : null,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Plan reminder schedule failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (syncSystemAlarm && _shouldCreateSystemAlarm(scheduledAt)) {
      await _setSystemAlarm(
        title: '一起进步呀：$planTitle',
        hour: hour,
        minute: minute,
      );
    }
  }

  static Future<void> cancelPlanReminder(String planId) async {
    try {
      await init();
      if (!_localNotificationsReady) return;
      await _cancelNotificationIds(planId);
    } catch (_) {}
  }

  static Future<void> showPushNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await init();
      if (!_localNotificationsReady) return;
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

  static tz.TZDateTime? _scheduledTime(
    int hour,
    int minute,
    DateTime? scheduledDate,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    if (scheduledDate == null) {
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      return scheduled;
    }

    final scheduled = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );
    return scheduled.isAfter(now) ? scheduled : null;
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

  static Future<AndroidScheduleMode> _androidScheduleMode() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return AndroidScheduleMode.exactAllowWhileIdle;

    final canScheduleExact =
        await androidPlugin.canScheduleExactNotifications() ?? false;
    return canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<void> _cancelNotificationIds(String planId) async {
    final legacyId = planId.hashCode;
    final currentId = _notificationId(planId);
    await _plugin.cancel(legacyId);
    if (currentId != legacyId) {
      await _plugin.cancel(currentId);
    }
  }

  static int _notificationId(String planId) => planId.hashCode & 0x7fffffff;

  static bool _shouldCreateSystemAlarm(tz.TZDateTime scheduledAt) {
    final now = tz.TZDateTime.now(tz.local);
    return scheduledAt.year == now.year &&
        scheduledAt.month == now.month &&
        scheduledAt.day == now.day &&
        scheduledAt.isAfter(now);
  }

  static Future<void> _setSystemAlarm({
    required String title,
    required int hour,
    required int minute,
  }) async {
    try {
      await _systemReminderChannel.invokeMethod<void>('setOneTimeAlarm', {
        'title': title,
        'hour': hour,
        'minute': minute,
      });
    } catch (error) {
      debugPrint('System alarm setup skipped: $error');
    }
  }
}
