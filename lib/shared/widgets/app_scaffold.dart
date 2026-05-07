import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 页面背景装饰层：渐变背景 + 软气泡。
/// 不再是一个 Scaffold —— 避免和 GrowTogetherShell 的外层 Scaffold 嵌套。
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _CreamBackground()),
        const _SoftBubble(top: 66, right: -24, size: 112, opacity: 0.24),
        const _SoftBubble(top: 182, left: -34, size: 92, opacity: 0.16),
        const _SoftBubble(bottom: 90, right: -42, size: 128, opacity: 0.18),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _CreamBackground extends StatelessWidget {
  const _CreamBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.background,
            AppColors.blush.withValues(alpha: 0.64),
            AppColors.cream,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _SoftBubble extends StatelessWidget {
  const _SoftBubble({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.opacity,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.lightPink.withValues(alpha: opacity),
                AppColors.lightPink.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
