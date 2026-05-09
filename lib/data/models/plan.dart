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

  double get progress => totalDays == 0 ? 0 : completedDays / totalDays;

  int get remainingDays => (totalDays - completedDays).clamp(0, totalDays);

  bool get hasReminder => reminderTime != null;

  bool get isEnded => status == PlanStatus.ended;

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
    if (isOnce) return isOverdue ? '已逾期' : '单次';
    if (hasDateRange) return '每日 · $totalDays天';
    return '每日';
  }

  bool get canCurrentUserCheckin => owner != PlanOwner.partner && !isEnded;

  bool get canCurrentUserEdit => owner != PlanOwner.partner && !isEnded;

  bool get isTogetherDoneToday => doneToday && partnerDoneToday;

  // 统一判定：当前计划是否完成（按角色视角）
  bool get isDoneForCurrentUser => switch (owner) {
    PlanOwner.me => doneToday,
    PlanOwner.partner => partnerDoneToday,
    PlanOwner.together => doneToday,
  };

  TogetherStatus get togetherStatus {
    if (doneToday && partnerDoneToday) return TogetherStatus.bothDone;
    if (doneToday && !partnerDoneToday) return TogetherStatus.onlyMeDone;
    return TogetherStatus.meNotDone;
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
