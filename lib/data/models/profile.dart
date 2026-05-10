class Profile {
  const Profile({
    required this.name,
    required this.partnerName,
    required this.togetherDays,
    required this.inviteCode,
    required this.isBound,
    this.avatarUrl,
    this.partnerAvatarUrl,
    this.anniversaryDate,
    this.currentUserId,
    this.partnerUserId,
    this.coupleSpaceId,
    this.avatarPath,
    this.partnerAvatarPath,
    this.profileUpdatedAt,
    this.partnerProfileUpdatedAt,
  });

  final String name;
  final String partnerName;
  final int togetherDays;
  final String inviteCode;
  final bool isBound;
  final String? avatarUrl;
  final String? partnerAvatarUrl;
  final DateTime? anniversaryDate;
  final String? currentUserId;
  final String? partnerUserId;
  final String? coupleSpaceId;
  final String? avatarPath;
  final String? partnerAvatarPath;
  final DateTime? profileUpdatedAt;
  final DateTime? partnerProfileUpdatedAt;

  Profile copyWith({
    String? name,
    String? partnerName,
    int? togetherDays,
    String? inviteCode,
    bool? isBound,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? partnerAvatarUrl,
    bool clearPartnerAvatarUrl = false,
    DateTime? anniversaryDate,
    bool clearAnniversaryDate = false,
    String? currentUserId,
    String? partnerUserId,
    bool clearPartnerUserId = false,
    String? coupleSpaceId,
    bool clearCoupleSpaceId = false,
    String? avatarPath,
    bool clearAvatarPath = false,
    String? partnerAvatarPath,
    bool clearPartnerAvatarPath = false,
    DateTime? profileUpdatedAt,
    DateTime? partnerProfileUpdatedAt,
    bool clearPartnerProfileUpdatedAt = false,
  }) {
    return Profile(
      name: name ?? this.name,
      partnerName: partnerName ?? this.partnerName,
      togetherDays: togetherDays ?? this.togetherDays,
      inviteCode: inviteCode ?? this.inviteCode,
      isBound: isBound ?? this.isBound,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      partnerAvatarUrl: clearPartnerAvatarUrl
          ? null
          : (partnerAvatarUrl ?? this.partnerAvatarUrl),
      anniversaryDate: clearAnniversaryDate
          ? null
          : (anniversaryDate ?? this.anniversaryDate),
      currentUserId: currentUserId ?? this.currentUserId,
      partnerUserId: clearPartnerUserId
          ? null
          : (partnerUserId ?? this.partnerUserId),
      coupleSpaceId: clearCoupleSpaceId
          ? null
          : (coupleSpaceId ?? this.coupleSpaceId),
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
      partnerAvatarPath: clearPartnerAvatarPath
          ? null
          : (partnerAvatarPath ?? this.partnerAvatarPath),
      profileUpdatedAt: profileUpdatedAt ?? this.profileUpdatedAt,
      partnerProfileUpdatedAt: clearPartnerProfileUpdatedAt
          ? null
          : (partnerProfileUpdatedAt ?? this.partnerProfileUpdatedAt),
    );
  }
}
