import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock/mock_store.dart';
import '../../data/models/plan.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_button.dart';

class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({super.key});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _taskController = TextEditingController();

  PlanOwner _owner = PlanOwner.me;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 29));
  TimeOfDay _reminderTime = const TimeOfDay(hour: 7, minute: 30);

  @override
  void dispose() {
    _titleController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建计划')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              120,
            ),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('计划信息', style: AppTextStyles.section),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(hintText: '输入计划名称'),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请输入计划名称'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _OwnerSelector(
                      selectedOwner: _owner,
                      onChanged: (owner) => setState(() => _owner = owner),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _taskController,
                      decoration: const InputDecoration(hintText: '输入每日任务'),
                      minLines: 2,
                      maxLines: 3,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请输入每日任务'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  children: [
                    _PickerTile(
                      icon: Icons.calendar_today_rounded,
                      title: '开始日期',
                      value: _formatDate(_startDate),
                      onTap: () => _pickStartDate(context),
                    ),
                    const Divider(height: 1, color: AppColors.line),
                    _PickerTile(
                      icon: Icons.event_available_rounded,
                      title: '结束日期',
                      value: _formatDate(_endDate),
                      onTap: () => _pickEndDate(context),
                    ),
                    const Divider(height: 1, color: AppColors.line),
                    _PickerTile(
                      icon: Icons.alarm_rounded,
                      title: '提醒时间',
                      value: _reminderTime.format(context),
                      onTap: () => _pickReminderTime(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            label: '保存创建计划',
            icon: Icons.check_rounded,
            onPressed: _savePlan,
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2028),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 29));
      }
    });
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2028),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _endDate = picked);
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _reminderTime = picked);
  }

  void _savePlan() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    MockStore.instance.createPlan(
      title: _titleController.text.trim(),
      owner: _owner,
      dailyTask: _taskController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      reminderTime: _reminderTime,
    );
    Navigator.of(context).pop();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _OwnerSelector extends StatelessWidget {
  const _OwnerSelector({required this.selectedOwner, required this.onChanged});

  final PlanOwner selectedOwner;
  final ValueChanged<PlanOwner> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PlanOwner>(
      segments: const [
        ButtonSegment(
          value: PlanOwner.me,
          label: Text('我的计划'),
          icon: Icon(Icons.person_rounded),
        ),
        ButtonSegment(
          value: PlanOwner.together,
          label: Text('共同计划'),
          icon: Icon(Icons.favorite_rounded),
        ),
      ],
      selected: {selectedOwner},
      onSelectionChanged: (value) => onChanged(value.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.lightPink,
        foregroundColor: AppColors.secondaryText,
        selectedBackgroundColor: Colors.white,
        selectedForegroundColor: AppColors.deepPink,
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.deepPink),
      title: Text(title, style: AppTextStyles.body),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTextStyles.caption),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.secondaryText,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
