import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/plan.dart';
import '../../data/store/store.dart';
import '../../features/plans/create_plan_page.dart';
import '../../features/plans/my_plans_page.dart';
import '../../features/plans/partner_plans_page.dart';
import '../../features/plans/plan_detail_page.dart';
import '../../features/plans/together_plans_page.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_tile.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/empty_state_card.dart';
import '../../shared/widgets/plan_list_tile.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/sticker_asset.dart';
import 'growth_record_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final allPlans = store.getPlans();
    final myPlans = allPlans.where((p) => p.owner == PlanOwner.me).toList();
    final partnerPlans = allPlans
        .where((p) => p.owner == PlanOwner.partner)
        .toList();
    final togetherPlans = allPlans
        .where((p) => p.owner == PlanOwner.together)
        .toList();

    return AppScaffold(
      child: RefreshIndicator(
        color: AppColors.deepPink,
        onRefresh: context.read<Store>().refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            32,
          ),
          children: [
            const _HomeHeader(),
            const SizedBox(height: AppSpacing.xl),
            const _GrowthHeroCard(),
            const SizedBox(height: AppSpacing.lg),
            _HomePlanSection(
              title: '我的今日计划',
              plans: myPlans,
              emptyMessage: '还没有自己的计划哦～',
              emptyActionLabel: '写下一个小目标',
              onViewAll: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MyPlansPage()),
              ),
              onPlanTap: (plan) => _openPlan(context, plan),
              onEmptyAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CreatePlanPage()),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _HomePlanSection(
              title: 'TA 的今日计划',
              plans: partnerPlans,
              emptyMessage: 'TA 还没有计划哦～',
              onViewAll: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PartnerPlansPage(),
                ),
              ),
              onPlanTap: (plan) => _openPlan(context, plan),
            ),
            const SizedBox(height: AppSpacing.lg),
            _HomePlanSection(
              title: '共同计划',
              plans: togetherPlans,
              emptyMessage: '还没有共同计划哦～',
              emptyActionLabel: '一起定个小目标',
              onViewAll: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TogetherPlansPage(),
                ),
              ),
              onPlanTap: (plan) => _openPlan(context, plan),
              onEmptyAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const CreatePlanPage(defaultOwner: PlanOwner.together),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _GrowthRecordEntry(),
          ],
        ),
      ),
    );
  }
}

// ========================= 首页计划区块 =========================

class _HomePlanSection extends StatelessWidget {
  const _HomePlanSection({
    required this.title,
    required this.plans,
    required this.emptyMessage,
    this.emptyActionLabel,
    required this.onViewAll,
    required this.onPlanTap,
    this.onEmptyAction,
  });

  final String title;
  final List<Plan> plans;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback onViewAll;
  final ValueChanged<Plan> onPlanTap;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return Column(
        children: [
          SectionHeader(title: title),
          const SizedBox(height: AppSpacing.sm),
          EmptyStateCard(
            message: emptyMessage,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          ),
        ],
      );
    }

    final visible = plans.take(2).toList();

    return Column(
      children: [
        SectionHeader(
          title: title,
          actionLabel: '全部 ${plans.length}',
          onAction: onViewAll,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final plan in visible) ...[
          PlanListTile(
            plan: plan,
            statusLabel: _statusLabel(plan),
            statusColor: _statusColor(plan),
            statusIcon: _statusIcon(plan),
            showReminderTime: false,
            onTap: () => onPlanTap(plan),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

// ========================= 空区块卡片 =========================

// ========================= 顶部头部 =========================

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('一起进步呀', style: AppTextStyles.display),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '和 TA 一起，把今天过得更好',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const _HeartBubble(size: 54),
      ],
    );
  }
}

// ========================= 成长 Hero 卡片 =========================

class _GrowthHeroCard extends StatelessWidget {
  const _GrowthHeroCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.46),
      borderColor: Colors.white.withValues(alpha: 0.76),
      child: SizedBox(
        height: 140,
        child: Stack(
          children: [
            Positioned(
              right: -8,
              bottom: -18,
              child: Icon(
                Icons.cloud_rounded,
                size: 96,
                color: Colors.white.withValues(alpha: 0.54),
              ),
            ),
            const Positioned(
              right: 2,
              top: 6,
              bottom: -6,
              child: StickerAsset(
                assetPath: AppAssets.calendarCharacter,
                placeholderIcon: Icons.calendar_month_rounded,
                width: 112,
                height: 132,
                borderRadius: 30,
              ),
            ),
            Positioned.fill(
              right: 116,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '你们已经一起进步',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.display.copyWith(fontSize: 44),
                        children: [
                          TextSpan(
                            text:
                                '${context.watch<Store>().getProfile().togetherDays}',
                            style: const TextStyle(color: AppColors.deepPink),
                          ),
                          const TextSpan(text: ' 天啦'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '轻轻努力，未来可期！',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================= 成长记录入口 =========================

class _GrowthRecordEntry extends StatelessWidget {
  const _GrowthRecordEntry();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.42),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const GrowthRecordPage())),
      child: Row(
        children: [
          const AppIconTile(
            icon: Icons.menu_book_rounded,
            color: AppColors.primary,
            size: 58,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('成长记录', style: AppTextStyles.title.copyWith(fontSize: 20)),
                const SizedBox(height: AppSpacing.xs),
                Text('看看我们一起留下的小进步', style: AppTextStyles.caption),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.76),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.deepPink,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

// ========================= 心形气泡 =========================

class _HeartBubble extends StatelessWidget {
  const _HeartBubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.52),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.favorite_rounded, color: AppColors.deepPink),
    );
  }
}

// ========================= 辅助函数 =========================

String _statusLabel(Plan plan) {
  return switch (plan.owner) {
    PlanOwner.partner => plan.partnerDoneToday ? 'TA已完成' : 'TA待打卡',
    PlanOwner.together => plan.doneToday ? '我已打卡' : '待打卡',
    PlanOwner.me => plan.doneToday ? '已完成' : '待打卡',
  };
}

Color _statusColor(Plan plan) {
  return plan.isDoneForCurrentUser ? AppColors.successText : AppColors.deepPink;
}

IconData _statusIcon(Plan plan) {
  return plan.isDoneForCurrentUser
      ? Icons.check_circle_rounded
      : Icons.radio_button_unchecked_rounded;
}

void _openPlan(BuildContext context, Plan plan) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PlanDetailPage(planId: plan.id)),
  );
}
