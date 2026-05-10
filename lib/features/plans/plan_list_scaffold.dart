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
    this.onDeletePlan,
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
  final Future<void> Function(Plan plan)? onDeletePlan;
  final String? addButtonLabel;
  final bool showAddButton;
  final Widget Function(BuildContext)? headerBuilder;

  @override
  State<PlanListScaffold> createState() => _PlanListScaffoldState();
}

class _PlanListScaffoldState extends State<PlanListScaffold> {
  int _filterIndex = 0;
  DateTime _selectedDate = _todayOnly();

  @override
  void didUpdateWidget(covariant PlanListScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_filterIndex >= widget.filterOptions.length) {
      _filterIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final datePlans = widget.plans
        .where((plan) => plan.isVisibleOnDate(_selectedDate))
        .toList();
    final filtered = _applyFilter(datePlans, _filterIndex);

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
              _PlanDateFilterCard(
                selectedDate: _selectedDate,
                onPickDate: _pickDate,
                onToday: () => setState(() => _selectedDate = _todayOnly()),
              ),
              const SizedBox(height: AppSpacing.md),
              _FilterBar(
                options: widget.filterOptions,
                selectedIndex: _filterIndex,
                onChanged: (index) => setState(() => _filterIndex = index),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '${_formatDateLabel(_selectedDate)} · 共 ${datePlans.length} 个计划',
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
                    child: _buildSwipeDeletePlanTile(plan),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeDeletePlanTile(Plan plan) {
    final canDelete =
        widget.onDeletePlan != null && plan.owner != PlanOwner.partner;
    final tile = _buildPlanTile(plan);
    if (!canDelete) return tile;

    return _SwipeDeletePlanTile(
      key: ValueKey('swipe-delete-${plan.id}'),
      onDelete: () => _confirmDeletePlan(plan),
      child: tile,
    );
  }

  Future<void> _confirmDeletePlan(Plan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('删除计划？', style: AppTextStyles.section),
        content: Text(
          '删除后，这个计划和相关记录将不再显示。确定要删除「${plan.title}」吗？',
          style: AppTextStyles.body.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '再想想',
              style: AppTextStyles.body.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.deepPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.onDeletePlan?.call(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除「${plan.title}」'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败：$error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: '选择查看日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    setState(() => _selectedDate = _dateOnly(picked));
  }

  List<Plan> _applyFilter(List<Plan> plans, int index) {
    return switch (_filterForIndex(index)) {
      _PlanFilter.all => plans,
      _PlanFilter.pending => plans.where(_isPendingForFilter).toList(),
      _PlanFilter.unfinished => plans.where(_isUnfinishedForFilter).toList(),
      _PlanFilter.completed => plans.where(_isDoneForFilter).toList(),
    };
  }

  _PlanFilter _filterForIndex(int index) {
    if (index < 0 || index >= widget.filterOptions.length) {
      return _PlanFilter.all;
    }

    return switch (widget.filterOptions[index]) {
      '待打卡' => _PlanFilter.pending,
      '未完成' => _PlanFilter.unfinished,
      '已完成' => _PlanFilter.completed,
      _ => _PlanFilter.all,
    };
  }

  bool _isPendingForFilter(Plan plan) {
    if (plan.isEnded && !plan.isCompletedOnceToday) return false;

    return !_isDoneForFilter(plan) && !_isUnfinishedForFilter(plan);
  }

  bool _isUnfinishedForFilter(Plan plan) {
    if (_isPastMissed(plan)) return true;

    if (plan.owner == PlanOwner.together) {
      return plan.isCurrentUserIncompleteOn(_selectedDate) ||
          plan.isPartnerIncompleteOn(_selectedDate);
    }

    return _isIncompleteForPlanOwner(plan);
  }

  bool _isDoneForFilter(Plan plan) {
    if (plan.owner == PlanOwner.together) {
      return plan.togetherStatusOn(_selectedDate) == TogetherStatus.bothDone;
    }
    return _isDoneForPlanOwner(plan);
  }

  Widget _buildPlanTile(Plan plan) {
    if (plan.owner == PlanOwner.together) {
      if (plan.isEnded && !plan.isCompletedOnceToday) {
        return PlanListTile(
          plan: plan,
          statusLabel: '已结束',
          statusColor: AppColors.secondaryText,
          statusIcon: Icons.event_available_rounded,
          showProgress: true,
          onTap: () => widget.onTapPlan(plan),
        );
      }
      final status = plan.togetherStatusOn(_selectedDate);
      final (label, color, icon) = _isPastMissed(plan)
          ? ('未完成', AppColors.reminder, Icons.warning_rounded)
          : plan.isOverdue && _isToday(_selectedDate)
          ? ('已逾期', AppColors.reminder, Icons.warning_rounded)
          : plan.isCurrentUserIncompleteOn(_selectedDate)
          ? ('我未完成', AppColors.reminder, Icons.error_outline_rounded)
          : plan.isPartnerIncompleteOn(_selectedDate) &&
                plan.isCurrentUserDoneOn(_selectedDate)
          ? ('TA 未完成', AppColors.reminder, Icons.error_outline_rounded)
          : _togetherStatusUI(status);
      return PlanListTile(
        plan: plan,
        statusLabel: label,
        statusColor: color,
        statusIcon: icon,
        showProgress: true,
        onTap: () => widget.onTapPlan(plan),
      );
    }
    if (plan.isEnded && !plan.isCompletedOnceToday) {
      return PlanListTile(
        plan: plan,
        statusLabel: '已结束',
        statusColor: AppColors.secondaryText,
        statusIcon: Icons.event_available_rounded,
        showProgress: true,
        onTap: () => widget.onTapPlan(plan),
      );
    }
    final done = _isDoneForPlanOwner(plan);
    final incomplete = _isIncompleteForPlanOwner(plan);
    final pastMissed = _isPastMissed(plan);
    return PlanListTile(
      plan: plan,
      statusLabel: pastMissed
          ? '未完成'
          : plan.isOverdue && _isToday(_selectedDate)
          ? '已逾期'
          : done
          ? '已打卡'
          : incomplete
          ? '未完成'
          : '待打卡',
      statusColor: pastMissed || (plan.isOverdue && _isToday(_selectedDate))
          ? AppColors.reminder
          : done
          ? AppColors.successText
          : incomplete
          ? AppColors.reminder
          : AppColors.deepPink,
      statusIcon: done
          ? Icons.check_circle_rounded
          : incomplete
          ? Icons.error_outline_rounded
          : Icons.radio_button_unchecked_rounded,
      showProgress: true,
      onTap: () => widget.onTapPlan(plan),
    );
  }

  bool _isDoneForPlanOwner(Plan plan) {
    return switch (plan.owner) {
      PlanOwner.me => plan.isCurrentUserDoneOn(_selectedDate),
      PlanOwner.partner => plan.isPartnerDoneOn(_selectedDate),
      PlanOwner.together =>
        plan.togetherStatusOn(_selectedDate) == TogetherStatus.bothDone,
    };
  }

  bool _isIncompleteForPlanOwner(Plan plan) {
    return switch (plan.owner) {
      PlanOwner.me => plan.isCurrentUserIncompleteOn(_selectedDate),
      PlanOwner.partner => plan.isPartnerIncompleteOn(_selectedDate),
      PlanOwner.together => plan.isCurrentUserIncompleteOn(_selectedDate),
    };
  }

  bool _isPastMissed(Plan plan) {
    return _dateOnly(_selectedDate).isBefore(_todayOnly()) &&
        !_isDoneForPlanOwner(plan);
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

class _SwipeDeletePlanTile extends StatefulWidget {
  const _SwipeDeletePlanTile({
    super.key,
    required this.child,
    required this.onDelete,
  });

  final Widget child;
  final VoidCallback onDelete;

  @override
  State<_SwipeDeletePlanTile> createState() => _SwipeDeletePlanTileState();
}

class _SwipeDeletePlanTileState extends State<_SwipeDeletePlanTile> {
  static const double _actionWidth = 92;
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: '删除计划',
                child: Tooltip(
                  message: '删除',
                  child: Material(
                    color: AppColors.reminder.withValues(alpha: 0.14),
                    child: InkWell(
                      onTap: widget.onDelete,
                      child: SizedBox(
                        width: _actionWidth,
                        height: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.reminder,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '删除',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.reminder,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragOffset = (_dragOffset + details.delta.dx)
                    .clamp(-_actionWidth, 0)
                    .toDouble();
              });
            },
            onHorizontalDragEnd: (_) {
              setState(() {
                if (_dragOffset.abs() > _actionWidth * 0.42) {
                  _dragOffset = _dragOffset.isNegative
                      ? -_actionWidth
                      : _actionWidth;
                } else {
                  _dragOffset = 0;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_dragOffset, 0, 0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanDateFilterCard extends StatelessWidget {
  const _PlanDateFilterCard({
    required this.selectedDate,
    required this.onPickDate,
    required this.onToday,
  });

  final DateTime selectedDate;
  final VoidCallback onPickDate;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDate(selectedDate, _todayOnly());

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.lightPink.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.deepPink,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _formatDateLabel(selectedDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.deepPink,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ChoiceChip(
            label: const Text('今天'),
            selected: isToday,
            showCheckmark: false,
            selectedColor: AppColors.deepPink,
            backgroundColor: Colors.white.withValues(alpha: 0.76),
            side: BorderSide(
              color: isToday ? AppColors.deepPink : AppColors.line,
            ),
            labelStyle: AppTextStyles.caption.copyWith(
              color: isToday ? Colors.white : AppColors.secondaryText,
              fontWeight: FontWeight.w900,
            ),
            onSelected: (_) => onToday(),
          ),
        ],
      ),
    );
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
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
      ),
    );
  }
}

enum _PlanFilter { all, pending, unfinished, completed }

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

DateTime _todayOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _isToday(DateTime date) => _isSameDate(date, DateTime.now());

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatDateLabel(DateTime date) {
  final prefix = _isToday(date)
      ? '今天'
      : _isSameDate(date, _todayOnly().add(const Duration(days: 1)))
      ? '明天'
      : _isSameDate(date, _todayOnly().subtract(const Duration(days: 1)))
      ? '昨天'
      : '';
  final dateText = '${date.month}月${date.day}日';
  return prefix.isEmpty ? dateText : '$prefix · $dateText';
}
