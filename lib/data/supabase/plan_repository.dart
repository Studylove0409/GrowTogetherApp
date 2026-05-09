import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/utils/plan_icon_mapper.dart';
import '../models/plan.dart';

class PlanRepository {
  const PlanRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  // ========================= 读 =========================

  Future<List<Plan>> fetchActivePlans() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    final coupleId = await _activeCoupleId();
    if (coupleId == null) return [];

    final plans = await _fetchPlans(coupleId, currentUserId);
    return plans.where(_isVisibleInActiveLists).toList();
  }

  Future<List<Plan>> fetchAllPlans() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    final coupleId = await _activeCoupleId();
    if (coupleId == null) return [];

    return _fetchPlans(coupleId, currentUserId);
  }

  Future<Plan?> fetchPlanById(String planId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return null;

    final planRow = await _supabase
        .from('plans')
        .select('*')
        .eq('id', planId)
        .maybeSingle();

    if (planRow == null) return null;

    final coupleId = planRow['couple_id'] as String;
    final partnerId = await _partnerId(coupleId);
    if (partnerId == null) return null;

    return _rowToPlan(
      planRow,
      todayCheckinMap: await _todayCheckinMap([planId], currentUserId),
      completedCountMap: await _completedCountMap([planId], currentUserId),
      currentUserId: currentUserId,
      partnerId: partnerId,
    );
  }

  Future<List<CheckinRecord>> fetchCheckinRecords(String planId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    final rows = await _supabase
        .from('checkins')
        .select('*')
        .eq('plan_id', planId)
        .order('checkin_date', ascending: false);

    return rows.map((row) => _rowToCheckinRecord(row, currentUserId)).toList();
  }

  // ========================= 写 =========================

  Future<Plan> createPlan({
    required bool isShared,
    required String title,
    required String dailyTask,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay? reminderTime,
    PlanRepeatType repeatType = PlanRepeatType.once,
    bool hasDateRange = true,
    String iconKey = PlanIconMapper.defaultKey,
  }) async {
    final coupleId = await _activeCoupleId();
    if (coupleId == null) {
      throw const PostgrestException(message: 'no active couple relationship');
    }

    final effectiveHasDateRange =
        repeatType == PlanRepeatType.daily && hasDateRange;
    final payload = {
      'couple_id': coupleId,
      'creator_id': _currentUserId,
      'plan_type': isShared ? 'shared' : 'personal',
      'repeat_type': _fromRepeatType(repeatType),
      'title': title,
      'description': dailyTask,
      'daily_task': dailyTask,
      'icon_key': iconKey,
      'start_date': _formatDate(startDate),
      'end_date': _formatDate(endDate),
      'remind_time': reminderTime == null ? null : _fromTimeOfDay(reminderTime),
      'has_date_range': effectiveHasDateRange,
    };

    final result = await _insertPlanWithScheduleFallback(payload);

    final plan = _rowToPlan(
      result,
      todayCheckinMap: {},
      completedCountMap: {},
      currentUserId: _currentUserId!,
      partnerId: await _partnerId(coupleId) ?? '',
    );
    if (result.containsKey('has_date_range') &&
        result.containsKey('repeat_type')) {
      return plan;
    }

    return plan.copyWith(
      repeatType: repeatType,
      hasDateRange: effectiveHasDateRange,
      totalDays: effectiveHasDateRange
          ? endDate.difference(startDate).inDays + 1
          : 1,
    );
  }

  Future<void> updatePlan({
    required String planId,
    String? title,
    String? dailyTask,
    String? iconKey,
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
    PlanRepeatType? repeatType,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasDateRange,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (dailyTask != null) {
      updates['daily_task'] = dailyTask;
      updates['description'] = dailyTask;
    }
    if (iconKey != null) updates['icon_key'] = iconKey;
    if (repeatType != null) {
      updates['repeat_type'] = _fromRepeatType(repeatType);
    }
    if (clearReminderTime) {
      updates['remind_time'] = null;
    } else if (reminderTime != null) {
      updates['remind_time'] = _fromTimeOfDay(reminderTime);
    }
    if (startDate != null) updates['start_date'] = _formatDate(startDate);
    if (endDate != null) updates['end_date'] = _formatDate(endDate);
    if (hasDateRange != null) updates['has_date_range'] = hasDateRange;

    if (updates.isEmpty) return;

    try {
      await _supabase.from('plans').update(updates).eq('id', planId);
    } on PostgrestException catch (error) {
      if (!_isMissingOptionalPlanColumn(error)) {
        rethrow;
      }

      final fallbackUpdates = _withoutOptionalPlanColumns(updates);
      if (fallbackUpdates.isEmpty) return;
      await _supabase.from('plans').update(fallbackUpdates).eq('id', planId);
    }
  }

  Future<void> endPlan(String planId) async {
    await _supabase
        .from('plans')
        .update({
          'status': 'ended',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', planId);
  }

  // ========================= 内部查询 =========================

  Future<List<Plan>> _fetchPlans(
    String coupleId,
    String currentUserId, {
    String? status,
  }) async {
    var query = _supabase.from('plans').select('*').eq('couple_id', coupleId);
    if (status != null) query = query.eq('status', status);

    final planRows = await query.order('created_at', ascending: false);
    if (planRows.isEmpty) return [];

    final planIds = planRows.map((r) => r['id'] as String).toList();
    final partnerId = await _partnerId(coupleId);
    if (partnerId == null) return [];

    final todayCheckinMap = await _todayCheckinMap(planIds, currentUserId);
    final completedCountMap = await _completedCountMap(planIds, currentUserId);

    return [
      for (final row in planRows)
        _rowToPlan(
          row,
          todayCheckinMap: todayCheckinMap,
          completedCountMap: completedCountMap,
          currentUserId: currentUserId,
          partnerId: partnerId,
        ),
    ];
  }

  // ========================= Plan 构建 =========================

  Plan _rowToPlan(
    Map<String, dynamic> row, {
    required Map<String, _UserCheckinStatus> todayCheckinMap,
    required Map<String, int> completedCountMap,
    required String currentUserId,
    required String partnerId,
  }) {
    final planId = row['id'] as String;
    final iconKey = row['icon_key'] as String? ?? PlanIconMapper.defaultKey;
    final startDate = DateTime.parse(row['start_date'] as String);
    final endDate = DateTime.parse(row['end_date'] as String);
    final hasDateRange = row['has_date_range'] as bool? ?? true;
    final repeatType = _toRepeatType(row['repeat_type'] as String?);
    final description = row['description'] as String?;
    final dailyTask = row['daily_task'] as String;

    final owner = _deriveOwner(
      row['plan_type'] as String,
      row['creator_id'] as String,
      currentUserId,
      partnerId,
    );

    final todayStatus = todayCheckinMap[planId] ?? _UserCheckinStatus();
    final completedDays = completedCountMap[planId] ?? 0;

    return Plan(
      id: planId,
      title: row['title'] as String,
      subtitle: (description != null && description.isNotEmpty)
          ? description
          : dailyTask,
      owner: owner,
      iconKey: iconKey,
      minutes: 20,
      completedDays: completedDays,
      totalDays: endDate.difference(startDate).inDays + 1,
      doneToday: todayStatus.currentUserCompleted,
      color: PlanIconMapper.color(iconKey),
      dailyTask: dailyTask,
      startDate: startDate,
      endDate: endDate,
      reminderTime: _toTimeOfDay(row['remind_time'] as String?),
      repeatType: repeatType,
      hasDateRange: hasDateRange,
      partnerDoneToday: todayStatus.partnerCompleted,
      status: _toStatus(row['status'] as String?),
      endedAt: row['ended_at'] != null
          ? DateTime.tryParse(row['ended_at'] as String)?.toLocal()
          : null,
    );
  }

  // ========================= CheckinRecord 构建 =========================

  CheckinRecord _rowToCheckinRecord(
    Map<String, dynamic> row,
    String currentUserId,
  ) {
    return CheckinRecord(
      date: DateTime.parse(row['checkin_date'] as String),
      completed: row['status'] == 'completed',
      mood: _toMood(row['mood'] as String?) ?? CheckinMood.happy,
      note: row['note'] as String? ?? '',
      actor: row['user_id'] == currentUserId
          ? CheckinActor.me
          : CheckinActor.partner,
    );
  }

  // ========================= 枚举推导 =========================

  PlanOwner _deriveOwner(
    String planType,
    String creatorId,
    String currentUserId,
    String partnerId,
  ) {
    if (planType == 'shared') return PlanOwner.together;
    return creatorId == currentUserId ? PlanOwner.me : PlanOwner.partner;
  }

  PlanStatus _toStatus(String? dbStatus) {
    return dbStatus == 'ended' ? PlanStatus.ended : PlanStatus.active;
  }

  PlanRepeatType _toRepeatType(String? dbRepeatType) {
    return dbRepeatType == 'once' ? PlanRepeatType.once : PlanRepeatType.daily;
  }

  String _fromRepeatType(PlanRepeatType repeatType) => switch (repeatType) {
    PlanRepeatType.once => 'once',
    PlanRepeatType.daily => 'daily',
  };

  CheckinMood? _toMood(String? dbMood) => switch (dbMood) {
    'happy' => CheckinMood.happy,
    'normal' => CheckinMood.normal,
    'tired' => CheckinMood.tired,
    'great' => CheckinMood.great,
    _ => null,
  };

  // ========================= 关系查询 =========================

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<String?> _activeCoupleId() async {
    final data = await _supabase
        .from('couples')
        .select('id')
        .eq('status', 'active')
        .or('user_a_id.eq.$_currentUserId,user_b_id.eq.$_currentUserId')
        .maybeSingle();
    return data?['id'] as String?;
  }

  Future<String?> _partnerId(String coupleId) async {
    final data = await _supabase
        .from('couples')
        .select('user_a_id, user_b_id')
        .eq('id', coupleId)
        .maybeSingle();
    if (data == null) return null;

    final userA = data['user_a_id'] as String;
    final userB = data['user_b_id'] as String;
    return userA == _currentUserId ? userB : userA;
  }

  // ========================= 今日打卡状态 =========================

  Future<Map<String, _UserCheckinStatus>> _todayCheckinMap(
    List<String> planIds,
    String currentUserId,
  ) async {
    if (planIds.isEmpty) return {};

    final today = DateTime.now();
    final todayStr = _formatDate(today);

    final rows = await _supabase
        .from('checkins')
        .select('plan_id, user_id, status')
        .inFilter('plan_id', planIds)
        .eq('checkin_date', todayStr);

    final map = <String, _UserCheckinStatus>{};
    for (final row in rows) {
      final planId = row['plan_id'] as String;
      final userId = row['user_id'] as String;
      final isCompleted = row['status'] == 'completed';

      final status = map.putIfAbsent(planId, () => _UserCheckinStatus());
      if (userId == currentUserId) {
        status.currentUserCompleted = isCompleted;
      } else {
        status.partnerCompleted = isCompleted;
      }
    }
    return map;
  }

  // ========================= 完成计数 =========================

  Future<Map<String, int>> _completedCountMap(
    List<String> planIds,
    String currentUserId,
  ) async {
    if (planIds.isEmpty) return {};

    final rows = await _supabase
        .from('checkins')
        .select('plan_id')
        .inFilter('plan_id', planIds)
        .eq('user_id', currentUserId)
        .eq('status', 'completed');

    final map = <String, int>{};
    for (final row in rows) {
      final planId = row['plan_id'] as String;
      map[planId] = (map[planId] ?? 0) + 1;
    }
    return map;
  }

  // ========================= 格式化 =========================

  Future<Map<String, dynamic>> _insertPlanWithScheduleFallback(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _supabase.from('plans').insert(payload).select().single();
    } on PostgrestException catch (error) {
      if (!_isMissingOptionalPlanColumn(error)) rethrow;

      final fallbackPayload = _withoutOptionalPlanColumns(payload);
      return await _supabase
          .from('plans')
          .insert(fallbackPayload)
          .select()
          .single();
    }
  }

  bool _isMissingOptionalPlanColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return (message.contains('has_date_range') ||
            message.contains('repeat_type')) &&
        (error.code == 'PGRST204' ||
            error.code == '42703' ||
            message.contains('column'));
  }

  Map<String, dynamic> _withoutOptionalPlanColumns(Map<String, dynamic> input) {
    return Map<String, dynamic>.of(input)
      ..remove('has_date_range')
      ..remove('repeat_type');
  }

  bool _isVisibleInActiveLists(Plan plan) {
    if (!plan.isEnded) return true;
    final endedAt = plan.endedAt;
    if (endedAt == null || !plan.isOnce) return false;
    final now = DateTime.now();
    return endedAt.year == now.year &&
        endedAt.month == now.month &&
        endedAt.day == now.day;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  TimeOfDay? _toTimeOfDay(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _fromTimeOfDay(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }
}

class _UserCheckinStatus {
  bool currentUserCompleted = false;
  bool partnerCompleted = false;
}
