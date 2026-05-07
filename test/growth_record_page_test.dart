import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grow_together/data/models/plan.dart';
import 'package:grow_together/features/home/growth_record_page.dart';

void main() {
  testWidgets('GrowthRecordPage filters weekly stats by actor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GrowthRecordPage(today: DateTime(2026, 5, 7))),
    );

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('只看我'), findsOneWidget);
    expect(find.text('只看TA'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('growth-stat-week-checks')))
          .data,
      '16',
    );

    await tester.tap(find.text('只看TA'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('growth-stat-week-checks')))
          .data,
      '6',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('growth-stat-together-days')))
          .data,
      '7',
    );
  });

  testWidgets('GrowthRecordPage changes the visible calendar month', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GrowthRecordPage(today: DateTime(2026, 5, 7))),
    );

    expect(find.text('2026 年 5 月'), findsOneWidget);

    await tester.tap(find.byTooltip('上个月'));
    await tester.pumpAndSettle();

    expect(find.text('2026 年 4 月'), findsOneWidget);

    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();

    expect(find.text('2026 年 5 月'), findsOneWidget);
  });

  testWidgets('GrowthRecordPage opens records for a calendar day', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GrowthRecordPage(today: DateTime(2026, 5, 7))),
    );

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-5-7')));
    await tester.pumpAndSettle();

    expect(find.text('5月7日打卡记录'), findsOneWidget);
    expect(find.text('学习英语 30 分钟'), findsOneWidget);
    expect(find.text('运动 45 分钟'), findsOneWidget);
    expect(find.textContaining('TA · 已完成'), findsWidgets);
  });

  testWidgets(
    'GrowthRecordPage builds timeline from checkins and handles empty data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: GrowthRecordPage(today: DateTime(2026, 5, 7))),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -520));
      await tester.pumpAndSettle();

      expect(find.textContaining('05月07日'), findsOneWidget);
      expect(find.textContaining('你完成了'), findsWidgets);
      expect(find.textContaining('TA完成了'), findsWidgets);
      expect(find.textContaining('05.20'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, 520));
      await tester.pumpAndSettle();
      await tester.tap(find.text('只看我'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -520));
      await tester.pumpAndSettle();

      expect(find.textContaining('05月07日'), findsOneWidget);
      expect(find.textContaining('TA完成了'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: GrowthRecordPage(
            key: const ValueKey('empty-growth-record-page'),
            today: DateTime(2026, 5, 7),
            plans: const <Plan>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('growth-stat-week-checks')))
            .data,
        '0',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -520));
      await tester.pumpAndSettle();
      expect(find.text('还没有成长记录哦～开始打卡后这里会慢慢丰富起来～'), findsOneWidget);
    },
  );
}
