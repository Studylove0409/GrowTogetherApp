import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reminder.dart';

class ReminderRepository {
  const ReminderRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<void> sendReminder({
    required String planId,
    required String type,
    required String content,
  }) async {
    await _supabase.rpc('send_reminder', params: {
      'p_plan_id': planId,
      'p_type': type,
      'p_content': content,
    });
  }

  Future<void> markReminderRead(String reminderId) async {
    await _supabase.rpc('mark_reminder_read', params: {
      'p_reminder_id': reminderId,
    });
  }

  Future<List<Reminder>> fetchReminders() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    final rows = await _supabase
        .from('reminders')
        .select('*, from_user_id, to_user_id')
        .or('from_user_id.eq.$currentUserId,to_user_id.eq.$currentUserId')
        .order('created_at', ascending: false);

    return rows.map((row) {
      final fromUserId = row['from_user_id'] as String;
      return Reminder(
        id: row['id'] as String,
        type: _toType(row['type'] as String),
        content: row['content'] as String,
        fromUserId: fromUserId,
        toUserId: row['to_user_id'] as String,
        planId: row['plan_id'] as String?,
        isRead: row['is_read'] as bool? ?? false,
        sentByMe: fromUserId == currentUserId,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
    }).toList();
  }

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  ReminderType _toType(String dbType) => switch (dbType) {
    'strict' => ReminderType.strict,
    'encourage' => ReminderType.encourage,
    'praise' => ReminderType.praise,
    _ => ReminderType.gentle,
  };
}
