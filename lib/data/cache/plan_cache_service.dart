import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/utils/plan_icon_mapper.dart';
import '../models/plan.dart';

class PlanCacheSnapshot {
  const PlanCacheSnapshot({required this.cachedAt, required this.plans});

  final DateTime cachedAt;
  final List<Plan> plans;
}

class PlanCacheService {
  const PlanCacheService();

  static const _schemaVersion = 1;
  static const _keyPrefix = 'grow_together.plan_cache.v1';

  Future<PlanCacheSnapshot?> readPlans(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyForUser(userId));
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['version'] != _schemaVersion) return null;

      final plansJson = decoded['plans'];
      if (plansJson is! List) return null;

      final cachedAt =
          _tryParseDateTime(decoded['cachedAt'] as String?) ?? DateTime.now();
      final plans = <Plan>[];
      for (final item in plansJson) {
        if (item is Map<String, dynamic>) {
          final plan = _planFromJson(item);
          if (plan != null) plans.add(plan);
        }
      }

      return PlanCacheSnapshot(cachedAt: cachedAt, plans: plans);
    } catch (_) {
      return null;
    }
  }

  Future<void> writePlans(String userId, List<Plan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'version': _schemaVersion,
      'cachedAt': DateTime.now().toIso8601String(),
      'plans': plans.map(_planToJson).toList(),
    };
    await prefs.setString(_keyForUser(userId), jsonEncode(payload));
  }

  String _keyForUser(String userId) => '$_keyPrefix.$userId';

  Map<String, dynamic> _planToJson(Plan plan) {
    return {
      'id': plan.id,
      'title': plan.title,
      'subtitle': plan.subtitle,
      'owner': plan.owner.name,
      'iconKey': plan.iconKey,
      'minutes': plan.minutes,
      'completedDays': plan.completedDays,
      'totalDays': plan.totalDays,
      'doneToday': plan.doneToday,
      'dailyTask': plan.dailyTask,
      'startDate': plan.startDate.toIso8601String(),
      'endDate': plan.endDate.toIso8601String(),
      'reminderTime': _timeOfDayToJson(plan.reminderTime),
      'repeatType': plan.repeatType.name,
      'hasDateRange': plan.hasDateRange,
      'partnerDoneToday': plan.partnerDoneToday,
      'status': plan.status.name,
      'endedAt': plan.endedAt?.toIso8601String(),
      'checkins': plan.checkins.map(_checkinToJson).toList(),
      'focusScore': plan.focusScore,
      'lastFocusedAt': plan.lastFocusedAt?.toIso8601String(),
    };
  }

  Plan? _planFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final title = json['title'] as String?;
    final dailyTask = json['dailyTask'] as String?;
    final startDate = _tryParseDateTime(json['startDate'] as String?);
    final endDate = _tryParseDateTime(json['endDate'] as String?);
    if (id == null ||
        title == null ||
        dailyTask == null ||
        startDate == null ||
        endDate == null) {
      return null;
    }

    final iconKey = json['iconKey'] as String? ?? PlanIconMapper.defaultKey;
    return Plan(
      id: id,
      title: title,
      subtitle: json['subtitle'] as String? ?? dailyTask,
      owner: _enumByName(
        PlanOwner.values,
        json['owner'] as String?,
        PlanOwner.me,
      ),
      iconKey: iconKey,
      minutes: _intValue(json['minutes'], fallback: 20),
      completedDays: _intValue(json['completedDays']),
      totalDays: _intValue(json['totalDays'], fallback: 1),
      doneToday: json['doneToday'] as bool? ?? false,
      color: PlanIconMapper.color(iconKey),
      dailyTask: dailyTask,
      startDate: startDate,
      endDate: endDate,
      reminderTime: _timeOfDayFromJson(json['reminderTime']),
      repeatType: _enumByName(
        PlanRepeatType.values,
        json['repeatType'] as String?,
        PlanRepeatType.daily,
      ),
      hasDateRange: json['hasDateRange'] as bool? ?? true,
      partnerDoneToday: json['partnerDoneToday'] as bool? ?? false,
      status: _enumByName(
        PlanStatus.values,
        json['status'] as String?,
        PlanStatus.active,
      ),
      endedAt: _tryParseDateTime(json['endedAt'] as String?),
      checkins: _checkinsFromJson(json['checkins']),
      focusScore: _intValue(json['focusScore']),
      lastFocusedAt: _tryParseDateTime(json['lastFocusedAt'] as String?),
    );
  }

  Map<String, dynamic> _checkinToJson(CheckinRecord record) {
    return {
      'date': record.date.toIso8601String(),
      'completed': record.completed,
      'mood': record.mood.name,
      'note': record.note,
      'actor': record.actor.name,
    };
  }

  List<CheckinRecord> _checkinsFromJson(Object? input) {
    if (input is! List) return const [];
    final records = <CheckinRecord>[];
    for (final item in input) {
      if (item is! Map<String, dynamic>) continue;
      final date = _tryParseDateTime(item['date'] as String?);
      if (date == null) continue;
      records.add(
        CheckinRecord(
          date: date,
          completed: item['completed'] as bool? ?? false,
          mood: _enumByName(
            CheckinMood.values,
            item['mood'] as String?,
            CheckinMood.happy,
          ),
          note: item['note'] as String? ?? '',
          actor: _enumByName(
            CheckinActor.values,
            item['actor'] as String?,
            CheckinActor.me,
          ),
        ),
      );
    }
    return records;
  }

  Map<String, int>? _timeOfDayToJson(TimeOfDay? value) {
    if (value == null) return null;
    return {'hour': value.hour, 'minute': value.minute};
  }

  TimeOfDay? _timeOfDayFromJson(Object? input) {
    if (input is! Map<String, dynamic>) return null;
    final hour = _intValue(input['hour'], fallback: -1);
    final minute = _intValue(input['minute'], fallback: -1);
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime? _tryParseDateTime(String? input) {
    if (input == null || input.isEmpty) return null;
    return DateTime.tryParse(input);
  }

  int _intValue(Object? input, {int fallback = 0}) {
    if (input is int) return input;
    if (input is num) return input.toInt();
    return fallback;
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
