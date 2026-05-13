import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/profile.dart';
import '../../data/models/plan.dart';
import '../../data/services/plan_occurrence_service.dart';
import '../../data/store/store.dart';
import '../../features/plans/create_plan_page.dart';
import '../../features/plans/my_plans_page.dart';
import '../../features/plans/partner_plans_page.dart';
import '../../features/plans/plan_detail_page.dart';
import '../../features/plans/together_plans_page.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/avatar_preview.dart';
import '../../shared/widgets/cached_avatar.dart';
import '../../shared/widgets/empty_state_card.dart';
import '../../shared/widgets/plan_loading_card.dart';
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
    final today = PlanOccurrenceService.dateOnly(DateTime.now());
    final plans = store.getPlans();
    final myPlans = PlanOccurrenceService.plansForDate(
      plans: plans,
      date: today,
      owner: PlanOwner.me,
    );
    final partnerPlans = PlanOccurrenceService.plansForDate(
      plans: plans,
      date: today,
      owner: PlanOwner.partner,
    );
    final togetherPlans = PlanOccurrenceService.plansForDate(
      plans: plans,
      date: today,
      owner: PlanOwner.together,
    );
    final isInitialPlansLoading =
        store.isInitialPlansLoading && !store.hasHydratedPlanCache;

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
            if (isInitialPlansLoading)
              const _HomePlansLoadingSection()
            else ...[
              _HomePlanSection(
                title: '我的今日计划',
                plans: myPlans,
                titleTrailing: _HomeSyncBadge(
                  isRefreshing:
                      store.isRefreshingPlans && store.hasHydratedPlanCache,
                  errorMessage: store.planSyncErrorMessage,
                  lastSyncedAt: store.lastPlansSyncedAt,
                ),
                prioritizeActionablePlans: true,
                emptyMessage: '还没有自己的计划哦～',
                emptyActionLabel: '写下一个小目标',
                onViewAll: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const MyPlansPage()),
                ),
                onPlanTap: (plan) => _openPlan(context, plan),
                onQuickCheckin: (plan) => _saveQuickCheckin(context, plan),
                onEmptyAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreatePlanPage(),
                  ),
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
                onQuickCheckin: (plan) => _saveQuickCheckin(context, plan),
                onEmptyAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const CreatePlanPage(defaultOwner: PlanOwner.together),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomePlansLoadingSection extends StatelessWidget {
  const _HomePlansLoadingSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SectionHeader(title: '我的今日计划'),
        SizedBox(height: AppSpacing.sm),
        PlanLoadingCard(message: '正在同步你的计划...'),
      ],
    );
  }
}

class _HomeSyncBadge extends StatelessWidget {
  const _HomeSyncBadge({
    required this.isRefreshing,
    required this.errorMessage,
    required this.lastSyncedAt,
  });

  final bool isRefreshing;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    final isError = errorMessage != null;
    final label = isError
        ? '网络不稳定，已显示上次内容'
        : isRefreshing
        ? '同步中'
        : _lastSyncedLabel(lastSyncedAt);
    if (label == null) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError
            ? AppColors.reminder.withValues(alpha: 0.07)
            : AppColors.lightPink.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRefreshing) ...[
              const SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1.4,
                  color: AppColors.deepPink,
                ),
              ),
              const SizedBox(width: 5),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 148),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.tiny.copyWith(
                  color: isError
                      ? AppColors.secondaryText
                      : AppColors.secondaryText.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _lastSyncedLabel(DateTime? value) {
    if (value == null) return null;

    final elapsed = DateTime.now().difference(value);
    if (elapsed.inMinutes < 1) return '刚刚更新';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} 分钟前更新';
    return '已更新';
  }
}

bool _needsTodayAction(Plan plan) {
  if (plan.isOverdue) return true;

  return switch (plan.owner) {
    PlanOwner.me => !plan.doneToday,
    PlanOwner.partner => !plan.partnerDoneToday,
    PlanOwner.together => !plan.doneToday || !plan.partnerDoneToday,
  };
}

Future<void> _saveQuickCheckin(BuildContext context, Plan plan) {
  return context.read<Store>().saveCheckin(
    planId: plan.id,
    completed: true,
    mood: CheckinMood.happy,
    note: '',
  );
}

// ========================= 首页计划区块 =========================

class _HomePlanSection extends StatefulWidget {
  const _HomePlanSection({
    required this.title,
    required this.plans,
    required this.emptyMessage,
    this.titleTrailing,
    this.emptyActionLabel,
    this.prioritizeActionablePlans = false,
    required this.onViewAll,
    required this.onPlanTap,
    this.onEmptyAction,
    this.onQuickCheckin,
  });

  final String title;
  final List<Plan> plans;
  final String emptyMessage;
  final Widget? titleTrailing;
  final String? emptyActionLabel;
  final bool prioritizeActionablePlans;
  final VoidCallback onViewAll;
  final ValueChanged<Plan> onPlanTap;
  final VoidCallback? onEmptyAction;
  final Future<void> Function(Plan plan)? onQuickCheckin;

  @override
  State<_HomePlanSection> createState() => _HomePlanSectionState();
}

class _HomePlanSectionState extends State<_HomePlanSection> {
  final Set<String> _optimisticDonePlanIds = <String>{};

  @override
  void didUpdateWidget(covariant _HomePlanSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visiblePlanIds = widget.plans.map((plan) => plan.id).toSet();
    _optimisticDonePlanIds.removeWhere((id) => !visiblePlanIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plans.isEmpty) {
      return Column(
        children: [
          SectionHeader(
            title: widget.title,
            titleTrailing: widget.titleTrailing,
          ),
          const SizedBox(height: AppSpacing.sm),
          EmptyStateCard(
            message: widget.emptyMessage,
            actionLabel: widget.emptyActionLabel,
            onAction: widget.onEmptyAction,
          ),
        ],
      );
    }

    final visible = widget.prioritizeActionablePlans
        ? _prioritizedVisiblePlans(widget.plans)
        : widget.plans.take(2).toList();

    return Column(
      children: [
        SectionHeader(
          title: widget.title,
          titleTrailing: widget.titleTrailing,
          actionLabel: '全部 ${widget.plans.length}',
          onAction: widget.onViewAll,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final plan in visible) ...[
          PlanListTile(
            plan: plan,
            statusLabel: _statusLabel(
              plan,
              optimisticDone: _optimisticDonePlanIds.contains(plan.id),
            ),
            statusColor: _statusColor(
              plan,
              optimisticDone: _optimisticDonePlanIds.contains(plan.id),
            ),
            statusIcon: _statusIcon(
              plan,
              optimisticDone: _optimisticDonePlanIds.contains(plan.id),
            ),
            showReminderTime: false,
            onTap: () => widget.onPlanTap(plan),
            onStatusTap: _canQuickCheckin(plan)
                ? () => _quickCheckin(plan)
                : null,
            statusTooltip: '完成打卡：${plan.title}',
            statusSemanticsLabel: '完成${plan.title}打卡',
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  bool _canQuickCheckin(Plan plan) {
    return widget.onQuickCheckin != null &&
        !_optimisticDonePlanIds.contains(plan.id) &&
        plan.canCurrentUserCheckin &&
        !plan.hasCurrentUserCheckinToday;
  }

  Future<void> _quickCheckin(Plan plan) async {
    final quickCheckin = widget.onQuickCheckin;
    if (quickCheckin == null) return;

    setState(() => _optimisticDonePlanIds.add(plan.id));
    try {
      await quickCheckin(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已完成「${plan.title}」打卡'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _optimisticDonePlanIds.remove(plan.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('打卡失败，请稍后再试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                                  currentUserAvatarPath: profile.avatarPath,
                                  partnerAvatarPath: profile.partnerAvatarPath,
                                  currentUserId: profile.currentUserId,
                                  partnerUserId: profile.partnerUserId,
                                  currentUserName: profile.name,
                                  partnerName: profile.partnerName,
                                  currentUserUpdatedAt:
                                      profile.profileUpdatedAt,
                                  partnerUpdatedAt:
                                      profile.partnerProfileUpdatedAt,
                                  isCoupleBound: profile.isBound,
                                  size: compact ? 62 : 68,
                                  onCurrentAvatarTap: () => showAvatarPreview(
                                    context,
                                    title: '我的头像',
                                    imageUrl: profile.avatarUrl,
                                  ),
                                  onPartnerAvatarTap: profile.isBound
                                      ? () => showAvatarPreview(
                                          context,
                                          title:
                                              '${profile.partnerName.trim().isEmpty ? 'TA' : profile.partnerName.trim()}的头像',
                                          imageUrl: profile.partnerAvatarUrl,
                                        )
                                      : null,
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
    this.currentUserAvatarPath,
    this.partnerAvatarPath,
    this.currentUserId,
    this.partnerUserId,
    this.currentUserName,
    this.partnerName,
    this.currentUserUpdatedAt,
    this.partnerUpdatedAt,
    required this.isCoupleBound,
    this.size = 52,
    this.onCurrentAvatarTap,
    this.onPartnerAvatarTap,
  });

  final String? currentUserAvatarUrl;
  final String? partnerAvatarUrl;
  final String? currentUserAvatarPath;
  final String? partnerAvatarPath;
  final String? currentUserId;
  final String? partnerUserId;
  final String? currentUserName;
  final String? partnerName;
  final DateTime? currentUserUpdatedAt;
  final DateTime? partnerUpdatedAt;
  final bool isCoupleBound;
  final double size;
  final VoidCallback? onCurrentAvatarTap;
  final VoidCallback? onPartnerAvatarTap;

  @override
  Widget build(BuildContext context) {
    final stackWidth = size * 1.28;
    final stackHeight = size * 0.94;
    final primarySize = size * 0.72;
    final partnerSize = size * 0.72;
    _debugHomeAvatars();

    return SizedBox(
      width: stackWidth,
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: SoftAvatar(
              imageUrl: currentUserAvatarUrl,
              avatarPath: currentUserAvatarPath,
              userId: currentUserId,
              updatedAt: currentUserUpdatedAt,
              label: currentUserName,
              size: primarySize,
              backgroundColor: AppColors.blush,
              iconColor: AppColors.deepPink,
              onTap: onCurrentAvatarTap,
            ),
          ),
          Positioned(
            right: 0,
            top: size * 0.12,
            child: isCoupleBound
                ? SoftAvatar(
                    imageUrl: partnerAvatarUrl,
                    avatarPath: partnerAvatarPath,
                    userId: partnerUserId,
                    updatedAt: partnerUpdatedAt,
                    label: partnerName,
                    size: partnerSize,
                    backgroundColor: AppColors.lightPink,
                    iconColor: AppColors.deepPink,
                    onTap: onPartnerAvatarTap,
                  )
                : PartnerPlaceholderAvatar(size: partnerSize),
          ),
          Positioned(
            left: stackWidth * 0.5 - size * 0.125,
            top: size * 0.03,
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
    this.avatarPath,
    this.userId,
    this.updatedAt,
    this.label,
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });

  final String? imageUrl;
  final String? avatarPath;
  final String? userId;
  final DateTime? updatedAt;
  final String? label;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl?.trim().isNotEmpty == true;
    final avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(
        gradient: hasImage
            ? null
            : LinearGradient(
                colors: [
                  backgroundColor.withValues(alpha: 0.96),
                  AppColors.lavender.withValues(alpha: 0.30),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: hasImage ? AppColors.surface : null,
        shape: BoxShape.circle,
        border: Border.all(
          color: hasImage
              ? Colors.white
              : AppColors.line.withValues(alpha: 0.72),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: CachedAvatar(
          imageUrl: imageUrl,
          cacheKey: avatarCacheKey(
            imageUrl: imageUrl,
            avatarPath: avatarPath,
            userId: userId,
            updatedAt: updatedAt,
          ),
          size: size,
          backgroundColor: backgroundColor,
          iconColor: iconColor,
          label: label,
        ),
      ),
    );

    if (onTap == null) return avatar;

    return Semantics(
      button: true,
      label: '预览头像',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: avatar,
      ),
    );
  }
}

extension _CoupleAvatarStackDebug on CoupleAvatarStack {
  void _debugHomeAvatars() {
    assert(() {
      debugPrint(
        'Home avatar debug: '
        'cachedCurrentAvatarUrl=${_avatarDebugValue(currentUserAvatarUrl)}, '
        'cachedPartnerAvatarUrl=${_avatarDebugValue(partnerAvatarUrl)}, '
        'remoteCurrentAvatarUrl=n/a, '
        'remotePartnerAvatarUrl=n/a, '
        'finalCurrentAvatarUrl=${_avatarDebugValue(currentUserAvatarUrl)}, '
        'finalPartnerAvatarUrl=${_avatarDebugValue(partnerAvatarUrl)}, '
        'currentAvatarSource=${_avatarSource(currentUserAvatarUrl, currentUserAvatarPath)}, '
        'partnerAvatarSource=${_avatarSource(partnerAvatarUrl, partnerAvatarPath)}, '
        'currentPath=${currentUserAvatarPath ?? 'null'}, '
        'partnerPath=${partnerAvatarPath ?? 'null'}',
      );
      return true;
    }());
  }

  String _avatarSource(String? url, String? path) {
    if (url?.trim().isNotEmpty == true) return 'cache_or_remote';
    if (path?.trim().isNotEmpty == true) return 'path_without_signed_url';
    return 'fallback';
  }

  String _avatarDebugValue(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return 'null';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return '<present>';
    return '${uri.scheme}://${uri.host}${uri.path}<query-redacted>';
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

String _statusLabel(Plan plan, {bool optimisticDone = false}) {
  if (optimisticDone) {
    return plan.owner == PlanOwner.together ? '我已打卡' : '已完成';
  }
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

Color _statusColor(Plan plan, {bool optimisticDone = false}) {
  if (optimisticDone) return AppColors.successText;
  if (plan.isOverdue) return AppColors.reminder;
  if (plan.owner == PlanOwner.partner && plan.hasPartnerCheckinToday) {
    return plan.partnerDoneToday ? AppColors.successText : AppColors.reminder;
  }
  if (plan.hasCurrentUserCheckinToday && !plan.isDoneForCurrentUser) {
    return AppColors.reminder;
  }
  return plan.isDoneForCurrentUser ? AppColors.successText : AppColors.deepPink;
}

IconData _statusIcon(Plan plan, {bool optimisticDone = false}) {
  if (optimisticDone) return Icons.check_circle_rounded;
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
