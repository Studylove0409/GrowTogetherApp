import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/utils/plan_icon_mapper.dart';
import '../models/plan.dart';
import '../models/reminder.dart';
import 'mock_data.dart';

class MockStore extends ChangeNotifier {
  MockStore._()
    : _plans = List.of(MockData.plans),
      _reminders = List.of(MockData.reminders);

  static final MockStore instance = MockStore._();

  final List<Plan> _plans;
  final List<Reminder> _reminders;

  List<Plan> getPlans() =>
      List.unmodifiable(_plans.where((p) => !p.isEnded));

  List<Plan> getPlansByOwner(PlanOwner owner) {
    return _plans.where((plan) => plan.owner == owner && !plan.isEnded).toList();
  }

  /// 按优先级排序后取前 3 条：我待打卡 > TA 待打卡 > 已完成
  List<Plan> getTodayFocusPlans() {
    final active = _plans.where((p) => !p.isEnded).toList()
      ..sort(_comparePlanPriority);
    return List.unmodifiable(active.take(3));
  }

  List<Plan> getAllPlans() => List.unmodifiable(_plans);

  /// 优先级：0=我待打卡, 1=TA待打卡, 2=已完成
  static int planPriority(Plan plan) {
    // 我待打卡：我的计划未完成，或共同计划中我未完成
    final myUndone = switch (plan.owner) {
      PlanOwner.me => !plan.doneToday,
      PlanOwner.together => !plan.doneToday,
      PlanOwner.partner => false,
    };
    if (myUndone) return 0;

    // TA 待打卡：TA 的计划未完成，或共同计划中 TA 未完成（但我已完成）
    final partnerUndone = switch (plan.owner) {
      PlanOwner.partner => !plan.partnerDoneToday,
      PlanOwner.together => !plan.partnerDoneToday,
      PlanOwner.me => false,
    };
    if (partnerUndone) return 1;

    return 2; // 已完成
  }

  static int _comparePlanPriority(Plan a, Plan b) {
    return planPriority(a).compareTo(planPriority(b));
  }

  List<CheckinRecord> getCheckinRecords(String planId) {
    final plan = getPlanById(planId);
    if (plan == null) return [];
    return List.unmodifiable(plan.checkins);
  }

  Plan? getPlanById(String id) {
    for (final plan in _plans) {
      if (plan.id == id) {
        return plan;
      }
    }
    return null;
  }

  List<Reminder> getReminders() => List.unmodifiable(_reminders);

  Plan createPlan({
    required String title,
    required PlanOwner owner,
    required String dailyTask,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay reminderTime,
    String iconKey = PlanIconMapper.defaultKey,
  }) {
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
      color: owner == PlanOwner.together
          ? AppColors.primary
          : AppColors.reminder,
      dailyTask: dailyTask,
      startDate: startDate,
      endDate: endDate,
      reminderTime: reminderTime,
    );

    _plans.insert(0, plan);
    notifyListeners();
    return plan;
  }

  void saveCheckin({
    required String planId,
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) {
      return;
    }

    final plan = _plans[index];
    if (!plan.canCurrentUserCheckin) {
      return;
    }

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

  void updatePlanStatus(String planId, {required bool doneToday}) {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) {
      return;
    }

    final plan = _plans[index];
    if (!plan.canCurrentUserCheckin) {
      return;
    }
    _plans[index] = plan.copyWith(doneToday: doneToday);
    notifyListeners();
  }

  void updatePlan({
    required String planId,
    String? title,
    String? dailyTask,
    String? iconKey,
    TimeOfDay? reminderTime,
    DateTime? startDate,
    DateTime? endDate,
  }) {
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
  }

  void endPlan(String planId) {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;

    final plan = _plans[index];
    if (!plan.canCurrentUserEdit) return;

    _plans[index] = plan.copyWith(
      status: PlanStatus.ended,
      endedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void sendReminder(Reminder reminder) {
    _reminders.insert(0, reminder);
    notifyListeners();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
