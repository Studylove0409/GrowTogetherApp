import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.reminderBadgeCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int reminderBadgeCount;

  static const double height = 64;
  static const double bottomGap = 20;
  static const double horizontalMargin = 24;
  static const Color _dockBackground = Color(0xFFFFF4F8);
  static const Color _dockBorder = Color(0xFFFFD6E6);

  static const _items = [
    _BottomNavItem(
      label: '首页',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _BottomNavItem(
      label: '计划',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
    ),
    _BottomNavItem(
      label: '专注',
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer_rounded,
    ),
    _BottomNavItem(
      label: '提醒',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
    ),
    _BottomNavItem(
      label: '我的',
      icon: Icons.face_6_outlined,
      selectedIcon: Icons.face_6_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        elevation: 0,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _dockBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _dockBorder, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26FF5C93),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;

              return Row(
                children: [
                  for (var index = 0; index < _items.length; index++)
                    SizedBox(
                      width: itemWidth,
                      child: _BottomNavButton(
                        item: _items[index],
                        selected: selectedIndex == index,
                        badgeCount: index == 3 ? reminderBadgeCount : 0,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final _BottomNavItem item;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.deepPink
        : AppColors.secondaryText.withValues(alpha: 0.76);

    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: AppColors.lightPink.withValues(alpha: 0.34),
          highlightColor: AppColors.lightPink.withValues(alpha: 0.18),
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  scale: selected ? 1.08 : 1,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.lightPink.withValues(alpha: 0.95)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    blurRadius: 5,
                                    offset: const Offset(0, -1),
                                  ),
                                ]
                              : const [],
                        ),
                        child: Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: 22,
                          color: color,
                        ),
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          top: -2,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.deepPink,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              badgeCount > 99 ? '99+' : '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    height: 1,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: 0,
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
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

class _BottomNavItem {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
