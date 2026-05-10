import 'package:flutter/material.dart';

import '../../shared/utils/plan_icon_mapper.dart';

enum PlanOwner { me, partner, together }

enum PlanStatus { active, ended }

enum PlanRepeatType { once, daily }

enum TogetherStatus { bothDone, onlyMeDone, meNotDone }

enum CheckinMood { happy, normal, tired, great }

enum CheckinActor { me, partner }

class CheckinRecord {
  const CheckinRecord({
    required this.date,
    required this.completed,
    required this.mood,
    required this.note,
    this.actor = CheckinActor.me,
  });

  final DateTime date;
  final bool completed;
  final CheckinMood mood;
  final String note;
  final CheckinActor actor;
}

class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.owner,
    required this.iconKey,
    required this.minutes,
    required this.completedDays,
    required this.totalDays,
    required this.doneToday,
    required this.color,
    required this.dailyTask,
    required this.startDate,
    required this.endDate,
    required this.reminderTime,
    this.repeatType = PlanRepeatType.daily,
    this.hasDateRange = true,
    this.partnerDoneToday = false,
    this.status = PlanStatus.active,
    this.endedAt,
    this.checkins = const [],
    this.focusScore = 0,
    this.lastFocusedAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final PlanOwner owner;
  final String iconKey;
  final int minutes;
  final int completedDays;
  final int totalDays;
  final bool doneToday;
  final Color color;
  final String dailyTask;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay? reminderTime;
  final PlanRepeatType repeatType;
  final bool hasDateRange;
  final bool partnerDoneToday;
  final PlanStatus status;
  final DateTime? endedAt;
  final List<CheckinRecord> checkins;
  final int focusScore;
  final DateTime? lastFocusedAt;

  IconData get icon => PlanIconMapper.iconData(iconKey);

  Color get iconColor => PlanIconMapper.color(iconKey);

  Color get iconBackgroundColor => PlanIconMapper.backgroundColor(iconKey);

  double get progress => totalDays == 0
      ? 0
      : completedDays.clamp(0, totalDays).toDouble() / totalDays;

  int get remainingDays {
    final effectiveCompletedDays = completedDays.clamp(0, totalDays).toInt();
    return (totalDays - effectiveCompletedDays).clamp(0, totalDays).toInt();
  }

  bool get hasReminder => reminderTime != null;

  bool get isEnded => status == PlanStatus.ended || isExpiredByDateRange;

  bool get shouldShowInActiveLists {
    if (!isEnded) return true;
    return isCompletedOnceToday;
  }

  bool get isCompletedOnceToday {
    final endedDate = endedAt;
    return isOnce &&
        status == PlanStatus.ended &&
        isDoneForCurrentUser &&
        endedDate != null &&
        _isSameDate(endedDate, DateTime.now());
  }

  bool get isExpiredByDateRange {
    if (status == PlanStatus.ended) return false;
    if (!isDaily || !hasDateRange) return false;
    final today = _dateOnly(DateTime.now());
    return _dateOnly(endDate).isBefore(today);
  }

  bool get isNotStartedYet {
    if (status == PlanStatus.ended) return false;
    final today = _dateOnly(DateTime.now());
    return _dateOnly(startDate).isAfter(today);
  }

  bool get isAvailableToday {
    if (status == PlanStatus.ended) return false;

    return isScheduledOnDate(DateTime.now());
  }

  bool isScheduledOnDate(DateTime date) {
    final day = _dateOnly(date);
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);

    if (isOnce) return day == start;
    if (day.isBefore(start)) return false;
    if (hasDateRange && day.isAfter(end)) return false;
    return true;
  }

  bool isVisibleOnDate(DateTime date) {
    if (!isScheduledOnDate(date)) return false;

    final endedDate = endedAt;
    if (status != PlanStatus.ended || endedDate == null) return true;
    return !_dateOnly(date).isAfter(_dateOnly(endedDate));
  }

  bool get isOnce => repeatType == PlanRepeatType.once;

  bool get isDaily => repeatType == PlanRepeatType.daily;

  bool get isOverdue {
    if (!isOnce || isEnded || isDoneForCurrentUser) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(startDate.year, startDate.month, startDate.day);
    return dueDate.isBefore(today);
  }

  String get repeatLabel {
    if (isExpiredByDateRange) return '已结束';
    if (isNotStartedYet) return '未开始';
    if (isOnce) return isOverdue ? '已逾期' : '单次';
    if (hasDateRange) return '每日 · $totalDays天';
    return '每日';
  }

  bool get canCurrentUserCheckin =>
      owner != PlanOwner.partner && isAvailableToday;

  bool get canCurrentUserEdit => owner != PlanOwner.partner && !isEnded;

  bool get isTogetherDoneToday => doneToday && partnerDoneToday;

  // 统一判定：当前计划是否完成（按角色视角）
  bool get isDoneForCurrentUser => switch (owner) {
    PlanOwner.me => doneToday,
    PlanOwner.partner => partnerDoneToday,
    PlanOwner.together => doneToday,
  };

  bool isCurrentUserDoneOn(DateTime date) {
    if (_isSameDate(date, DateTime.now())) return isDoneForCurrentUser;
    return checkins.any(
      (record) =>
          record.actor == CheckinActor.me &&
          record.completed &&
          _isSameDate(record.date, date),
    );
  }

  bool get hasCurrentUserCheckinToday =>
      hasCurrentUserCheckinOn(DateTime.now());

  bool hasCurrentUserCheckinOn(DateTime date) {
    if (_isSameDate(date, DateTime.now()) && isDoneForCurrentUser) return true;
    return checkins.any(
      (record) =>
          record.actor == CheckinActor.me && _isSameDate(record.date, date),
    );
  }

  bool isCurrentUserIncompleteOn(DateTime date) {
    return hasCurrentUserCheckinOn(date) && !isCurrentUserDoneOn(date);
  }

  bool isPartnerDoneOn(DateTime date) {
    if (_isSameDate(date, DateTime.now())) return partnerDoneToday;
    return checkins.any(
      (record) =>
          record.actor == CheckinActor.partner &&
          record.completed &&
          _isSameDate(record.date, date),
    );
  }

  bool get hasPartnerCheckinToday => hasPartnerCheckinOn(DateTime.now());

  bool hasPartnerCheckinOn(DateTime date) {
    if (_isSameDate(date, DateTime.now()) && partnerDoneToday) return true;
    return checkins.any(
      (record) =>
          record.actor == CheckinActor.partner &&
          _isSameDate(record.date, date),
    );
  }

  bool isPartnerIncompleteOn(DateTime date) {
    return hasPartnerCheckinOn(date) && !isPartnerDoneOn(date);
  }

  TogetherStatus togetherStatusOn(DateTime date) {
    final currentDone = isCurrentUserDoneOn(date);
    final partnerDone = isPartnerDoneOn(date);
    if (currentDone && partnerDone) return TogetherStatus.bothDone;
    if (currentDone && !partnerDone) return TogetherStatus.onlyMeDone;
    return TogetherStatus.meNotDone;
  }

  TogetherStatus get togetherStatus {
    if (doneToday && partnerDoneToday) return TogetherStatus.bothDone;
    if (doneToday && !partnerDoneToday) return TogetherStatus.onlyMeDone;
    return TogetherStatus.meNotDone;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Plan copyWith({
    String? id,
    String? title,
    String? subtitle,
    PlanOwner? owner,
    String? iconKey,
    int? minutes,
    int? completedDays,
    int? totalDays,
    bool? doneToday,
    Color? color,
    String? dailyTask,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
    PlanRepeatType? repeatType,
    bool? hasDateRange,
    bool? partnerDoneToday,
    PlanStatus? status,
    DateTime? endedAt,
    List<CheckinRecord>? checkins,
    int? focusScore,
    DateTime? lastFocusedAt,
  }) {
    return Plan(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      owner: owner ?? this.owner,
      iconKey: iconKey ?? this.iconKey,
      minutes: minutes ?? this.minutes,
      completedDays: completedDays ?? this.completedDays,
      totalDays: totalDays ?? this.totalDays,
      doneToday: doneToday ?? this.doneToday,
      color: color ?? this.color,
      dailyTask: dailyTask ?? this.dailyTask,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderTime: clearReminderTime
          ? null
          : (reminderTime ?? this.reminderTime),
      repeatType: repeatType ?? this.repeatType,
      hasDateRange: hasDateRange ?? this.hasDateRange,
      partnerDoneToday: partnerDoneToday ?? this.partnerDoneToday,
      status: status ?? this.status,
      endedAt: endedAt ?? this.endedAt,
      checkins: checkins ?? this.checkins,
      focusScore: focusScore ?? this.focusScore,
      lastFocusedAt: lastFocusedAt ?? this.lastFocusedAt,
    );
  }
}
