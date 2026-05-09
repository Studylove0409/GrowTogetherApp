import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/focus_session.dart';
import '../models/plan.dart';

class FocusSessionRepository {
  const FocusSessionRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<List<FocusSession>> fetchFocusSessions() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    final coupleId = await _activeCoupleId();
    if (coupleId == null) return [];

    final rows = await _supabase
        .from('focus_sessions')
        .select('*')
        .eq('couple_id', coupleId)
        .order('created_at', ascending: false)
        .limit(80);

    return rows.map((row) => _rowToFocusSession(row, currentUserId)).toList();
  }

  Future<FocusSession> createCoupleInvite({
    required Plan plan,
    required int plannedDurationMinutes,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw const AuthException('authentication required');
    }

    final row = await _supabase.rpc(
      'create_focus_invite',
      params: {
        'p_plan_id': plan.id,
        'p_planned_duration_minutes': plannedDurationMinutes,
      },
    );

    return _rowToFocusSession(_asRow(row), currentUserId);
  }

  Future<FocusSession?> joinSession(String sessionId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return null;

    final row = await _supabase.rpc(
      'join_focus_session',
      params: {'p_session_id': sessionId},
    );
    return _rowToFocusSession(_asRow(row), currentUserId);
  }

  Future<FocusSession?> startSessionNow(String sessionId) async {
    return _rpcSession('start_focus_session', sessionId);
  }

  Future<FocusSession?> pauseSession(String sessionId) async {
    return _rpcSession('pause_focus_session', sessionId);
  }

  Future<FocusSession?> resumeSession(FocusSession session) async {
    return _rpcSession('resume_focus_session', session.id);
  }

  Future<FocusSession?> finishSession({
    required String sessionId,
    required FocusSessionStatus status,
    required int actualDurationSeconds,
    required int scoreDelta,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return null;

    final row = await _supabase.rpc(
      'finish_focus_session',
      params: {'p_session_id': sessionId, 'p_status': _fromStatus(status)},
    );
    return _rowToFocusSession(_asRow(row), currentUserId);
  }

  Future<FocusSession?> insertCompletedSession(FocusSession session) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return null;

    final row = await _supabase.rpc(
      'create_completed_focus_session',
      params: {
        'p_plan_id': session.planId,
        'p_mode': _fromMode(session.mode),
        'p_planned_duration_minutes': session.plannedDurationMinutes,
        'p_actual_duration_seconds': session.actualDurationSeconds,
        'p_started_at': session.startedAt?.toUtc().toIso8601String(),
        'p_ended_at': session.endedAt?.toUtc().toIso8601String(),
        'p_status': _fromStatus(session.status),
      },
    );

    return _rowToFocusSession(_asRow(row), currentUserId);
  }

  Future<FocusSession?> _rpcSession(String fn, String sessionId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return null;

    final row = await _supabase.rpc(fn, params: {'p_session_id': sessionId});
    return _rowToFocusSession(_asRow(row), currentUserId);
  }

  FocusSession _rowToFocusSession(
    Map<String, dynamic> row,
    String currentUserId,
  ) {
    final creatorUserId = row['created_by_user_id'] as String?;
    return FocusSession(
      id: row['id'] as String,
      planId: row['plan_id'] as String,
      planTitle: row['plan_title'] as String? ?? '专注计划',
      mode: _toMode(row['mode'] as String?),
      plannedDurationMinutes: row['planned_duration_minutes'] as int? ?? 25,
      actualDurationSeconds: row['actual_duration_seconds'] as int? ?? 0,
      status: _toStatus(row['status'] as String?),
      scoreDelta: row['score_delta'] as int? ?? 0,
      startedAt: _toDateTime(row['started_at']),
      endedAt: _toDateTime(row['ended_at']),
      creatorUserId: creatorUserId,
      sentByMe: creatorUserId == currentUserId,
      partnerJoinedAt: _toDateTime(row['partner_joined_at']),
      pausedAt: _toDateTime(row['paused_at']),
      totalPausedSeconds: row['total_paused_seconds'] as int? ?? 0,
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
    );
  }

  FocusMode _toMode(String? mode) => switch (mode) {
    'couple' => FocusMode.couple,
    _ => FocusMode.solo,
  };

  String _fromMode(FocusMode mode) => switch (mode) {
    FocusMode.solo => 'solo',
    FocusMode.couple => 'couple',
  };

  FocusSessionStatus _toStatus(String? status) => switch (status) {
    'waiting' => FocusSessionStatus.waiting,
    'running' => FocusSessionStatus.running,
    'paused' => FocusSessionStatus.paused,
    'cancelled' => FocusSessionStatus.cancelled,
    'interrupted' => FocusSessionStatus.interrupted,
    _ => FocusSessionStatus.completed,
  };

  String _fromStatus(FocusSessionStatus status) => switch (status) {
    FocusSessionStatus.waiting => 'waiting',
    FocusSessionStatus.running => 'running',
    FocusSessionStatus.paused => 'paused',
    FocusSessionStatus.completed => 'completed',
    FocusSessionStatus.cancelled => 'cancelled',
    FocusSessionStatus.interrupted => 'interrupted',
  };

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String)?.toLocal();
  }

  Map<String, dynamic> _asRow(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw StateError('Unexpected focus session RPC response: $value');
  }

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<String?> _activeCoupleId() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return null;

    final data = await _supabase
        .from('couples')
        .select('id')
        .eq('status', 'active')
        .or('user_a_id.eq.$currentUserId,user_b_id.eq.$currentUserId')
        .maybeSingle();
    return data?['id'] as String?;
  }
}
