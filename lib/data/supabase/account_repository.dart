import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/account_identity.dart';

class AccountRepository {
  const AccountRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<AccountIdentity> getCurrentIdentity() async {
    if (!SupabaseConfig.isConfigured) {
      return const AccountIdentity(isConfigured: false, isAnonymous: true);
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const AccountIdentity(isConfigured: true, isAnonymous: true);
    }

    return AccountIdentity(
      isConfigured: true,
      isAnonymous: user.isAnonymous,
      email: user.email,
      emailConfirmedAt: user.emailConfirmedAt,
    );
  }

  Future<void> linkEmail(String email) async {
    await _supabase.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: SupabaseConfig.emailRedirectTo,
    );
  }

  Future<void> setPassword(String password) async {
    await _supabase.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
    await _supabase.rpc(
      'create_profile_for_current_user',
      params: {'p_nickname': '一起进步的你'},
    );
  }

  Future<void> signOutToAnonymous() async {
    await _supabase.auth.signOut();
    await _supabase.auth.signInAnonymously();
    await _supabase.rpc(
      'create_profile_for_current_user',
      params: {'p_nickname': '一起进步的你'},
    );
  }
}
