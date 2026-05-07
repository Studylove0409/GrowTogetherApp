import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 54,
    this.iconSize,
    this.borderRadius,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.20),
            AppColors.paper.withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius ?? size * 0.38),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.86),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color == AppColors.success ? AppColors.successText : color,
        size: iconSize ?? size * 0.45,
      ),
    );
  }
}
