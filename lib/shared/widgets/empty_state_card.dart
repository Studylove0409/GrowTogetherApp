import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_card.dart';
import 'primary_pill_button.dart';

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 26,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.24),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            PrimaryPillButton(
              label: actionLabel!,
              onPressed: onAction!,
              height: 44,
            ),
          ],
        ],
      ),
    );
  }
}
