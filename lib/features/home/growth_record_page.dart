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
        title: const Text('成长记录', style: AppTextStyles.section),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.deepPink,
          onRefresh: context.read<Store>().refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              _FilterBar(
                filter: _filter,
                onChanged: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: AppSpacing.lg),
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
                onDaySelected: (date) => _showDayRecords(context, plans, date),
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
                    side: const BorderSide(color: AppColors.deepPink),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final FilterType filter;
  final ValueChanged<FilterType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FilterType>(
      showSelectedIcon: false,
      selected: {filter},
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.lightPink.withValues(alpha: 0.56);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.deepPink;
          }
          return AppColors.secondaryText;
        }),
        side: WidgetStateProperty.all(
          BorderSide(color: AppColors.deepPink.withValues(alpha: 0.22)),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      segments: const [
        ButtonSegment(value: FilterType.all, label: Text('全部')),
        ButtonSegment(value: FilterType.me, label: Text('只看我')),
        ButtonSegment(value: FilterType.partner, label: Text('只看TA')),
      ],
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.46),
      child: Column(
        children: [
          Row(
            children: [
              _StatItem(
                value: '$togetherDays',
                label: '一起进步\n天数',
                color: AppColors.deepPink,
                valueKey: const ValueKey('growth-stat-together-days'),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatItem(
                value: '${(totalRate * 100).round()}%',
                label: '总完成率',
                color: AppColors.successText,
                valueKey: const ValueKey('growth-stat-total-rate'),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatItem(
                value: '$weekChecks',
                label: '本周完成',
                color: AppColors.reminder,
                valueKey: const ValueKey('growth-stat-week-checks'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: totalRate.clamp(0, 1),
              minHeight: 10,
              backgroundColor: AppColors.lightPink.withValues(alpha: 0.66),
              color: AppColors.deepPink,
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
    required this.color,
    required this.valueKey,
  });

  final String value;
  final String label;
  final Color color;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                key: valueKey,
                semanticsLabel: '${label.replaceAll('\n', '')} $value',
                style: AppTextStyles.title.copyWith(color: color, fontSize: 28),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
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

    final cellWidth = (MediaQuery.sizeOf(context).width - 64) / 7;

    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('打卡日历', style: AppTextStyles.section),
                ),
                IconButton(
                  tooltip: '上个月',
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: AppColors.deepPink,
                ),
                Text(
                  '${currentMonth.year} 年 ${currentMonth.month} 月',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                IconButton(
                  tooltip: '下个月',
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: AppColors.deepPink,
                ),
              ],
            ),
          ),
          Row(
            children: const ['一', '二', '三', '四', '五', '六', '日']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
            children: [
              for (var i = 1; i < firstWeekday; i++)
                SizedBox(width: cellWidth, height: 38),
              for (var day = 1; day <= daysInMonth; day++)
                SizedBox(
                  width: cellWidth,
                  height: 38,
                  child: _CalendarCell(
                    date: DateTime(currentMonth.year, currentMonth.month, day),
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
          const SizedBox(height: AppSpacing.sm),
          const Center(
            child: _LegendDot(color: AppColors.successText, label: '已完成'),
          ),
        ],
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
    }

    return Semantics(
      button: true,
      label: '查看 ${date.year}年${date.month}月${date.day}日 打卡记录',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(color: AppColors.deepPink, width: 1.5)
                  : null,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
                        color: isToday ? AppColors.deepPink : AppColors.text,
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
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.md,
            ),
            child: Text('本周趋势', style: AppTextStyles.section),
          ),
          SizedBox(
            height: 120,
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
        : (widget.rate / widget.maxRate * 72).clamp(4, 72).toDouble();
    final barHeight = _animatedIn ? targetHeight : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!isFuture)
          Text(
            widget.rate == 0 ? '-' : '${(widget.rate * 100).round()}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: widget.isToday
                  ? AppColors.deepPink
                  : AppColors.secondaryText,
            ),
          )
        else
          const Text('', style: TextStyle(fontSize: 10)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          height: barHeight,
          decoration: BoxDecoration(
            color: isFuture
                ? Colors.transparent
                : widget.isToday
                ? AppColors.deepPink.withValues(alpha: 0.72)
                : AppColors.lightPink.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isFuture ? '' : widget.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: widget.isToday ? FontWeight.w900 : FontWeight.w600,
            color: widget.isToday
                ? AppColors.deepPink
                : AppColors.secondaryText,
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
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: Text('成长时间线', style: AppTextStyles.section),
          ),
          const SizedBox(height: AppSpacing.md),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            ...List.generate(records.length, (i) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < records.length - 1 ? AppSpacing.md : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? AppColors.deepPink
                                : AppColors.lightPink,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i < records.length - 1)
                          Container(
                            width: 1.5,
                            height: 32,
                            color: AppColors.line,
                          ),
                      ],
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
              );
            }),
        ],
      ),
    );
  }
}
