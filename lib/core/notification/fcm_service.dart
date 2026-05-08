import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  FcmService._();

  static Future<void> init() async {
    await Firebase.initializeApp();

    final messaging = FirebaseMessaging.instance;

    // 请求通知权限
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 获取 FCM token
    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');

    if (token != null) {
      await _saveTokenToSupabase(token);
    }

    // 监听 token 刷新
    messaging.onTokenRefresh.listen(_saveTokenToSupabase);
  }

  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }
}
