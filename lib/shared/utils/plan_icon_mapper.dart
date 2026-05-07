import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PlanIconOption {
  const PlanIconOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.isCustom = false,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final bool isCustom;
}

/// 自定义图标创建时可选的基础图标样式。
class CustomIconStyle {
  const CustomIconStyle({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

/// 自定义图标可选的颜色。
class CustomIconColor {
  const CustomIconColor({
    required this.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String key;
  final String label;
  final Color color;
  final Color backgroundColor;
}

class PlanIconMapper {
  const PlanIconMapper._();

  static const defaultKey = 'book';

  // --------------- 预设图标（8 个常用图标） ---------------

  static const presetOptions = [
    PlanIconOption(
      key: 'book',
      label: '学习',
      icon: Icons.menu_book_rounded,
      color: AppColors.deepPink,
      backgroundColor: AppColors.lightPink,
    ),
    PlanIconOption(
      key: 'edit',
      label: '写作业',
      icon: Icons.edit_rounded,
      color: AppColors.deepPink,
      backgroundColor: AppColors.blush,
    ),
    PlanIconOption(
      key: 'sun',
      label: '早起',
      icon: Icons.wb_sunny_rounded,
      color: AppColors.reminder,
      backgroundColor: AppColors.peach,
    ),
    PlanIconOption(
      key: 'run',
      label: '运动',
      icon: Icons.directions_run_rounded,
      color: AppColors.successText,
      backgroundColor: AppColors.mint,
    ),
    PlanIconOption(
      key: 'walk',
      label: '散步',
      icon: Icons.directions_walk_rounded,
      color: AppColors.successText,
      backgroundColor: AppColors.mint,
    ),
    PlanIconOption(
      key: 'read',
      label: '阅读',
      icon: Icons.auto_stories_rounded,
      color: AppColors.deepPink,
      backgroundColor: AppColors.lightPink,
    ),
    PlanIconOption(
      key: 'music',
      label: '音乐',
      icon: Icons.music_note_rounded,
      color: AppColors.deepPink,
      backgroundColor: AppColors.blush,
    ),
    PlanIconOption(
      key: 'chat',
      label: '聊天',
      icon: Icons.chat_bubble_outline_rounded,
      color: AppColors.deepPink,
      backgroundColor: AppColors.lightPink,
    ),
  ];

  // --------------- 用户自定义图标 ---------------

  static final List<PlanIconOption> _customOptions = [];

  static List<PlanIconOption> get customOptions =>
      List.unmodifiable(_customOptions);

  /// 合并后的完整选项列表（预设 + 自定义）。
  static List<PlanIconOption> get options =>
      [...presetOptions, ..._customOptions];

  /// 添加一个自定义图标选项，返回新生成的 key。
  static String addCustomOption({
    required String label,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    final key = 'custom_${_customOptions.length}';
    _customOptions.add(PlanIconOption(
      key: key,
      label: label,
      icon: icon,
      color: color,
      backgroundColor: backgroundColor,
      isCustom: true,
    ));
    return key;
  }

  /// 根据 key 查找选项，找不到则返回第一个预设。
  static PlanIconOption optionOf(String? key) {
    for (final option in options) {
      if (option.key == key) {
        return option;
      }
    }
    return presetOptions.first;
  }

  // --------------- 查找方法 ---------------

  static IconData iconData(String? key) => optionOf(key).icon;

  static Color color(String? key) => optionOf(key).color;

  static Color backgroundColor(String? key) => optionOf(key).backgroundColor;

  static String label(String? key) => optionOf(key).label;

  // --------------- 自定义图标弹窗中的可选样式 ---------------

  static const customIconStyles = [
    CustomIconStyle(
      key: 'book',
      label: '书本',
      icon: Icons.menu_book_rounded,
    ),
    CustomIconStyle(
      key: 'star',
      label: '星星',
      icon: Icons.star_rounded,
    ),
    CustomIconStyle(
      key: 'heart',
      label: '爱心',
      icon: Icons.favorite_rounded,
    ),
    CustomIconStyle(
      key: 'fire',
      label: '火焰',
      icon: Icons.local_fire_department_rounded,
    ),
    CustomIconStyle(
      key: 'wallet',
      label: '钱包',
      icon: Icons.account_balance_wallet_rounded,
    ),
    CustomIconStyle(
      key: 'computer',
      label: '电脑',
      icon: Icons.computer_rounded,
    ),
    CustomIconStyle(
      key: 'goal',
      label: '目标',
      icon: Icons.flag_rounded,
    ),
    CustomIconStyle(
      key: 'fitness',
      label: '运动',
      icon: Icons.fitness_center_rounded,
    ),
    CustomIconStyle(
      key: 'moon',
      label: '月亮',
      icon: Icons.nightlight_rounded,
    ),
    CustomIconStyle(
      key: 'sun2',
      label: '太阳',
      icon: Icons.wb_sunny_rounded,
    ),
    CustomIconStyle(
      key: 'bell',
      label: '铃铛',
      icon: Icons.notifications_rounded,
    ),
    CustomIconStyle(
      key: 'music2',
      label: '音乐',
      icon: Icons.music_note_rounded,
    ),
  ];

  // --------------- 自定义图标弹窗中的可选颜色 ---------------

  static const customIconColors = [
    CustomIconColor(
      key: 'pink',
      label: '粉色',
      color: AppColors.deepPink,
      backgroundColor: AppColors.lightPink,
    ),
    CustomIconColor(
      key: 'green',
      label: '绿色',
      color: AppColors.successText,
      backgroundColor: AppColors.mint,
    ),
    CustomIconColor(
      key: 'purple',
      label: '紫色',
      color: Color(0xFF9B6FE8),
      backgroundColor: Color(0xFFF0E8FF),
    ),
    CustomIconColor(
      key: 'orange',
      label: '橙色',
      color: Color(0xFFFF8F6C),
      backgroundColor: Color(0xFFFFF0EB),
    ),
    CustomIconColor(
      key: 'blue',
      label: '蓝色',
      color: Color(0xFF6CA8FF),
      backgroundColor: Color(0xFFEBF4FF),
    ),
  ];
}
