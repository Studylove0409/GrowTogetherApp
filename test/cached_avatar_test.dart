import 'package:flutter_test/flutter_test.dart';

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
}
