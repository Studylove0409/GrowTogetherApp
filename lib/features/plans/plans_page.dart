import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/store/store.dart';
import '../../data/models/plan.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_tile.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/sticker_asset.dart';
import '../../shared/widgets/status_pill.dart';
import 'create_plan_page.dart';
import 'my_plans_page.dart';
import 'partner_plans_page.dart';
import 'plan_detail_page.dart';
import 'together_plans_page.dart';

class PlansPage extends StatelessWidget {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final plans = store.getPlans();
    final myPlans = _plansByOwner(plans, PlanOwner.me);
    final partnerPlans = _plansByOwner(plans, PlanOwner.partner);
    final togetherPlans = _plansByOwner(plans, PlanOwner.together);
    final visibleTogetherPlans = _preferredTogetherPlans(togetherPlans);

        return Stack(
          children: [
            AppScaffold(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  32,
                ),
                children: [
                  const Center(child: Text('计划', style: AppTextStyles.display)),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _OverviewCard(
                          title: '我的计划',
                          icon: Icons.flag_rounded,
                          accentColor: AppColors.deepPink,
                          countColor: AppColors.deepPink,
                          doneCount: _doneCount(myPlans),
                          totalCount: myPlans.length,
                          focusPlan: myPlans.isEmpty ? null : myPlans.first,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyPlansPage(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _OverviewCard(
                          title: 'TA 的计划',
                          icon: Icons.directions_run_rounded,
                          accentColor: AppColors.success,
                          countColor: AppColors.successText,
                          doneCount: _doneCount(partnerPlans),
                          totalCount: partnerPlans.length,
                          focusPlan: partnerPlans.isEmpty
                              ? null
                              : partnerPlans.first,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PartnerPlansPage(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _TogetherPlansPanel(plans: visibleTogetherPlans),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 112,
              child: FloatingActionButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreatePlanPage(),
                  ),
                ),
                backgroundColor: AppColors.deepPink,
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ],
        );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.countColor,
    required this.doneCount,
    required this.totalCount,
    required this.focusPlan,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final Color countColor;
  final int doneCount;
  final int totalCount;
  final Plan? focusPlan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(14),
      backgroundColor: Colors.white.withValues(alpha: 0.64),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(icon: icon, color: accentColor, size: 48),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.section.copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text.rich(
            TextSpan(
              text: '今日完成 ',
              style: AppTextStyles.body.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: '$doneCount',
                  style: TextStyle(color: countColor, fontSize: 16),
                ),
                TextSpan(text: '/$totalCount'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                AppIconTile(
                  icon: focusPlan?.icon ?? icon,
                  color: focusPlan?.iconColor ?? accentColor,
                  size: 38,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    focusPlan?.title ?? '还没有计划',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '查看全部',
                style: AppTextStyles.body.copyWith(
                  color: countColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: countColor, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _TogetherPlansPanel extends StatelessWidget {
  const _TogetherPlansPanel({required this.plans});

  final List<Plan> plans;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.38),
      child: Column(
        children: [
          Row(
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
              const _CoupleDecoration(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final plan in plans) ...[
            _TogetherPlanCard(
              plan: plan,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlanDetailPage(planId: plan.id),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TogetherPlansPage(),
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.deepPink),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '查看全部',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TogetherPlanCard extends StatelessWidget {
  const _TogetherPlanCard({required this.plan, required this.onTap});

  final Plan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppIconTile(icon: plan.icon, color: plan.iconColor, size: 58),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${plan.subtitle} ❤️',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: _togetherStatusLabel(plan.togetherStatus),
                color: _togetherStatusColor(plan.togetherStatus),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '已坚持 ${plan.completedDays} 天',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w900,
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
      ),
    ),
    );
  }
}

class _CoupleDecoration extends StatelessWidget {
  const _CoupleDecoration();

  @override
  Widget build(BuildContext context) {
    return const StickerAsset(
      assetPath: AppAssets.coupleAnimals,
      placeholderIcon: Icons.diversity_1_rounded,
      width: 86,
      height: 70,
      borderRadius: 28,
      backgroundColor: AppColors.peach,
    );
  }
}

List<Plan> _plansByOwner(List<Plan> plans, PlanOwner owner) {
  return plans.where((plan) => plan.owner == owner).toList();
}

List<Plan> _preferredTogetherPlans(List<Plan> plans) {
  return plans.take(2).toList();
}

int _doneCount(List<Plan> plans) {
  return plans.where((plan) => plan.isDoneForCurrentUser).length;
}

String _togetherStatusLabel(TogetherStatus status) {
  return switch (status) {
    TogetherStatus.bothDone => '双方已完成',
    TogetherStatus.onlyMeDone => '我已打卡',
    TogetherStatus.meNotDone => '待打卡',
  };
}

Color _togetherStatusColor(TogetherStatus status) {
  return switch (status) {
    TogetherStatus.bothDone => AppColors.successText,
    TogetherStatus.onlyMeDone => AppColors.reminder,
    TogetherStatus.meNotDone => AppColors.deepPink,
  };
}
