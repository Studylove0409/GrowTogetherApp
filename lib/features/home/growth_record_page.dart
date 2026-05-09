import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/store/store.dart';
import '../../data/models/plan.dart';
import '../../shared/widgets/app_card.dart';

enum FilterType { all, me, partner }

class GrowthRecordPage extends StatefulWidget {
  const GrowthRecordPage({super.key, this.today, this.plans});

  final DateTime? today;
  final List<Plan>? plans;

  @override
  State<GrowthRecordPage> createState() => _GrowthRecordPageState();
}

class _GrowthRecordPageState extends State<GrowthRecordPage> {
  late DateTime _currentMonth;
  FilterType _filter = FilterType.all;

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final today = _today;
    _currentMonth = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final plans = widget.plans ?? store.getAllPlans();
    final profile = store.getProfile();
    final checkins = _filterCheckins(
      plans.expand((plan) => plan.checkins).toList(),
      _filter,
    );
    final timelineRecords = _buildTimelineRecords(plans);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('成长记录', style: AppTextStyles.section),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.background,
                AppColors.paperWarm.withValues(alpha: 0.46),
                AppColors.cream,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: RefreshIndicator(
            color: AppColors.deepPink,
            onRefresh: context.read<Store>().refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                _FilterBar(
                  filter: _filter,
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: AppSpacing.md),
                _StatsOverviewCard(
                  togetherDays: profile.togetherDays,
                  checkins: checkins,
                  today: _today,
                ),
                const SizedBox(height: AppSpacing.md),
                _CheckinCalendar(
                  checkins: checkins,
                  currentMonth: _currentMonth,
                  today: _today,
                  onPreviousMonth: () => setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month - 1,
                    );
                  }),
                  onNextMonth: () => setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                    );
                  }),
                  onDaySelected: (date) =>
                      _showDayRecords(context, plans, date),
                ),
                const SizedBox(height: AppSpacing.md),
                _WeeklyTrendCard(
                  checkins: checkins,
                  today: _today,
                  animationKey: _filter,
                ),
                const SizedBox(height: AppSpacing.md),
                _GrowthTimeline(
                  records: timelineRecords,
                  emptyMessage: _filter == FilterType.all
                      ? '还没有成长记录哦～开始打卡后这里会慢慢丰富起来～'
                      : '该筛选下暂无数据',
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.favorite_rounded, size: 18),
                    label: const Text('继续记录你们的小进步吧'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepPink,
                      side: BorderSide(
                        color: AppColors.deepPink.withValues(alpha: 0.42),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.62),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<CheckinRecord> _filterCheckins(
    List<CheckinRecord> records,
    FilterType filter,
  ) {
    return switch (filter) {
      FilterType.all => records,
      FilterType.me =>
        records.where((record) => record.actor == CheckinActor.me).toList(),
      FilterType.partner =>
        records
            .where((record) => record.actor == CheckinActor.partner)
            .toList(),
    };
  }

  List<String> _buildTimelineRecords(List<Plan> plans) {
    final today = _today;
    final startDate = today.subtract(const Duration(days: 6));
    final grouped = <DateTime, _TimelineDay>{};

    for (final plan in plans) {
      final records = _filterCheckins(plan.checkins, _filter).where((record) {
        final date = _dateOnly(record.date);
        return record.completed &&
            !date.isBefore(startDate) &&
            !date.isAfter(today);
      });

      for (final record in records) {
        final date = _dateOnly(record.date);
        final day = grouped.putIfAbsent(date, () => _TimelineDay());
        switch (record.actor) {
          case CheckinActor.me:
            day.myPlans.add(plan.title);
          case CheckinActor.partner:
            day.partnerPlans.add(plan.title);
        }
      }
    }

    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final date in dates)
        if (grouped[date]!.hasRecords)
          '${date.month.toString().padLeft(2, '0')}月'
              '${date.day.toString().padLeft(2, '0')}日 — '
              '${grouped[date]!.description}',
    ];
  }

  void _showDayRecords(BuildContext context, List<Plan> plans, DateTime date) {
    final entries = _dayEntries(plans, date);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.month}月${date.day}日打卡记录',
                  style: AppTextStyles.section,
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            '这天还没有打卡记录哦～',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final entry in entries)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: _DayRecordTile(entry: entry),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_DayRecordEntry> _dayEntries(List<Plan> plans, DateTime date) {
    final selectedDate = _dateOnly(date);
    final entries = <_DayRecordEntry>[];
    for (final plan in plans) {
      final records = _filterCheckins(plan.checkins, _filter).where((record) {
        return _dateOnly(record.date) == selectedDate;
      });
      for (final record in records) {
        entries.add(_DayRecordEntry(planTitle: plan.title, record: record));
      }
    }
    return entries;
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _TimelineDay {
  final List<String> myPlans = [];
  final List<String> partnerPlans = [];

  bool get hasRecords => myPlans.isNotEmpty || partnerPlans.isNotEmpty;

  String get description {
    final parts = <String>[];
    if (myPlans.isNotEmpty) {
      parts.add('你完成了${myPlans.map((title) => '「$title」').join()}');
    }
    if (partnerPlans.isNotEmpty) {
      parts.add('TA完成了${partnerPlans.map((title) => '「$title」').join()}');
    }
    return parts.join('，');
  }
}

class _DayRecordEntry {
  const _DayRecordEntry({required this.planTitle, required this.record});

  final String planTitle;
  final CheckinRecord record;
}

class _DayRecordTile extends StatelessWidget {
  const _DayRecordTile({required this.entry});

  final _DayRecordEntry entry;

  @override
  Widget build(BuildContext context) {
    final isMe = entry.record.actor == CheckinActor.me;
    final statusColor = entry.record.completed
        ? AppColors.successText
        : AppColors.reminder;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              entry.record.completed
                  ? Icons.check_rounded
                  : Icons.close_rounded,
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.planTitle,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${isMe ? '你' : 'TA'} · ${entry.record.completed ? '已完成' : '未完成'}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.record.note.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.record.note,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.deepPink.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.deepPink, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.section),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.tiny.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final FilterType filter;
  final ValueChanged<FilterType> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (filter: FilterType.all, label: '全部', icon: Icons.auto_awesome_rounded),
      (filter: FilterType.me, label: '只看我', icon: Icons.person_rounded),
      (filter: FilterType.partner, label: '只看TA', icon: Icons.favorite_rounded),
    ];

    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _FilterPill(
                label: item.label,
                icon: item.icon,
                selected: item.filter == filter,
                onTap: () => onChanged(item.filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: double.infinity,
            decoration: BoxDecoration(
              color: selected ? AppColors.deepPink : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.deepPink.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.secondaryText,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsOverviewCard extends StatelessWidget {
  const _StatsOverviewCard({
    required this.togetherDays,
    required this.checkins,
    required this.today,
  });

  final int togetherDays;
  final List<CheckinRecord> checkins;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final totalChecks = checkins.length;
    final completedChecks = checkins.where((c) => c.completed).length;
    final totalRate = totalChecks == 0 ? 0.0 : completedChecks / totalChecks;
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekChecks = checkins.where((c) {
      final date = _dateOnly(c.date);
      return c.completed && !date.isBefore(weekStart) && !date.isAfter(today);
    }).length;

    return AppCard(
      borderRadius: 32,
      padding: EdgeInsets.zero,
      backgroundColor: AppColors.blush.withValues(alpha: 0.72),
      borderColor: Colors.white.withValues(alpha: 0.82),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: [
                  AppColors.lightPink.withValues(alpha: 0.44),
                  Colors.white.withValues(alpha: 0.58),
                  AppColors.mint.withValues(alpha: 0.34),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const _CardTitle(
                  icon: Icons.insights_rounded,
                  title: '进步概览',
                  subtitle: '最近打卡状态一眼看清',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _StatItem(
                      value: '$togetherDays',
                      label: '一起进步',
                      unit: '天',
                      color: AppColors.deepPink,
                      backgroundColor: AppColors.lightPink,
                      valueKey: const ValueKey('growth-stat-together-days'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatItem(
                      value: '${(totalRate * 100).round()}',
                      label: '总完成率',
                      unit: '%',
                      color: AppColors.successText,
                      backgroundColor: AppColors.mint,
                      valueKey: const ValueKey('growth-stat-total-rate'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatItem(
                      value: '$weekChecks',
                      label: '本周完成',
                      unit: '次',
                      color: AppColors.secondaryText,
                      backgroundColor: AppColors.peach,
                      valueKey: const ValueKey('growth-stat-week-checks'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _ProgressSummary(rate: totalRate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.unit,
    required this.color,
    required this.backgroundColor,
    required this.valueKey,
  });

  final String value;
  final String label;
  final String unit;
  final Color color;
  final Color backgroundColor;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 106,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    key: valueKey,
                    semanticsLabel: '$label $value$unit',
                    style: AppTextStyles.title.copyWith(
                      color: color,
                      fontSize: 30,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 2),
                    child: Text(
                      unit,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final percent = (rate * 100).round();
    return Column(
      children: [
        Row(
          children: [
            Text(
              '完成率',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.deepPink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: rate.clamp(0, 1),
            minHeight: 9,
            backgroundColor: Colors.white.withValues(alpha: 0.78),
            color: AppColors.deepPink,
          ),
        ),
      ],
    );
  }
}

class _CheckinCalendar extends StatelessWidget {
  const _CheckinCalendar({
    required this.checkins,
    required this.currentMonth,
    required this.today,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final List<CheckinRecord> checkins;
  final DateTime currentMonth;
  final DateTime today;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    ).day;
    final firstWeekday = DateTime(
      currentMonth.year,
      currentMonth.month,
      1,
    ).weekday;
    final isCurrentMonth =
        currentMonth.year == today.year && currentMonth.month == today.month;

    final completedDates = checkins
        .where((c) => c.completed)
        .map((c) => DateTime(c.date.year, c.date.month, c.date.day))
        .toSet();

    return AppCard(
      borderRadius: 30,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.paper,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 7;
          return Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _CardTitle(
                      icon: Icons.calendar_month_rounded,
                      title: '打卡日历',
                      subtitle: '点击日期查看当天记录',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MonthButton(
                    tooltip: '上个月',
                    icon: Icons.chevron_left_rounded,
                    onPressed: onPreviousMonth,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 88),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blush.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${currentMonth.year} 年 ${currentMonth.month} 月',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  _MonthButton(
                    tooltip: '下个月',
                    icon: Icons.chevron_right_rounded,
                    onPressed: onNextMonth,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: const ['一', '二', '三', '四', '五', '六', '日']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                runSpacing: 6,
                children: [
                  for (var i = 1; i < firstWeekday; i++)
                    SizedBox(width: cellWidth, height: 40),
                  for (var day = 1; day <= daysInMonth; day++)
                    SizedBox(
                      width: cellWidth,
                      height: 40,
                      child: _CalendarCell(
                        date: DateTime(
                          currentMonth.year,
                          currentMonth.month,
                          day,
                        ),
                        day: day,
                        isCompleted: completedDates.contains(
                          DateTime(currentMonth.year, currentMonth.month, day),
                        ),
                        isToday: isCurrentMonth && day == today.day,
                        onTap: () => onDaySelected(
                          DateTime(currentMonth.year, currentMonth.month, day),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _LegendDot(color: AppColors.successText, label: '已完成'),
                  const SizedBox(width: AppSpacing.md),
                  _LegendDot(
                    color: AppColors.deepPink.withValues(alpha: 0.85),
                    label: '今天',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: AppColors.deepPink,
        style: IconButton.styleFrom(
          fixedSize: const Size(34, 34),
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.date,
    required this.day,
    required this.isCompleted,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final int day;
  final bool isCompleted;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    if (isCompleted) {
      bgColor = AppColors.successText;
    } else if (isToday) {
      bgColor = AppColors.lightPink.withValues(alpha: 0.62);
    }

    return Semantics(
      button: true,
      label: '查看 ${date.year}年${date.month}月${date.day}日 打卡记录',
      child: Center(
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey(
              'calendar-day-${date.year}-${date.month}-${date.day}',
            ),
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: AppColors.deepPink, width: 1.6)
                    : null,
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: AppColors.successText.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 17,
                      )
                    : Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: isToday ? AppColors.deepPink : AppColors.text,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.36),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _WeeklyTrendCard extends StatelessWidget {
  const _WeeklyTrendCard({
    required this.checkins,
    required this.today,
    required this.animationKey,
  });

  final List<CheckinRecord> checkins;
  final DateTime today;
  final Object animationKey;

  @override
  Widget build(BuildContext context) {
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final labels = ['一', '二', '三', '四', '五', '六', '日'];

    final dailyRates = <double>[];
    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      if (date.isAfter(today)) {
        dailyRates.add(-1); // future day
        continue;
      }
      final dayCheckins = checkins.where((c) {
        final cd = _dateOnly(c.date);
        return cd == date;
      }).toList();

      if (dayCheckins.isEmpty) {
        dailyRates.add(0);
      } else {
        final completed = dayCheckins.where((c) => c.completed).length;
        dailyRates.add(completed / dayCheckins.length);
      }
    }

    final maxRate = dailyRates
        .where((r) => r >= 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return AppCard(
      borderRadius: 30,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.bar_chart_rounded,
            title: '本周趋势',
            subtitle: '每天完成率变化',
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 148,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.blush.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      Expanded(
                        child: _BarColumn(
                          label: labels[i],
                          rate: dailyRates[i],
                          maxRate: maxRate,
                          isToday: i == today.weekday - 1,
                          key: ValueKey('$animationKey-$i'),
                        ),
                      ),
                      if (i < 6) const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            maxRate == 0 ? '本周还没有完成记录' : '粉色高亮为今天',
            style: AppTextStyles.tiny.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatefulWidget {
  const _BarColumn({
    required super.key,
    required this.label,
    required this.rate,
    required this.maxRate,
    required this.isToday,
  });

  final String label;
  final double rate;
  final double maxRate;
  final bool isToday;

  @override
  State<_BarColumn> createState() => _BarColumnState();
}

class _BarColumnState extends State<_BarColumn> {
  bool _animatedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _animatedIn = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFuture = widget.rate < 0;
    final targetHeight = isFuture
        ? 0.0
        : widget.maxRate == 0
        ? 0.0
        : (widget.rate / widget.maxRate * 72).clamp(6, 72).toDouble();
    final barHeight = _animatedIn ? targetHeight : 0.0;
    final activeColor = widget.isToday
        ? AppColors.deepPink
        : AppColors.primary.withValues(alpha: 0.64);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 16,
          child: !isFuture
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.rate == 0 ? '-' : '${(widget.rate * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: widget.isToday
                          ? AppColors.deepPink
                          : AppColors.secondaryText,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 74,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              width: 20,
              height: barHeight,
              decoration: BoxDecoration(
                gradient: isFuture
                    ? null
                    : LinearGradient(
                        colors: [
                          activeColor.withValues(alpha: 0.96),
                          activeColor.withValues(alpha: 0.48),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                color: isFuture ? Colors.transparent : null,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 26,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isToday
                ? AppColors.deepPink.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isFuture ? '' : widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: widget.isToday ? FontWeight.w900 : FontWeight.w700,
              color: widget.isToday
                  ? AppColors.deepPink
                  : AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _GrowthTimeline extends StatelessWidget {
  const _GrowthTimeline({required this.records, required this.emptyMessage});

  final List<String> records;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 30,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.timeline_rounded,
            title: '成长时间线',
            subtitle: '最近的小进步都在这里',
          ),
          const SizedBox(height: AppSpacing.md),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.blush.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.deepPink.withValues(alpha: 0.62),
                      size: 34,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(records.length, (i) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < records.length - 1 ? AppSpacing.md : 0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: i == 0
                        ? AppColors.lightPink.withValues(alpha: 0.52)
                        : AppColors.blush.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? AppColors.deepPink
                              : AppColors.primary.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          i == 0 ? Icons.favorite_rounded : Icons.check_rounded,
                          color: i == 0 ? Colors.white : AppColors.deepPink,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          records[i],
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
