import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock/mock_store.dart';
import '../../data/models/plan.dart';
import '../../features/checkin/checkin_page.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_button.dart';

class PlanDetailPage extends StatelessWidget {
  const PlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MockStore.instance,
      builder: (context, _) {
        final plan = MockStore.instance.getPlanById(planId);
        if (plan == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('计划详情')),
            body: const Center(child: Text('计划不存在')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('计划详情')),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                120,
              ),
              children: [
                _PlanHeroCard(plan: plan),
                const SizedBox(height: AppSpacing.md),
                _PlanInfoCard(plan: plan),
                if (plan.owner == PlanOwner.together) ...[
                  const SizedBox(height: AppSpacing.md),
                  _TogetherCheckinStatusCard(plan: plan),
                ],
                const SizedBox(height: AppSpacing.md),
                _RecentCheckinsCard(records: plan.checkins),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              plan.canCurrentUserEdit ? '功能开发中' : '不能修改 TA 的计划',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('编辑计划'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      label: plan.canCurrentUserCheckin ? '去打卡' : '仅可查看',
                      icon: Icons.check_circle_rounded,
                      onPressed: () {
                        if (!plan.canCurrentUserCheckin) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('不能代替 TA 打卡'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CheckinPage(planId: plan.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlanHeroCard extends StatelessWidget {
  const _PlanHeroCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.lightPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(plan.icon, color: AppColors.deepPink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_ownerLabel(plan.owner), style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(plan.dailyTask, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _PlanInfoCard extends StatelessWidget {
  const _PlanInfoCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('计划进度', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _InfoPill(label: '已坚持', value: '${plan.completedDays} 天'),
              const SizedBox(width: AppSpacing.sm),
              _InfoPill(
                value: '${(plan.progress * 100).round()}%',
                label: '完成率',
              ),
              const SizedBox(width: AppSpacing.sm),
              _InfoPill(label: '今日状态', value: _todayStatusLabel(plan)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: plan.progress,
              minHeight: 10,
              color: AppColors.deepPink,
              backgroundColor: AppColors.lightPink,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${_formatDate(plan.startDate)} - ${_formatDate(plan.endDate)} · 每天 ${plan.reminderTime.format(context)} 提醒',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _TogetherCheckinStatusCard extends StatelessWidget {
  const _TogetherCheckinStatusCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日共同打卡', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.md),
          _CheckinStatusRow(
            label: '我',
            subtitle: '只能更新自己的打卡状态',
            checked: plan.doneToday,
            activeColor: AppColors.success,
          ),
          const Divider(height: 20, color: AppColors.line),
          _CheckinStatusRow(
            label: 'TA',
            subtitle: 'TA 完成后这里会显示 TA 的状态',
            checked: plan.partnerDoneToday,
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
    required this.subtitle,
    required this.checked,
    required this.activeColor,
  });

  final String label;
  final String subtitle;
  final bool checked;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          checked
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: checked ? activeColor : AppColors.secondaryText,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label${checked ? '已打卡' : '待打卡'}',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.lightPink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.section),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _RecentCheckinsCard extends StatelessWidget {
  const _RecentCheckinsCard({required this.records});

  final List<CheckinRecord> records;

  @override
  Widget build(BuildContext context) {
    final visibleRecords = records.take(3).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('最近打卡记录', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.sm),
          if (visibleRecords.isEmpty)
            Text('还没有打卡记录，今天开始也很好。', style: AppTextStyles.caption)
          else
            ...visibleRecords.map(
              (record) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  record.completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: record.completed
                      ? AppColors.success
                      : AppColors.reminder,
                ),
                title: Text(
                  '${_formatDate(record.date)} · ${_actorLabel(record.actor)} · ${_moodLabel(record.mood)}',
                  style: AppTextStyles.body,
                ),
                subtitle: Text(
                  record.note.isEmpty ? '没有备注' : record.note,
                  style: AppTextStyles.caption,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _ownerLabel(PlanOwner owner) {
  return switch (owner) {
    PlanOwner.me => '我的计划',
    PlanOwner.partner => 'TA 的计划',
    PlanOwner.together => '共同计划',
  };
}

String _todayStatusLabel(Plan plan) {
  return switch (plan.owner) {
    PlanOwner.me => plan.doneToday ? '已完成' : '待打卡',
    PlanOwner.partner => plan.partnerDoneToday ? 'TA 已完成' : 'TA 待打卡',
    PlanOwner.together =>
      plan.isTogetherDoneToday
          ? '双方已完成'
          : plan.doneToday
          ? '我已完成'
          : '我待打卡',
  };
}

String _actorLabel(CheckinActor actor) {
  return switch (actor) {
    CheckinActor.me => '我',
    CheckinActor.partner => 'TA',
  };
}

String _moodLabel(CheckinMood mood) {
  return switch (mood) {
    CheckinMood.happy => '开心',
    CheckinMood.normal => '一般',
    CheckinMood.tired => '有点累',
    CheckinMood.great => '超棒',
  };
}

String _formatDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
