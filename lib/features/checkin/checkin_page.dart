import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock/mock_store.dart';
import '../../data/models/plan.dart';
import '../../shared/widgets/app_card.dart';
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

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = MockStore.instance.getPlanById(widget.planId);
    final canCheckin = plan?.canCurrentUserCheckin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('每日打卡')),
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
            AppCard(
              backgroundColor: AppColors.lightPink,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.deepPink,
                    ),
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
                          plan?.dailyTask ?? '',
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
                      'TA 的计划只能查看，不能代替 TA 打卡。',
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
                    onSelectionChanged: canCheckin
                        ? (value) => setState(() => _completed = value.first)
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
                            onSelected: canCheckin
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
                enabled: canCheckin,
                maxLength: 50,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(hintText: '写一句今天的完成备注...'),
              ),
            ),
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
          child: PrimaryButton(
            label: '保存打卡',
            icon: Icons.save_rounded,
            onPressed: canCheckin ? _saveCheckin : _showCannotCheckin,
          ),
        ),
      ),
    );
  }

  void _saveCheckin() {
    MockStore.instance.saveCheckin(
      planId: widget.planId,
      completed: _completed,
      mood: _mood,
      note: _noteController.text,
    );
    Navigator.of(context).pop();
  }

  void _showCannotCheckin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('不能代替 TA 打卡'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
