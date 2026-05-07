import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock/mock_store.dart';
import '../../data/models/plan.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_tile.dart';
import 'create_plan_page.dart';
import 'plan_detail_page.dart';
import 'plan_list_scaffold.dart';

class TogetherPlansPage extends StatelessWidget {
  const TogetherPlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MockStore.instance,
      builder: (context, _) {
        final allPlans = MockStore.instance.getPlansByOwner(PlanOwner.together);
        return PlanListScaffold(
          title: '共同计划',
          filterOptions: const ['全部', '待打卡', '已完成'],
          plans: allPlans,
          planCountLabel: '共 ${allPlans.length} 个计划',
          owner: PlanOwner.together,
          onAdd: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CreatePlanPage(
                  defaultOwner: PlanOwner.together,
                ),
              ),
            );
          },
          onTapPlan: (plan) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanDetailPage(planId: plan.id),
              ),
            );
          },
          headerBuilder: (context) => _TogetherHeader(plans: allPlans),
        );
      },
    );
  }
}

class _TogetherHeader extends StatelessWidget {
  const _TogetherHeader({required this.plans});

  final List<Plan> plans;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          borderRadius: 32,
          padding: const EdgeInsets.all(AppSpacing.lg),
          backgroundColor: AppColors.lightPink.withValues(alpha: 0.38),
          child: Row(
            children: [
              const AppIconTile(
                icon: Icons.favorite_border_rounded,
                color: AppColors.primary,
                size: 58,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '共同计划',
                      style: AppTextStyles.display.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '我们一起努力的小目标',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 74,
                height: 62,
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      bottom: 4,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.deepPink.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.face_rounded, color: Colors.white, size: 19),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.reminder.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.face_rounded, color: Colors.white, size: 19),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 0,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: AppColors.deepPink.withValues(alpha: 0.74),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
