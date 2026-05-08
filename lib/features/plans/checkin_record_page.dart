import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/store/store.dart';
import '../../data/models/plan.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_tile.dart';

class CheckinRecordPage extends StatelessWidget {
  const CheckinRecordPage({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final plan = store.getPlanById(planId);
    if (plan == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('打卡记录')),
            body: const Center(child: Text('计划不存在')),
          );
        }

        final records = plan.checkins;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('打卡记录', style: AppTextStyles.section),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                32,
              ),
              children: [
                _RecordPlanHeader(plan: plan),
                const SizedBox(height: AppSpacing.md),
                _MonthHeader(plan: plan),
                const SizedBox(height: AppSpacing.lg),
                _CalendarCard(plan: plan, records: records),
                const SizedBox(height: AppSpacing.lg),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('最近打卡', style: AppTextStyles.section),
                ),
                const SizedBox(height: AppSpacing.md),
                if (records.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        '还没有打卡记录',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  )
                else
                  ...records.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _CheckinTile(record: record),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepPink,
                      side: const BorderSide(color: AppColors.deepPink),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      '返回计划详情',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

class _RecordPlanHeader extends StatelessWidget {
  const _RecordPlanHeader({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.42),
      child: Row(
        children: [
          AppIconTile(icon: plan.icon, color: plan.iconColor, size: 54),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.section,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  plan.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.deepPink,
          ),
          onPressed: () {},
        ),
        Text(
          '${now.year} 年 ${now.month} 月',
          style: AppTextStyles.title.copyWith(fontSize: 20),
        ),
        IconButton(
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.deepPink,
          ),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.plan, required this.records});

  final Plan plan;
  final List<CheckinRecord> records;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday;
    final completedDates = records
        .where((r) => r.completed)
        .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
        .toSet();
    final today = DateTime(now.year, now.month, now.day);

    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: const ['一', '二', '三', '四', '五', '六', '日']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
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
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 64) / 7,
                  height: 40,
                ),
              for (var day = 1; day <= daysInMonth; day++)
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 64) / 7,
                  height: 40,
                  child: _DayCell(
                    day: day,
                    isCompleted: completedDates.contains(
                      DateTime(now.year, now.month, day),
                    ),
                    isToday: day == today.day,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isCompleted,
    required this.isToday,
  });

  final int day;
  final bool isCompleted;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isCompleted
          ? BoxDecoration(
              color: AppColors.lightPink.withValues(alpha: 0.64),
              shape: BoxShape.circle,
            )
          : isToday
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.deepPink, width: 1.5),
            )
          : null,
      child: Center(
        child: isCompleted
            ? const Icon(
                Icons.check_rounded,
                color: AppColors.successText,
                size: 16,
              )
            : Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  color: isToday ? AppColors.deepPink : AppColors.text,
                ),
              ),
      ),
    );
  }
}

class _CheckinTile extends StatelessWidget {
  const _CheckinTile({required this.record});

  final CheckinRecord record;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${record.date.month.toString().padLeft(2, '0')}/${record.date.day.toString().padLeft(2, '0')}';
    const statusLabel = '已完成';
    final moodLabel = _moodLabel(record.mood);

    return AppCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: record.completed
                  ? AppColors.success.withValues(alpha: 0.22)
                  : AppColors.reminder.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              record.completed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: record.completed
                  ? AppColors.successText
                  : AppColors.reminder,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dateLabel,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: record.completed
                            ? AppColors.success.withValues(alpha: 0.18)
                            : AppColors.reminder.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: record.completed
                              ? AppColors.successText
                              : AppColors.reminder,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      moodLabel,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                if (record.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _moodLabel(CheckinMood mood) {
    return switch (mood) {
      CheckinMood.happy => '😊 开心',
      CheckinMood.normal => '😐 一般',
      CheckinMood.tired => '😮‍💨 有点累',
      CheckinMood.great => '🎉 超棒',
    };
  }
}
