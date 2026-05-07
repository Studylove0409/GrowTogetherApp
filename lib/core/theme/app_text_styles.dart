import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const String? fontFamily = null;

  static const display = TextStyle(
    fontSize: 32,
    height: 1.18,
    fontWeight: FontWeight.w900,
    color: AppColors.text,
    letterSpacing: 0,
    fontFamilyFallback: [
      'PingFang SC',
      'Hiragino Sans GB',
      'Microsoft YaHei',
      'sans-serif',
    ],
  );

  static const title = TextStyle(
    fontSize: 23,
    height: 1.25,
    fontWeight: FontWeight.w900,
    color: AppColors.text,
    letterSpacing: 0,
    fontFamilyFallback: [
      'PingFang SC',
      'Hiragino Sans GB',
      'Microsoft YaHei',
      'sans-serif',
    ],
  );

  static const section = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
    letterSpacing: 0,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
    letterSpacing: 0,
  );

  static const caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    letterSpacing: 0,
  );

  static const tiny = TextStyle(
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.mutedText,
    letterSpacing: 0,
  );
}
