import 'package:flutter/material.dart';

import '../../core/notification/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/plan_icon_mapper.dart';
import '../models/focus_session.dart';
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
  final List<FocusSession> _focusSessions = [];

  // ========================= Profile =========================

  @override
  Profile getProfile() => MockData.profile;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<void> refreshPlans() async {}

  @override
  Future<void> refreshReminders() async {}

  @override
  Future<void> refreshFocusSessions() async {}

  @override
  Future<void> refreshAll() async {}

  // ========================= Plan =========================

  @override
  List<Plan> getPlans() {
    return List.unmodifiable(_plans.where(_isVisibleInActiveLists));
  }

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) {
    return _plans
        .where((plan) => plan.owner == owner && _isVisibleInActiveLists(plan))
        .toList();
  }

  @override
  List<Plan> getTodayFocusPlans() {
    final active = _plans.where(_isVisibleInActiveLists).toList()
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
    required TimeOfDay? reminderTime,
    PlanRepeatType repeatType = PlanRepeatType.once,
    bool hasDateRange = true,
    String iconKey = PlanIconMapper.defaultKey,
  }) async {
    final owner = isShared ? PlanOwner.together : PlanOwner.me;
    final effectiveHasDateRange =
        repeatType == PlanRepeatType.daily && hasDateRange;
    final totalDays = effectiveHasDateRange
        ? endDate.difference(startDate).inDays + 1
        : 1;
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
      repeatType: repeatType,
      hasDateRange: effectiveHasDateRange,
    );

    _plans.insert(0, plan);
    notifyListeners();
    if (plan.hasReminder) {
      _scheduleReminder(plan, syncSystemAlarm: true);
    }
    return plan;
  }

  @override
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
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;

    final plan = _plans[index];
    if (!plan.canCurrentUserEdit) return;

    final updatedRepeatType = repeatType ?? plan.repeatType;
    final updatedHasDateRange =
        updatedRepeatType == PlanRepeatType.daily &&
        (hasDateRange ?? plan.hasDateRange);
    final totalDays = updatedHasDateRange
        ? (endDate ?? plan.endDate)
                  .difference(startDate ?? plan.startDate)
                  .inDays +
              1
        : 1;

    _plans[index] = plan.copyWith(
      title: title,
      subtitle: dailyTask ?? (dailyTask != null ? '' : null),
      dailyTask: dailyTask,
      iconKey: iconKey,
      reminderTime: reminderTime,
      clearReminderTime: clearReminderTime,
      repeatType: updatedRepeatType,
      startDate: startDate,
      endDate: endDate,
      hasDateRange: updatedHasDateRange,
      totalDays: totalDays < 1 ? 1 : totalDays,
    );
    notifyListeners();
    if (clearReminderTime) {
      await NotificationService.cancelPlanReminder(planId);
    } else if (reminderTime != null) {
      _scheduleReminder(_plans[index], syncSystemAlarm: true);
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
    _finishOncePlanIfComplete(index);
    notifyListeners();
  }

  @override
  Future<void> updatePlanStatus(
    String planId, {
    required bool doneToday,
  }) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;

    final plan = _plans[index];
    if (!plan.canCurrentUserCheckin) return;
    _plans[index] = plan.copyWith(doneToday: doneToday);
    _finishOncePlanIfComplete(index);
    notifyListeners();
  }

  // ========================= Focus =========================

  @override
  List<FocusSession> getFocusSessions() {
    return List.unmodifiable(_focusSessions);
  }

  @override
  List<FocusSession> getTodayFocusSessions() {
    final today = DateTime.now();
    return List.unmodifiable(
      _focusSessions.where(
        (session) => session.isSameDay(today) && !session.isActive,
      ),
    );
  }

  @override
  List<FocusSession> getActiveFocusSessions() {
    return List.unmodifiable(
      _focusSessions.where((session) => session.isActive),
    );
  }

  @override
  List<FocusSession> getIncomingFocusInvites() {
    return List.unmodifiable(
      _focusSessions.where((session) => session.canJoin),
    );
  }

  @override
  Future<void> saveFocusSession(FocusSession session) async {
    _focusSessions.insert(0, session);
    _applyFocusScore(session);
    notifyListeners();
  }

  @override
  Future<FocusSession> createCoupleFocusInvite({
    required Plan plan,
    required int plannedDurationMinutes,
  }) async {
    final now = DateTime.now();
    final session = FocusSession(
      id: 'focus_${now.microsecondsSinceEpoch}',
      planId: plan.id,
      planTitle: plan.title,
      mode: FocusMode.couple,
      plannedDurationMinutes: plannedDurationMinutes,
      actualDurationSeconds: 0,
      status: FocusSessionStatus.waiting,
      scoreDelta: 0,
      startedAt: null,
      endedAt: null,
      creatorUserId: 'current-user',
      sentByMe: true,
      partnerJoinedAt: null,
      createdAt: now,
    );
    _focusSessions.insert(0, session);
    notifyListeners();
    return session;
  }

  @override
  Future<FocusSession?> joinFocusSession(String sessionId) async {
    final index = _focusSessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (index == -1) return null;
    final session = _focusSessions[index];
    final now = DateTime.now();
    final updated = session.copyWith(
      status: session.startedAt == null
          ? FocusSessionStatus.running
          : session.status,
      startedAt: session.startedAt ?? now,
      partnerJoinedAt: now,
    );
    _focusSessions[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<FocusSession?> startFocusSessionNow(String sessionId) async {
    final index = _focusSessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (index == -1) return null;
    final now = DateTime.now();
    final updated = _focusSessions[index].copyWith(
      status: FocusSessionStatus.running,
      startedAt: now,
      clearPausedAt: true,
    );
    _focusSessions[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<FocusSession?> pauseFocusSession(String sessionId) async {
    final index = _focusSessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (index == -1) return null;
    final updated = _focusSessions[index].copyWith(
      status: FocusSessionStatus.paused,
      pausedAt: DateTime.now(),
    );
    _focusSessions[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<FocusSession?> resumeFocusSession(String sessionId) async {
    final index = _focusSessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (index == -1) return null;
    final session = _focusSessions[index];
    final pausedAt = session.pausedAt;
    final pausedSeconds = pausedAt == null
        ? 0
        : DateTime.now().difference(pausedAt).inSeconds;
    final updated = session.copyWith(
      status: FocusSessionStatus.running,
      totalPausedSeconds: session.totalPausedSeconds + pausedSeconds,
      clearPausedAt: true,
    );
    _focusSessions[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<FocusSession?> finishFocusSession({
    required String sessionId,
    required FocusSessionStatus status,
    required int actualDurationSeconds,
    required int scoreDelta,
  }) async {
    final index = _focusSessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (index == -1) return null;
    final updated = _focusSessions[index].copyWith(
      status: status,
      actualDurationSeconds: actualDurationSeconds,
      scoreDelta: scoreDelta,
      endedAt: DateTime.now(),
      clearPausedAt: true,
    );
    _focusSessions[index] = updated;
    _applyFocusScore(updated);
    notifyListeners();
    return updated;
  }

  void _applyFocusScore(FocusSession session) {
    final index = _plans.indexWhere((plan) => plan.id == session.planId);
    if (index != -1 && session.scoreDelta > 0) {
      final plan = _plans[index];
      _plans[index] = plan.copyWith(
        focusScore: plan.focusScore + session.scoreDelta,
        lastFocusedAt: session.endedAt ?? DateTime.now(),
      );
    }
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
    _reminders.insert(
      0,
      Reminder(
        id: 'rem_${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        content: content,
        fromUserId: 'current-user',
        toUserId: 'partner',
        sentByMe: true,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> markReceivedRemindersRead() async {
    var changed = false;
    for (var index = 0; index < _reminders.length; index++) {
      final reminder = _reminders[index];
      if (!reminder.sentByMe && !reminder.isRead) {
        _reminders[index] = reminder.copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  // ========================= 辅助 =========================

  /// 计划优先级用于首页排序：我待打卡 > TA 待打卡 > 已完成
  static int planPriority(Plan plan) {
    if (plan.isOverdue) return 0;

    final myUndone = switch (plan.owner) {
      PlanOwner.me => !plan.doneToday,
      PlanOwner.together => !plan.doneToday,
      PlanOwner.partner => false,
    };
    if (myUndone) return plan.isOnce ? 2 : 1;

    final partnerUndone = switch (plan.owner) {
      PlanOwner.partner => !plan.partnerDoneToday,
      PlanOwner.together => !plan.partnerDoneToday,
      PlanOwner.me => false,
    };
    if (partnerUndone) return 3;

    return 4;
  }

  static int _comparePlanPriority(Plan a, Plan b) {
    return planPriority(a).compareTo(planPriority(b));
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isVisibleInActiveLists(Plan plan) {
    if (!plan.isEnded) return true;
    final endedAt = plan.endedAt;
    return plan.isOnce &&
        endedAt != null &&
        _isSameDate(endedAt, DateTime.now());
  }

  void _finishOncePlanIfComplete(int index) {
    final plan = _plans[index];
    if (!plan.isOnce || !plan.isDoneForCurrentUser) return;
    if (plan.owner == PlanOwner.together && !plan.isTogetherDoneToday) return;

    _plans[index] = plan.copyWith(
      status: PlanStatus.ended,
      endedAt: DateTime.now(),
    );
    NotificationService.cancelPlanReminder(plan.id);
  }

  void _scheduleReminder(Plan plan, {bool syncSystemAlarm = false}) {
    final reminderTime = plan.reminderTime;
    if (reminderTime == null) return;

    NotificationService.schedulePlanReminder(
      planId: plan.id,
      planTitle: plan.title,
      hour: reminderTime.hour,
      minute: reminderTime.minute,
      syncSystemAlarm: syncSystemAlarm,
    );
  }
}
