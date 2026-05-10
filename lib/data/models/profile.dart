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
  });

  final String name;
  final String partnerName;
  final int togetherDays;
  final String inviteCode;
  final bool isBound;
  final String? avatarUrl;
  final String? partnerAvatarUrl;
  final DateTime? anniversaryDate;
}
