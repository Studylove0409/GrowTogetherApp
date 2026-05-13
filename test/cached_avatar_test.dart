import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grow_together/core/theme/app_colors.dart';
import 'package:grow_together/shared/widgets/cached_avatar.dart';

void main() {
  test('avatarCacheKey prefers stable avatar path and updated timestamp', () {
    final updatedAt = DateTime.utc(2026, 5, 10, 8);
    final key = avatarCacheKey(
      imageUrl: 'https://signed.example.com/avatar?token=abc',
      avatarPath: 'user-a/avatar.jpg',
      userId: 'user-a',
      updatedAt: updatedAt,
    );

    expect(key, 'avatar:user-a/avatar.jpg:${updatedAt.millisecondsSinceEpoch}');
  });

  test('avatarCacheKey avoids signed URL tokens when no path exists', () {
    final key = avatarCacheKey(
      imageUrl: 'https://signed.example.com/avatar?token=abc',
      avatarPath: null,
      userId: 'user-a',
      updatedAt: null,
    );

    expect(key, 'avatar:user:user-a');
  });

  test('avatarCacheKey can use stable public URLs', () {
    final key = avatarCacheKey(
      imageUrl: 'https://example.com/avatar.jpg',
      avatarPath: null,
      userId: null,
      updatedAt: null,
    );

    expect(key, 'avatar:url:https://example.com/avatar.jpg');
  });

  testWidgets('CachedAvatar keeps last non-empty avatar when rebuilt empty', (
    tester,
  ) async {
    Widget avatar(String? imageUrl) {
      return MaterialApp(
        home: Center(
          child: CachedAvatar(
            imageUrl: imageUrl,
            cacheKey: avatarCacheKey(
              imageUrl: imageUrl,
              avatarPath: 'user-a/avatar.jpg',
              userId: 'user-a',
              updatedAt: DateTime.utc(2026, 5, 10, 8),
            ),
            size: 48,
            backgroundColor: AppColors.lightPink,
            iconColor: AppColors.deepPink,
            label: '小鱼',
          ),
        ),
      );
    }

    await tester.pumpWidget(
      avatar('https://signed.example.com/avatar?token=a'),
    );
    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .imageUrl,
      'https://signed.example.com/avatar?token=a',
    );

    await tester.pumpWidget(avatar(null));
    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .imageUrl,
      'https://signed.example.com/avatar?token=a',
    );
  });

  testWidgets('CachedAvatar shows soft fallback when no avatar exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CachedAvatar(
            imageUrl: null,
            size: 48,
            backgroundColor: AppColors.lightPink,
            iconColor: AppColors.deepPink,
            label: '小鱼',
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('小'), findsOneWidget);
  });
}
