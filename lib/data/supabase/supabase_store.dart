import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notification/notification_service.dart';
import '../../shared/utils/plan_icon_mapper.dart';
import '../models/focus_session.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/reminder.dart';
import '../store/store.dart';
import 'checkin_repository.dart';
import 'focus_session_repository.dart';
import 'plan_repository.dart';
import 'profile_repository.dart';
import 'reminder_repository.dart';

class SupabaseStore extends Store {
  SupabaseStore() {
    _init();
  }

  final _planRepo = const PlanRepository();
  final _checkinRepo = const CheckinRepository();
  final _focusRepo = const FocusSessionRepository();
  final _reminderRepo = const ReminderRepository();
  final _profileRepo = const ProfileRepository();

  // ========================= 缓存 =========================

  List<Plan> _plans = [];
  List<Reminder> _reminders = [];
  List<FocusSession> _focusSessions = [];
  final Set<String> _notifiedFocusInviteIds = {};
  Profile _profile = const Profile(
    name: '一起进步的你',
    partnerName: '加载中...',
    togetherDays: 0,
    inviteCode: '',
    isBound: false,
  );

  // ========================= 初始化 =========================

  Future<void> _init() async {
    await Future.wait([_loadProfile(), _loadFocusSessions(), _loadReminders()]);
    await _loadPlans();
    _subscribeRealtime();
    _startAutoRefresh();
    unawaited(_syncPlanReminders());
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    try {
      _profile = await _profileRepo.getCurrentProfile();
    } catch (_) {}
  }

  Future<void> _loadPlans() async {
    try {
      _plans = await _planRepo.fetchActivePlans();
      if (_plans.isNotEmpty) {
        final planIds = _plans.map((p) => p.id).toList();
        final client = Supabase.instance.client;
        final checkinRows = await client
            .from('checkins')
            .select('*')
            .inFilter('plan_id', planIds)
            .order('checkin_date', ascending: false);

        final allCheckins = <String, List<CheckinRecord>>{};
        for (final row in checkinRows) {
          final planId = row['plan_id'] as String;
          allCheckins
              .putIfAbsent(planId, () => [])
              .add(_rowToCheckinRecord(row));
        }

        _plans = _plans.map((p) {
          final records = allCheckins[p.id] ?? [];
          return p.copyWith(checkins: records);
        }).toList();
      }
      _plans = _plans.map(_withLocalFocusMetrics).toList();
    } catch (_) {}
  }

  CheckinRecord _rowToCheckinRecord(Map<String, dynamic> row) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return CheckinRecord(
      date: DateTime.parse(row['checkin_date'] as String),
      completed: row['status'] == 'completed',
      mood: _toMood(row['mood'] as String?),
      note: row['note'] as String? ?? '',
      actor: row['user_id'] == currentUserId
          ? CheckinActor.me
          : CheckinActor.partner,
    );
  }

  CheckinMood _toMood(String? dbMood) => switch (dbMood) {
    'happy' => CheckinMood.happy,
    'normal' => CheckinMood.normal,
    'tired' => CheckinMood.tired,
    'great' => CheckinMood.great,
    _ => CheckinMood.happy,
  };

  Future<void> _loadReminders() async {
    try {
      _reminders = await _reminderRepo.fetchReminders();
    } catch (_) {}
  }

  Future<void> _loadFocusSessions() async {
    try {
      final sessions = await _focusRepo.fetchFocusSessions();
      _focusSessions = sessions;
      _showNewFocusInviteNotifications(sessions);
    } catch (_) {}
  }

  void _showNewFocusInviteNotifications(List<FocusSession> sessions) {
    for (final session in sessions.where((session) => session.canJoin)) {
      if (!_notifiedFocusInviteIds.add(session.id)) continue;

      unawaited(
        NotificationService.showPushNotification(
          id: session.id.hashCode & 0x7fffffff,
          title: '一起专注邀请',
          body:
              'TA 邀请你为「${session.planTitle}」专注 ${session.plannedDurationMinutes} 分钟',
        ),
      );
    }
  }

  // ========================= Realtime =========================

  RealtimeChannel? _channel;
  Timer? _realtimeRetryTimer;
  Timer? _autoRefreshTimer;
  bool _autoRefreshInFlight = false;
  bool _markingRemindersRead = false;

  void _subscribeRealtime() {
    unawaited(_channel?.unsubscribe());
    _realtimeRetryTimer?.cancel();

    final client = Supabase.instance.client;
    _channel = client.channel('store-changes');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'plans',
          callback: (_) {
            _loadPlans().then((_) => notifyListeners());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'checkins',
          callback: (_) {
            _loadPlans().then((_) => notifyListeners());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reminders',
          callback: (_) {
            _loadReminders().then((_) => notifyListeners());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'focus_sessions',
          callback: (_) async {
            await _loadFocusSessions();
            await _loadPlans();
            notifyListeners();
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            return;
          }
          debugPrint('Supabase realtime status: $status ${error ?? ''}');
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut ||
              status == RealtimeSubscribeStatus.closed) {
            _realtimeRetryTimer?.cancel();
            _realtimeRetryTimer = Timer(
              const Duration(seconds: 5),
              _subscribeRealtime,
            );
          }
        });
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_refreshAllQuietly());
    });
  }

  Future<void> _refreshAllQuietly() async {
    if (_autoRefreshInFlight) return;
    _autoRefreshInFlight = true;
    try {
      await Future.wait([
        _loadProfile(),
        _loadFocusSessions(),
        _loadReminders(),
      ]);
      await _loadPlans();
      await _syncPlanReminders();
      notifyListeners();
    } finally {
      _autoRefreshInFlight = false;
    }
  }

  // ========================= Profile =========================

  @override
  Profile getProfile() => _profile;

  @override
  Future<void> refreshProfile() async {
    await _loadProfile();
    notifyListeners();
  }

  @override
  Future<void> refreshPlans() async {
    await _loadPlans();
    await _syncPlanReminders();
    notifyListeners();
  }

  @override
  Future<void> refreshReminders() async {
    await _loadReminders();
    notifyListeners();
  }

  @override
  Future<void> refreshFocusSessions() async {
    await _loadFocusSessions();
    await _loadPlans();
    notifyListeners();
  }

  @override
  Future<void> refreshAll() async {
    await _refreshAllQuietly();
  }

  // ========================= Plan 读 =========================

  @override
  List<Plan> getPlans() {
    return List.unmodifiable(_plans.where((p) => !p.isEnded));
  }

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) {
    return _plans
        .where((plan) => plan.owner == owner && !plan.isEnded)
        .toList();
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

  // ========================= Plan 写 =========================

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
    final plan = await _planRepo.createPlan(
      isShared: isShared,
      title: title,
      dailyTask: dailyTask,
      startDate: startDate,
      endDate: endDate,
      reminderTime: reminderTime,
      repeatType: repeatType,
      hasDateRange: hasDateRange,
      iconKey: iconKey,
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
    await _planRepo.updatePlan(
      planId: planId,
      title: title,
      dailyTask: dailyTask,
      iconKey: iconKey,
      reminderTime: reminderTime,
      clearReminderTime: clearReminderTime,
      repeatType: repeatType,
      startDate: startDate,
      endDate: endDate,
      hasDateRange: hasDateRange,
    );
    await _loadPlans();
    await _syncPlanReminders();
    notifyListeners();
    if (clearReminderTime) {
      await NotificationService.cancelPlanReminder(planId);
    } else if (reminderTime != null) {
      final updated = getPlanById(planId);
      if (updated != null) _scheduleReminder(updated, syncSystemAlarm: true);
    }
  }

  @override
  Future<void> endPlan(String planId) async {
    await _planRepo.endPlan(planId);
    await _loadPlans();
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
    await _checkinRepo.upsertTodayCheckin(
      planId: planId,
      completed: completed,
      mood: mood,
      note: note,
    );
    await _finishOncePlanIfComplete(planId);
    await _loadPlans();
    notifyListeners();
  }

  @override
  Future<void> updatePlanStatus(
    String planId, {
    required bool doneToday,
  }) async {
    await _checkinRepo.upsertTodayCheckin(
      planId: planId,
      completed: doneToday,
      mood: CheckinMood.happy,
      note: '',
    );
    await _finishOncePlanIfComplete(planId);
    await _loadPlans();
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
    final saved = await _focusRepo.insertCompletedSession(session);
    if (saved != null) _upsertFocusSession(saved);
    await _loadPlans();
    notifyListeners();
  }

  @override
  Future<FocusSession> createCoupleFocusInvite({
    required Plan plan,
    required int plannedDurationMinutes,
  }) async {
    final session = await _focusRepo.createCoupleInvite(
      plan: plan,
      plannedDurationMinutes: plannedDurationMinutes,
    );
    _upsertFocusSession(session);
    notifyListeners();
    return session;
  }

  @override
  Future<FocusSession?> joinFocusSession(String sessionId) async {
    final session = await _focusRepo.joinSession(sessionId);
    if (session != null) _upsertFocusSession(session);
    notifyListeners();
    return session;
  }

  @override
  Future<FocusSession?> startFocusSessionNow(String sessionId) async {
    final session = await _focusRepo.startSessionNow(sessionId);
    if (session != null) _upsertFocusSession(session);
    notifyListeners();
    return session;
  }

  @override
  Future<FocusSession?> pauseFocusSession(String sessionId) async {
    final session = await _focusRepo.pauseSession(sessionId);
    if (session != null) _upsertFocusSession(session);
    notifyListeners();
    return session;
  }

  @override
  Future<FocusSession?> resumeFocusSession(String sessionId) async {
    final existing = getFocusSessionById(sessionId);
    if (existing == null) return null;

    final session = await _focusRepo.resumeSession(existing);
    if (session != null) _upsertFocusSession(session);
    notifyListeners();
    return session;
  }

  @override
  Future<FocusSession?> finishFocusSession({
    required String sessionId,
    required FocusSessionStatus status,
    required int actualDurationSeconds,
    required int scoreDelta,
  }) async {
    final session = await _focusRepo.finishSession(
      sessionId: sessionId,
      status: status,
      actualDurationSeconds: actualDurationSeconds,
      scoreDelta: scoreDelta,
    );
    if (session != null) _upsertFocusSession(session);
    await _loadPlans();
    notifyListeners();
    return session;
  }

  FocusSession? getFocusSessionById(String sessionId) {
    for (final session in _focusSessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  void _upsertFocusSession(FocusSession session) {
    final index = _focusSessions.indexWhere((item) => item.id == session.id);
    if (index == -1) {
      _focusSessions.insert(0, session);
    } else {
      _focusSessions[index] = session;
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
    await _reminderRepo.sendReminder(
      planId: planId,
      type: _fromReminderType(type),
      content: content,
    );
    await _loadReminders();
    notifyListeners();
  }

  @override
  Future<void> markReceivedRemindersRead() async {
    if (_markingRemindersRead) return;

    final unread = _reminders.where((r) => !r.sentByMe && !r.isRead).toList();
    if (unread.isEmpty) return;

    _markingRemindersRead = true;
    _reminders = _reminders
        .map((r) => !r.sentByMe && !r.isRead ? r.copyWith(isRead: true) : r)
        .toList();
    notifyListeners();

    try {
      await _reminderRepo.markRemindersRead(unread.map((r) => r.id).toList());
      await _loadReminders();
      notifyListeners();
    } catch (error) {
      debugPrint('markReceivedRemindersRead failed: $error');
      await _loadReminders();
      notifyListeners();
    } finally {
      _markingRemindersRead = false;
    }
  }

  // ========================= 辅助 =========================

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

  Plan _withLocalFocusMetrics(Plan plan) {
    final planSessions = _focusSessions.where(
      (session) =>
          session.planId == plan.id &&
          session.scoreDelta > 0 &&
          !session.isActive,
    );
    if (planSessions.isEmpty) return plan;

    final focusScore = planSessions.fold<int>(
      0,
      (total, session) => total + session.scoreDelta,
    );
    final lastFocusedAt = planSessions
        .map((session) => session.endedAt ?? session.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return plan.copyWith(focusScore: focusScore, lastFocusedAt: lastFocusedAt);
  }

  String _fromReminderType(ReminderType type) => switch (type) {
    ReminderType.gentle => 'gentle',
    ReminderType.strict => 'strict',
    ReminderType.encourage => 'encourage',
    ReminderType.praise => 'praise',
  };

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

  Future<void> _finishOncePlanIfComplete(String planId) async {
    final plan = await _planRepo.fetchPlanById(planId);
    if (plan == null || !plan.isOnce || !plan.isDoneForCurrentUser) return;
    if (plan.owner == PlanOwner.together && !plan.isTogetherDoneToday) return;

    await _planRepo.endPlan(planId);
    await NotificationService.cancelPlanReminder(planId);
  }

  Future<void> _syncPlanReminders() async {
    final activeOwnedPlans = _plans.where(
      (plan) => !plan.isEnded && plan.owner != PlanOwner.partner,
    );
    await Future.wait(
      activeOwnedPlans.map((plan) async {
        final reminderTime = plan.reminderTime;
        if (reminderTime == null) {
          await NotificationService.cancelPlanReminder(plan.id);
          return;
        }

        await NotificationService.schedulePlanReminder(
          planId: plan.id,
          planTitle: plan.title,
          hour: reminderTime.hour,
          minute: reminderTime.minute,
        );
      }),
    );
  }

  @override
  void dispose() {
    _realtimeRetryTimer?.cancel();
    _autoRefreshTimer?.cancel();
    unawaited(_channel?.unsubscribe());
    super.dispose();
  }
}
