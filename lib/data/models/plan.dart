import 'package:flutter/material.dart';

import '../../shared/utils/plan_icon_mapper.dart';

enum PlanOwner { me, partner, together }

enum PlanStatus { active, ended }

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
    this.hasDateRange = true,
    this.partnerDoneToday = false,
    this.status = PlanStatus.active,
    this.endedAt,
    this.checkins = const [],
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
  final bool hasDateRange;
  final bool partnerDoneToday;
  final PlanStatus status;
  final DateTime? endedAt;
  final List<CheckinRecord> checkins;

  IconData get icon => PlanIconMapper.iconData(iconKey);

  Color get iconColor => PlanIconMapper.color(iconKey);

  Color get iconBackgroundColor => PlanIconMapper.backgroundColor(iconKey);

  double get progress => totalDays == 0 ? 0 : completedDays / totalDays;

  int get remainingDays => (totalDays - completedDays).clamp(0, totalDays);

  bool get hasReminder => reminderTime != null;

  bool get isEnded => status == PlanStatus.ended;

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
    bool? hasDateRange,
    bool? partnerDoneToday,
    PlanStatus? status,
    DateTime? endedAt,
    List<CheckinRecord>? checkins,
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
      hasDateRange: hasDateRange ?? this.hasDateRange,
      partnerDoneToday: partnerDoneToday ?? this.partnerDoneToday,
      status: status ?? this.status,
      endedAt: endedAt ?? this.endedAt,
      checkins: checkins ?? this.checkins,
    );
  }
}
