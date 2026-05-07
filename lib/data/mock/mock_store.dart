import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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

  List<Plan> getPlans() => List.unmodifiable(_plans);

  List<Plan> getTodayFocusPlans() => List.unmodifiable(_plans.take(3));

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
  }) {
    final totalDays = endDate.difference(startDate).inDays + 1;
    final plan = Plan(
      id: 'plan_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      subtitle: dailyTask,
      owner: owner,
      icon: owner == PlanOwner.together
          ? Icons.favorite_rounded
          : Icons.flag_rounded,
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

  void sendReminder(Reminder reminder) {
    _reminders.insert(0, reminder);
    notifyListeners();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
