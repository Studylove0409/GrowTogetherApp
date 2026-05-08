import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notification/notification_service.dart';
import '../../shared/utils/plan_icon_mapper.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/reminder.dart';
import '../store/store.dart';
import 'checkin_repository.dart';
import 'plan_repository.dart';
import 'profile_repository.dart';
import 'reminder_repository.dart';

class SupabaseStore extends Store {
  SupabaseStore() {
    _init();
  }

  final _planRepo = const PlanRepository();
  final _checkinRepo = const CheckinRepository();
  final _reminderRepo = const ReminderRepository();
  final _profileRepo = const ProfileRepository();

  // ========================= 缓存 =========================

  List<Plan> _plans = [];
  List<Reminder> _reminders = [];
  bool _remindersLoaded = false;
  Profile _profile = const Profile(
    name: '一起进步的你',
    partnerName: '加载中...',
    togetherDays: 0,
    inviteCode: '',
    isBound: false,
  );

  // ========================= 初始化 =========================

  Future<void> _init() async {
    await Future.wait([_loadProfile(), _loadPlans(), _loadReminders()]);
    _subscribeRealtime();
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
      final previous = _reminders;
      _reminders = await _reminderRepo.fetchReminders();
      if (_remindersLoaded) {
        final prevIds = previous
            .where((r) => !r.sentByMe && !r.isRead)
            .map((r) => r.id)
            .toSet();
        for (final r in _reminders) {
          if (!r.sentByMe && !r.isRead && !prevIds.contains(r.id)) {
            NotificationService.showReminderReceived(
              reminderId: r.id,
              senderName: '你的另一半',
              content: r.content,
            );
          }
        }
      }
      _remindersLoaded = true;
    } catch (_) {}
  }

  // ========================= Realtime =========================

  RealtimeChannel? _channel;

  void _subscribeRealtime() {
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
        .subscribe();
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
    notifyListeners();
  }

  @override
  Future<void> refreshReminders() async {
    await _loadReminders();
    notifyListeners();
  }

  @override
  Future<void> refreshAll() async {
    await Future.wait([_loadProfile(), _loadPlans(), _loadReminders()]);
    notifyListeners();
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
    required TimeOfDay reminderTime,
    String iconKey = PlanIconMapper.defaultKey,
  }) async {
    final plan = await _planRepo.createPlan(
      isShared: isShared,
      title: title,
      dailyTask: dailyTask,
      startDate: startDate,
      endDate: endDate,
      reminderTime: reminderTime,
      iconKey: iconKey,
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
    await _planRepo.updatePlan(
      planId: planId,
      title: title,
      dailyTask: dailyTask,
      iconKey: iconKey,
      reminderTime: reminderTime,
      startDate: startDate,
      endDate: endDate,
    );
    await _loadPlans();
    notifyListeners();
    if (reminderTime != null) {
      final updated = getPlanById(planId);
      if (updated != null) _scheduleReminder(updated);
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
    await _loadPlans();
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
    final unread = _reminders.where((r) => !r.sentByMe && !r.isRead).toList();
    if (unread.isEmpty) return;

    _reminders = _reminders
        .map((r) => !r.sentByMe && !r.isRead ? r.copyWith(isRead: true) : r)
        .toList();
    notifyListeners();

    try {
      for (final reminder in unread) {
        await _reminderRepo.markReminderRead(reminder.id);
      }
      await _loadReminders();
      notifyListeners();
    } catch (_) {}
  }

  // ========================= 辅助 =========================

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

  String _fromReminderType(ReminderType type) => switch (type) {
    ReminderType.gentle => 'gentle',
    ReminderType.strict => 'strict',
    ReminderType.encourage => 'encourage',
    ReminderType.praise => 'praise',
  };

  void _scheduleReminder(Plan plan) {
    NotificationService.schedulePlanReminder(
      planId: plan.id,
      planTitle: plan.title,
      hour: plan.reminderTime.hour,
      minute: plan.reminderTime.minute,
    );
  }
}
