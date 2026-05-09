import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 页面背景装饰层：奶油纸张纹理 + 底部草地贴纸。
/// 不再是一个 Scaffold —— 避免和 GrowTogetherShell 的外层 Scaffold 嵌套。
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _CreamBackground()),
        const Positioned.fill(child: _PaperTexture()),
        const Positioned(left: 0, right: 0, bottom: 0, child: _GrassSticker()),
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
            AppColors.paperWarm.withValues(alpha: 0.70),
            AppColors.cream,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _PaperTexture extends StatelessWidget {
  const _PaperTexture();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _PaperTexturePainter()));
  }
}

class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = AppColors.paperLine.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (var y = 18.0; y < size.height; y += 26) {
      for (var x = 12.0; x < size.width; x += 34) {
        final jitter = ((x + y) % 11) - 5;
        canvas.drawCircle(Offset(x + jitter, y), 0.7, dotPaint);
      }
    }

    final fiberPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    for (var y = 36.0; y < size.height; y += 58) {
      canvas.drawLine(
        Offset(22, y),
        Offset(size.width - 22, y + ((y % 3) - 1) * 2),
        fiberPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GrassSticker extends StatelessWidget {
  const _GrassSticker();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.58,
        child: SizedBox(
          height: 74,
          child: CustomPaint(painter: _GrassPainter()),
        ),
      ),
    );
  }
}

class _GrassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final groundPaint = Paint()
      ..color = AppColors.grass.withValues(alpha: 0.82);
    final deepPaint = Paint()
      ..color = AppColors.grassDeep.withValues(alpha: 0.72)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final ground = Path()
      ..moveTo(0, size.height * 0.64)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.42,
        size.width * 0.5,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.74,
        size.width,
        size.height * 0.50,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ground, groundPaint);

    for (var x = 12.0; x < size.width; x += 24) {
      final baseY = size.height * (0.66 + ((x % 5) * 0.018));
      canvas.drawLine(Offset(x, baseY), Offset(x + 3, baseY - 13), deepPaint);
      canvas.drawLine(
        Offset(x + 8, baseY + 2),
        Offset(x + 2, baseY - 8),
        deepPaint,
      );
    }

    for (final x in [28.0, size.width - 48, size.width * 0.72]) {
      _drawFlower(canvas, Offset(x, size.height * 0.55));
    }
  }

  void _drawFlower(Canvas canvas, Offset center) {
    final petalPaint = Paint()
      ..color = AppColors.lightPink.withValues(alpha: 0.92);
    final centerPaint = Paint()..color = AppColors.flowerYellow;
    final stemPaint = Paint()
      ..color = AppColors.grassDeep
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + const Offset(0, 22),
      center + const Offset(0, 5),
      stemPaint,
    );
    for (final offset in const [
      Offset(-6, 0),
      Offset(6, 0),
      Offset(0, -6),
      Offset(0, 6),
    ]) {
      canvas.drawCircle(center + offset, 5, petalPaint);
    }
    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
