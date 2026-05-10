import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/profile.dart';
import '../../data/models/plan.dart';
import '../../data/store/store.dart';
import '../../features/plans/create_plan_page.dart';
import '../../features/plans/my_plans_page.dart';
import '../../features/plans/partner_plans_page.dart';
import '../../features/plans/plan_detail_page.dart';
import '../../features/plans/together_plans_page.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/empty_state_card.dart';
import '../../shared/widgets/plan_list_tile.dart';
import '../../shared/widgets/section_header.dart';
import 'growth_record_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.isSelected = true});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final store = isSelected ? context.watch<Store>() : context.read<Store>();
    final profile = store.getProfile();
    final todayPlans = store.getPlans().where(_isTodayPlan).toList();
    final myPlans = todayPlans.where((p) => p.owner == PlanOwner.me).toList();
    final partnerPlans = todayPlans
        .where((p) => p.owner == PlanOwner.partner)
        .toList();
    final togetherPlans = todayPlans
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
            138,
          ),
          children: [
            _HomeHeader(profile: profile),
            const SizedBox(height: AppSpacing.xl),
            _GrowthHeroCard(profile: profile),
            const SizedBox(height: AppSpacing.lg),
            _HomePlanSection(
              title: '我的今日计划',
              plans: myPlans,
              prioritizeActionablePlans: true,
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
          ],
        ),
      ),
    );
  }
}

bool _isTodayPlan(Plan plan) {
  return plan.isScheduledOnDate(DateTime.now());
}

bool _needsTodayAction(Plan plan) {
  if (plan.isOverdue) return true;

  return switch (plan.owner) {
    PlanOwner.me => !plan.doneToday,
    PlanOwner.partner => !plan.partnerDoneToday,
    PlanOwner.together => !plan.doneToday || !plan.partnerDoneToday,
  };
}

// ========================= 首页计划区块 =========================

class _HomePlanSection extends StatelessWidget {
  const _HomePlanSection({
    required this.title,
    required this.plans,
    required this.emptyMessage,
    this.emptyActionLabel,
    this.prioritizeActionablePlans = false,
    required this.onViewAll,
    required this.onPlanTap,
    this.onEmptyAction,
  });

  final String title;
  final List<Plan> plans;
  final String emptyMessage;
  final String? emptyActionLabel;
  final bool prioritizeActionablePlans;
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

    final visible = prioritizeActionablePlans
        ? _prioritizedVisiblePlans(plans)
        : plans.take(2).toList();

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

List<Plan> _prioritizedVisiblePlans(List<Plan> plans) {
  final actionable = plans.where(_needsTodayAction).toList();
  if (actionable.isNotEmpty) {
    return actionable.take(2).toList();
  }

  return plans.take(2).toList();
}

// ========================= 顶部头部 =========================

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final partnerName = profile.isBound && profile.partnerName.trim().isNotEmpty
        ? profile.partnerName.trim()
        : 'TA';

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
                '和 $partnerName 一起，把今天过得更好',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
  const _GrowthHeroCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 32,
      padding: EdgeInsets.zero,
      backgroundColor: AppColors.blush.withValues(alpha: 0.76),
      borderColor: Colors.white.withValues(alpha: 0.76),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 370;
          final artSize = compact ? 116.0 : 128.0;
          final numberSize = compact ? 40.0 : 44.0;
          final togetherDays = profile.togetherDays;

          return Container(
            height: compact ? 188 : 196,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              compact ? AppSpacing.md : AppSpacing.lg,
              AppSpacing.lg,
              compact ? AppSpacing.md : AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: [
                  AppColors.lightPink.withValues(alpha: 0.44),
                  AppColors.paper.withValues(alpha: 0.54),
                  AppColors.reminder.withValues(alpha: 0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: compact ? 74 : 84,
                  top: compact ? 8 : 10,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: AppColors.primary.withValues(alpha: 0.38),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(
                    Icons.cloud_rounded,
                    size: compact ? 68 : 78,
                    color: Colors.white.withValues(alpha: 0.54),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                CoupleAvatarStack(
                                  currentUserAvatarUrl: profile.avatarUrl,
                                  partnerAvatarUrl: profile.partnerAvatarUrl,
                                  isCoupleBound: profile.isBound,
                                  size: compact ? 62 : 68,
                                ),
                                SizedBox(width: compact ? 10 : 12),
                                Expanded(
                                  child: Text(
                                    '你们已经一起进步',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.secondaryText,
                                      fontSize: compact ? 13 : 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 6 : 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: RichText(
                                text: TextSpan(
                                  style: AppTextStyles.display.copyWith(
                                    fontSize: numberSize,
                                    height: 1,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '$togetherDays',
                                      style: const TextStyle(
                                        color: AppColors.deepPink,
                                      ),
                                    ),
                                    const TextSpan(text: ' 天啦'),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 4 : 5),
                            Text(
                              '轻轻努力，未来可期！',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.secondaryText,
                                fontSize: compact ? 13 : 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
                    _HeroCalendarArt(
                      size: artSize,
                      onTap: () {
                        final store = context.read<Store>();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChangeNotifierProvider<Store>.value(
                              value: store,
                              child: const GrowthRecordPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroCalendarArt extends StatelessWidget {
  const _HeroCalendarArt({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '查看成长记录',
      child: Semantics(
        button: true,
        label: '查看成长记录',
        child: SizedBox(
          width: size,
          height: size,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(34),
            splashColor: AppColors.primary.withValues(alpha: 0.16),
            highlightColor: AppColors.primary.withValues(alpha: 0.08),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    width: size * 0.53,
                    height: size * 0.53,
                    decoration: BoxDecoration(
                      color: AppColors.lightPink.withValues(alpha: 0.34),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Container(
                  width: size * 0.48,
                  height: size * 0.48,
                  decoration: BoxDecoration(
                    color: AppColors.lightPink.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(size * 0.17),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.deepPink,
                    size: size * 0.30,
                  ),
                ),
                const Positioned(
                  top: 20,
                  right: 21,
                  child: _HeroSparkle(size: 8, color: AppColors.reminder),
                ),
                const Positioned(
                  left: 16,
                  bottom: 20,
                  child: _HeroSparkle(size: 10, color: AppColors.primary),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.deepPink.withValues(alpha: 0.72),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CoupleAvatarStack extends StatelessWidget {
  const CoupleAvatarStack({
    super.key,
    required this.currentUserAvatarUrl,
    required this.partnerAvatarUrl,
    required this.isCoupleBound,
    this.size = 52,
  });

  final String? currentUserAvatarUrl;
  final String? partnerAvatarUrl;
  final bool isCoupleBound;
  final double size;

  @override
  Widget build(BuildContext context) {
    final primarySize = size * 0.78;
    final partnerSize = size * 0.66;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            bottom: 1,
            child: isCoupleBound
                ? SoftAvatar(
                    imageUrl: partnerAvatarUrl,
                    size: partnerSize,
                    backgroundColor: AppColors.lightPink,
                    iconColor: AppColors.deepPink,
                  )
                : PartnerPlaceholderAvatar(size: partnerSize),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: SoftAvatar(
              imageUrl: currentUserAvatarUrl,
              size: primarySize,
              backgroundColor: AppColors.blush,
              iconColor: AppColors.deepPink,
            ),
          ),
          Positioned(
            right: size * 0.18,
            top: size * 0.06,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: AppColors.deepPink,
                size: size * 0.14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SoftAvatar extends StatelessWidget {
  const SoftAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
  });

  final String? imageUrl;
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? _DefaultSoftAvatar(
                size: size,
                backgroundColor: backgroundColor,
                iconColor: iconColor,
              )
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _DefaultSoftAvatar(
                      size: size,
                      backgroundColor: backgroundColor,
                      iconColor: iconColor,
                    ),
              ),
      ),
    );
  }
}

class PartnerPlaceholderAvatar extends StatelessWidget {
  const PartnerPlaceholderAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.paper,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line.withValues(alpha: 0.62)),
        ),
        child: Icon(
          Icons.add_rounded,
          color: AppColors.deepPink.withValues(alpha: 0.72),
          size: size * 0.42,
        ),
      ),
    );
  }
}

class _DefaultSoftAvatar extends StatelessWidget {
  const _DefaultSoftAvatar({
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
  });

  final double size;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(Icons.face_6_rounded, color: iconColor, size: size * 0.42),
    );
  }
}

class _HeroSparkle extends StatelessWidget {
  const _HeroSparkle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.72),
          shape: BoxShape.circle,
        ),
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
  if (plan.isOverdue) return '已逾期';
  return switch (plan.owner) {
    PlanOwner.partner =>
      plan.partnerDoneToday
          ? 'TA已完成'
          : plan.hasPartnerCheckinToday
          ? 'TA未完成'
          : 'TA待打卡',
    PlanOwner.together =>
      plan.doneToday
          ? '我已打卡'
          : plan.hasCurrentUserCheckinToday
          ? '我未完成'
          : '待打卡',
    PlanOwner.me =>
      plan.doneToday
          ? '已完成'
          : plan.hasCurrentUserCheckinToday
          ? '未完成'
          : '待打卡',
  };
}

Color _statusColor(Plan plan) {
  if (plan.isOverdue) return AppColors.reminder;
  if (plan.owner == PlanOwner.partner && plan.hasPartnerCheckinToday) {
    return plan.partnerDoneToday ? AppColors.successText : AppColors.reminder;
  }
  if (plan.hasCurrentUserCheckinToday && !plan.isDoneForCurrentUser) {
    return AppColors.reminder;
  }
  return plan.isDoneForCurrentUser ? AppColors.successText : AppColors.deepPink;
}

IconData _statusIcon(Plan plan) {
  if (plan.owner == PlanOwner.partner &&
      plan.hasPartnerCheckinToday &&
      !plan.partnerDoneToday) {
    return Icons.error_outline_rounded;
  }
  if (plan.hasCurrentUserCheckinToday && !plan.isDoneForCurrentUser) {
    return Icons.error_outline_rounded;
  }
  return plan.isDoneForCurrentUser
      ? Icons.check_circle_rounded
      : Icons.radio_button_unchecked_rounded;
}

void _openPlan(BuildContext context, Plan plan) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PlanDetailPage(planId: plan.id)),
  );
}
