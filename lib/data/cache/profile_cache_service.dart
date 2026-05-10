import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

class ProfileCacheSnapshot {
  const ProfileCacheSnapshot({required this.cachedAt, required this.profile});

  final DateTime cachedAt;
  final Profile profile;
}

class ProfileCacheService {
  const ProfileCacheService();

  static const _schemaVersion = 1;
  static const _keyPrefix = 'grow_together.profile_cache.v1';

  Future<ProfileCacheSnapshot?> readProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyForUser(userId));
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['version'] != _schemaVersion) return null;

      final profileJson = decoded['profile'];
      if (profileJson is! Map<String, dynamic>) return null;

      final profile = _profileFromJson(profileJson);
      if (profile == null) return null;

      return ProfileCacheSnapshot(
        cachedAt:
            _tryParseDateTime(decoded['cachedAt'] as String?) ?? DateTime.now(),
        profile: profile,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProfile(String userId, Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'version': _schemaVersion,
      'cachedAt': DateTime.now().toIso8601String(),
      'profile': _profileToJson(profile),
    };
    await prefs.setString(_keyForUser(userId), jsonEncode(payload));
  }

  String _keyForUser(String userId) => '$_keyPrefix.$userId';

  Map<String, dynamic> _profileToJson(Profile profile) {
    return {
      'name': profile.name,
      'partnerName': profile.partnerName,
      'togetherDays': profile.togetherDays,
      'inviteCode': profile.inviteCode,
      'isBound': profile.isBound,
      'avatarUrl': profile.avatarUrl,
      'partnerAvatarUrl': profile.partnerAvatarUrl,
      'anniversaryDate': profile.anniversaryDate?.toIso8601String(),
      'currentUserId': profile.currentUserId,
      'partnerUserId': profile.partnerUserId,
      'coupleSpaceId': profile.coupleSpaceId,
      'avatarPath': profile.avatarPath,
      'partnerAvatarPath': profile.partnerAvatarPath,
      'profileUpdatedAt': profile.profileUpdatedAt?.toIso8601String(),
      'partnerProfileUpdatedAt': profile.partnerProfileUpdatedAt
          ?.toIso8601String(),
    };
  }

  Profile? _profileFromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final partnerName = json['partnerName'] as String?;
    final inviteCode = json['inviteCode'] as String?;
    final isBound = json['isBound'] as bool?;
    if (name == null ||
        partnerName == null ||
        inviteCode == null ||
        isBound == null) {
      return null;
    }

    return Profile(
      name: name,
      partnerName: partnerName,
      togetherDays: _intValue(json['togetherDays']),
      inviteCode: inviteCode,
      isBound: isBound,
      avatarUrl: json['avatarUrl'] as String?,
      partnerAvatarUrl: json['partnerAvatarUrl'] as String?,
      anniversaryDate: _tryParseDateTime(json['anniversaryDate'] as String?),
      currentUserId: json['currentUserId'] as String?,
      partnerUserId: json['partnerUserId'] as String?,
      coupleSpaceId: json['coupleSpaceId'] as String?,
      avatarPath: json['avatarPath'] as String?,
      partnerAvatarPath: json['partnerAvatarPath'] as String?,
      profileUpdatedAt: _tryParseDateTime(json['profileUpdatedAt'] as String?),
      partnerProfileUpdatedAt: _tryParseDateTime(
        json['partnerProfileUpdatedAt'] as String?,
      ),
    );
  }

  DateTime? _tryParseDateTime(String? input) {
    if (input == null || input.isEmpty) return null;
    return DateTime.tryParse(input);
  }

  int _intValue(Object? input) {
    if (input is int) return input;
    if (input is num) return input.toInt();
    return 0;
  }
}
