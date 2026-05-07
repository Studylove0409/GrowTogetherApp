import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/reminder.dart';
import 'app_card.dart';
import 'app_icon_tile.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({super.key, required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 18,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            bottom: 0,
            child: Icon(
              Icons.favorite_rounded,
              size: 20,
              color: AppColors.primary.withValues(alpha: 0.36),
            ),
          ),
          Row(
            children: [
              AppIconTile(icon: reminder.icon, color: reminder.color, size: 58),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reminder.title, style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      reminder.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                reminder.time,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
