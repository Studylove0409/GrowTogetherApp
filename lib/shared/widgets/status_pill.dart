import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StatusPill extends StatefulWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
    this.onTap,
    this.tooltip,
    this.semanticsLabel,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;
  final VoidCallback? onTap;
  final String? tooltip;
  final String? semanticsLabel;

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _celebrationController.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 10 : 12,
        vertical: widget.compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.18),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size: widget.compact ? 14 : 16,
              color: widget.color,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            widget.label,
            style: TextStyle(
              color: widget.color,
              fontSize: widget.compact ? 12 : 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );

    final animatedPill = AnimatedBuilder(
      animation: _celebrationController,
      child: pill,
      builder: (context, child) {
        final value = _celebrationController.value;
        final pulse = math.sin(value * math.pi).clamp(0.0, 1.0).toDouble();
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(scale: 1 + pulse * 0.08, child: child),
            if (_celebrationController.isAnimating)
              ..._CelebrationParticle.presets.map(
                (particle) => _CelebrationParticleView(
                  particle: particle,
                  progress: value,
                ),
              ),
          ],
        );
      },
    );

    final tap = widget.onTap;
    if (tap == null) return animatedPill;

    return Tooltip(
      message: widget.tooltip ?? widget.label,
      child: Semantics(
        button: true,
        label: widget.semanticsLabel ?? widget.label,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: _handleTap,
            splashColor: widget.color.withValues(alpha: 0.14),
            highlightColor: widget.color.withValues(alpha: 0.08),
            child: animatedPill,
          ),
        ),
      ),
    );
  }
}

class _CelebrationParticle {
  const _CelebrationParticle({
    required this.angle,
    required this.distance,
    required this.icon,
    required this.color,
    required this.size,
    required this.delay,
  });

  final double angle;
  final double distance;
  final IconData icon;
  final Color color;
  final double size;
  final double delay;

  static const presets = [
    _CelebrationParticle(
      angle: -2.76,
      distance: 38,
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF6F9F),
      size: 12,
      delay: 0.00,
    ),
    _CelebrationParticle(
      angle: -2.18,
      distance: 44,
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFFC857),
      size: 13,
      delay: 0.04,
    ),
    _CelebrationParticle(
      angle: -1.55,
      distance: 34,
      icon: Icons.star_rounded,
      color: Color(0xFFFF8FAB),
      size: 11,
      delay: 0.02,
    ),
    _CelebrationParticle(
      angle: -0.92,
      distance: 46,
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF6F9F),
      size: 10,
      delay: 0.08,
    ),
    _CelebrationParticle(
      angle: -0.24,
      distance: 39,
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFFC857),
      size: 12,
      delay: 0.03,
    ),
    _CelebrationParticle(
      angle: 0.34,
      distance: 42,
      icon: Icons.star_rounded,
      color: Color(0xFF4FAE67),
      size: 10,
      delay: 0.07,
    ),
    _CelebrationParticle(
      angle: 1.05,
      distance: 38,
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF8FAB),
      size: 11,
      delay: 0.00,
    ),
    _CelebrationParticle(
      angle: 1.88,
      distance: 33,
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFFC857),
      size: 10,
      delay: 0.05,
    ),
  ];
}

class _CelebrationParticleView extends StatelessWidget {
  const _CelebrationParticleView({
    required this.particle,
    required this.progress,
  });

  final _CelebrationParticle particle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final raw = ((progress - particle.delay) / (1 - particle.delay))
        .clamp(0.0, 1.0)
        .toDouble();
    final travel = Curves.easeOutCubic.transform(raw);
    final fade = raw < 0.42 ? raw / 0.42 : (1 - raw) / 0.58;
    final opacity = fade.clamp(0.0, 1.0).toDouble();
    final offset = Offset(
      math.cos(particle.angle) * particle.distance * travel,
      math.sin(particle.angle) * particle.distance * travel,
    );

    return IgnorePointer(
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: particle.angle * 0.18 + progress * math.pi * 0.55,
          child: Opacity(
            opacity: opacity,
            child: Icon(
              particle.icon,
              size: particle.size * (0.72 + travel * 0.48),
              color: particle.color,
            ),
          ),
        ),
      ),
    );
  }
}
