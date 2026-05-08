import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/notification/fcm_service.dart';
import 'core/notification/notification_service.dart';
import 'data/supabase/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFF8F1),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const GrowTogetherApp());
  unawaited(_initializeNotifications());
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService.init();
    await FcmService.init();
  } catch (error, stackTrace) {
    debugPrint('Notification bootstrap skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
