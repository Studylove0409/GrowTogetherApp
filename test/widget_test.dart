import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grow_together/app.dart';
import 'package:grow_together/data/mock/mock_store.dart';
import 'package:grow_together/data/models/plan.dart';

void main() {
  testWidgets('GrowTogether shell shows the home page', (tester) async {
    await tester.pumpWidget(const GrowTogetherApp());

    expect(find.text('一起进步呀'), findsWidgets);
    expect(find.text('今日重点计划'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('计划'), findsOneWidget);
    expect(find.text('提醒'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('GrowTogether shell switches between the four tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const GrowTogetherApp());

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();
    expect(find.text('共同计划'), findsOneWidget);

    await tester.tap(find.text('提醒'));
    await tester.pumpAndSettle();
    expect(find.text('提醒一下'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('LOVE5208'), findsOneWidget);

    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('今日重点计划'), findsOneWidget);
  });

  test('MockStore creates plan and saves checkin', () {
    final store = MockStore.instance;
    final initialCount = store.getPlans().length;

    final plan = store.createPlan(
      title: '测试计划',
      owner: PlanOwner.together,
      dailyTask: '每天一起复盘 10 分钟',
      startDate: DateTime(2026, 5, 7),
      endDate: DateTime(2026, 5, 14),
      reminderTime: const TimeOfDay(hour: 20, minute: 0),
    );

    expect(store.getPlans().length, initialCount + 1);
    expect(store.getPlanById(plan.id)?.doneToday, isFalse);

    store.saveCheckin(
      planId: plan.id,
      completed: true,
      mood: CheckinMood.great,
      note: '完成打卡',
    );

    final updated = store.getPlanById(plan.id)!;
    expect(updated.doneToday, isTrue);
    expect(updated.completedDays, 1);
    expect(updated.checkins.first.note, '完成打卡');
    expect(updated.partnerDoneToday, isFalse);
  });

  test(
    'MockStore blocks partner plan checkin and keeps together statuses separate',
    () {
      final store = MockStore.instance;
      final partnerPlan = store.getPlans().firstWhere(
        (plan) => plan.owner == PlanOwner.partner,
      );
      final beforePartner = store.getPlanById(partnerPlan.id)!;

      store.saveCheckin(
        planId: partnerPlan.id,
        completed: true,
        mood: CheckinMood.happy,
        note: '不应该成功',
      );

      final afterPartner = store.getPlanById(partnerPlan.id)!;
      expect(afterPartner.doneToday, beforePartner.doneToday);
      expect(afterPartner.checkins.length, beforePartner.checkins.length);

      final togetherPlan = store.createPlan(
        title: '共同测试计划',
        owner: PlanOwner.together,
        dailyTask: '各自完成自己的打卡',
        startDate: DateTime(2026, 5, 7),
        endDate: DateTime(2026, 5, 14),
        reminderTime: const TimeOfDay(hour: 21, minute: 0),
      );

      store.saveCheckin(
        planId: togetherPlan.id,
        completed: true,
        mood: CheckinMood.great,
        note: '我已完成',
      );

      final updatedTogether = store.getPlanById(togetherPlan.id)!;
      expect(updatedTogether.doneToday, isTrue);
      expect(updatedTogether.partnerDoneToday, isFalse);
      expect(updatedTogether.isTogetherDoneToday, isFalse);
    },
  );
}
