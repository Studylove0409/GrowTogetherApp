import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

class StickerAsset extends StatelessWidget {
  const StickerAsset({
    super.key,
    required this.assetPath,
    required this.placeholderIcon,
    this.width,
    this.height,
    this.borderRadius = 28,
    this.backgroundColor,
  });

  final String assetPath;
  final IconData placeholderIcon;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ByteData?>(
      future: _tryLoad(assetPath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.asset(
            assetPath,
            width: width,
            height: height,
            fit: BoxFit.contain,
          );
        }

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color:
                backgroundColor ?? AppColors.lightPink.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            placeholderIcon,
            color: AppColors.deepPink,
            size: ((width ?? height ?? 72) * 0.42).clamp(24, 54),
          ),
        );
      },
    );
  }
}

Future<ByteData?> _tryLoad(String assetPath) async {
  try {
    return await rootBundle.load(assetPath);
  } on FlutterError {
    return null;
  }
}
