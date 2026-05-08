import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        await auth.signInAnonymously();
      }

      await Supabase.instance.client.rpc(
        'create_profile_for_current_user',
        params: {'p_nickname': '一起进步的你'},
      );
    } on AuthException catch (error) {
      debugPrint('Supabase auth bootstrap skipped: ${error.message}');
    } on PostgrestException catch (error) {
      debugPrint('Supabase profile bootstrap skipped: ${error.message}');
    }
  }
}
