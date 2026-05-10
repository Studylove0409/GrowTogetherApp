import 'package:flutter/material.dart';

class ReminderSettings {
  const ReminderSettings({
    this.dailyReminderEnabled = true,
    this.dailyReminderTime = const TimeOfDay(hour: 20, minute: 30),
    this.partnerActivityReminderEnabled = true,
    this.doNotDisturbEnabled = false,
    this.doNotDisturbStart = const TimeOfDay(hour: 22, minute: 30),
    this.doNotDisturbEnd = const TimeOfDay(hour: 8, minute: 0),
  });

  final bool dailyReminderEnabled;
  final TimeOfDay dailyReminderTime;
  final bool partnerActivityReminderEnabled;
  final bool doNotDisturbEnabled;
  final TimeOfDay doNotDisturbStart;
  final TimeOfDay doNotDisturbEnd;

  int get doNotDisturbStartMinutes => _minutesOf(doNotDisturbStart);

  int get doNotDisturbEndMinutes => _minutesOf(doNotDisturbEnd);

  ReminderSettings copyWith({
    bool? dailyReminderEnabled,
    TimeOfDay? dailyReminderTime,
    bool? partnerActivityReminderEnabled,
    bool? doNotDisturbEnabled,
    TimeOfDay? doNotDisturbStart,
    TimeOfDay? doNotDisturbEnd,
  }) {
    return ReminderSettings(
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      partnerActivityReminderEnabled:
          partnerActivityReminderEnabled ?? this.partnerActivityReminderEnabled,
      doNotDisturbEnabled: doNotDisturbEnabled ?? this.doNotDisturbEnabled,
      doNotDisturbStart: doNotDisturbStart ?? this.doNotDisturbStart,
      doNotDisturbEnd: doNotDisturbEnd ?? this.doNotDisturbEnd,
    );
  }

  static int _minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;
}
