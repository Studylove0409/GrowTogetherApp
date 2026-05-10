import '../models/plan.dart';

class PlanOccurrenceService {
  const PlanOccurrenceService._();

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool shouldPlanAppearOnDate(Plan plan, DateTime date) {
    final day = dateOnly(date);
    final start = dateOnly(plan.startDate);
    final end = dateOnly(plan.endDate);

    final isScheduled = switch (plan.repeatType) {
      PlanRepeatType.once => isSameDate(day, start),
      PlanRepeatType.daily =>
        !day.isBefore(start) && (!plan.hasDateRange || !day.isAfter(end)),
    };
    if (!isScheduled) return false;

    final endedAt = plan.endedAt;
    if (plan.status != PlanStatus.ended || endedAt == null) return true;
    return !day.isAfter(dateOnly(endedAt));
  }

  static List<Plan> plansForDate({
    required List<Plan> plans,
    required DateTime date,
    PlanOwner? owner,
  }) {
    return plans.where((plan) {
      if (owner != null && plan.owner != owner) return false;
      return shouldPlanAppearOnDate(plan, date);
    }).toList();
  }

  static bool isDoneOnDate(Plan plan, DateTime date) {
    return switch (plan.owner) {
      PlanOwner.me => plan.isCurrentUserDoneOn(date),
      PlanOwner.partner => plan.isPartnerDoneOn(date),
      PlanOwner.together =>
        plan.togetherStatusOn(date) == TogetherStatus.bothDone,
    };
  }

  static int completedCountForDate({
    required List<Plan> plans,
    required DateTime date,
    PlanOwner? owner,
  }) {
    return plansForDate(
      plans: plans,
      date: date,
      owner: owner,
    ).where((plan) => isDoneOnDate(plan, date)).length;
  }
}
