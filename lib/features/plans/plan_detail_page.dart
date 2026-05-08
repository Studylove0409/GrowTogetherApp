import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/store/store.dart';
import '../../data/models/plan.dart';
import '../../data/models/reminder.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_button.dart';
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            32,
          ),
          children: [
            _PlanHeroCard(plan: plan),
            const SizedBox(height: AppSpacing.md),
            _PlanStatusCard(plan: plan),
            const SizedBox(height: AppSpacing.md),
            _PlanProgressCard(plan: plan),
            if (plan.owner == PlanOwner.together) ...[
              const SizedBox(height: AppSpacing.md),
              _TogetherCheckinCard(plan: plan),
            ],
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
      bottomNavigationBar: plan.isEnded
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
    if (plan.isEnded) {
      return const SizedBox.shrink();
    }

    if (!plan.canCurrentUserCheckin && !plan.canCurrentUserEdit) {
      return PrimaryButton(
        label: '提醒 TA',
        icon: Icons.notifications_rounded,
        onPressed: () => _showRemindSheet(context, plan),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreatePlanPage(existingPlan: plan),
                ),
              );
            },
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
            label: '去打卡',
            icon: Icons.check_circle_rounded,
            onPressed: plan.canCurrentUserCheckin
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CheckinPage(planId: plan.id),
                      ),
                    );
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('不能代替 TA 打卡'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
          ),
        ),
      ],
    );
  }

  void _showRemindSheet(BuildContext context, Plan plan) {
    final store = context.read<Store>();
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
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
                  onTap: () async {
                    final type = _remindTypeFromLabel(label);
                    final navigator = Navigator.of(context);
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
      return '这个计划已结束，不能再发送提醒';
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
    showDialog<void>(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('再想想'),
            ),
            TextButton(
              onPressed: () async {
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
              style: TextButton.styleFrom(foregroundColor: AppColors.reminder),
              child: const Text('确定结束'),
            ),
          ],
        );
      },
    );
  }
}

class _RemindTypeTile extends StatelessWidget {
  const _RemindTypeTile({
    required this.label,
    required this.icon,
    required this.message,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
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
        ],
      ),
    );
  }
}

class _PlanHeroCard extends StatelessWidget {
  const _PlanHeroCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.46),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: plan.iconBackgroundColor.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(plan.icon, color: plan.iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title, style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xs),
                Text(plan.subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanStatusCard extends StatelessWidget {
  const _PlanStatusCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (plan.owner) {
      PlanOwner.me =>
        plan.doneToday
            ? ('已打卡', AppColors.successText)
            : ('待打卡', AppColors.deepPink),
      PlanOwner.partner =>
        plan.partnerDoneToday
            ? ('TA 已打卡', AppColors.successText)
            : ('TA 待打卡', AppColors.deepPink),
      PlanOwner.together => switch (plan.togetherStatus) {
        TogetherStatus.bothDone => ('双方已完成', AppColors.successText),
        TogetherStatus.onlyMeDone => ('我已打卡', AppColors.reminder),
        TogetherStatus.meNotDone => ('我待打卡', AppColors.deepPink),
      },
    };

    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              statusColor == AppColors.successText
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日状态',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: AppTextStyles.title.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (plan.owner == PlanOwner.together)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    (plan.partnerDoneToday
                            ? AppColors.success
                            : AppColors.reminder)
                        .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                plan.partnerDoneToday ? 'TA 已打卡' : 'TA 待打卡',
                style: TextStyle(
                  fontSize: 11,
                  color: plan.partnerDoneToday
                      ? AppColors.successText
                      : AppColors.reminder,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanProgressCard extends StatelessWidget {
  const _PlanProgressCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatBlock(label: '已坚持', value: '${plan.completedDays} 天'),
              const SizedBox(width: AppSpacing.sm),
              _StatBlock(
                label: '完成率',
                value: '${(plan.progress * 100).round()}%',
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatBlock(label: '总天数', value: '${plan.totalDays} 天'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: plan.progress.clamp(0, 1),
              minHeight: 12,
              backgroundColor: AppColors.lightPink.withValues(alpha: 0.66),
              color: AppColors.deepPink,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '提醒 ${plan.reminderTime.format(context)}  ·  ${_formatDate(plan.startDate)} - ${_formatDate(plan.endDate)}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.lightPink.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.title.copyWith(
                color: AppColors.deepPink,
                fontSize: 24,
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

class _TogetherCheckinCard extends StatelessWidget {
  const _TogetherCheckinCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日共同打卡', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.md),
          _CheckinStatusRow(
            label: '我',
            done: plan.doneToday,
            activeColor: AppColors.success,
          ),
          const Divider(height: 20, color: AppColors.line),
          _CheckinStatusRow(
            label: 'TA',
            done: plan.partnerDoneToday,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _CheckinStatusRow extends StatelessWidget {
  const _CheckinStatusRow({
    required this.label,
    required this.done,
    required this.activeColor,
  });

  final String label;
  final bool done;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: done ? activeColor : AppColors.secondaryText,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label${done ? '已打卡' : '待打卡'}',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            color: done ? activeColor : AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('最近打卡记录', style: AppTextStyles.section),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '打卡记录',
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
            Text('还没有打卡记录', style: AppTextStyles.caption)
          else
            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      record.completed
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: record.completed
                          ? AppColors.successText
                          : AppColors.reminder,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatDate(record.date)} · ${_moodLabel(record.mood)}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (record.note.isNotEmpty)
                            Text(
                              record.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
