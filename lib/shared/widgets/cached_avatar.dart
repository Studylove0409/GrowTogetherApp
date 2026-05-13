import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

String? avatarCacheKey({
  required String? imageUrl,
  required String? avatarPath,
  required String? userId,
  required DateTime? updatedAt,
}) {
  final path = avatarPath?.trim();
  if (path != null && path.isNotEmpty) {
    final version = updatedAt?.millisecondsSinceEpoch ?? 0;
    return 'avatar:$path:$version';
  }

  final url = imageUrl?.trim();
  if (url != null && url.isNotEmpty && !url.contains('token=')) {
    return 'avatar:url:$url';
  }

  final id = userId?.trim();
  if (id != null && id.isNotEmpty) return 'avatar:user:$id';
  return null;
}

class CachedAvatar extends StatefulWidget {
  const CachedAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
    this.cacheKey,
    this.label,
    this.icon = Icons.face_6_rounded,
    this.fadeDuration = const Duration(milliseconds: 220),
    this.clearAvatar = false,
  });

  final String? imageUrl;
  final String? cacheKey;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final String? label;
  final IconData icon;
  final Duration fadeDuration;
  final bool clearAvatar;

  @override
  State<CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<CachedAvatar> {
  String? _lastGoodImageUrl;
  String? _lastGoodCacheKey;

  @override
  void initState() {
    super.initState();
    _rememberCurrentAvatar();
  }

  @override
  void didUpdateWidget(covariant CachedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clearAvatar) {
      _lastGoodImageUrl = null;
      _lastGoodCacheKey = null;
      return;
    }
    _rememberCurrentAvatar();
  }

  void _rememberCurrentAvatar() {
    final url = widget.imageUrl?.trim();
    if (url == null || url.isEmpty) return;
    _lastGoodImageUrl = url;
    _lastGoodCacheKey = widget.cacheKey;
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.imageUrl?.trim();
    final url = widget.clearAvatar
        ? null
        : (currentUrl == null || currentUrl.isEmpty
              ? _lastGoodImageUrl
              : currentUrl);
    final cacheKey = widget.clearAvatar
        ? null
        : (currentUrl == null || currentUrl.isEmpty
              ? _lastGoodCacheKey
              : widget.cacheKey);
    final fallback = _SoftAvatarFallback(
      size: widget.size,
      backgroundColor: widget.backgroundColor,
      iconColor: widget.iconColor,
      label: widget.label,
      icon: widget.icon,
    );

    if (url == null || url.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKey,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      fadeInDuration: widget.fadeDuration,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _SoftAvatarFallback extends StatelessWidget {
  const _SoftAvatarFallback({
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
    required this.label,
    required this.icon,
  });

  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final String? label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final initial = _initialOf(label);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              backgroundColor.withValues(alpha: 0.96),
              AppColors.lavender.withValues(alpha: 0.34),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: initial == null
              ? Icon(
                  icon,
                  color: iconColor.withValues(alpha: 0.82),
                  size: size * 0.42,
                )
              : Text(
                  initial,
                  style: TextStyle(
                    color: iconColor.withValues(alpha: 0.88),
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }

  String? _initialOf(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.characters.first;
  }
}
