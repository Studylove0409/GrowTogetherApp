import 'package:flutter/material.dart';

import '../../core/notification/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/plan_icon_mapper.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/reminder.dart';
import '../store/store.dart';
import 'mock_data.dart';

/// Mock 实现的 Store。
///
/// 当前数据来源为内存 mock。后续 SupabaseStore 实现同一接口后，
/// 顶层 Provider 切换注入即可，页面层零改动。
class MockStore extends Store {
  MockStore._()
    : _plans = List.of(MockData.plans),
      _reminders = List.of(MockData.reminders);

  static final MockStore instance = MockStore._();

  // ========================= 数据源 =========================

  final List<Plan> _plans;
  final List<Reminder> _reminders;

  // ========================= Profile =========================

  @override
  Profile getProfile() => MockData.profile;

  @override
  Future<void> refreshProfile() async {}

  // ========================= Plan =========================

  @override
  List<Plan> getPlans() {
    return List.unmodifiable(_plans.where((p) => !p.isEnded));
  }

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) {
    return _plans.where((plan) => plan.owner == owner && !plan.isEnded).toList();
  }

  @override
  List<Plan> getTodayFocusPlans() {
    final active = _plans.where((p) => !p.isEnded).toList()
      ..sort(_comparePlanPriority);
    return List.unmodifiable(active.take(3));
  }

  @override
  List<Plan> getAllPlans() {
    return List.unmodifiable(_plans);
  }

  @override
  Plan? getPlanById(String id) {
    for (final plan in _plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  @override
  Future<Plan> createPlan({
    required String title,
    required bool isShared,
    required String dailyTask,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay reminderTime,
    String iconKey = PlanIconMapper.defaultKey,
  }) async {
    final owner = isShared ? PlanOwner.together : PlanOwner.me;
    final totalDays = endDate.difference(startDate).inDays + 1;
    final plan = Plan(
      id: 'plan_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      subtitle: dailyTask,
      owner: owner,
      iconKey: iconKey,
      minutes: 20,
      completedDays: 0,
      totalDays: totalDays < 1 ? 1 : totalDays,
      doneToday: false,
      color: isShared ? AppColors.primary : AppColors.reminder,
      dailyTask: dailyTask,
      startDate: startDate,
      endDate: endDate,
      reminderTime: reminderTime,
    );

    _plans.insert(0, plan);
    notifyListeners();
    _scheduleReminder(plan);
    return plan;
  }

  @override
  Future<void> updatePlan({
    required String planId,
    String? title,
    String? dailyTask,
    String? iconKey,
    TimeOfDay? reminderTime,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;

    final plan = _plans[index];
    if (!plan.canCurrentUserEdit) return;

    final totalDays = (endDate ?? plan.endDate)
        .difference(startDate ?? plan.startDate)
        .inDays + 1;

    _plans[index] = plan.copyWith(
      title: title,
      subtitle: dailyTask ?? (dailyTask != null ? '' : null),
      dailyTask: dailyTask,
      iconKey: iconKey,
      reminderTime: reminderTime,
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays < 1 ? 1 : totalDays,
    );
    notifyListeners();
    if (reminderTime != null) {
      _scheduleReminder(_plans[index]);
    }
  }

  @override
  Future<void> endPlan(String planId) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;

    final plan = _plans[index];
    if (!plan.canCurrentUserEdit) return;

    _plans[index] = plan.copyWith(
      status: PlanStatus.ended,
      endedAt: DateTime.now(),
    );
    notifyListeners();
    NotificationService.cancelPlanReminder(planId);
  }

  // ========================= Checkin =========================

  @override
  List<CheckinRecord> getCheckinRecords(String planId) {
    final plan = getPlanById(planId);
    if (plan == null) return [];
    return List.unmodifiable(plan.checkins);
  }

  @override
  Future<void> saveCheckin({
    required String planId,
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;

    final plan = _plans[index];
    if (!plan.canCurrentUserCheckin) return;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final checkins = [
      CheckinRecord(
        date: todayOnly,
        completed: completed,
        mood: mood,
        note: note.trim(),
        actor: CheckinActor.me,
      ),
      ...plan.checkins.where(
        (record) =>
            record.actor != CheckinActor.me ||
            !_isSameDate(record.date, todayOnly),
      ),
    ];

    final wasDoneToday = plan.doneToday;
    final completedDays = completed && !wasDoneToday
        ? plan.completedDays + 1
        : !completed && wasDoneToday
        ? (plan.completedDays - 1).clamp(0, plan.totalDays)
        : plan.completedDays;

    _plans[index] = plan.copyWith(
      doneToday: completed,
      completedDays: completedDays,
      checkins: checkins,
    );
    notifyListeners();
  }

  @override
  Future<void> updatePlanStatus(String planId, {required bool doneToday}) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;

    final plan = _plans[index];
    if (!plan.canCurrentUserCheckin) return;
    _plans[index] = plan.copyWith(doneToday: doneToday);
    notifyListeners();
  }

  // ========================= Reminder =========================

  @override
  List<Reminder> getReminders() {
    return List.unmodifiable(_reminders);
  }

  @override
  int get unreadReminderCount =>
      _reminders.where((r) => !r.sentByMe && !r.isRead).length;

  @override
  Future<void> sendReminder({
    required String planId,
    required ReminderType type,
    required String content,
  }) async {
    _reminders.insert(0, Reminder(
      id: 'rem_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      content: content,
      fromUserId: 'current-user',
      toUserId: 'partner',
      sentByMe: true,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  // ========================= 辅助 =========================

  /// 计划优先级用于首页排序：我待打卡 > TA 待打卡 > 已完成
  static int planPriority(Plan plan) {
    final myUndone = switch (plan.owner) {
      PlanOwner.me => !plan.doneToday,
      PlanOwner.together => !plan.doneToday,
      PlanOwner.partner => false,
    };
    if (myUndone) return 0;

    final partnerUndone = switch (plan.owner) {
      PlanOwner.partner => !plan.partnerDoneToday,
      PlanOwner.together => !plan.partnerDoneToday,
      PlanOwner.me => false,
    };
    if (partnerUndone) return 1;

    return 2;
  }

  static int _comparePlanPriority(Plan a, Plan b) {
    return planPriority(a).compareTo(planPriority(b));
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _scheduleReminder(Plan plan) {
    NotificationService.schedulePlanReminder(
      planId: plan.id,
      planTitle: plan.title,
      hour: plan.reminderTime.hour,
      minute: plan.reminderTime.minute,
    );
  }
}
