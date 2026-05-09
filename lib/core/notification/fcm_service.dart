import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'notification_service.dart';

class FcmService {
  FcmService._();
  static bool _started = false;
  static StreamSubscription<AuthState>? _authSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static String? _lastSyncedUserId;
  static String? _lastSyncedToken;

  static Future<void> init() async {
    if (_started) return;
    if (!SupabaseConfig.isConfigured || kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (error) {
      debugPrint('Firebase init skipped: $error');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // 请求通知权限
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      await _syncCurrentToken(messaging);

      _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen(
        _saveTokenToSupabase,
      );
      _authSubscription ??= Supabase.instance.client.auth.onAuthStateChange
          .listen((state) {
            if (state.session == null) return;
            unawaited(syncTokenToCurrentUser());
          });
      _messageSubscription ??= FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _started = true;
    } catch (error, stackTrace) {
      debugPrint('FCM setup skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> syncTokenToCurrentUser() async {
    if (!SupabaseConfig.isConfigured || kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await _syncCurrentToken(FirebaseMessaging.instance);
    } catch (error) {
      debugPrint('FCM token sync skipped: $error');
    }
  }

  static Future<void> _syncCurrentToken(FirebaseMessaging messaging) async {
    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');
    if (token == null || token.isEmpty) {
      debugPrint('FCM token is empty; push notifications cannot be delivered.');
      return;
    }

    await _saveTokenToSupabase(token);
  }

  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('FCM token sync skipped: no authenticated user yet.');
        return;
      }
      if (_lastSyncedUserId == userId && _lastSyncedToken == token) return;

      await Supabase.instance.client.rpc(
        'save_fcm_token',
        params: {'p_token': token},
      );
      _lastSyncedUserId = userId;
      _lastSyncedToken = token;
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? '一起进步呀';
    final body = notification?.body ?? message.data['body'] as String? ?? '';
    if (body.isEmpty) return;

    NotificationService.showPushNotification(
      id: message.messageId.hashCode,
      title: title,
      body: body,
    );
  }
}
