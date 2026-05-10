import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grow_together/app.dart';
import 'package:grow_together/data/mock/mock_store.dart';
import 'package:grow_together/data/models/focus_session.dart';
import 'package:grow_together/data/models/plan.dart';
import 'package:grow_together/data/models/profile.dart';
import 'package:grow_together/data/services/plan_occurrence_service.dart';
import 'package:grow_together/data/store/store.dart';
import 'package:grow_together/features/focus/focus_page.dart';
import 'package:grow_together/features/plans/create_plan_page.dart';
import 'package:grow_together/features/home/home_page.dart';
import 'package:grow_together/features/plans/plan_detail_page.dart';
import 'package:grow_together/features/plans/plan_list_scaffold.dart';
import 'package:grow_together/features/plans/plans_page.dart';
import 'package:grow_together/features/reminders/reminders_page.dart';
import 'package:grow_together/data/models/reminder.dart';
import 'package:grow_together/shared/utils/plan_icon_mapper.dart';
import 'package:grow_together/shared/widgets/reminder_card.dart';

Plan _testPlan({
  required DateTime startDate,
  required DateTime endDate,
  required PlanRepeatType repeatType,
  bool hasDateRange = true,
}) {
  return Plan(
    id: 'test-plan',
    title: '测试计划',
    subtitle: '测试',
    owner: PlanOwner.me,
    iconKey: PlanIconMapper.defaultKey,
    minutes: 20,
    completedDays: 0,
    totalDays: 1,
    doneToday: false,
    color: Colors.pink,
    dailyTask: '测试',
    startDate: startDate,
    endDate: endDate,
    reminderTime: null,
    repeatType: repeatType,
    hasDateRange: hasDateRange,
  );
}

DateTime _todayOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _daysFromToday(int days) {
  return _todayOnly().add(Duration(days: days));
}

void main() {
  testWidgets('GrowTogether shell shows the home page', (tester) async {
    await tester.pumpWidget(const GrowTogetherApp());

    expect(find.text('一起进步呀'), findsWidgets);
    expect(find.text('我的今日计划'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('计划'), findsOneWidget);
    expect(find.text('专注'), findsOneWidget);
    expect(find.text('提醒'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('HomePage pull-to-refresh refreshes all store data', (
    tester,
  ) async {
    final store = _RefreshSmokeStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<Store>.value(
            value: store,
            child: const HomePage(),
          ),
        ),
      ),
    );

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(store.refreshAllCount, 1);
  });

  testWidgets('HomePage shows gentle loading before cached plans exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<Store>.value(
            value: _PlansInitialLoadingStore(),
            child: const HomePage(),
          ),
        ),
      ),
    );

    expect(find.text('正在同步你的计划...'), findsOneWidget);
    expect(find.text('还没有自己的计划哦～'), findsNothing);
  });

  testWidgets('HomePage keeps cached plans visible while syncing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<Store>.value(
            value: _PlansRefreshingWithCacheStore(),
            child: const HomePage(),
          ),
        ),
      ),
    );

    expect(find.text('同步中'), findsOneWidget);
    expect(find.text('正在同步'), findsNothing);
    expect(find.text('缓存里的计划'), findsOneWidget);
  });

  testWidgets('HomePage hides plans that start tomorrow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: _HomeDateFilterStore(),
          child: const HomePage(),
        ),
      ),
    );

    expect(find.text('今天计划'), findsOneWidget);
    expect(find.text('明天考试'), findsNothing);
  });

  testWidgets('PlansPage overview only summarizes today plans', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: _PlansOverviewDateFilterStore(),
          child: const PlansPage(),
        ),
      ),
    );

    expect(find.text('今天已完成'), findsOneWidget);
    expect(find.text('明天测试'), findsNothing);
    expect(find.text('TA 今天计划'), findsOneWidget);
    expect(find.text('TA 明天计划'), findsNothing);
    expect(find.text('今日完成 1/1'), findsOneWidget);
    expect(find.text('今日完成 0/1'), findsOneWidget);
  });

  testWidgets('HomePage promotes unfinished own plans before completed ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: _HomeProgressionStore(),
          child: const HomePage(),
        ),
      ),
    );

    expect(find.text('第一项待打卡'), findsOneWidget);
    expect(find.text('后面的待打卡'), findsOneWidget);
    expect(find.text('中间已完成'), findsNothing);
  });

  testWidgets('HomePage completes own today plan from status pill', (
    tester,
  ) async {
    final store = _HomeQuickCheckinStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<Store>.value(
            value: store,
            child: const HomePage(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('完成打卡：首页一键打卡'));
    await tester.pumpAndSettle();

    expect(store.getPlanById('home-quick-checkin')?.doneToday, isTrue);
    expect(find.text('已完成「首页一键打卡」打卡'), findsOneWidget);
  });

  testWidgets('HomePage calendar art opens growth records', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: MockStore.instance,
          child: const HomePage(),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.calendar_month_rounded));
    await tester.pumpAndSettle();

    expect(find.text('成长记录'), findsOneWidget);
  });

  testWidgets('FocusPage pull-to-refresh refreshes focus data', (tester) async {
    final store = _FocusRefreshStore();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: const FocusPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(store.refreshFocusSessionsCount, greaterThanOrEqualTo(1));
  });

  testWidgets('FocusPage does not interrupt with incoming invite prompt', (
    tester,
  ) async {
    final store = _FocusInviteStore();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: const FocusPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('TA 邀请你一起专注'), findsNothing);
    expect(find.text('加入专注'), findsNothing);
    expect(find.text('今日专注'), findsOneWidget);
  });

  testWidgets('FocusPage starts a regular focus session without a plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: _FocusRefreshStore(),
          child: const FocusPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('未关联计划'), findsOneWidget);
    expect(find.text('先选择计划'), findsNothing);

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, '开始专注'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, '开始专注'));
    await tester.pump();

    expect(find.text('25:00'), findsWidgets);
    expect(find.text('正在专注：普通专注'), findsOneWidget);
  });

  test('Plan date range controls today availability', () {
    final todayOnly = _todayOnly();
    final yesterday = todayOnly.subtract(const Duration(days: 1));
    final tomorrow = todayOnly.add(const Duration(days: 1));

    final expiredDailyPlan = _testPlan(
      startDate: yesterday,
      endDate: yesterday,
      repeatType: PlanRepeatType.daily,
    );
    expect(expiredDailyPlan.isEnded, isTrue);
    expect(expiredDailyPlan.canCurrentUserCheckin, isFalse);
    expect(expiredDailyPlan.repeatLabel, '已结束');

    final futureDailyPlan = _testPlan(
      startDate: tomorrow,
      endDate: tomorrow.add(const Duration(days: 2)),
      repeatType: PlanRepeatType.daily,
    );
    expect(futureDailyPlan.isNotStartedYet, isTrue);
    expect(futureDailyPlan.canCurrentUserCheckin, isFalse);
    expect(futureDailyPlan.repeatLabel, '未开始');
  });

  test('PlanOccurrenceService filters plans by local calendar date', () {
    final today = _todayOnly();
    final lateToday = DateTime(today.year, today.month, today.day, 23, 30);
    final tomorrow = _daysFromToday(1);

    final todayOncePlan = _testPlan(
      startDate: today,
      endDate: today,
      repeatType: PlanRepeatType.once,
    );
    final tomorrowOncePlan = _testPlan(
      startDate: tomorrow,
      endDate: tomorrow,
      repeatType: PlanRepeatType.once,
    );
    final dailyPlan = _testPlan(
      startDate: tomorrow,
      endDate: tomorrow.add(const Duration(days: 2)),
      repeatType: PlanRepeatType.daily,
    );
    final completedFuturePlan = tomorrowOncePlan.copyWith(doneToday: true);

    expect(
      PlanOccurrenceService.shouldPlanAppearOnDate(todayOncePlan, today),
      isTrue,
    );
    expect(
      PlanOccurrenceService.shouldPlanAppearOnDate(tomorrowOncePlan, today),
      isFalse,
    );
    expect(
      PlanOccurrenceService.shouldPlanAppearOnDate(tomorrowOncePlan, lateToday),
      isFalse,
    );
    expect(
      PlanOccurrenceService.shouldPlanAppearOnDate(tomorrowOncePlan, tomorrow),
      isTrue,
    );
    expect(
      PlanOccurrenceService.shouldPlanAppearOnDate(dailyPlan, today),
      isFalse,
    );
    expect(
      PlanOccurrenceService.shouldPlanAppearOnDate(dailyPlan, tomorrow),
      isTrue,
    );
    expect(
      PlanOccurrenceService.shouldPlanAppearOnDate(
        dailyPlan,
        tomorrow.add(const Duration(days: 3)),
      ),
      isFalse,
    );
    expect(
      PlanOccurrenceService.completedCountForDate(
        plans: [todayOncePlan, completedFuturePlan],
        date: today,
        owner: PlanOwner.me,
      ),
      0,
    );
  });

  test('completed once plans stay visible on completion day', () {
    final completedOncePlan =
        _testPlan(
          startDate: _todayOnly(),
          endDate: _todayOnly(),
          repeatType: PlanRepeatType.once,
        ).copyWith(
          doneToday: true,
          status: PlanStatus.ended,
          endedAt: DateTime.now(),
        );

    expect(completedOncePlan.isEnded, isTrue);
    expect(completedOncePlan.isCompletedOnceToday, isTrue);
    expect(completedOncePlan.shouldShowInActiveLists, isTrue);
  });

  test('MockStore keeps completed once plan visible today', () async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '今天完成后仍显示',
      isShared: false,
      dailyTask: '完成后列表里还能看到',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      reminderTime: null,
      repeatType: PlanRepeatType.once,
      hasDateRange: false,
    );

    await store.saveCheckin(
      planId: plan.id,
      completed: true,
      mood: CheckinMood.happy,
      note: '完成',
    );

    final updated = store.getPlanById(plan.id)!;
    expect(updated.status, PlanStatus.ended);
    expect(updated.doneToday, isTrue);
    expect(store.getPlans().map((item) => item.id), contains(plan.id));
  });

  test('MockStore keeps manually ended plan visible in owner list', () async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '手动结束后仍显示',
      isShared: false,
      dailyTask: '列表里应该能看到已结束',
      startDate: _todayOnly(),
      endDate: _daysFromToday(7),
      reminderTime: null,
      repeatType: PlanRepeatType.daily,
      hasDateRange: true,
    );

    await store.endPlan(plan.id);

    final ended = store.getPlanById(plan.id)!;
    expect(ended.status, PlanStatus.ended);
    expect(store.getPlans(), isNot(contains(ended)));
    expect(
      store.getPlansByOwner(PlanOwner.me).map((item) => item.id),
      contains(plan.id),
    );
  });

  test('MockStore deletes editable plan', () async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '准备删除的计划',
      isShared: false,
      dailyTask: '删除后不再展示',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      reminderTime: null,
      repeatType: PlanRepeatType.once,
      hasDateRange: true,
    );

    await store.deletePlan(plan.id);

    expect(store.getPlanById(plan.id), isNull);
    expect(
      store.getPlansByOwner(PlanOwner.me).map((item) => item.id),
      isNot(contains(plan.id)),
    );
  });

  testWidgets('PlanListScaffold filters plans by selected date', (
    tester,
  ) async {
    final todayPlan = _testPlan(
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      repeatType: PlanRepeatType.once,
    ).copyWith(id: 'today-plan', title: '今天考试');
    final tomorrowPlan = _testPlan(
      startDate: _daysFromToday(1),
      endDate: _daysFromToday(1),
      repeatType: PlanRepeatType.once,
    ).copyWith(id: 'tomorrow-plan', title: '明天考试');

    await tester.pumpWidget(
      MaterialApp(
        home: PlanListScaffold(
          title: '我的计划',
          filterOptions: const ['全部', '待打卡', '已完成'],
          plans: [todayPlan, tomorrowPlan],
          planCountLabel: '共 2 个计划',
          owner: PlanOwner.me,
          onAdd: () {},
          onTapPlan: (_) {},
        ),
      ),
    );

    expect(find.text('今天考试'), findsOneWidget);
    expect(find.text('明天考试'), findsNothing);
    expect(find.textContaining('共 1 个计划'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_month_rounded));
    await tester.pumpAndSettle();

    expect(find.text('选择查看日期'), findsOneWidget);
  });

  testWidgets('PlanListScaffold filters unfinished plans separately', (
    tester,
  ) async {
    final today = _todayOnly();
    final pendingPlan = _testPlan(
      startDate: today,
      endDate: today,
      repeatType: PlanRepeatType.once,
    ).copyWith(id: 'pending-plan', title: '等待完成计划');
    final unfinishedPlan =
        _testPlan(
          startDate: today,
          endDate: today,
          repeatType: PlanRepeatType.once,
        ).copyWith(
          id: 'unfinished-plan',
          title: '今天未完成计划',
          checkins: [
            CheckinRecord(
              date: DateTime.now(),
              completed: false,
              mood: CheckinMood.normal,
              note: '今天没完成',
            ),
          ],
        );
    final completedPlan =
        _testPlan(
          startDate: today,
          endDate: today,
          repeatType: PlanRepeatType.once,
        ).copyWith(
          id: 'completed-plan',
          title: '今天已完成计划',
          completedDays: 1,
          doneToday: true,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: PlanListScaffold(
          title: '我的计划',
          filterOptions: const ['全部', '待打卡', '未完成', '已完成'],
          plans: [pendingPlan, unfinishedPlan, completedPlan],
          planCountLabel: '共 3 个计划',
          owner: PlanOwner.me,
          onAdd: () {},
          onTapPlan: (_) {},
        ),
      ),
    );

    expect(find.text('等待完成计划'), findsOneWidget);
    expect(find.text('今天未完成计划'), findsOneWidget);
    expect(find.text('今天已完成计划'), findsOneWidget);

    await tester.tap(find.text('未完成').first);
    await tester.pumpAndSettle();

    expect(find.text('等待完成计划'), findsNothing);
    expect(find.text('今天未完成计划'), findsOneWidget);
    expect(find.text('今天已完成计划'), findsNothing);

    await tester.tap(find.text('待打卡'));
    await tester.pumpAndSettle();

    expect(find.text('等待完成计划'), findsOneWidget);
    expect(find.text('今天未完成计划'), findsNothing);
    expect(find.text('今天已完成计划'), findsNothing);

    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();

    expect(find.text('等待完成计划'), findsNothing);
    expect(find.text('今天未完成计划'), findsNothing);
    expect(find.text('今天已完成计划'), findsOneWidget);
  });

  testWidgets('PlanListScaffold completes pending plan from status pill', (
    tester,
  ) async {
    var quickCheckinCount = 0;
    var openedPlanCount = 0;
    final plan = _testPlan(
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      repeatType: PlanRepeatType.once,
    ).copyWith(id: 'quick-plan', title: '等待完成计划');

    await tester.pumpWidget(
      MaterialApp(
        home: PlanListScaffold(
          title: '我的计划',
          filterOptions: const ['全部', '待打卡', '已完成'],
          plans: [plan],
          planCountLabel: '共 1 个计划',
          owner: PlanOwner.me,
          onAdd: () {},
          onTapPlan: (_) => openedPlanCount++,
          onQuickCheckin: (_) async => quickCheckinCount++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('完成打卡：等待完成计划'));
    await tester.pumpAndSettle();

    expect(quickCheckinCount, 1);
    expect(openedPlanCount, 0);
    expect(find.text('已完成「等待完成计划」打卡'), findsOneWidget);

    await tester.tap(find.text('等待完成计划'));
    await tester.pumpAndSettle();

    expect(quickCheckinCount, 1);
    expect(openedPlanCount, 1);
  });

  testWidgets(
    'PlanListScaffold only enables quick checkin for eligible plans',
    (tester) async {
      final today = _todayOnly();
      final pendingPlan = _testPlan(
        startDate: today,
        endDate: today,
        repeatType: PlanRepeatType.once,
      ).copyWith(id: 'pending-plan', title: '可直接打卡');
      final completedPlan =
          _testPlan(
            startDate: today,
            endDate: today,
            repeatType: PlanRepeatType.once,
          ).copyWith(
            id: 'completed-plan',
            title: '已经打卡',
            doneToday: true,
            completedDays: 1,
          );
      final unfinishedPlan =
          _testPlan(
            startDate: today,
            endDate: today,
            repeatType: PlanRepeatType.once,
          ).copyWith(
            id: 'unfinished-plan',
            title: '今天未完成',
            checkins: [
              CheckinRecord(
                date: today,
                completed: false,
                mood: CheckinMood.normal,
                note: '',
              ),
            ],
          );
      final partnerPlan = _testPlan(
        startDate: today,
        endDate: today,
        repeatType: PlanRepeatType.once,
      ).copyWith(id: 'partner-plan', title: 'TA 的计划', owner: PlanOwner.partner);

      await tester.pumpWidget(
        MaterialApp(
          home: PlanListScaffold(
            title: '我的计划',
            filterOptions: const ['全部', '待打卡', '未完成', '已完成'],
            plans: [pendingPlan, completedPlan, unfinishedPlan, partnerPlan],
            planCountLabel: '共 4 个计划',
            owner: PlanOwner.me,
            onAdd: () {},
            onTapPlan: (_) {},
            onQuickCheckin: (_) async {},
          ),
        ),
      );

      expect(find.byTooltip('完成打卡：可直接打卡'), findsOneWidget);
      expect(find.byTooltip('完成打卡：已经打卡'), findsNothing);
      expect(find.byTooltip('完成打卡：今天未完成'), findsNothing);
      expect(find.byTooltip('完成打卡：TA 的计划'), findsNothing);
    },
  );

  testWidgets('PlanListScaffold asks before deleting a swiped plan', (
    tester,
  ) async {
    String? deletedPlanId;
    final plan = _testPlan(
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      repeatType: PlanRepeatType.once,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlanListScaffold(
          title: '我的计划',
          filterOptions: const ['全部', '待打卡', '已完成'],
          plans: [plan],
          planCountLabel: '共 1 个计划',
          owner: PlanOwner.me,
          onAdd: () {},
          onTapPlan: (_) {},
          onDeletePlan: (item) async => deletedPlanId = item.id,
        ),
      ),
    );

    await tester.drag(find.text('测试计划'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除计划？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(deletedPlanId, plan.id);
  });

  testWidgets('PlanListScaffold resets swipe offset after deleting a plan', (
    tester,
  ) async {
    final plans = [
      _testPlan(
        startDate: _todayOnly(),
        endDate: _todayOnly(),
        repeatType: PlanRepeatType.once,
      ).copyWith(id: 'first-plan', title: '第一条计划'),
      _testPlan(
        startDate: _todayOnly(),
        endDate: _todayOnly(),
        repeatType: PlanRepeatType.once,
      ).copyWith(id: 'second-plan', title: '第二条计划'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => PlanListScaffold(
            title: '我的计划',
            filterOptions: const ['全部', '待打卡', '已完成'],
            plans: plans,
            planCountLabel: '共 ${plans.length} 个计划',
            owner: PlanOwner.me,
            onAdd: () {},
            onTapPlan: (_) {},
            onDeletePlan: (item) async {
              setState(() {
                plans.removeWhere((plan) => plan.id == item.id);
              });
            },
          ),
        ),
      ),
    );

    await tester.drag(find.text('第一条计划'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('第一条计划'), findsNothing);
    expect(find.text('第二条计划'), findsOneWidget);
    final containers = tester.widgetList<AnimatedContainer>(
      find.ancestor(
        of: find.text('第二条计划'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final swipeContainer = containers.firstWhere(
      (container) => container.transform != null,
    );
    expect(swipeContainer.transform!.storage[12], 0);
  });

  testWidgets('GrowTogether shell switches between the five tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const GrowTogetherApp());

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();
    expect(find.text('共同计划'), findsOneWidget);

    await tester.tap(find.text('专注'));
    await tester.pump();
    expect(find.text('今日专注'), findsOneWidget);
    expect(find.text('先选择计划'), findsNothing);
    expect(find.text('25 分钟'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('未关联计划'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('未关联计划'), findsOneWidget);
    await tester.tap(find.text('未关联计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('学习英语 30 分钟'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('自定义'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    expect(find.text('自定义专注时长'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '37');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(find.text('37 分钟'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, '开始专注'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '开始专注'));
    await tester.pump();
    expect(find.text('37:00'), findsWidgets);
    expect(find.text('正在专注：学习英语 30 分钟'), findsOneWidget);
    expect(find.text('模式：自己专注'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.text('提前结束'));
    await tester.pumpAndSettle();
    expect(find.text('提前结束专注？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '提前结束'));
    await tester.pumpAndSettle();
    expect(find.text('这次没有完成，也没关系'), findsOneWidget);
    await tester.tap(find.text('回到专注'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('今日专注记录'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('今日专注记录'), findsOneWidget);

    await tester.tap(find.text('提醒'));
    await tester.pumpAndSettle();
    expect(find.text('提醒一下'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('待绑定'), findsOneWidget);
    expect(find.text('邀请另一半'), findsOneWidget);

    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('我的今日计划'), findsOneWidget);
  });

  testWidgets(
    'GrowTogether shell clears reminder badge after opening reminders',
    (tester) async {
      final store = _ReminderBadgeStore();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<Store>.value(
            value: store,
            child: const GrowTogetherShell(),
          ),
        ),
      );

      expect(store.unreadReminderCount, 2);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('提醒'));
      await tester.pumpAndSettle();

      expect(store.unreadReminderCount, 0);
      expect(find.text('2'), findsNothing);
    },
  );

  testWidgets('GrowTogether shell counts focus invites in reminder badge', (
    tester,
  ) async {
    final store = _FocusInviteStore();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: const GrowTogetherShell(),
        ),
      ),
    );

    expect(store.unreadReminderCount, 0);
    expect(store.getIncomingFocusInvites().length, 1);
    expect(find.text('1'), findsOneWidget);
  });

  test('MockStore creates plan and saves checkin', () async {
    final store = MockStore.instance;
    final initialCount = store.getPlans().length;

    final plan = await store.createPlan(
      title: '测试计划',
      isShared: true,
      dailyTask: '每天一起复盘 10 分钟',
      startDate: _daysFromToday(-1),
      endDate: _daysFromToday(6),
      reminderTime: const TimeOfDay(hour: 20, minute: 0),
      repeatType: PlanRepeatType.daily,
      hasDateRange: true,
      iconKey: 'music',
    );

    expect(store.getPlans().length, initialCount + 1);
    expect(store.getPlanById(plan.id)?.doneToday, isFalse);
    expect(store.getPlanById(plan.id)?.iconKey, 'music');

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

  test('MockStore records focus session and adds focus score', () async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '专注计分计划',
      isShared: false,
      dailyTask: '完成一段安静专注',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      reminderTime: null,
      repeatType: PlanRepeatType.once,
      hasDateRange: false,
    );
    final beforeScore = store.getPlanById(plan.id)!.focusScore;
    final endedAt = DateTime.now();

    await store.saveFocusSession(
      FocusSession(
        id: 'focus_test',
        planId: plan.id,
        planTitle: plan.title,
        mode: FocusMode.solo,
        plannedDurationMinutes: 25,
        actualDurationSeconds: 25 * 60,
        status: FocusSessionStatus.completed,
        scoreDelta: 5,
        startedAt: endedAt.subtract(const Duration(minutes: 25)),
        endedAt: endedAt,
        createdAt: endedAt,
      ),
    );

    final updated = store.getPlanById(plan.id)!;
    expect(store.getTodayFocusSessions().first.id, 'focus_test');
    expect(updated.focusScore, beforeScore + 5);
    expect(updated.lastFocusedAt, endedAt);
  });

  test('MockStore records regular focus without changing plan score', () async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '不应加分计划',
      isShared: false,
      dailyTask: '普通专注不归属到这里',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      reminderTime: null,
      repeatType: PlanRepeatType.once,
      hasDateRange: false,
    );
    final beforeScore = store.getPlanById(plan.id)!.focusScore;
    final endedAt = DateTime.now();

    await store.saveFocusSession(
      FocusSession(
        id: 'focus_regular_test',
        planId: null,
        planTitle: '普通专注',
        mode: FocusMode.solo,
        plannedDurationMinutes: 25,
        actualDurationSeconds: 25 * 60,
        status: FocusSessionStatus.completed,
        scoreDelta: 5,
        startedAt: endedAt.subtract(const Duration(minutes: 25)),
        endedAt: endedAt,
        createdAt: endedAt,
      ),
    );

    expect(store.getTodayFocusSessions().first.id, 'focus_regular_test');
    expect(store.getTodayFocusSessions().first.planId, isNull);
    expect(store.getPlanById(plan.id)?.focusScore, beforeScore);
  });

  test('MockStore creates and controls couple focus session', () async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '一起专注计划',
      isShared: true,
      dailyTask: '一起完成一段专注',
      startDate: _todayOnly(),
      endDate: _daysFromToday(7),
      reminderTime: null,
      repeatType: PlanRepeatType.daily,
      hasDateRange: true,
    );

    final invite = await store.createCoupleFocusInvite(
      plan: plan,
      plannedDurationMinutes: 25,
    );
    expect(invite.status, FocusSessionStatus.waiting);
    expect(store.getActiveFocusSessions().first.id, invite.id);

    final started = await store.startFocusSessionNow(invite.id);
    expect(started?.status, FocusSessionStatus.running);
    expect(started?.startedAt, isNotNull);

    final paused = await store.pauseFocusSession(invite.id);
    expect(paused?.status, FocusSessionStatus.paused);
    expect(paused?.pausedAt, isNotNull);

    final resumed = await store.resumeFocusSession(invite.id);
    expect(resumed?.status, FocusSessionStatus.running);
    expect(resumed?.pausedAt, isNull);

    final finished = await store.finishFocusSession(
      sessionId: invite.id,
      status: FocusSessionStatus.completed,
      actualDurationSeconds: 25 * 60,
      scoreDelta: 5,
    );
    expect(finished?.status, FocusSessionStatus.completed);
    expect(store.getTodayFocusSessions().first.id, invite.id);
    expect(store.getPlanById(plan.id)?.focusScore, 5);
  });

  test('MockStore exposes refresh entry points', () async {
    final store = MockStore.instance;

    await store.refreshProfile();
    await store.refreshPlans();
    await store.refreshReminders();
    await store.refreshAll();

    expect(store.getProfile().name, isNotEmpty);
    expect(store.getPlans(), isNotEmpty);
    expect(store.getReminders(), isNotEmpty);
  });

  testWidgets('CreatePlanPage shows icon grid and saves selected iconKey', (
    tester,
  ) async {
    final store = MockStore.instance;
    final initialCount = store.getPlans().length;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: MockStore.instance,
          child: const CreatePlanPage(),
        ),
      ),
    );

    expect(find.text('我的计划'), findsOneWidget);
    expect(find.text('共同计划'), findsOneWidget);
    expect(find.text('TA 的计划'), findsNothing);

    // 图标选择区标题存在
    expect(find.text('选择图标'), findsOneWidget);

    // 8 个预设图标都应显示
    expect(find.text('学习'), findsOneWidget);
    expect(find.text('写作业'), findsOneWidget);
    expect(find.text('早起'), findsOneWidget);
    expect(find.text('运动'), findsOneWidget);
    expect(find.text('散步'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('音乐'), findsOneWidget);
    expect(find.text('聊天'), findsOneWidget);

    // "+ 自定义"入口存在
    expect(find.text('自定义'), findsOneWidget);

    // 点击预设图标 '写作业' 选中
    await tester.tap(find.text('写作业'));
    await tester.pumpAndSettle();

    // 输入计划名称并保存
    await tester.enterText(find.byType(TextField).first, '图标测试计划');
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();

    expect(store.getPlans().length, initialCount + 1);
    expect(store.getPlans().first.title, '图标测试计划');
    expect(store.getPlans().first.iconKey, 'edit');
  });

  testWidgets('CreatePlanPage keeps optional schedule fields off by default', (
    tester,
  ) async {
    final store = MockStore.instance;
    final initialCount = store.getPlans().length;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: const CreatePlanPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '今天买晚饭');
    await tester.scrollUntilVisible(
      find.text('计划类型'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('计划类型'), findsOneWidget);
    expect(find.text('单次计划'), findsOneWidget);
    expect(find.text('每日打卡'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('提醒时间'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('提醒时间'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('计划日期'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('计划日期'), findsOneWidget);
    expect(find.text('计划周期'), findsNothing);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('开始日期'), findsNothing);
    expect(find.text('结束日期'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('明天'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('明天'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();

    final plan = store.getPlans().first;
    final tomorrow = _daysFromToday(1);
    expect(store.getPlans().length, initialCount + 1);
    expect(plan.title, '今天买晚饭');
    expect(plan.repeatType, PlanRepeatType.once);
    expect(plan.startDate, tomorrow);
    expect(plan.endDate, tomorrow);
    expect(plan.reminderTime, isNull);
    expect(plan.hasDateRange, isFalse);
    expect(plan.totalDays, 1);
  });

  testWidgets('CreatePlanPage creates daily plans with optional period', (
    tester,
  ) async {
    final store = MockStore.instance;
    final initialCount = store.getPlans().length;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: const CreatePlanPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '每天背单词');
    await tester.scrollUntilVisible(
      find.text('每日打卡'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('每日打卡'));
    await tester.pumpAndSettle();

    expect(find.text('计划周期'), findsOneWidget);
    expect(find.text('长期每日'), findsOneWidget);

    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();

    final plan = store.getPlans().first;
    expect(store.getPlans().length, initialCount + 1);
    expect(plan.title, '每天背单词');
    expect(plan.repeatType, PlanRepeatType.daily);
    expect(plan.hasDateRange, isFalse);
  });

  testWidgets('CreatePlanPage keeps once plan dates when editing', (
    tester,
  ) async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '过期单次计划',
      isShared: false,
      dailyTask: '补交资料',
      startDate: DateTime(2026, 5, 7),
      endDate: DateTime(2026, 5, 7),
      reminderTime: null,
      repeatType: PlanRepeatType.once,
      hasDateRange: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: CreatePlanPage(existingPlan: plan),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '过期单次计划已编辑');
    await tester.tap(find.text('保存修改'));
    await tester.pump(const Duration(milliseconds: 100));

    final updatedPlan = store.getPlans().firstWhere(
      (item) => item.id == plan.id,
    );
    expect(updatedPlan.title, '过期单次计划已编辑');
    expect(updatedPlan.repeatType, PlanRepeatType.once);
    expect(updatedPlan.hasDateRange, isFalse);
    expect(updatedPlan.startDate, DateTime(2026, 5, 7));
    expect(updatedPlan.endDate, DateTime(2026, 5, 7));
  });

  testWidgets('CreatePlanPage "+ 自定义" opens BottomSheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: MockStore.instance,
          child: const CreatePlanPage(),
        ),
      ),
    );

    // 点击 "+ 自定义"
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();

    // BottomSheet 标题
    expect(find.text('自定义图标'), findsOneWidget);

    // 图标名称输入区
    expect(find.text('图标名称'), findsOneWidget);
    expect(find.text('请输入名称，例如：考研、存钱、编程'), findsOneWidget);

    // 图标样式选择区
    expect(find.text('图标样式'), findsOneWidget);
    expect(find.text('书本'), findsOneWidget);
    expect(find.text('星星'), findsOneWidget);
    expect(find.text('爱心'), findsOneWidget);

    // 颜色选择区
    expect(find.text('颜色'), findsOneWidget);
    expect(find.text('粉色'), findsOneWidget);
    expect(find.text('紫色'), findsOneWidget);

    // 保存按钮
    expect(find.text('保存自定义图标'), findsOneWidget);
  });

  testWidgets(
    'CreatePlanPage saves custom icon and shows its name in the grid',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<Store>.value(
            value: MockStore.instance,
            child: const CreatePlanPage(),
          ),
        ),
      );

      // 打开自定义图标弹窗
      await tester.tap(find.text('自定义'));
      await tester.pumpAndSettle();

      // 输入自定义名称
      final nameField = find.widgetWithText(TextField, '请输入名称，例如：考研、存钱、编程');
      await tester.enterText(nameField, '考研');

      // 选择样式：星星
      await tester.tap(find.text('星星'));
      await tester.pumpAndSettle();

      // 选择颜色：紫色
      await tester.tap(find.text('紫色'));
      await tester.pumpAndSettle();

      // 保存
      await tester.tap(find.text('保存自定义图标'));
      await tester.pumpAndSettle();

      // BottomSheet 关闭，图标选择区出现新图标 "考研"
      expect(find.text('考研'), findsOneWidget);

      // "考研" 是自定义图标，key 以 custom_ 开头
      final allOptions = PlanIconMapper.options;
      final customOption = allOptions.firstWhere(
        (o) => o.label == '考研',
        orElse: () => allOptions.first,
      );
      expect(customOption.isCustom, isTrue);
      expect(customOption.key, startsWith('custom_'));

      // 输入计划名称并保存
      await tester.enterText(find.byType(TextField).first, '考研计划');
      await tester.tap(find.text('保存计划'));
      await tester.pumpAndSettle();

      // 保存的计划使用自定义图标 key
      final store = MockStore.instance;
      expect(store.getPlans().first.iconKey, customOption.key);
      // iconKey 能正确解析出自定义名称
      expect(PlanIconMapper.label(customOption.key), '考研');
    },
  );

  test(
    'MockStore blocks partner plan checkin and keeps together statuses separate',
    () async {
      final store = MockStore.instance;
      final partnerPlan = store.getPlans().firstWhere(
        (plan) => plan.owner == PlanOwner.partner,
      );
      final beforePartner = store.getPlanById(partnerPlan.id)!;

      await store.saveCheckin(
        planId: partnerPlan.id,
        completed: true,
        mood: CheckinMood.happy,
        note: '不应该成功',
      );

      final afterPartner = store.getPlanById(partnerPlan.id)!;
      expect(afterPartner.doneToday, beforePartner.doneToday);
      expect(afterPartner.checkins.length, beforePartner.checkins.length);

      final togetherPlan = await store.createPlan(
        title: '共同测试计划',
        isShared: true,
        dailyTask: '各自完成自己的打卡',
        startDate: _daysFromToday(-1),
        endDate: _daysFromToday(6),
        reminderTime: const TimeOfDay(hour: 21, minute: 0),
        repeatType: PlanRepeatType.daily,
        hasDateRange: true,
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

  testWidgets('PlanDetailPage lets together plans remind partner', (
    tester,
  ) async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '共同提醒测试计划',
      isShared: true,
      dailyTask: '互相提醒完成今天的小任务',
      startDate: _daysFromToday(-1),
      endDate: _daysFromToday(6),
      reminderTime: null,
      repeatType: PlanRepeatType.daily,
      hasDateRange: true,
    );
    final initialReminderCount = store.getReminders().length;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: PlanDetailPage(planId: plan.id),
        ),
      ),
    );

    expect(find.text('今日行动'), findsOneWidget);
    expect(find.text('我待打卡'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('最近记录'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('最近记录'), findsOneWidget);
    expect(find.text('还没有记录，完成一次就会出现在这里'), findsOneWidget);
    expect(find.text('提醒 TA'), findsOneWidget);

    await tester.tap(find.text('提醒 TA'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('鼓励一下'));
    await tester.pumpAndSettle();

    expect(store.getReminders().length, initialReminderCount + 1);
    expect(find.text('提醒已经飞过去啦～'), findsOneWidget);
  });

  testWidgets('PlanDetailPage shows incomplete checkin as not completed', (
    tester,
  ) async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '未完成状态测试计划',
      isShared: false,
      dailyTask: '记录今天没有完成',
      startDate: _daysFromToday(-1),
      endDate: _daysFromToday(6),
      reminderTime: null,
      repeatType: PlanRepeatType.daily,
      hasDateRange: true,
    );

    await store.saveCheckin(
      planId: plan.id,
      completed: false,
      mood: CheckinMood.normal,
      note: '今天没完成',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: PlanDetailPage(planId: plan.id),
        ),
      ),
    );

    expect(find.text('未完成'), findsWidgets);
    expect(find.text('待打卡'), findsNothing);
    expect(find.text('修改打卡'), findsOneWidget);
  });

  testWidgets('PlanDetailPage does not remind for a not-started plan', (
    tester,
  ) async {
    final store = MockStore.instance;
    final plan = await store.createPlan(
      title: '明天共同计划',
      isShared: true,
      dailyTask: '明天再开始',
      startDate: _daysFromToday(1),
      endDate: _daysFromToday(1),
      reminderTime: null,
      repeatType: PlanRepeatType.once,
      hasDateRange: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: PlanDetailPage(planId: plan.id),
        ),
      ),
    );

    expect(find.text('未开始'), findsWidgets);
    expect(find.text('提醒 TA'), findsNothing);
  });

  testWidgets('ReminderCard calls onTap when tapped', (tester) async {
    var tapped = false;
    final reminder = Reminder(
      id: 'test-reminder',
      type: ReminderType.gentle,
      content: '测试提醒内容',
      fromUserId: 'user-a',
      toUserId: 'user-b',
      planId: 'plan-123',
      createdAt: DateTime(2026, 5, 8, 10, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReminderCard(reminder: reminder, onTap: () => tapped = true),
        ),
      ),
    );

    await tester.tap(find.text('测试提醒内容'));
    expect(tapped, isTrue);
  });

  testWidgets(
    'PlanDetailPage shows friendly message when prompt reminder is blocked',
    (tester) async {
      final store = _BlockedPromptReminderStore();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<Store>.value(
            value: store,
            child: const PlanDetailPage(planId: 'partner-plan'),
          ),
        ),
      );

      await tester.tap(find.text('提醒 TA'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('温柔提醒'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('TA 今天已经完成这个计划啦，换个夸夸会更合适'), findsOneWidget);
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(
        find.textContaining(
          'prompt reminders are not allowed after completion',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('RemindersPage filters reminders by selected date', (
    tester,
  ) async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final store = _ReminderDateFilterStore(today: today, yesterday: yesterday);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: const Scaffold(body: RemindersPage()),
        ),
      ),
    );

    expect(find.text('今天的提醒'), findsOneWidget);
    expect(find.text('昨天的提醒'), findsNothing);

    await tester.tap(find.text(yesterday.day.toString().padLeft(2, '0')));
    await tester.pumpAndSettle();

    expect(find.text('今天的提醒'), findsNothing);
    expect(find.text('昨天的提醒'), findsOneWidget);
  });

  testWidgets('RemindersPage separates focus invites from normal reminders', (
    tester,
  ) async {
    final store = _FocusInviteStore();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: const Scaffold(body: RemindersPage()),
        ),
      ),
    );

    expect(find.text('一起专注邀请'), findsOneWidget);
    expect(find.text('加入专注'), findsOneWidget);
    expect(find.text('婉拒'), findsOneWidget);

    await tester.tap(find.text('婉拒'));
    await tester.pumpAndSettle();

    expect(store.getIncomingFocusInvites(), isEmpty);
    expect(find.text('一起专注邀请'), findsNothing);
  });

  testWidgets('RemindersPage focus invite card fits a small viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FocusInviteStore();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: const Scaffold(body: RemindersPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('一起专注邀请'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FocusPage adopts a joined couple focus session', (tester) async {
    final store = _FocusInviteStore();
    await store.joinFocusSession('incoming-focus');

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<Store>.value(
          value: store,
          child: const FocusPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('正在专注：专注测试计划'), findsOneWidget);
    expect(find.text('模式：一起专注'), findsOneWidget);
  });
}

class _ReminderBadgeStore extends Store {
  final List<Reminder> _reminders = [
    Reminder(
      id: 'reminder-a',
      type: ReminderType.gentle,
      content: '提醒 A',
      fromUserId: 'partner',
      toUserId: 'me',
      createdAt: DateTime(2026, 5, 8, 12, 0),
    ),
    Reminder(
      id: 'reminder-b',
      type: ReminderType.praise,
      content: '提醒 B',
      fromUserId: 'partner',
      toUserId: 'me',
      createdAt: DateTime(2026, 5, 8, 12, 5),
    ),
  ];

  @override
  Profile getProfile() => const Profile(
    name: '测试',
    partnerName: '对方',
    togetherDays: 1,
    inviteCode: 'TEST',
    isBound: true,
  );

  @override
  Future<void> refreshProfile() async {}

  @override
  List<Plan> getPlans() => [];

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) => [];

  @override
  List<Plan> getTodayFocusPlans() => [];

  @override
  List<Plan> getAllPlans() => [];

  @override
  Plan? getPlanById(String id) => null;

  @override
  Future<Plan> createPlan({
    required String title,
    required bool isShared,
    required String dailyTask,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay? reminderTime,
    PlanRepeatType repeatType = PlanRepeatType.once,
    bool hasDateRange = true,
    String iconKey = PlanIconMapper.defaultKey,
    bool syncSystemCalendar = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePlan({
    required String planId,
    String? title,
    String? dailyTask,
    String? iconKey,
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
    PlanRepeatType? repeatType,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasDateRange,
  }) async {}

  @override
  Future<void> endPlan(String planId) async {}

  @override
  List<CheckinRecord> getCheckinRecords(String planId) => [];

  @override
  Future<void> saveCheckin({
    required String planId,
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) async {}

  @override
  Future<void> updatePlanStatus(
    String planId, {
    required bool doneToday,
  }) async {}

  @override
  List<Reminder> getReminders() => List.unmodifiable(_reminders);

  @override
  int get unreadReminderCount =>
      _reminders.where((r) => !r.sentByMe && !r.isRead).length;

  @override
  Future<void> sendReminder({
    required String planId,
    required ReminderType type,
    required String content,
  }) async {}

  @override
  Future<void> markReceivedRemindersRead() async {
    for (var index = 0; index < _reminders.length; index++) {
      _reminders[index] = _reminders[index].copyWith(isRead: true);
    }
    notifyListeners();
  }
}

class _RefreshSmokeStore extends Store {
  int refreshAllCount = 0;

  @override
  Profile getProfile() => const Profile(
    name: '测试',
    partnerName: '对方',
    togetherDays: 9,
    inviteCode: 'TEST',
    isBound: true,
  );

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<void> refreshAll() async {
    refreshAllCount += 1;
  }

  @override
  List<Plan> getPlans() => [];

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) => [];

  @override
  List<Plan> getTodayFocusPlans() => [];

  @override
  List<Plan> getAllPlans() => [];

  @override
  Plan? getPlanById(String id) => null;

  @override
  Future<Plan> createPlan({
    required String title,
    required bool isShared,
    required String dailyTask,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay? reminderTime,
    PlanRepeatType repeatType = PlanRepeatType.once,
    bool hasDateRange = true,
    String iconKey = PlanIconMapper.defaultKey,
    bool syncSystemCalendar = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePlan({
    required String planId,
    String? title,
    String? dailyTask,
    String? iconKey,
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
    PlanRepeatType? repeatType,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasDateRange,
  }) async {}

  @override
  Future<void> endPlan(String planId) async {}

  @override
  List<CheckinRecord> getCheckinRecords(String planId) => [];

  @override
  Future<void> saveCheckin({
    required String planId,
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) async {}

  @override
  Future<void> updatePlanStatus(
    String planId, {
    required bool doneToday,
  }) async {}

  @override
  List<Reminder> getReminders() => [];

  @override
  int get unreadReminderCount => 0;

  @override
  Future<void> sendReminder({
    required String planId,
    required ReminderType type,
    required String content,
  }) async {}

  @override
  Future<void> markReceivedRemindersRead() async {}
}

class _PlansInitialLoadingStore extends _RefreshSmokeStore {
  @override
  bool get isInitialPlansLoading => true;
}

class _PlansRefreshingWithCacheStore extends _HomeDateFilterStore {
  @override
  bool get hasHydratedPlanCache => true;

  @override
  bool get isRefreshingPlans => true;

  @override
  List<Plan> getPlans() => [
    _homePlan(
      id: 'cached-home-plan',
      title: '缓存里的计划',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
    ),
  ];
}

class _HomeDateFilterStore extends _RefreshSmokeStore {
  final List<Plan> _plans = [
    _homePlan(
      id: 'today-home-plan',
      title: '今天计划',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
    ),
    _homePlan(
      id: 'tomorrow-home-plan',
      title: '明天考试',
      startDate: _daysFromToday(1),
      endDate: _daysFromToday(1),
    ),
  ];

  @override
  List<Plan> getPlans() => List.unmodifiable(_plans);

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) =>
      _plans.where((plan) => plan.owner == owner).toList();

  @override
  List<Plan> getAllPlans() => List.unmodifiable(_plans);

  @override
  Plan? getPlanById(String id) {
    for (final plan in _plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }
}

class _PlansOverviewDateFilterStore extends _RefreshSmokeStore {
  final List<Plan> _plans = [
    _homePlan(
      id: 'today-completed-plan',
      title: '今天已完成',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      doneToday: true,
    ),
    _homePlan(
      id: 'tomorrow-plan',
      title: '明天测试',
      startDate: _daysFromToday(1),
      endDate: _daysFromToday(1),
    ),
    _homePlan(
      id: 'partner-today-plan',
      title: 'TA 今天计划',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      owner: PlanOwner.partner,
    ),
    _homePlan(
      id: 'partner-tomorrow-plan',
      title: 'TA 明天计划',
      startDate: _daysFromToday(1),
      endDate: _daysFromToday(1),
      owner: PlanOwner.partner,
      partnerDoneToday: true,
    ),
  ];

  @override
  List<Plan> getPlans() => List.unmodifiable(_plans);

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) =>
      _plans.where((plan) => plan.owner == owner).toList();

  @override
  List<Plan> getAllPlans() => List.unmodifiable(_plans);

  @override
  Plan? getPlanById(String id) {
    for (final plan in _plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }
}

class _HomeProgressionStore extends _RefreshSmokeStore {
  final List<Plan> _plans = [
    _homePlan(
      id: 'pending-front',
      title: '第一项待打卡',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
    ),
    _homePlan(
      id: 'completed-middle',
      title: '中间已完成',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
      doneToday: true,
    ),
    _homePlan(
      id: 'pending-behind',
      title: '后面的待打卡',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
    ),
  ];

  @override
  List<Plan> getPlans() => List.unmodifiable(_plans);

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) =>
      _plans.where((plan) => plan.owner == owner).toList();

  @override
  List<Plan> getAllPlans() => List.unmodifiable(_plans);

  @override
  Plan? getPlanById(String id) {
    for (final plan in _plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }
}

class _HomeQuickCheckinStore extends _RefreshSmokeStore {
  final List<Plan> _plans = [
    _homePlan(
      id: 'home-quick-checkin',
      title: '首页一键打卡',
      startDate: _todayOnly(),
      endDate: _todayOnly(),
    ),
  ];

  @override
  List<Plan> getPlans() => List.unmodifiable(_plans);

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) =>
      _plans.where((plan) => plan.owner == owner).toList();

  @override
  List<Plan> getAllPlans() => List.unmodifiable(_plans);

  @override
  Plan? getPlanById(String id) {
    for (final plan in _plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  @override
  Future<void> saveCheckin({
    required String planId,
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) return;
    final plan = _plans[index];
    _plans[index] = plan.copyWith(
      doneToday: completed,
      completedDays: completed ? 1 : 0,
      checkins: [
        CheckinRecord(
          date: _todayOnly(),
          completed: completed,
          mood: mood,
          note: note,
        ),
      ],
    );
    notifyListeners();
  }
}

Plan _homePlan({
  required String id,
  required String title,
  required DateTime startDate,
  required DateTime endDate,
  PlanOwner owner = PlanOwner.me,
  bool doneToday = false,
  bool partnerDoneToday = false,
}) {
  return Plan(
    id: id,
    title: title,
    subtitle: '$title说明',
    owner: owner,
    iconKey: 'book',
    minutes: 20,
    completedDays: doneToday ? 1 : 0,
    totalDays: 1,
    doneToday: doneToday,
    color: Colors.pink,
    dailyTask: title,
    startDate: startDate,
    endDate: endDate,
    reminderTime: null,
    repeatType: PlanRepeatType.once,
    hasDateRange: true,
    partnerDoneToday: partnerDoneToday,
  );
}

class _FocusRefreshStore extends _RefreshSmokeStore {
  int refreshFocusSessionsCount = 0;

  final Plan _plan = Plan(
    id: 'focus-plan',
    title: '专注测试计划',
    subtitle: '完成一段专注',
    owner: PlanOwner.me,
    iconKey: 'book',
    minutes: 25,
    completedDays: 0,
    totalDays: 7,
    doneToday: false,
    color: Colors.pink,
    dailyTask: '完成一段专注',
    startDate: _todayOnly(),
    endDate: _daysFromToday(7),
    reminderTime: null,
  );

  @override
  List<Plan> getPlans() => [_plan];

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) =>
      owner == _plan.owner ? [_plan] : [];

  @override
  List<Plan> getTodayFocusPlans() => [_plan];

  @override
  List<Plan> getAllPlans() => [_plan];

  @override
  Plan? getPlanById(String id) => id == _plan.id ? _plan : null;

  @override
  Future<void> refreshFocusSessions() async {
    refreshFocusSessionsCount += 1;
    notifyListeners();
  }
}

class _FocusInviteStore extends _FocusRefreshStore {
  late FocusSession _session = FocusSession(
    id: 'incoming-focus',
    planId: 'focus-plan',
    planTitle: '专注测试计划',
    mode: FocusMode.couple,
    plannedDurationMinutes: 25,
    actualDurationSeconds: 0,
    status: FocusSessionStatus.waiting,
    scoreDelta: 0,
    creatorUserId: 'partner',
    sentByMe: false,
    createdAt: DateTime.now(),
  );

  @override
  List<FocusSession> getFocusSessions() => [_session];

  @override
  List<FocusSession> getActiveFocusSessions() =>
      _session.isActive ? [_session] : [];

  @override
  List<FocusSession> getIncomingFocusInvites() =>
      _session.canJoin ? [_session] : [];

  @override
  Future<FocusSession?> joinFocusSession(String sessionId) async {
    if (_session.id != sessionId || !_session.canJoin) return null;
    final now = DateTime.now();
    _session = _session.copyWith(
      status: FocusSessionStatus.running,
      startedAt: now,
      partnerJoinedAt: now,
    );
    notifyListeners();
    return _session;
  }

  @override
  Future<FocusSession?> finishFocusSession({
    required String sessionId,
    required FocusSessionStatus status,
    required int actualDurationSeconds,
    required int scoreDelta,
  }) async {
    if (_session.id != sessionId) return null;
    _session = _session.copyWith(
      status: status,
      actualDurationSeconds: actualDurationSeconds,
      scoreDelta: scoreDelta,
      endedAt: DateTime.now(),
    );
    notifyListeners();
    return _session;
  }

  void completeInvite() {
    final endedAt = DateTime.now();
    _session = _session.copyWith(
      status: FocusSessionStatus.completed,
      actualDurationSeconds: 25 * 60,
      scoreDelta: 5,
      startedAt: endedAt.subtract(const Duration(minutes: 25)),
      endedAt: endedAt,
      partnerJoinedAt: endedAt,
    );
    notifyListeners();
  }
}

class _BlockedPromptReminderStore extends Store {
  final Plan _plan = Plan(
    id: 'partner-plan',
    title: '阅读计划',
    subtitle: '每天读 12 页',
    owner: PlanOwner.partner,
    iconKey: 'book',
    minutes: 12,
    completedDays: 0,
    totalDays: 31,
    doneToday: false,
    partnerDoneToday: false,
    color: Colors.pink,
    dailyTask: '读 12 页书',
    startDate: _daysFromToday(-1),
    endDate: _daysFromToday(30),
    reminderTime: const TimeOfDay(hour: 20, minute: 0),
  );

  @override
  Profile getProfile() => const Profile(
    name: '测试',
    partnerName: '对方',
    togetherDays: 1,
    inviteCode: 'TEST',
    isBound: true,
  );

  @override
  Future<void> refreshProfile() async {}

  @override
  List<Plan> getPlans() => [_plan];

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) =>
      owner == _plan.owner ? [_plan] : [];

  @override
  List<Plan> getTodayFocusPlans() => [_plan];

  @override
  List<Plan> getAllPlans() => [_plan];

  @override
  Plan? getPlanById(String id) => id == _plan.id ? _plan : null;

  @override
  Future<Plan> createPlan({
    required String title,
    required bool isShared,
    required String dailyTask,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay? reminderTime,
    PlanRepeatType repeatType = PlanRepeatType.once,
    bool hasDateRange = true,
    String iconKey = PlanIconMapper.defaultKey,
    bool syncSystemCalendar = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePlan({
    required String planId,
    String? title,
    String? dailyTask,
    String? iconKey,
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
    PlanRepeatType? repeatType,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasDateRange,
  }) async {}

  @override
  Future<void> endPlan(String planId) async {}

  @override
  List<CheckinRecord> getCheckinRecords(String planId) => [];

  @override
  Future<void> saveCheckin({
    required String planId,
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) async {}

  @override
  Future<void> updatePlanStatus(
    String planId, {
    required bool doneToday,
  }) async {}

  @override
  List<Reminder> getReminders() => [];

  @override
  int get unreadReminderCount => 0;

  @override
  Future<void> sendReminder({
    required String planId,
    required ReminderType type,
    required String content,
  }) {
    throw Exception(
      'PostgrestException(message: prompt reminders are not allowed after completion, code: P0001, details: Bad Request, hint: null)',
    );
  }

  @override
  Future<void> markReceivedRemindersRead() async {}
}

class _ReminderDateFilterStore extends Store {
  _ReminderDateFilterStore({
    required DateTime today,
    required DateTime yesterday,
  }) : _reminders = [
         Reminder(
           id: 'today-reminder',
           type: ReminderType.gentle,
           content: '今天的提醒',
           fromUserId: 'partner',
           toUserId: 'me',
           createdAt: DateTime(today.year, today.month, today.day, 9, 0),
         ),
         Reminder(
           id: 'yesterday-reminder',
           type: ReminderType.strict,
           content: '昨天的提醒',
           fromUserId: 'partner',
           toUserId: 'me',
           createdAt: DateTime(
             yesterday.year,
             yesterday.month,
             yesterday.day,
             9,
             0,
           ),
         ),
       ];

  final List<Reminder> _reminders;

  @override
  Profile getProfile() => const Profile(
    name: '测试',
    partnerName: '对方',
    togetherDays: 1,
    inviteCode: 'TEST',
    isBound: true,
  );

  @override
  Future<void> refreshProfile() async {}

  @override
  List<Plan> getPlans() => [];

  @override
  List<Plan> getPlansByOwner(PlanOwner owner) => [];

  @override
  List<Plan> getTodayFocusPlans() => [];

  @override
  List<Plan> getAllPlans() => [];

  @override
  Plan? getPlanById(String id) => null;

  @override
  Future<Plan> createPlan({
    required String title,
    required bool isShared,
    required String dailyTask,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay? reminderTime,
    PlanRepeatType repeatType = PlanRepeatType.once,
    bool hasDateRange = true,
    String iconKey = PlanIconMapper.defaultKey,
    bool syncSystemCalendar = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePlan({
    required String planId,
    String? title,
    String? dailyTask,
    String? iconKey,
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
    PlanRepeatType? repeatType,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasDateRange,
  }) async {}

  @override
  Future<void> endPlan(String planId) async {}

  @override
  List<CheckinRecord> getCheckinRecords(String planId) => [];

  @override
  Future<void> saveCheckin({
    required String planId,
    required bool completed,
    required CheckinMood mood,
    required String note,
  }) async {}

  @override
  Future<void> updatePlanStatus(
    String planId, {
    required bool doneToday,
  }) async {}

  @override
  List<Reminder> getReminders() => List.unmodifiable(_reminders);

  @override
  int get unreadReminderCount => _reminders.length;

  @override
  Future<void> sendReminder({
    required String planId,
    required ReminderType type,
    required String content,
  }) async {}

  @override
  Future<void> markReceivedRemindersRead() async {}
}
