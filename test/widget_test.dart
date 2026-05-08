import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grow_together/app.dart';
import 'package:grow_together/data/mock/mock_store.dart';
import 'package:grow_together/data/models/plan.dart';
import 'package:grow_together/data/models/profile.dart';
import 'package:grow_together/data/store/store.dart';
import 'package:grow_together/features/plans/create_plan_page.dart';
import 'package:grow_together/data/models/reminder.dart';
import 'package:grow_together/shared/utils/plan_icon_mapper.dart';
import 'package:grow_together/shared/widgets/reminder_card.dart';

void main() {
  testWidgets('GrowTogether shell shows the home page', (tester) async {
    await tester.pumpWidget(const GrowTogetherApp());

    expect(find.text('一起进步呀'), findsWidgets);
    expect(find.text('我的今日计划'), findsOneWidget);
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
    expect(find.text('待绑定'), findsOneWidget);
    expect(find.text('我们的空间邀请码'), findsOneWidget);

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

  test('MockStore creates plan and saves checkin', () async {
    final store = MockStore.instance;
    final initialCount = store.getPlans().length;

    final plan = await store.createPlan(
      title: '测试计划',
      isShared: true,
      dailyTask: '每天一起复盘 10 分钟',
      startDate: DateTime(2026, 5, 7),
      endDate: DateTime(2026, 5, 14),
      reminderTime: const TimeOfDay(hour: 20, minute: 0),
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
    required TimeOfDay reminderTime,
    String iconKey = PlanIconMapper.defaultKey,
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
    DateTime? startDate,
    DateTime? endDate,
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
