import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/notification/fcm_service.dart';
import 'core/notification/notification_service.dart';
import 'data/cache/profile_cache_service.dart';
import 'data/models/profile.dart';
import 'data/supabase/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  final initialProfile = await _readInitialProfileCache();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFF8F1),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(GrowTogetherApp(initialProfile: initialProfile));
  unawaited(_initializeNotifications());
}

Future<Profile?> _readInitialProfileCache() async {
  if (!SupabaseConfig.isConfigured) return null;

  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final snapshot = await const ProfileCacheService().readProfile(userId);
    return snapshot?.profile;
  } catch (error, stackTrace) {
    debugPrint('Initial profile cache read skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
    return null;
  }
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
