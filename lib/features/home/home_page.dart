import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock/mock_store.dart';
import '../../data/models/plan.dart';
import '../../features/plans/plan_detail_page.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_tile.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/plan_list_tile.dart';
import '../../shared/widgets/section_header.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MockStore.instance,
      builder: (context, _) {
        final todayPlans = MockStore.instance.getTodayFocusPlans();
        final doneCount = todayPlans.where(_isDoneForHome).length;

        return AppScaffold(
          child: ListView(
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
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: '今日重点计划',
                  actionLabel: '全部 ${todayPlans.length}',
                  onAction: () => _showSnack(context, '计划列表功能开发中'),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final plan in todayPlans) ...[
                  PlanListTile(
                    plan: plan,
                    statusLabel: _statusLabel(plan),
                    statusColor: _statusColor(plan),
                    statusIcon: _statusIcon(plan),
                    onTap: () => _openPlan(context, plan),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                SectionHeader(title: '今日完成统计'),
                const SizedBox(height: AppSpacing.md),
                _TodayStatsCard(
                  doneCount: doneCount,
                  totalCount: todayPlans.length,
                ),
                const SizedBox(height: AppSpacing.lg),
                const _GrowthRecordEntry(),
              ],
            ),
          );
      },
    );
  }
}

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
        height: 168,
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
            Positioned(right: 14, top: 20, child: _CalendarIllustration()),
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
                        children: const [
                          TextSpan(
                            text: '7',
                            style: TextStyle(color: AppColors.deepPink),
                          ),
                          TextSpan(text: ' 天啦'),
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

class _CalendarIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.08,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepPink.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
              ),
            ),
            const Positioned(
              top: 10,
              left: 18,
              child: Icon(Icons.circle, size: 8, color: Colors.white),
            ),
            const Positioned(
              top: 10,
              right: 18,
              child: Icon(Icons.circle, size: 8, color: Colors.white),
            ),
            const Center(
              child: Icon(
                Icons.calendar_month_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const Positioned(
              right: 10,
              bottom: 12,
              child: Icon(
                Icons.favorite_rounded,
                color: AppColors.deepPink,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayStatsCard extends StatelessWidget {
  const _TodayStatsCard({required this.doneCount, required this.totalCount});

  final int doneCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final remaining = (totalCount - doneCount).clamp(0, totalCount);
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;

    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              _StatBlock(
                value: '$doneCount',
                label: '已完成',
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatBlock(
                value: '$remaining',
                label: '待完成',
                color: AppColors.reminder,
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatBlock(
                value: '${(progress * 100).round()}%',
                label: '完成率',
                color: AppColors.deepPink,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppColors.lightPink.withValues(alpha: 0.66),
              color: AppColors.deepPink,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTextStyles.title.copyWith(
                  color: color == AppColors.success
                      ? AppColors.successText
                      : color,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _GrowthRecordEntry extends StatelessWidget {
  const _GrowthRecordEntry();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.42),
      onTap: () => _showSnack(context, '成长记录功能开发中'),
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

bool _isDoneForHome(Plan plan) {
  return switch (plan.owner) {
    PlanOwner.me => plan.doneToday,
    PlanOwner.partner => plan.partnerDoneToday,
    PlanOwner.together => plan.doneToday,
  };
}

String _statusLabel(Plan plan) {
  return switch (plan.owner) {
    PlanOwner.partner => plan.partnerDoneToday ? 'TA已完成' : 'TA待打卡',
    PlanOwner.together => plan.doneToday ? '我已打卡' : '待打卡',
    PlanOwner.me => plan.doneToday ? '已完成' : '待打卡',
  };
}

Color _statusColor(Plan plan) {
  return _isDoneForHome(plan) ? AppColors.successText : AppColors.deepPink;
}

IconData _statusIcon(Plan plan) {
  return _isDoneForHome(plan)
      ? Icons.check_circle_rounded
      : Icons.radio_button_unchecked_rounded;
}

void _openPlan(BuildContext context, Plan plan) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PlanDetailPage(planId: plan.id)),
  );
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
