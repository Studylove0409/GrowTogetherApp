import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan.dart';

class CheckinRepository {
  const CheckinRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// 写入或更新今日打卡。RPC 自动推导 user_id 和 checkin_date。
  Future<void> upsertTodayCheckin({
    required String planId,
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) async {
    await _supabase.rpc('upsert_today_checkin', params: {
      'p_plan_id': planId,
      'p_status': completed ? 'completed' : 'uncompleted',
      'p_mood': _fromMood(mood),
      'p_note': note.isEmpty ? null : note,
    });
  }

  String _fromMood(CheckinMood mood) => switch (mood) {
    CheckinMood.happy => 'happy',
    CheckinMood.normal => 'normal',
    CheckinMood.tired => 'tired',
    CheckinMood.great => 'great',
  };
}
