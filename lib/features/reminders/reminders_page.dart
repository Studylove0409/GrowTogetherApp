import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/reminder.dart';
import '../../data/store/store.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/empty_state_card.dart';
import '../plans/plan_detail_page.dart';
import '../../shared/widgets/reminder_card.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key, this.isSelected = true, this.onOpenFocus});

  final bool isSelected;
  final VoidCallback? onOpenFocus;

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool _showReceived = true;
  late DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = widget.isSelected
        ? context.watch<Store>()
        : context.read<Store>();
    final reminders = store
        .getReminders()
        .where((reminder) => reminder.sentByMe != _showReceived)
        .where((reminder) => !_isLegacyFocusInviteReminder(reminder))
        .where((reminder) => _isSameDate(reminder.createdAt, _selectedDate))
        .toList();
    final focusInvites =
        _showReceived && _isSameDate(_selectedDate, _dateOnly(DateTime.now()))
        ? store.getIncomingFocusInvites()
        : <FocusSession>[];

    return AppScaffold(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          const _ReminderTitle(),
          const SizedBox(height: AppSpacing.lg),
          _ReminderDateFilter(
            selectedDate: _selectedDate,
            onDateSelected: (date) {
              setState(() => _selectedDate = _dateOnly(date));
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _ReminderTabs(
              showReceived: _showReceived,
              onChanged: (value) => setState(() => _showReceived = value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.deepPink,
              onRefresh: () async {
                final store = context.read<Store>();
                await Future.wait([
                  store.refreshPlans(),
                  store.refreshReminders(),
                  store.refreshFocusSessions(),
                ]);
              },
              child: reminders.isEmpty && focusInvites.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        32,
                      ),
                      children: [
                        EmptyStateCard(
                          message:
                              '${_formatDateLabel(_selectedDate)}没有${_showReceived ? '收到' : '发出'}的提醒',
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        32,
                      ),
                      itemCount: focusInvites.length + reminders.length,
                      itemBuilder: (context, index) {
                        if (index < focusInvites.length) {
                          final invite = focusInvites[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _FocusInviteReminderCard(
                              invite: invite,
                              onJoin: () => _joinFocusInvite(context, invite),
                              onDecline: () =>
                                  _declineFocusInvite(context, invite),
                            ),
                          );
                        }

                        final reminder = reminders[index - focusInvites.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: ReminderCard(
                            reminder: reminder,
                            onTap: reminder.planId != null
                                ? () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => PlanDetailPage(
                                        planId: reminder.planId!,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isLegacyFocusInviteReminder(Reminder reminder) {
    return reminder.content.startsWith('想邀请你一起专注');
  }

  static String _formatDateLabel(DateTime date) =>
      '${date.month}.${date.day.toString().padLeft(2, '0')}';

  Future<void> _joinFocusInvite(
    BuildContext context,
    FocusSession invite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<Store>().joinFocusSession(invite.id);
      if (!mounted) return;
      widget.onOpenFocus?.call();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('这次专注邀请暂时无法加入，请刷新后再试。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _declineFocusInvite(
    BuildContext context,
    FocusSession invite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<Store>().finishFocusSession(
        sessionId: invite.id,
        status: FocusSessionStatus.cancelled,
        actualDurationSeconds: 0,
        scoreDelta: 0,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('已婉拒这次专注邀请。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('暂时无法处理这次邀请，请稍后再试。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _FocusInviteReminderCard extends StatelessWidget {
  const _FocusInviteReminderCard({
    required this.invite,
    required this.onJoin,
    required this.onDecline,
  });

  final FocusSession invite;
  final VoidCallback onJoin;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      showDashedBorder: false,
      padding: const EdgeInsets.all(14),
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.54),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.timer_rounded,
                  color: AppColors.deepPink,
                  size: 27,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '一起专注邀请',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.section,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${invite.planTitle} · ${invite.plannedDurationMinutes} 分钟',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTime(invite.createdAt),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onJoin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepPink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 20),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '加入专注',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                    side: BorderSide(
                      color: AppColors.secondaryText.withValues(alpha: 0.28),
                    ),
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: const Text(
                    '婉拒',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ReminderDateFilter extends StatelessWidget {
  const _ReminderDateFilter({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final dates = List.generate(
      7,
      (index) => selectedDate.add(Duration(days: index - 3)),
    );

    return SizedBox(
      height: 88,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dates.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final date = dates[index];
                  return _DateFilterItem(
                    date: date,
                    selected: _isSameDate(date, selectedDate),
                    onTap: () => onDateSelected(date),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _CalendarPickerButton(
                selectedDate: selectedDate,
                onDateSelected: onDateSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateFilterItem extends StatelessWidget {
  const _DateFilterItem({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    return Semantics(
      button: true,
      selected: selected,
      label: '${_monthDay(date)} ${_weekday(date)}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.deepPink : AppColors.paper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? AppColors.deepPink
                  : AppColors.dashedLine.withValues(alpha: 0.70),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: selected ? 0.18 : 0.08,
                ),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isToday ? '今天' : _weekday(date),
                style: AppTextStyles.caption.copyWith(
                  color: selected ? Colors.white : AppColors.secondaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                date.day.toString().padLeft(2, '0'),
                style: AppTextStyles.title.copyWith(
                  color: selected ? Colors.white : AppColors.deepPink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${date.month}月',
                style: AppTextStyles.caption.copyWith(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.86)
                      : AppColors.mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthDay(DateTime date) => '${date.month}月${date.day}日';

  String _weekday(DateTime date) {
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[date.weekday - 1];
  }
}

class _CalendarPickerButton extends StatelessWidget {
  const _CalendarPickerButton({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '选择日期',
      child: GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
            helpText: '选择提醒日期',
            cancelText: '取消',
            confirmText: '确定',
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppColors.deepPink,
                    onPrimary: Colors.white,
                    surface: AppColors.surface,
                    onSurface: AppColors.text,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            onDateSelected(picked);
          }
        },
        child: Container(
          width: 52,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.lightPink.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.dashedLine),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: AppColors.deepPink,
          ),
        ),
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
