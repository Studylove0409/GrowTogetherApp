import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grow_together/data/mock/mock_store.dart';
import 'package:grow_together/data/store/store.dart';
import 'package:grow_together/features/plans/create_plan_page.dart';
import 'package:grow_together/shared/utils/plan_icon_mapper.dart';

void main() {
  setUp(() {
    PlanIconMapper.clearCustomOptions();
  });

  testWidgets(
    'long-pressing a custom icon shows delete confirmation and removes it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<Store>.value(
            value: MockStore.instance,
            child: const CreatePlanPage(),
          ),
        ),
      );

      // 1. 打开自定义图标弹窗
      await tester.tap(find.text('自定义'));
      await tester.pumpAndSettle();

      // 2. 输入名称并保存
      final nameField = find.widgetWithText(
        TextField,
        '请输入名称，例如：考研、存钱、编程',
      );
      await tester.enterText(nameField, '考研');
      await tester.tap(find.text('保存自定义图标'));
      await tester.pumpAndSettle();

      // 3. 新图标出现在网格中
      expect(find.text('考研'), findsOneWidget);

      // 4. 长按自定义图标 "考研"
      await tester.longPress(find.text('考研'));
      await tester.pumpAndSettle();

      // 5. 弹出确认删除对话框
      expect(find.text('删除自定义图标'), findsOneWidget);
      expect(find.text('确定要删除 "考研" 图标吗？'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      // 6. 点击确认删除
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 7. 图标从网格消失
      expect(find.text('考研'), findsNothing);
    },
  );

  testWidgets(
    'deleting the selected custom icon falls back to default icon',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<Store>.value(
            value: MockStore.instance,
            child: const CreatePlanPage(),
          ),
        ),
      );

      // 1. 添加自定义图标
      await tester.tap(find.text('自定义'));
      await tester.pumpAndSettle();
      final nameField = find.widgetWithText(
        TextField,
        '请输入名称，例如：考研、存钱、编程',
      );
      await tester.enterText(nameField, '编程');
      await tester.tap(find.text('保存自定义图标'));
      await tester.pumpAndSettle();

      // 2. 点击选中自定义图标 "编程"
      await tester.tap(find.text('编程'));
      await tester.pumpAndSettle();

      // 3. 长按删除该图标
      await tester.longPress(find.text('编程'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 4. 图标消失
      expect(find.text('编程'), findsNothing);

      // 5. 默认图标 "学习" 被重新选中（检查它的边框样式或 Semantic selected 状态）
      final studyFinder = find.ancestor(
        of: find.text('学习'),
        matching: find.byType(AnimatedContainer),
      );
      expect(studyFinder, findsOneWidget);
    },
  );
}
