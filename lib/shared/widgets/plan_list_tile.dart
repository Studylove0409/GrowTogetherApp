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
    this.subtitleSuffix,
    this.onTap,
  });

  final Plan plan;
  final String statusLabel;
  final Color statusColor;
  final IconData? statusIcon;
  final bool showProgress;
  final String? subtitleSuffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 26,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              AppIconTile(icon: plan.icon, color: plan.color, size: 56),
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
                      '${plan.subtitle}${subtitleSuffix ?? ' · ${plan.minutes} 分钟'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: statusLabel,
                color: statusColor,
                icon: statusIcon,
                compact: true,
              ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  '已坚持 ${plan.completedDays} 天',
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
                        alpha: 0.72,
                      ),
                      color: AppColors.deepPink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
