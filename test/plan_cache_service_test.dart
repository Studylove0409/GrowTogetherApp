import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grow_together/data/cache/plan_cache_service.dart';
import 'package:grow_together/data/models/plan.dart';
import 'package:grow_together/shared/utils/plan_icon_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PlanCacheService round-trips plan fields', () async {
    const service = PlanCacheService();
    final plan = Plan(
      id: 'plan-1',
      title: '早起',
      subtitle: '八点前起床',
      owner: PlanOwner.together,
      iconKey: PlanIconMapper.defaultKey,
      minutes: 20,
      completedDays: 3,
      totalDays: 7,
      doneToday: true,
      color: Colors.pink,
      dailyTask: '八点前起床',
      startDate: DateTime(2026, 5, 10),
      endDate: DateTime(2026, 5, 16),
      reminderTime: const TimeOfDay(hour: 8, minute: 0),
      repeatType: PlanRepeatType.daily,
      hasDateRange: true,
      partnerDoneToday: false,
      status: PlanStatus.active,
      checkins: [
        CheckinRecord(
          date: DateTime(2026, 5, 10),
          completed: true,
          mood: CheckinMood.great,
          note: '完成',
        ),
      ],
      focusScore: 12,
      lastFocusedAt: DateTime(2026, 5, 10, 9),
    );

    await service.writePlans('user-a', [plan]);
    final snapshot = await service.readPlans('user-a');

    expect(snapshot, isNotNull);
    expect(snapshot!.plans, hasLength(1));
    final cached = snapshot.plans.single;
    expect(cached.id, plan.id);
    expect(cached.title, plan.title);
    expect(cached.owner, PlanOwner.together);
    expect(cached.doneToday, isTrue);
    expect(cached.partnerDoneToday, isFalse);
    expect(cached.reminderTime, const TimeOfDay(hour: 8, minute: 0));
    expect(cached.repeatType, PlanRepeatType.daily);
    expect(cached.checkins.single.mood, CheckinMood.great);
    expect(cached.focusScore, 12);
    expect(cached.lastFocusedAt, DateTime(2026, 5, 10, 9));
  });

  test('PlanCacheService isolates users and ignores broken cache', () async {
    const service = PlanCacheService();
    await service.writePlans('user-a', const []);

    final userA = await service.readPlans('user-a');
    final userB = await service.readPlans('user-b');

    expect(userA, isNotNull);
    expect(userA!.plans, isEmpty);
    expect(userB, isNull);

    SharedPreferences.setMockInitialValues({
      'grow_together.plan_cache.v1.user-c': '{broken',
    });
    expect(await service.readPlans('user-c'), isNull);
  });
}
