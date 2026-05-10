import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notification/notification_service.dart';
import '../../shared/utils/plan_icon_mapper.dart';
import '../cache/plan_cache_service.dart';
import '../cache/profile_cache_service.dart';
import '../models/focus_session.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/reminder.dart';
import '../models/reminder_settings.dart';
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
  final _planCache = const PlanCacheService();
  final _profileCache = const ProfileCacheService();

  // ========================= 缓存 =========================

  List<Plan> _plans = [];
  List<Reminder> _reminders = [];
  List<FocusSession> _focusSessions = [];
  ReminderSettings _reminderSettings = const ReminderSettings();
  final Set<String> _notifiedFocusInviteIds = {};
  final Set<String> _notifiedReminderIds = {};
  final Set<String> _locallyDirtyPlanIds = {};
  bool _reminderNotificationsPrimed = false;
  bool _isInitialPlansLoading = true;
  bool _isRefreshingPlans = false;
  bool _hasHydratedPlanCache = false;
  DateTime? _lastPlansSyncedAt;
  String? _planSyncErrorMessage;
  Profile _profile = const Profile(
    name: '一起进步的你',
    partnerName: '加载中...',
    togetherDays: 0,
    inviteCode: '',
    isBound: false,
    avatarUrl: null,
    partnerAvatarUrl: null,
  );

  // ========================= 初始化 =========================

  Future<void> _init() async {
    await _hydrateProfileFromCache();
    await _hydratePlansFromCache();
    await _loadReminderSettings();
    unawaited(_applyReminderSettings());
    final nonPlanLoads = Future.wait([
      _loadProfile(),
      _loadFocusSessions(),
      _loadReminders(),
    ]);
    await _refreshPlansFromRemote(syncReminders: true);
    await nonPlanLoads;
    _plans = _plans.map(_withLocalFocusMetrics).toList();
    await _writePlanCache();
    _subscribeRealtime();
    _startAutoRefresh();
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    try {
      _profile = _mergeProfileWithCachedAvatars(
        await _profileRepo.getCurrentProfile(),
      );
      await _writeProfileCache();
    } catch (_) {}
  }

  Future<void> _hydrateProfileFromCache() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final snapshot = await _profileCache.readProfile(userId);
    if (snapshot == null) return;

    _profile = snapshot.profile;
    notifyListeners();
  }

  Future<void> _loadReminderSettings() async {
    try {
      _reminderSettings = await _profileRepo.getCurrentReminderSettings();
    } catch (_) {}
  }

  Future<void> _hydratePlansFromCache() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final snapshot = await _planCache.readPlans(userId);
    if (snapshot == null) return;

    _plans = snapshot.plans.map(_withLocalFocusMetrics).toList();
    _hasHydratedPlanCache = true;
    _lastPlansSyncedAt = snapshot.cachedAt;
    _isInitialPlansLoading = false;
    _planSyncErrorMessage = null;
    notifyListeners();
  }

  Future<void> _refreshPlansFromRemote({bool syncReminders = false}) async {
    if (_isRefreshingPlans) return;

    _isRefreshingPlans = true;
    _planSyncErrorMessage = null;
    notifyListeners();

    try {
      final remotePlans = await _fetchPlansFromRemote();
      _plans = _mergeRemotePlansWithLocalDirty(remotePlans);
      _isInitialPlansLoading = false;
      _lastPlansSyncedAt = DateTime.now();
      _planSyncErrorMessage = null;
      await _writePlanCache();
      if (syncReminders) {
        unawaited(_syncPlanRemindersQuietly());
      }
    } catch (error) {
      debugPrint('Plan remote refresh failed: $error');
      _isInitialPlansLoading = false;
      _planSyncErrorMessage = _plans.isEmpty
          ? '网络异常，暂时无法同步计划'
          : '网络异常，当前显示上次同步数据';
    } finally {
      _isRefreshingPlans = false;
      notifyListeners();
    }
  }

  Future<List<Plan>> _fetchPlansFromRemote() async {
    var plans = await _planRepo.fetchAllPlans();
    if (plans.isNotEmpty) {
      final planIds = plans.map((p) => p.id).toList();
      final client = Supabase.instance.client;
      final checkinRows = await client
          .from('checkins')
          .select('*')
          .inFilter('plan_id', planIds)
          .order('checkin_date', ascending: false);

      final allCheckins = <String, List<CheckinRecord>>{};
      for (final row in checkinRows) {
        final planId = row['plan_id'] as String;
        allCheckins.putIfAbsent(planId, () => []).add(_rowToCheckinRecord(row));
      }

      plans = plans.map((p) {
        final records = allCheckins[p.id] ?? [];
        return p.copyWith(checkins: records);
      }).toList();
    }
    return plans.map(_withLocalFocusMetrics).toList();
  }

  Future<void> _writePlanCache() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _planCache.writePlans(userId, _plans);
      _hasHydratedPlanCache = true;
    } catch (error) {
      debugPrint('Plan cache write skipped: $error');
    }
  }

  Future<void> _writeProfileCache() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _profileCache.writeProfile(userId, _profile);
    } catch (error) {
      debugPrint('Profile cache write skipped: $error');
    }
  }

  Profile _mergeProfileWithCachedAvatars(Profile next) {
    final current = _profile;
    return next.copyWith(
      avatarUrl:
          _shouldKeepCurrentAvatarUrl(
            currentPath: current.avatarPath,
            nextPath: next.avatarPath,
            currentUrl: current.avatarUrl,
            nextUrl: next.avatarUrl,
          )
          ? current.avatarUrl
          : next.avatarUrl,
      partnerAvatarUrl:
          _shouldKeepCurrentAvatarUrl(
            currentPath: current.partnerAvatarPath,
            nextPath: next.partnerAvatarPath,
            currentUrl: current.partnerAvatarUrl,
            nextUrl: next.partnerAvatarUrl,
          )
          ? current.partnerAvatarUrl
          : next.partnerAvatarUrl,
    );
  }

  bool _shouldKeepCurrentAvatarUrl({
    required String? currentPath,
    required String? nextPath,
    required String? currentUrl,
    required String? nextUrl,
  }) {
    if (nextUrl != null && nextUrl.trim().isNotEmpty) return false;
    if (currentUrl == null || currentUrl.trim().isEmpty) return false;
    return currentPath != null && currentPath == nextPath;
  }

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  List<Plan> _mergeRemotePlansWithLocalDirty(List<Plan> remotePlans) {
    if (_locallyDirtyPlanIds.isEmpty) return remotePlans;

    final localById = {for (final plan in _plans) plan.id: plan};
    return [
      for (final remotePlan in remotePlans)
        if (_locallyDirtyPlanIds.contains(remotePlan.id) &&
            localById[remotePlan.id] != null)
          _mergeDirtyPlan(remotePlan, localById[remotePlan.id]!)
        else
          remotePlan,
    ];
  }

  Plan _mergeDirtyPlan(Plan remotePlan, Plan localPlan) {
    if (_remoteConfirmsLocalToday(remotePlan, localPlan)) {
      _locallyDirtyPlanIds.remove(remotePlan.id);
      return remotePlan;
    }

    final localTodayRecord = _currentUserTodayRecord(localPlan);
    final mergedCheckins = [
      if (localTodayRecord != null) localTodayRecord,
      ...remotePlan.checkins.where(
        (record) =>
            record.actor != CheckinActor.me ||
            !_isSameDate(record.date, DateTime.now()),
      ),
    ];

    return remotePlan.copyWith(
      doneToday: localPlan.doneToday,
      completedDays: localPlan.completedDays,
      status: localPlan.status == PlanStatus.ended
          ? localPlan.status
          : remotePlan.status,
      endedAt: localPlan.status == PlanStatus.ended
          ? localPlan.endedAt
          : remotePlan.endedAt,
      checkins: mergedCheckins,
    );
  }

  bool _remoteConfirmsLocalToday(Plan remotePlan, Plan localPlan) {
    final localRecord = _currentUserTodayRecord(localPlan);
    if (localRecord == null) return true;

    final remoteRecord = _currentUserTodayRecord(remotePlan);
    return remoteRecord != null &&
        remoteRecord.completed == localRecord.completed &&
        remotePlan.doneToday == localPlan.doneToday;
  }

  CheckinRecord? _currentUserTodayRecord(Plan plan) {
    for (final record in plan.checkins) {
      if (record.actor == CheckinActor.me &&
          _isSameDate(record.date, DateTime.now())) {
        return record;
      }
    }
    return plan.doneToday
        ? CheckinRecord(
            date: DateTime.now(),
            completed: true,
            mood: CheckinMood.happy,
            note: '',
          )
        : null;
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
      final reminders = await _reminderRepo.fetchReminders();
      _reminders = reminders;
      _showNewReminderNotifications(reminders);
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
    if (!_reminderSettings.partnerActivityReminderEnabled) {
      _notifiedFocusInviteIds.addAll(
        sessions
            .where((session) => session.canJoin)
            .map((session) => session.id),
      );
      return;
    }

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

  void _showNewReminderNotifications(List<Reminder> reminders) {
    final incomingUnread = reminders.where(
      (reminder) =>
          !reminder.sentByMe &&
          !reminder.isRead &&
          !_isLegacyFocusInviteReminder(reminder),
    );

    if (!_reminderSettings.partnerActivityReminderEnabled) {
      _notifiedReminderIds.addAll(
        incomingUnread.map((reminder) => reminder.id),
      );
      _reminderNotificationsPrimed = true;
      return;
    }

    if (!_reminderNotificationsPrimed) {
      _notifiedReminderIds.addAll(
        incomingUnread.map((reminder) => reminder.id),
      );
      _reminderNotificationsPrimed = true;
      return;
    }

    for (final reminder in incomingUnread) {
      if (!_notifiedReminderIds.add(reminder.id)) continue;

      unawaited(
        NotificationService.showPushNotification(
          id: reminder.id.hashCode & 0x7fffffff,
          title: reminder.type.label,
          body: reminder.content,
        ),
      );
    }
  }

  static bool _isLegacyFocusInviteReminder(Reminder reminder) {
    return reminder.content.startsWith('想邀请你一起专注');
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
            unawaited(_refreshPlansFromRemote(syncReminders: true));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'checkins',
          callback: (_) {
            unawaited(_refreshPlansFromRemote());
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
            _plans = _plans.map(_withLocalFocusMetrics).toList();
            await _writePlanCache();
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
        _loadReminderSettings(),
        _loadFocusSessions(),
        _loadReminders(),
      ]);
      await _refreshPlansFromRemote(syncReminders: true);
      await _applyReminderSettings();
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
    await _refreshPlansFromRemote(syncReminders: true);
  }

  @override
  Future<void> refreshReminders() async {
    await _loadReminders();
    notifyListeners();
  }

  @override
  Future<void> refreshFocusSessions() async {
    await _loadFocusSessions();
    _plans = _plans.map(_withLocalFocusMetrics).toList();
    await _writePlanCache();
    notifyListeners();
  }

  @override
  Future<void> refreshAll() async {
    await _refreshAllQuietly();
  }

  // ========================= Plan 读 =========================

  @override
  bool get isInitialPlansLoading => _isInitialPlansLoading;

  @override
  bool get isRefreshingPlans => _isRefreshingPlans;

  @override
  bool get hasHydratedPlanCache => _hasHydratedPlanCache;

  @override
  DateTime? get lastPlansSyncedAt => _lastPlansSyncedAt;

  @override
  String? get planSyncErrorMessage => _planSyncErrorMessage;

  @override
  List<Plan> getPlans() {
    return List.unmodifiable(_plans.where((p) => p.shouldShowInActiveLists));
  }

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) {
    return _plans.where((plan) => plan.owner == owner).toList();
  }

  @override
  List<Plan> getTodayFocusPlans() {
    final active = _plans.where(_isVisibleToday).toList()
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
    bool syncSystemCalendar = false,
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
    await _writePlanCache();
    notifyListeners();
    if (plan.hasReminder) {
      if (_shouldScheduleReminder(plan)) {
        _scheduleReminder(plan, syncSystemCalendar: syncSystemCalendar);
      } else {
        await NotificationService.cancelPlanReminder(plan.id);
      }
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
    await _refreshPlansFromRemote(syncReminders: true);
    if (clearReminderTime) {
      await NotificationService.cancelPlanReminder(planId);
    } else if (reminderTime != null) {
      final updated = getPlanById(planId);
      if (updated != null && _shouldScheduleReminder(updated)) {
        _scheduleReminder(updated);
      } else {
        await NotificationService.cancelPlanReminder(planId);
      }
    }
  }

  @override
  Future<void> endPlan(String planId) async {
    await _planRepo.endPlan(planId);
    await _refreshPlansFromRemote();
    NotificationService.cancelPlanReminder(planId);
  }

  @override
  Future<void> deletePlan(String planId) async {
    await _planRepo.deletePlan(planId);
    await _refreshPlansFromRemote(syncReminders: true);
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

    final previousPlan = _plans[index];
    if (!previousPlan.canCurrentUserCheckin) return;

    _locallyDirtyPlanIds.add(planId);
    _plans[index] = _planWithTodayCheckin(
      previousPlan,
      completed: completed,
      mood: mood,
      note: note,
    );
    await _writePlanCache();
    notifyListeners();

    try {
      await _checkinRepo.upsertTodayCheckin(
        planId: planId,
        completed: completed,
        mood: mood,
        note: note.trim(),
      );
      await _finishOncePlanIfCompleteFromLocal(planId);
      await _refreshPlansFromRemote();
    } catch (_) {
      _locallyDirtyPlanIds.remove(planId);
      final rollbackIndex = _plans.indexWhere((plan) => plan.id == planId);
      if (rollbackIndex != -1) {
        _plans[rollbackIndex] = previousPlan;
        await _writePlanCache();
        notifyListeners();
      }
      rethrow;
    }
  }

  @override
  Future<void> updatePlanStatus(
    String planId, {
    required bool doneToday,
  }) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;

    final previousPlan = _plans[index];
    if (!previousPlan.canCurrentUserCheckin) return;

    _locallyDirtyPlanIds.add(planId);
    _plans[index] = _planWithTodayCheckin(
      previousPlan,
      completed: doneToday,
      mood: CheckinMood.happy,
      note: '',
    );
    await _writePlanCache();
    notifyListeners();

    try {
      await _checkinRepo.upsertTodayCheckin(
        planId: planId,
        completed: doneToday,
        mood: CheckinMood.happy,
        note: '',
      );
      await _finishOncePlanIfCompleteFromLocal(planId);
      await _refreshPlansFromRemote();
    } catch (_) {
      _locallyDirtyPlanIds.remove(planId);
      final rollbackIndex = _plans.indexWhere((plan) => plan.id == planId);
      if (rollbackIndex != -1) {
        _plans[rollbackIndex] = previousPlan;
        await _writePlanCache();
        notifyListeners();
      }
      rethrow;
    }
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
    _plans = _plans.map(_withLocalFocusMetrics).toList();
    await _writePlanCache();
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
    _plans = _plans.map(_withLocalFocusMetrics).toList();
    await _writePlanCache();
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

  // ========================= Reminder Settings =========================

  @override
  ReminderSettings getReminderSettings() => _reminderSettings;

  @override
  Future<void> updateReminderSettings(ReminderSettings settings) async {
    _reminderSettings = settings;
    await _applyReminderSettings();
    notifyListeners();
    try {
      await _profileRepo.updateCurrentReminderSettings(settings);
    } catch (error) {
      debugPrint('Reminder settings save skipped: $error');
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

  void _scheduleReminder(Plan plan, {bool syncSystemCalendar = false}) {
    final reminderTime = plan.reminderTime;
    if (reminderTime == null) return;
    if (!_shouldScheduleReminder(plan)) {
      unawaited(NotificationService.cancelPlanReminder(plan.id));
      return;
    }

    NotificationService.schedulePlanReminder(
      planId: plan.id,
      planTitle: plan.title,
      hour: reminderTime.hour,
      minute: reminderTime.minute,
      scheduledDate: plan.isOnce ? plan.startDate : null,
      repeatsDaily: plan.isDaily,
      syncSystemCalendar: syncSystemCalendar,
      calendarStartDate: plan.startDate,
      calendarEndDate: plan.endDate,
      calendarHasDateRange: plan.hasDateRange,
    );
  }

  bool _shouldScheduleReminder(Plan plan) {
    return plan.owner != PlanOwner.partner &&
        plan.hasReminder &&
        plan.canCurrentUserCheckin;
  }

  bool _isVisibleToday(Plan plan) {
    return plan.shouldShowInActiveLists &&
        plan.isScheduledOnDate(DateTime.now());
  }

  Plan _planWithTodayCheckin(
    Plan plan, {
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) {
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
        ? (plan.completedDays - 1).clamp(0, plan.totalDays).toInt()
        : plan.completedDays;

    return plan.copyWith(
      doneToday: completed,
      completedDays: completedDays,
      checkins: checkins,
    );
  }

  Future<void> _finishOncePlanIfCompleteFromLocal(String planId) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;

    final plan = _plans[index];
    if (!plan.isOnce || !plan.isDoneForCurrentUser) return;
    if (plan.owner == PlanOwner.together && !plan.isTogetherDoneToday) return;

    try {
      await _planRepo.endPlan(planId);
      _plans[index] = plan.copyWith(
        status: PlanStatus.ended,
        endedAt: DateTime.now(),
      );
      await _writePlanCache();
      notifyListeners();
      await NotificationService.cancelPlanReminder(planId);
    } catch (error) {
      debugPrint('Finish once plan after checkin failed: $error');
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _syncPlanReminders() async {
    final plansForReminderSync = await _planRepo.fetchAllPlans();
    final ownedPlans = plansForReminderSync.where(
      (plan) => plan.owner != PlanOwner.partner,
    );
    await Future.wait(
      ownedPlans.map((plan) async {
        final reminderTime = plan.reminderTime;
        if (reminderTime == null || !_shouldScheduleReminder(plan)) {
          await NotificationService.cancelPlanReminder(plan.id);
          return;
        }

        await NotificationService.schedulePlanReminder(
          planId: plan.id,
          planTitle: plan.title,
          hour: reminderTime.hour,
          minute: reminderTime.minute,
          scheduledDate: plan.isOnce ? plan.startDate : null,
          repeatsDaily: plan.isDaily,
          calendarStartDate: plan.startDate,
          calendarEndDate: plan.endDate,
          calendarHasDateRange: plan.hasDateRange,
        );
      }),
    );
  }

  Future<void> _syncPlanRemindersQuietly() async {
    try {
      await _syncPlanReminders();
    } catch (error) {
      debugPrint('Plan reminder sync skipped: $error');
    }
  }

  Future<void> _applyReminderSettings() async {
    NotificationService.configureDoNotDisturb(
      enabled: _reminderSettings.doNotDisturbEnabled,
      startMinutes: _reminderSettings.doNotDisturbStartMinutes,
      endMinutes: _reminderSettings.doNotDisturbEndMinutes,
    );

    if (_reminderSettings.dailyReminderEnabled) {
      await NotificationService.scheduleDailyAppReminder(
        hour: _reminderSettings.dailyReminderTime.hour,
        minute: _reminderSettings.dailyReminderTime.minute,
      );
    } else {
      await NotificationService.cancelDailyAppReminder();
    }
  }

  @override
  void dispose() {
    _realtimeRetryTimer?.cancel();
    _autoRefreshTimer?.cancel();
    unawaited(_channel?.unsubscribe());
    super.dispose();
  }
}
