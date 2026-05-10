import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grow_together/data/cache/profile_cache_service.dart';
import 'package:grow_together/data/models/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ProfileCacheService round-trips profile and avatar metadata', () async {
    const service = ProfileCacheService();
    final profile = Profile(
      name: '小鱼',
      partnerName: '小熊',
      togetherDays: 12,
      inviteCode: 'LOVE2026',
      isBound: true,
      avatarUrl: 'https://example.com/me-signed',
      partnerAvatarUrl: 'https://example.com/ta-signed',
      anniversaryDate: DateTime(2026, 5, 1),
      currentUserId: 'user-a',
      partnerUserId: 'user-b',
      coupleSpaceId: 'couple-1',
      avatarPath: 'user-a/avatar.jpg',
      partnerAvatarPath: 'user-b/avatar.jpg',
      profileUpdatedAt: DateTime(2026, 5, 10, 8),
      partnerProfileUpdatedAt: DateTime(2026, 5, 10, 9),
    );

    await service.writeProfile('user-a', profile);
    final snapshot = await service.readProfile('user-a');

    expect(snapshot, isNotNull);
    final cached = snapshot!.profile;
    expect(cached.name, '小鱼');
    expect(cached.partnerName, '小熊');
    expect(cached.avatarUrl, 'https://example.com/me-signed');
    expect(cached.partnerAvatarUrl, 'https://example.com/ta-signed');
    expect(cached.avatarPath, 'user-a/avatar.jpg');
    expect(cached.partnerAvatarPath, 'user-b/avatar.jpg');
    expect(cached.profileUpdatedAt, DateTime(2026, 5, 10, 8));
    expect(cached.partnerProfileUpdatedAt, DateTime(2026, 5, 10, 9));
  });

  test('ProfileCacheService isolates users and ignores broken cache', () async {
    const service = ProfileCacheService();
    await service.writeProfile(
      'user-a',
      const Profile(
        name: '我',
        partnerName: 'TA',
        togetherDays: 1,
        inviteCode: 'A',
        isBound: false,
      ),
    );

    expect(await service.readProfile('user-a'), isNotNull);
    expect(await service.readProfile('user-b'), isNull);

    SharedPreferences.setMockInitialValues({
      'grow_together.profile_cache.v1.user-c': '{broken',
    });
    expect(await service.readProfile('user-c'), isNull);
  });
}
