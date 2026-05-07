import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/plan.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_tile.dart';
import '../../shared/widgets/status_pill.dart';

class TodayStatsDetailPage extends StatelessWidget {
  const TodayStatsDetailPage({
    super.key,
    required this.title,
    required this.plans,
    this.emptyMessage = '',
  });

  final String title;
  final List<Plan> plans;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.section),
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
            AppSpacing.xxl,
          ),
          children: [
            _SectionHeader(title: title, count: plans.length),
            const SizedBox(height: AppSpacing.md),
            if (plans.isEmpty)
              AppCard(
                borderRadius: 22,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              )
            else
              ...plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PlanRow(plan: plan),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.deepPink,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$title（$count）',
          style: AppTextStyles.title,
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final done = plan.owner == PlanOwner.partner
        ? plan.partnerDoneToday
        : plan.doneToday;

    return AppCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppIconTile(icon: plan.icon, color: plan.iconColor, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  plan.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusPill(
            label: done ? '已完成' : '待打卡',
            color: done ? AppColors.successText : AppColors.deepPink,
            icon: done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            compact: true,
          ),
        ],
      ),
    );
  }
}
