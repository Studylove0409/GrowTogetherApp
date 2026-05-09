import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/plan.dart';
import '../../shared/widgets/empty_state_card.dart';
import '../../shared/widgets/plan_list_tile.dart';

/// 通用计划列表页框架：AppBar + 分段筛选 + 计划卡片列表
class PlanListScaffold extends StatefulWidget {
  const PlanListScaffold({
    super.key,
    required this.title,
    required this.filterOptions,
    required this.plans,
    required this.planCountLabel,
    required this.owner,
    required this.onAdd,
    required this.onTapPlan,
    this.onRefresh,
    this.addButtonLabel,
    this.showAddButton = true,
    this.headerBuilder,
  });

  final String title;
  final List<String> filterOptions;
  final List<Plan> plans;
  final String planCountLabel;
  final PlanOwner owner;
  final VoidCallback onAdd;
  final ValueChanged<Plan> onTapPlan;
  final Future<void> Function()? onRefresh;
  final String? addButtonLabel;
  final bool showAddButton;
  final Widget Function(BuildContext)? headerBuilder;

  @override
  State<PlanListScaffold> createState() => _PlanListScaffoldState();
}

class _PlanListScaffoldState extends State<PlanListScaffold> {
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(widget.plans, _filterIndex);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title, style: AppTextStyles.section),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.showAddButton)
            IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightPink.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.deepPink,
                  size: 22,
                ),
              ),
              onPressed: widget.onAdd,
            ),
          if (widget.showAddButton) const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.deepPink,
          onRefresh: widget.onRefresh ?? () async {},
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              32,
            ),
            children: [
              if (widget.headerBuilder != null) widget.headerBuilder!(context),
              _FilterBar(
                options: widget.filterOptions,
                selectedIndex: _filterIndex,
                onChanged: (index) => setState(() => _filterIndex = index),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  widget.planCountLabel,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (filtered.isEmpty)
                const _EmptyPlansHint()
              else
                ...filtered.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _buildPlanTile(plan),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Plan> _applyFilter(List<Plan> plans, int index) {
    return switch (index) {
      0 => plans,
      1 => plans.where((p) => !_isDoneForFilter(p)).toList(),
      2 => plans.where(_isDoneForFilter).toList(),
      _ => plans,
    };
  }

  bool _isDoneForFilter(Plan plan) {
    if (plan.owner == PlanOwner.together) {
      return plan.togetherStatus == TogetherStatus.bothDone;
    }
    return plan.isDoneForCurrentUser;
  }

  Widget _buildPlanTile(Plan plan) {
    if (plan.owner == PlanOwner.together) {
      final (label, color, icon) = plan.isOverdue
          ? ('已逾期', AppColors.reminder, Icons.warning_rounded)
          : _togetherStatusUI(plan.togetherStatus);
      return PlanListTile(
        plan: plan,
        statusLabel: label,
        statusColor: color,
        statusIcon: icon,
        showProgress: true,
        onTap: () => widget.onTapPlan(plan),
      );
    }
    final done = plan.isDoneForCurrentUser;
    return PlanListTile(
      plan: plan,
      statusLabel: plan.isOverdue
          ? '已逾期'
          : done
          ? '已打卡'
          : '待打卡',
      statusColor: plan.isOverdue
          ? AppColors.reminder
          : done
          ? AppColors.successText
          : AppColors.deepPink,
      statusIcon: done
          ? Icons.check_circle_rounded
          : Icons.radio_button_unchecked_rounded,
      showProgress: true,
      onTap: () => widget.onTapPlan(plan),
    );
  }

  (String, Color, IconData) _togetherStatusUI(TogetherStatus status) {
    return switch (status) {
      TogetherStatus.bothDone => (
        '双方已完成',
        AppColors.successText,
        Icons.check_circle_rounded,
      ),
      TogetherStatus.onlyMeDone => (
        '我已打卡',
        AppColors.reminder,
        Icons.check_circle_rounded,
      ),
      TogetherStatus.meNotDone => (
        '待打卡',
        AppColors.deepPink,
        Icons.radio_button_unchecked_rounded,
      ),
    };
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: selectedIndex == i
                    ? AppColors.lightPink.withValues(alpha: 0.64)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                options[i],
                style: AppTextStyles.body.copyWith(
                  color: selectedIndex == i
                      ? AppColors.deepPink
                      : AppColors.secondaryText,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (i < options.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _EmptyPlansHint extends StatelessWidget {
  const _EmptyPlansHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: EmptyStateCard(message: '这里还没有计划'),
      ),
    );
  }
}
