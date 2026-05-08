import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/couple_invitation.dart';
import '../models/profile.dart';

class ProfileRepository {
  const ProfileRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<Profile> getCurrentProfile() async {
    final response = await _supabase.rpc(
      'create_profile_for_current_user',
      params: {'p_nickname': '一起进步的你'},
    );
    final data = _responseRow(response);
    final userId = data['user_id'] as String;
    final couple = await _activeCoupleFor(userId);

    if (couple == null) {
      return Profile(
        name: data['nickname'] as String? ?? '一起进步的你',
        partnerName: '还没有绑定 TA',
        togetherDays: 0,
        inviteCode: data['invite_code'] as String? ?? '',
        isBound: false,
      );
    }

    final partnerId = couple['user_a_id'] == userId
        ? couple['user_b_id'] as String
        : couple['user_a_id'] as String;
    final partnerProfile = await _supabase
        .from('profiles')
        .select('nickname')
        .eq('user_id', partnerId)
        .maybeSingle();

    return Profile(
      name: data['nickname'] as String? ?? '一起进步的你',
      partnerName: partnerProfile?['nickname'] as String? ?? '你的另一半',
      togetherDays: _daysSince(couple['created_at'] as String?),
      inviteCode: data['invite_code'] as String? ?? '',
      isBound: true,
    );
  }

  Future<List<CoupleInvitation>> getPendingIncomingCoupleInvitations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    final rows = await _supabase
        .from('couple_invitations')
        .select('id, from_user_id, created_at')
        .eq('to_user_id', userId)
        .eq('status', 'pending')
        .order('created_at');

    return rows
        .map(
          (row) => CoupleInvitation(
            id: row['id'] as String,
            fromUserId: row['from_user_id'] as String,
            createdAt:
                DateTime.tryParse(
                  row['created_at'] as String? ?? '',
                )?.toLocal() ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  Future<void> createCoupleInvitationByInviteCode(String inviteCode) async {
    await _supabase.rpc(
      'create_couple_invitation_by_invite_code',
      params: {'p_invite_code': inviteCode},
    );
  }

  Future<void> acceptCoupleInvitation(String invitationId) async {
    await _supabase.rpc(
      'accept_couple_invitation',
      params: {'p_invitation_id': invitationId},
    );
  }

  Future<void> declineCoupleInvitation(String invitationId) async {
    await _supabase.rpc(
      'decline_couple_invitation',
      params: {'p_invitation_id': invitationId},
    );
  }

  Future<void> endCurrentCoupleRelationship() async {
    await _supabase.rpc('end_current_couple_relationship');
  }

  Future<Map<String, dynamic>?> _activeCoupleFor(String userId) async {
    final data = await _supabase
        .from('couples')
        .select('user_a_id, user_b_id, created_at')
        .eq('status', 'active')
        .or('user_a_id.eq.$userId,user_b_id.eq.$userId')
        .maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Map<String, dynamic> _responseRow(Object? response) {
    if (response is List && response.isNotEmpty && response.first is Map) {
      return _responseRow(response.first);
    }

    if (response is Map) {
      final data = Map<String, dynamic>.from(response);
      if (data.containsKey('user_id')) {
        return data;
      }

      final nestedProfile = data['create_profile_for_current_user'];
      if (nestedProfile is Map) {
        return Map<String, dynamic>.from(nestedProfile);
      }

      final onlyValue = data.length == 1 ? data.values.first : null;
      if (onlyValue is Map) {
        return Map<String, dynamic>.from(onlyValue);
      }
    }

    throw const FormatException('Unexpected Supabase response shape.');
  }

  int _daysSince(String? isoDate) {
    if (isoDate == null) return 0;
    final createdAt = DateTime.tryParse(isoDate)?.toLocal();
    if (createdAt == null) return 0;
    final now = DateTime.now();
    final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays + 1;
  }
}
