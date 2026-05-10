import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/profile.dart';
import '../../data/store/store.dart';
import '../../data/models/plan.dart';
import '../../data/models/reminder.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/primary_pill_button.dart';
import '../checkin/checkin_page.dart';
import 'checkin_record_page.dart';
import 'create_plan_page.dart';

class PlanDetailPage extends StatelessWidget {
  const PlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final plan = store.getPlanById(planId);
    final profile = store.getProfile();
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('计划详情')),
        body: const Center(child: Text('计划不存在')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('计划详情', style: AppTextStyles.section),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.deepPink,
          onRefresh: context.read<Store>().refreshPlans,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              32,
            ),
            children: [
              _PlanOverviewCard(plan: plan),
              const SizedBox(height: AppSpacing.md),
              _TodayActionCard(plan: plan, profile: profile),
              const SizedBox(height: AppSpacing.md),
              _RecentCheckinsCard(
                plan: plan,
                onViewAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CheckinRecordPage(planId: plan.id),
                    ),
                  );
                },
              ),
              if (plan.canCurrentUserEdit && !plan.isEnded) ...[
                const SizedBox(height: AppSpacing.md),
                _buildEndPlanButton(context, plan),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: plan.isEnded && !plan.isCompletedOnceToday
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: _buildBottomButton(context, plan),
              ),
            ),
    );
  }

  Widget _buildBottomButton(BuildContext context, Plan plan) {
    if (plan.isEnded && !plan.isCompletedOnceToday) {
      return const SizedBox.shrink();
    }

    if (plan.isCompletedOnceToday) {
      return const _CompletedActionPill(
        label: '已完成',
        icon: Icons.check_circle_rounded,
      );
    }

    if (plan.isNotStartedYet) {
      return _buildNotStartedBottomButton(context, plan);
    }

    if (!plan.canCurrentUserCheckin && !plan.canCurrentUserEdit) {
      return PrimaryButton(
        label: '提醒 TA',
        icon: Icons.notifications_rounded,
        onPressed: () => _showRemindSheet(context, plan),
      );
    }

    if (plan.owner == PlanOwner.together) {
      if (plan.isTogetherDoneToday) {
        return Row(
          children: [
            Expanded(
              child: _PlanActionButton(
                label: '编辑',
                icon: Icons.edit_rounded,
                onPressed: () => _openEditPage(context, plan),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: _CompletedActionPill(
                label: '双方已完成',
                icon: Icons.verified_rounded,
              ),
            ),
          ],
        );
      }

      if (plan.doneToday) {
        return Row(
          children: [
            Expanded(
              child: _PlanActionButton(
                label: '编辑',
                icon: Icons.edit_rounded,
                onPressed: () => _openEditPage(context, plan),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryPillButton(
                label: '提醒 TA',
                icon: Icons.notifications_rounded,
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () => _showRemindSheet(context, plan),
              ),
            ),
          ],
        );
      }

      return Row(
        children: [
          Expanded(
            child: _PlanActionButton(
              label: '提醒 TA',
              icon: Icons.notifications_rounded,
              onPressed: () => _showRemindSheet(context, plan),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: PrimaryPillButton(
              label: plan.hasCurrentUserCheckinToday ? '修改打卡' : '打卡',
              icon: Icons.check_circle_rounded,
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: plan.canCurrentUserCheckin
                  ? () => _openCheckinPage(context, plan)
                  : () => _showCannotCheckinMessage(context, plan),
            ),
          ),
        ],
      );
    }

    if (plan.isDoneForCurrentUser) {
      return Row(
        children: [
          Expanded(
            child: _PlanActionButton(
              label: '编辑',
              icon: Icons.edit_rounded,
              onPressed: () => _openEditPage(context, plan),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: _CompletedActionPill(
              label: '今日已完成',
              icon: Icons.check_circle_rounded,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _openEditPage(context, plan),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepPink,
              side: const BorderSide(color: AppColors.deepPink),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              '编辑计划',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: PrimaryButton(
            label: plan.hasCurrentUserCheckinToday ? '修改打卡' : '去打卡',
            icon: Icons.check_circle_rounded,
            onPressed: plan.canCurrentUserCheckin
                ? () => _openCheckinPage(context, plan)
                : () => _showCannotCheckinMessage(context, plan),
          ),
        ),
      ],
    );
  }

  Widget _buildNotStartedBottomButton(BuildContext context, Plan plan) {
    const status = _MutedActionPill(label: '未开始', icon: Icons.event_rounded);

    if (!plan.canCurrentUserEdit) return status;

    return Row(
      children: [
        Expanded(
          child: _PlanActionButton(
            label: '编辑',
            icon: Icons.edit_rounded,
            onPressed: () => _openEditPage(context, plan),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: status),
      ],
    );
  }

  void _openEditPage(BuildContext context, Plan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatePlanPage(existingPlan: plan),
      ),
    );
  }

  void _openCheckinPage(BuildContext context, Plan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CheckinPage(planId: plan.id)),
    );
  }

  void _showCannotCheckinMessage(BuildContext context, Plan plan) {
    final message = plan.isNotStartedYet
        ? '这个计划还没开始，到了计划日期再打卡。'
        : '这个计划今天不在可打卡时间内啦';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showRemindSheet(BuildContext context, Plan plan) {
    final store = context.read<Store>();
    final messenger = ScaffoldMessenger.of(context);
    String? sendingLabel;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('提醒 TA', style: AppTextStyles.section),
                  const SizedBox(height: AppSpacing.xs),
                  Text('关联计划：${plan.title}', style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.lg),
                  for (final (label, icon, message) in _remindTypes) ...[
                    _RemindTypeTile(
                      label: label,
                      icon: icon,
                      message: message,
                      isLoading: sendingLabel == label,
                      enabled: sendingLabel == null,
                      onTap: () async {
                        if (sendingLabel != null) return;

                        final type = _remindTypeFromLabel(label);
                        final navigator = Navigator.of(context);
                        setModalState(() => sendingLabel = label);
                        try {
                          await store.sendReminder(
                            planId: plan.id,
                            type: type,
                            content: '$message（计划：${plan.title}）',
                          );
                          if (!context.mounted) return;
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('提醒已经飞过去啦～'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (error) {
                          if (kDebugMode) {
                            debugPrint('sendReminder failed: $error');
                          }
                          if (!context.mounted) return;
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(_reminderFailureMessage(error)),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  static const _remindTypes = [
    ('温柔提醒', Icons.alarm_rounded, '今天的小任务还没完成哦～要不要现在开始呀？'),
    ('认真监督', Icons.assignment_turned_in_rounded, '不许偷偷摆烂哦，要不要现在开始一点点？'),
    ('鼓励一下', Icons.thumb_up_alt_rounded, '你已经坚持很久啦，再完成一天！'),
    ('夸夸对方', Icons.favorite_rounded, '今天的你也很努力，值得夸夸！'),
  ];

  static ReminderType _remindTypeFromLabel(String label) => switch (label) {
    '认真监督' => ReminderType.strict,
    '鼓励一下' => ReminderType.encourage,
    '夸夸对方' => ReminderType.praise,
    _ => ReminderType.gentle,
  };

  static String _reminderFailureMessage(Object error) {
    final message = error.toString();

    if (message.contains('prompt reminders are not allowed after completion')) {
      return 'TA 今天已经完成这个计划啦，换个夸夸会更合适';
    }
    if (message.contains('supervision is disabled for this plan')) {
      return '这个计划没有开启互相监督，暂时不能提醒';
    }
    if (message.contains('plan is not in the current user couple') ||
        message.contains('reminder users must belong to the plan couple') ||
        message.contains('reminder couple_id must match plan') ||
        message.contains(
          'reminder couple_id must match sender active couple',
        )) {
      return '这个计划和当前情侣关系不一致，请刷新后再试';
    }
    if (message.contains('plan does not exist')) {
      return '这个计划不存在或已被删除';
    }
    if (message.contains('authentication required')) {
      return '登录状态已失效，请重新进入后再试';
    }
    if (message.contains('reminders can only be sent to an active partner')) {
      return '绑定关系已变化，暂时不能发送提醒';
    }
    if (message.contains('reminders can only be linked to an active plan')) {
      return '这个计划当前不在可提醒时间内，请确认开始和结束日期';
    }

    return '发送提醒失败，请稍后再试';
  }

  Widget _buildEndPlanButton(BuildContext context, Plan plan) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _confirmEndPlan(context, plan),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.reminder,
          side: const BorderSide(color: AppColors.reminder),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: const Text(
          '结束计划',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  void _confirmEndPlan(BuildContext context, Plan plan) {
    var ending = false;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text('确认结束计划'),
              content: Text(
                '确定要结束「${plan.title}」吗？\n结束后的计划将不再出现在日常列表中，但打卡记录依然可以查看。',
              ),
              actions: [
                TextButton(
                  onPressed: ending ? null : () => Navigator.of(context).pop(),
                  child: const Text('再想想'),
                ),
                TextButton(
                  onPressed: ending
                      ? null
                      : () async {
                          setDialogState(() => ending = true);
                          try {
                            await context.read<Store>().endPlan(plan.id);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('计划已结束，辛苦啦～'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (error) {
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('结束计划失败，请稍后再试'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.reminder,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    child: ending
                        ? const SizedBox(
                            key: ValueKey('ending'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('确定结束', key: ValueKey('end-label')),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlanActionButton extends StatelessWidget {
  const _PlanActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepPink,
        side: BorderSide(color: AppColors.deepPink.withValues(alpha: 0.56)),
        backgroundColor: Colors.white.withValues(alpha: 0.66),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RemindTypeTile extends StatelessWidget {
  const _RemindTypeTile({
    required this.label,
    required this.icon,
    required this.message,
    required this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final String message;
  final VoidCallback onTap;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: enabled || isLoading ? 1 : 0.62,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.lightPink.withValues(alpha: 0.46),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.deepPink, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: AppSpacing.sm),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletedActionPill extends StatelessWidget {
  const _CompletedActionPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.34),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: AppColors.successText),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.successText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedActionPill extends StatelessWidget {
  const _MutedActionPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.line.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.secondaryText.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanOverviewCard extends StatelessWidget {
  const _PlanOverviewCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final status = _planStatusUi(plan);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            AppColors.lightPink.withValues(alpha: 0.72),
            AppColors.paperWarm.withValues(alpha: 0.56),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepPink.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: plan.iconBackgroundColor.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: plan.iconColor.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(plan.icon, color: plan.iconColor, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _InfoBadge(
                          label: status.label,
                          icon: status.icon,
                          color: status.color,
                          filled: true,
                        ),
                        _InfoBadge(
                          label: plan.repeatLabel,
                          icon: plan.isDaily
                              ? Icons.event_repeat_rounded
                              : Icons.task_alt_rounded,
                          color: AppColors.deepPink,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      plan.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ScheduleStrip(plan: plan),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStrip extends StatelessWidget {
  const _ScheduleStrip({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          _InlineMeta(
            icon: Icons.notifications_none_rounded,
            text: plan.reminderTime == null
                ? '未开启提醒'
                : '提醒 ${plan.reminderTime!.format(context)}',
          ),
          _InlineMeta(icon: Icons.date_range_rounded, text: _dateText(plan)),
        ],
      ),
    );
  }

  String _dateText(Plan plan) {
    if (plan.hasDateRange) {
      return '${_formatDate(plan.startDate)} - ${_formatDate(plan.endDate)}';
    }
    if (plan.isDaily) return '长期每日';
    return '单次 ${_formatDate(plan.startDate)}';
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryText),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TodayActionCard extends StatelessWidget {
  const _TodayActionCard({required this.plan, required this.profile});

  final Plan plan;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final status = _planStatusUi(plan);

    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.surface,
      showDashedBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '今日行动',
                  style: AppTextStyles.section.copyWith(fontSize: 22),
                ),
              ),
              _InfoBadge(
                label: status.label,
                icon: status.icon,
                color: status.color,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (plan.owner == PlanOwner.together) ...[
            _CoupleStatusPanel(plan: plan, profile: profile),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              _MetricTile(
                label: plan.isDaily ? '已坚持' : '完成情况',
                value: plan.isDaily
                    ? '${plan.completedDays}天'
                    : plan.isDoneForCurrentUser
                    ? '已完成'
                    : plan.hasCurrentUserCheckinToday
                    ? '未完成'
                    : '待完成',
              ),
              const SizedBox(width: AppSpacing.sm),
              _MetricTile(label: '完成率', value: _progressLabel(plan)),
              const SizedBox(width: AppSpacing.sm),
              _MetricTile(label: '周期', value: _periodLabel(plan)),
            ],
          ),
          if (plan.isDaily && plan.hasDateRange) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: plan.progress.clamp(0, 1),
                minHeight: 10,
                backgroundColor: AppColors.lightPink.withValues(alpha: 0.58),
                color: AppColors.deepPink,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _progressLabel(Plan plan) {
    if (plan.isOnce) return plan.isDoneForCurrentUser ? '100%' : '0%';
    if (!plan.hasDateRange) return '长期';
    return '${(plan.progress.clamp(0, 1) * 100).round()}%';
  }

  String _periodLabel(Plan plan) {
    if (plan.isCompletedOnceToday) return '单次';
    if (plan.isEnded) return '已结束';
    if (plan.isNotStartedYet) return '未开始';
    if (plan.isOnce) return '单次';
    if (!plan.hasDateRange) return '每日';
    return '${plan.totalDays}天';
  }
}

class _CoupleStatusPanel extends StatelessWidget {
  const _CoupleStatusPanel({required this.plan, required this.profile});

  final Plan plan;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.blush.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PersonStatusTile(
              label: '我',
              avatarUrl: profile.avatarUrl,
              fallbackIcon: Icons.face_6_rounded,
              completed: plan.doneToday,
              checkedIn: plan.hasCurrentUserCheckinToday,
              color: AppColors.deepPink,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _PersonStatusTile(
              label: profile.isBound && profile.partnerName.trim().isNotEmpty
                  ? profile.partnerName.trim()
                  : 'TA',
              avatarUrl: profile.partnerAvatarUrl,
              fallbackIcon: Icons.favorite_rounded,
              completed: plan.partnerDoneToday,
              checkedIn: plan.hasPartnerCheckinToday,
              color: AppColors.successText,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonStatusTile extends StatelessWidget {
  const _PersonStatusTile({
    required this.label,
    required this.avatarUrl,
    required this.fallbackIcon,
    required this.completed,
    required this.checkedIn,
    required this.color,
  });

  final String label;
  final String? avatarUrl;
  final IconData fallbackIcon;
  final bool completed;
  final bool checkedIn;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = completed
        ? color
        : checkedIn
        ? AppColors.reminder
        : AppColors.secondaryText;
    final statusText = completed
        ? '已打卡'
        : checkedIn
        ? '未完成'
        : '待打卡';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _TinyProfileAvatar(
            imageUrl: avatarUrl,
            color: color,
            fallbackIcon: fallbackIcon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: effectiveColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            completed
                ? Icons.check_circle_rounded
                : checkedIn
                ? Icons.error_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            color: effectiveColor,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _TinyProfileAvatar extends StatelessWidget {
  const _TinyProfileAvatar({
    required this.imageUrl,
    required this.color,
    required this.fallbackIcon,
  });

  final String? imageUrl;
  final Color color;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    return Container(
      width: 38,
      height: 38,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(fallbackIcon, color: color, size: 20),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(fallbackIcon, color: color, size: 20),
                ),
              ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 86,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.lightPink.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.deepPink,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({String label, Color color, IconData icon}) _planStatusUi(Plan plan) {
  if (plan.isCompletedOnceToday) {
    return (
      label: '已完成',
      color: AppColors.successText,
      icon: Icons.check_circle_rounded,
    );
  }

  if (plan.isEnded) {
    return (
      label: '已结束',
      color: AppColors.secondaryText,
      icon: Icons.event_available_rounded,
    );
  }

  if (plan.isNotStartedYet) {
    return (
      label: '未开始',
      color: AppColors.secondaryText,
      icon: Icons.event_rounded,
    );
  }

  if (plan.isOverdue) {
    return (
      label: '已逾期',
      color: AppColors.reminder,
      icon: Icons.warning_rounded,
    );
  }

  return switch (plan.owner) {
    PlanOwner.me =>
      plan.doneToday
          ? (
              label: '已打卡',
              color: AppColors.successText,
              icon: Icons.check_circle_rounded,
            )
          : plan.hasCurrentUserCheckinToday
          ? (
              label: '未完成',
              color: AppColors.reminder,
              icon: Icons.error_outline_rounded,
            )
          : (
              label: '待打卡',
              color: AppColors.deepPink,
              icon: Icons.radio_button_unchecked_rounded,
            ),
    PlanOwner.partner =>
      plan.partnerDoneToday
          ? (
              label: 'TA 已打卡',
              color: AppColors.successText,
              icon: Icons.check_circle_rounded,
            )
          : plan.hasPartnerCheckinToday
          ? (
              label: 'TA 未完成',
              color: AppColors.reminder,
              icon: Icons.error_outline_rounded,
            )
          : (
              label: 'TA 待打卡',
              color: AppColors.deepPink,
              icon: Icons.radio_button_unchecked_rounded,
            ),
    PlanOwner.together => switch (plan.togetherStatus) {
      TogetherStatus.bothDone => (
        label: '双方已完成',
        color: AppColors.successText,
        icon: Icons.verified_rounded,
      ),
      TogetherStatus.onlyMeDone => (
        label: '等 TA',
        color: AppColors.reminder,
        icon: Icons.hourglass_top_rounded,
      ),
      TogetherStatus.meNotDone => (
        label: plan.hasCurrentUserCheckinToday ? '我未完成' : '我待打卡',
        color: plan.hasCurrentUserCheckinToday
            ? AppColors.reminder
            : AppColors.deepPink,
        icon: plan.hasCurrentUserCheckinToday
            ? Icons.error_outline_rounded
            : Icons.radio_button_unchecked_rounded,
      ),
    },
  };
}

class _RecentCheckinsCard extends StatelessWidget {
  const _RecentCheckinsCard({required this.plan, required this.onViewAll});

  final Plan plan;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final records = plan.checkins.take(3).toList();

    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.surface,
      showDashedBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('最近记录', style: AppTextStyles.section)),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '全部',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepPink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.blush.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '还没有记录，完成一次就会出现在这里',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...records.indexed.map(
              (entry) => _CheckinTimelineRow(
                record: entry.$2,
                isLast: entry.$1 == records.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckinTimelineRow extends StatelessWidget {
  const _CheckinTimelineRow({required this.record, required this.isLast});

  final CheckinRecord record;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = record.completed ? AppColors.successText : AppColors.reminder;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                record.completed
                    ? Icons.check_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: color,
                size: 17,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: AppColors.line.withValues(alpha: 0.7),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(record.date)} · ${_moodLabel(record.mood)}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (record.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _moodLabel(CheckinMood mood) {
    return switch (mood) {
      CheckinMood.happy => '开心',
      CheckinMood.normal => '一般',
      CheckinMood.tired => '有点累',
      CheckinMood.great => '超棒',
    };
  }
}
