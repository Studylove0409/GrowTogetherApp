import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    _BottomNavItem(
      label: '首页',
      icon: Icons.favorite_border_rounded,
      selectedIcon: Icons.favorite_rounded,
    ),
    _BottomNavItem(
      label: '计划',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
    ),
    _BottomNavItem(
      label: '提醒',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
    ),
    _BottomNavItem(
      label: '我的',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F1EE),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var index = 0; index < _items.length; index++)
            Expanded(
              child: _BottomNavButton(
                item: _items[index],
                selected: selectedIndex == index,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.deepPink : AppColors.secondaryText;

    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.lightPink.withValues(alpha: 0.72)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 23,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0,
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
