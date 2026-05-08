import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/store/store.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../plans/plan_detail_page.dart';
import '../../shared/widgets/reminder_card.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool _showReceived = true;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final reminders = store
        .getReminders()
        .where((reminder) => reminder.sentByMe != _showReceived)
        .toList();

        return AppScaffold(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              const _ReminderTitle(),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _ReminderTabs(
                  showReceived: _showReceived,
                  onChanged: (value) => setState(() => _showReceived = value),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    16,
                  ),
                  itemCount: reminders.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ReminderCard(
                      reminder: reminders[index],
                      onTap: reminders[index].planId != null
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PlanDetailPage(
                                    planId: reminders[index].planId!,
                                  ),
                                ),
                              )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
  }
}

class _ReminderTitle extends StatelessWidget {
  const _ReminderTitle();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        const Text('提醒一下', style: AppTextStyles.display),
        Positioned(
          right: -22,
          top: -14,
          child: Icon(
            Icons.favorite_rounded,
            color: AppColors.primary.withValues(alpha: 0.62),
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _ReminderTabs extends StatelessWidget {
  const _ReminderTabs({required this.showReceived, required this.onChanged});

  final bool showReceived;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 999,
      padding: const EdgeInsets.all(5),
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.42),
      child: Row(
        children: [
          _ReminderTabItem(
            label: '收到的提醒',
            selected: showReceived,
            onTap: () => onChanged(true),
          ),
          _ReminderTabItem(
            label: '发出的提醒',
            selected: !showReceived,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ReminderTabItem extends StatelessWidget {
  const _ReminderTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.84)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: selected ? AppColors.deepPink : AppColors.secondaryText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
