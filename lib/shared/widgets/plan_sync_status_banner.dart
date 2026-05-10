import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class PlanSyncStatusBanner extends StatelessWidget {
  const PlanSyncStatusBanner({
    super.key,
    required this.isRefreshing,
    this.errorMessage,
  });

  final bool isRefreshing;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final message = errorMessage;
    if (message == null && !isRefreshing) return const SizedBox.shrink();

    final isError = message != null;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.reminder.withValues(alpha: 0.12)
            : AppColors.lightPink.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isError
              ? AppColors.reminder.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          if (isError)
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.reminder,
              size: 18,
            )
          else
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.deepPink,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message ?? '正在同步',
              style: AppTextStyles.caption.copyWith(
                color: isError ? AppColors.reminder : AppColors.secondaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
