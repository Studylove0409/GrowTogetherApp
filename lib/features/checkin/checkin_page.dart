import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/store/store.dart';
import '../../data/models/plan.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_tile.dart';
import '../../shared/widgets/primary_button.dart';

class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key, required this.planId});

  final String planId;

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  final _noteController = TextEditingController();
  bool _completed = true;
  CheckinMood _mood = CheckinMood.happy;
  bool _saving = false;
  bool _showSuccess = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final plan = store.getPlanById(widget.planId);
    final canCheckin = plan?.canCurrentUserCheckin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('每日打卡')),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                120,
              ),
              children: [
                AppCard(
                  backgroundColor: AppColors.lightPink,
                  child: Row(
                    children: [
                      AppIconTile(
                        icon: plan?.icon ?? Icons.check_circle_rounded,
                        color: plan?.iconColor ?? AppColors.deepPink,
                        size: 50,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan?.title ?? '计划不存在',
                              style: AppTextStyles.section,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              plan?.subtitle ?? '',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('完成状态', style: AppTextStyles.section),
                      if (!canCheckin) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _cannotCheckinText(plan),
                          style: AppTextStyles.caption,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('完成'),
                            icon: Icon(Icons.check_rounded),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('未完成'),
                            icon: Icon(Icons.close_rounded),
                          ),
                        ],
                        selected: {_completed},
                        onSelectionChanged: canCheckin && !_saving
                            ? (value) =>
                                  setState(() => _completed = value.first)
                            : null,
                        style: SegmentedButton.styleFrom(
                          backgroundColor: AppColors.lightPink,
                          selectedBackgroundColor: Colors.white,
                          selectedForegroundColor: AppColors.deepPink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('今日心情', style: AppTextStyles.section),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: CheckinMood.values
                            .map(
                              (mood) => ChoiceChip(
                                label: Text(_moodLabel(mood)),
                                selected: _mood == mood,
                                selectedColor: AppColors.lightPink,
                                checkmarkColor: AppColors.deepPink,
                                onSelected: canCheckin && !_saving
                                    ? (_) => setState(() => _mood = mood)
                                    : null,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: TextField(
                    controller: _noteController,
                    enabled: canCheckin && !_saving,
                    maxLength: 50,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '写一句今天的完成备注...',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showSuccess)
            _CheckinSuccessOverlay(
              completed: _completed,
              planTitle: plan?.title ?? '今日计划',
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: PrimaryButton(
            label: '保存打卡',
            icon: Icons.save_rounded,
            isLoading: _saving,
            onPressed: _saving
                ? null
                : (canCheckin ? () => _saveCheckin() : _showCannotCheckin),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCheckin() async {
    if (_saving) return;

    final store = context.read<Store>();
    final saveFuture = store.saveCheckin(
      planId: widget.planId,
      completed: _completed,
      mood: _mood,
      note: _noteController.text,
    );

    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _showSuccess = true;
    });

    try {
      await Future.wait([
        saveFuture,
        Future<void>.delayed(const Duration(milliseconds: 650)),
      ]);
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _showSuccess = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('打卡失败，请稍后再试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCannotCheckin() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_cannotCheckinText(null)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _cannotCheckinText(Plan? plan) {
    if (plan == null) return '这个计划今天不在可打卡时间内啦';
    if (plan.owner == PlanOwner.partner) return 'TA 的计划只能查看，不能代替 TA 打卡。';
    if (plan.isEnded) return '这个计划已经结束啦，不需要再打卡。';
    if (plan.isNotStartedYet) return '这个计划还没开始，到了开始日期再打卡。';
    return '这个计划今天不在可打卡时间内啦';
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

class _CheckinSuccessOverlay extends StatelessWidget {
  const _CheckinSuccessOverlay({
    required this.completed,
    required this.planTitle,
  });

  final bool completed;
  final String planTitle;

  @override
  Widget build(BuildContext context) {
    final title = completed ? '恭喜完成打卡' : '今天也记录下来啦';
    final subtitle = completed ? '「$planTitle」又前进了一小步' : '状态已保存，明天继续调整节奏';

    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.text.withValues(alpha: 0.24),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.86, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: AppCard(
                borderRadius: 30,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xl,
                ),
                showDashedBorder: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ...List.generate(8, (index) {
                          final angle = index * math.pi / 4;
                          return Transform.translate(
                            offset: Offset(
                              46 * math.cos(angle),
                              46 * math.sin(angle),
                            ),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 13,
                              color: index.isEven
                                  ? AppColors.primary
                                  : AppColors.flowerYellow,
                            ),
                          );
                        }),
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.lightPink,
                            borderRadius: BorderRadius.circular(38),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.deepPink.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            completed
                                ? Icons.check_rounded
                                : Icons.edit_note_rounded,
                            color: AppColors.deepPink,
                            size: 42,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title.copyWith(
                        color: AppColors.text,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
