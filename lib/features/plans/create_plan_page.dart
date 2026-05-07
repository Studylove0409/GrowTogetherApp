import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock/mock_store.dart';
import '../../data/models/plan.dart';
import '../../shared/utils/plan_icon_mapper.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_button.dart';

class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({
    super.key,
    this.defaultOwner = PlanOwner.me,
    this.existingPlan,
  });

  final PlanOwner defaultOwner;
  final Plan? existingPlan;

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  late PlanOwner _owner;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedIconKey = PlanIconMapper.defaultKey;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _dailyRepeat = true;

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;
    if (plan != null) {
      _owner = plan.owner;
      _nameController.text = plan.title;
      _descriptionController.text = plan.dailyTask;
      _selectedIconKey = plan.iconKey;
      _reminderTime = plan.reminderTime;
      _startDate = plan.startDate;
      _endDate = plan.endDate;
    } else {
      _owner = widget.defaultOwner == PlanOwner.partner
          ? PlanOwner.me
          : widget.defaultOwner;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingPlan != null ? '编辑计划' : '创建计划',
          style: AppTextStyles.section,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            168,
          ),
          children: [
            _OwnerSelector(
              selected: _owner,
              onChanged: (owner) => setState(() => _owner = owner),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PlanIconPicker(
              selectedKey: _selectedIconKey,
              onChanged: (key) => setState(() => _selectedIconKey = key),
              onCustomIconSaved: (key) =>
                  setState(() => _selectedIconKey = key),
            ),
            const SizedBox(height: AppSpacing.md),
            _FormField(
              label: '计划名称',
              hint: '一起早起打卡',
              controller: _nameController,
            ),
            const SizedBox(height: AppSpacing.md),
            _FormField(
              label: '计划说明',
              hint: '简单描述你的计划，给自己和 TA 一点动力～',
              controller: _descriptionController,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            _DateTimeField(
              label: '提醒时间',
              value: _reminderTime.format(context),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime,
                );
                if (picked != null) {
                  setState(() => _reminderTime = picked);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _DateTimeField(
              label: '开始日期',
              value:
                  '${_startDate.year}年${_startDate.month}月${_startDate.day}日',
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                  if (_endDate.isBefore(_startDate)) {
                    _endDate = _startDate.add(const Duration(days: 30));
                  }
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _DateTimeField(
              label: '结束日期',
              value: '${_endDate.year}年${_endDate.month}月${_endDate.day}日',
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: _startDate,
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _endDate = picked);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              borderRadius: 28,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '每日重复',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _dailyRepeat,
                    activeColor: AppColors.deepPink,
                    onChanged: (value) => setState(() => _dailyRepeat = value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: PrimaryButton(
            label: widget.existingPlan != null ? '保存修改' : '保存计划',
            icon: Icons.save_rounded,
            onPressed: _savePlan,
          ),
        ),
      ),
    );
  }

  void _savePlan() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      _showError('请输入计划名称');
      return;
    }

    final existing = widget.existingPlan;
    if (existing != null) {
      MockStore.instance.updatePlan(
        planId: existing.id,
        title: name,
        dailyTask: description.isEmpty ? name : description,
        iconKey: _selectedIconKey,
        reminderTime: _reminderTime,
        startDate: _startDate,
        endDate: _endDate,
      );
    } else {
      MockStore.instance.createPlan(
        title: name,
        owner: _owner,
        dailyTask: description.isEmpty ? name : description,
        startDate: _startDate,
        endDate: _endDate,
        reminderTime: _reminderTime,
        iconKey: _selectedIconKey,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing != null ? '计划已更新' : '计划已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

// ========================= 图标选择器 =========================

class _PlanIconPicker extends StatelessWidget {
  const _PlanIconPicker({
    required this.selectedKey,
    required this.onChanged,
    required this.onCustomIconSaved,
  });

  final String selectedKey;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCustomIconSaved;

  @override
  Widget build(BuildContext context) {
    final allOptions = PlanIconMapper.options;

    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择图标',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              const crossAxisCount = 4;
              final itemWidth =
                  (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;

              return Wrap(
                spacing: spacing,
                runSpacing: 8,
                children: [
                  // 预设 + 自定义图标
                  for (final option in allOptions)
                    _PlanIconChoice(
                      option: option,
                      selected: selectedKey == option.key,
                      onTap: () => onChanged(option.key),
                      width: itemWidth,
                    ),
                  // "+ 自定义" 入口
                  _AddCustomEntry(
                    width: itemWidth,
                    onTap: () => _openCustomIconSheet(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _openCustomIconSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomIconSheet(
        onSaved: (key) {
          onCustomIconSaved(key);
        },
      ),
    );
  }
}

// ========================= 单个图标选项 =========================

class _PlanIconChoice extends StatelessWidget {
  const _PlanIconChoice({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.width,
  });

  final PlanIconOption option;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: Tooltip(
        message: option.label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.lightPink.withValues(alpha: 0.78)
                  : option.backgroundColor.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AppColors.deepPink
                    : Colors.white.withValues(alpha: 0.72),
                width: selected ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepPink.withValues(
                    alpha: selected ? 0.14 : 0.06,
                  ),
                  blurRadius: selected ? 12 : 8,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  option.icon,
                  size: 22,
                  color: selected
                      ? AppColors.deepPink
                      : option.color.withValues(alpha: 0.62),
                ),
                const SizedBox(height: 4),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? AppColors.deepPink
                        : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================= "+ 自定义" 入口 =========================

class _AddCustomEntry extends StatelessWidget {
  const _AddCustomEntry({required this.width, required this.onTap});

  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.cream.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.line,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.lightPink.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: AppColors.deepPink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '自定义',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.deepPink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================= 自定义图标 BottomSheet =========================

class _CustomIconSheet extends StatefulWidget {
  const _CustomIconSheet({required this.onSaved});

  final ValueChanged<String> onSaved;

  @override
  State<_CustomIconSheet> createState() => _CustomIconSheetState();
}

class _CustomIconSheetState extends State<_CustomIconSheet> {
  final _nameController = TextEditingController();
  String _selectedStyleKey = PlanIconMapper.customIconStyles.first.key;
  String _selectedColorKey = PlanIconMapper.customIconColors.first.key;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18FF6F96),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题
            Text(
              '自定义图标',
              style: AppTextStyles.title.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 图标名称输入框
            _SheetSectionLabel(label: '图标名称'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '请输入名称，例如：考研、存钱、编程',
                  hintStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.mutedText,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 图标样式选择区
            _SheetSectionLabel(label: '图标样式'),
            const SizedBox(height: AppSpacing.sm),
            _StyleGrid(
              selectedKey: _selectedStyleKey,
              onChanged: (key) => setState(() => _selectedStyleKey = key),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 颜色选择区
            _SheetSectionLabel(label: '颜色'),
            const SizedBox(height: AppSpacing.sm),
            _ColorRow(
              selectedKey: _selectedColorKey,
              onChanged: (key) => setState(() => _selectedColorKey = key),
            ),
            const SizedBox(height: AppSpacing.xl),
            // 保存按钮
            PrimaryButton(
              label: '保存自定义图标',
              icon: Icons.save_rounded,
              onPressed: _saveCustomIcon,
            ),
          ],
        ),
      ),
    );
  }

  void _saveCustomIcon() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入图标名称'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final style = PlanIconMapper.customIconStyles.firstWhere(
      (s) => s.key == _selectedStyleKey,
    );
    final color = PlanIconMapper.customIconColors.firstWhere(
      (c) => c.key == _selectedColorKey,
    );

    final newKey = PlanIconMapper.addCustomOption(
      label: name,
      icon: style.icon,
      color: color.color,
      backgroundColor: color.backgroundColor,
    );

    widget.onSaved(newKey);
    Navigator.of(context).pop();
  }
}

// ========================= BottomSheet 辅助组件 =========================

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.secondaryText,
      ),
    );
  }
}

class _StyleGrid extends StatelessWidget {
  const _StyleGrid({required this.selectedKey, required this.onChanged});

  final String selectedKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final styles = PlanIconMapper.customIconStyles;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const crossAxisCount = 4;
        final itemWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          children: [
            for (final style in styles)
              GestureDetector(
                onTap: () => onChanged(style.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: itemWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selectedKey == style.key
                        ? AppColors.lightPink.withValues(alpha: 0.72)
                        : Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selectedKey == style.key
                          ? AppColors.deepPink
                          : Colors.white.withValues(alpha: 0.72),
                      width: selectedKey == style.key ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        style.icon,
                        size: 24,
                        color: selectedKey == style.key
                            ? AppColors.deepPink
                            : AppColors.secondaryText,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        style.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: selectedKey == style.key
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selectedKey == style.key
                              ? AppColors.deepPink
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.selectedKey, required this.onChanged});

  final String selectedKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = PlanIconMapper.customIconColors;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onChanged(c.key),
            child: SizedBox(
              width: 48,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.color,
                      shape: BoxShape.circle,
                      boxShadow: selectedKey == c.key
                          ? [
                              BoxShadow(
                                color: c.color.withValues(alpha: 0.36),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: selectedKey == c.key
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: selectedKey == c.key
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: selectedKey == c.key
                          ? AppColors.deepPink
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ========================= 页面辅助组件 =========================

class _OwnerSelector extends StatelessWidget {
  const _OwnerSelector({required this.selected, required this.onChanged});

  final PlanOwner selected;
  final ValueChanged<PlanOwner> onChanged;

  @override
  Widget build(BuildContext context) {
    const creatableOwners = [PlanOwner.me, PlanOwner.together];

    return Row(
      children: [
        for (final owner in creatableOwners) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(owner),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == owner
                      ? AppColors.lightPink.withValues(alpha: 0.64)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _ownerLabel(owner),
                  style: AppTextStyles.body.copyWith(
                    color: selected == owner
                        ? AppColors.deepPink
                        : AppColors.secondaryText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          if (owner != creatableOwners.last) const SizedBox(width: 4),
        ],
      ],
    );
  }

  String _ownerLabel(PlanOwner owner) {
    return switch (owner) {
      PlanOwner.me => '我的计划',
      PlanOwner.partner => 'TA 的计划',
      PlanOwner.together => '共同计划',
    };
  }
}

class _FormField extends StatefulWidget {
  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() => _focused = _focusNode.hasFocus);
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _focused
                  ? AppColors.cream.withValues(alpha: 0.88)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                bottom: BorderSide(
                  color: _focused
                      ? AppColors.primary.withValues(alpha: 0.62)
                      : AppColors.line.withValues(alpha: 0.38),
                  width: _focused ? 1.2 : 1,
                ),
              ),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              maxLines: widget.maxLines,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.caption.copyWith(
                  color: AppColors.mutedText,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                isDense: true,
              ),
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: AppColors.deepPink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.deepPink,
            size: 22,
          ),
        ],
      ),
    );
  }
}
