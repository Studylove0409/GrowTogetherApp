import 'package:flutter/material.dart';

enum PlanOwner { me, partner, together }

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
    required this.icon,
    required this.minutes,
    required this.completedDays,
    required this.totalDays,
    required this.doneToday,
    required this.color,
    required this.dailyTask,
    required this.startDate,
    required this.endDate,
    required this.reminderTime,
    this.partnerDoneToday = false,
    this.checkins = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final PlanOwner owner;
  final IconData icon;
  final int minutes;
  final int completedDays;
  final int totalDays;
  final bool doneToday;
  final Color color;
  final String dailyTask;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay reminderTime;
  final bool partnerDoneToday;
  final List<CheckinRecord> checkins;

  double get progress => totalDays == 0 ? 0 : completedDays / totalDays;

  bool get canCurrentUserCheckin => owner != PlanOwner.partner;

  bool get canCurrentUserEdit => owner != PlanOwner.partner;

  bool get isTogetherDoneToday => doneToday && partnerDoneToday;

  Plan copyWith({
    String? id,
    String? title,
    String? subtitle,
    PlanOwner? owner,
    IconData? icon,
    int? minutes,
    int? completedDays,
    int? totalDays,
    bool? doneToday,
    Color? color,
    String? dailyTask,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? reminderTime,
    bool? partnerDoneToday,
    List<CheckinRecord>? checkins,
  }) {
    return Plan(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      owner: owner ?? this.owner,
      icon: icon ?? this.icon,
      minutes: minutes ?? this.minutes,
      completedDays: completedDays ?? this.completedDays,
      totalDays: totalDays ?? this.totalDays,
      doneToday: doneToday ?? this.doneToday,
      color: color ?? this.color,
      dailyTask: dailyTask ?? this.dailyTask,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderTime: reminderTime ?? this.reminderTime,
      partnerDoneToday: partnerDoneToday ?? this.partnerDoneToday,
      checkins: checkins ?? this.checkins,
    );
  }
}
