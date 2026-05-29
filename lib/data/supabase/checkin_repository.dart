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

  /// 为任意日期（过去或未来）提交打卡，调用 upsert_checkin_for_date RPC。
  Future<void> upsertCheckinForDate({
    required String planId,
    required DateTime date,
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) async {
    // yyyy-MM-dd 格式，不依赖 intl 包
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    await _supabase.rpc('upsert_checkin_for_date', params: {
      'p_plan_id': planId,
      'p_date': dateStr,
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
