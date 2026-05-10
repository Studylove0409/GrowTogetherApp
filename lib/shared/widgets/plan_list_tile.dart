import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/plan.dart';
import 'app_card.dart';
import 'app_icon_tile.dart';
import 'status_pill.dart';

class PlanListTile extends StatelessWidget {
  const PlanListTile({
    super.key,
    required this.plan,
    required this.statusLabel,
    required this.statusColor,
    this.statusIcon,
    this.showProgress = false,
    this.showReminderTime = true,
    this.subtitleSuffix,
    this.trailing,
    this.onTap,
    this.onStatusTap,
    this.statusTooltip,
    this.statusSemanticsLabel,
  });

  final Plan plan;
  final String statusLabel;
  final Color statusColor;
  final IconData? statusIcon;
  final bool showProgress;
  final bool showReminderTime;
  final String? subtitleSuffix;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onStatusTap;
  final String? statusTooltip;
  final String? statusSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final progressText = switch (plan.repeatType) {
      PlanRepeatType.once => plan.isDoneForCurrentUser ? '已完成' : '待完成',
      PlanRepeatType.daily =>
        plan.hasDateRange
            ? '已坚持 ${plan.completedDays} 天'
                  '${plan.remainingDays > 0 ? ' · 剩余 ${plan.remainingDays} 天' : ''}'
            : '已完成 ${plan.completedDays} 次',
    };

    return AppCard(
      borderRadius: 26,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(icon: plan.icon, color: plan.iconColor, size: 52),
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
                      '${plan.subtitle}${subtitleSuffix ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.repeatLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.tiny.copyWith(
                        color: plan.isOverdue
                            ? AppColors.reminder
                            : AppColors.secondaryText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(
                    label: statusLabel,
                    color: statusColor,
                    icon: statusIcon,
                    compact: true,
                    onTap: onStatusTap,
                    tooltip: statusTooltip,
                    semanticsLabel: statusSemanticsLabel,
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 8),
                    trailing!,
                  ],
                ],
              ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  progressText,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: plan.progress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: AppColors.lightPink.withValues(
                        alpha: 0.68,
                      ),
                      color: AppColors.deepPink,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (showReminderTime && plan.hasReminder) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '提醒 ${plan.reminderTime!.format(context)}',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
