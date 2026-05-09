enum FocusMode { solo, couple }

enum FocusSessionStatus {
  waiting,
  running,
  paused,
  completed,
  cancelled,
  interrupted,
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.planId,
    required this.planTitle,
    required this.mode,
    required this.plannedDurationMinutes,
    required this.actualDurationSeconds,
    required this.status,
    required this.scoreDelta,
    this.startedAt,
    this.endedAt,
    this.creatorUserId,
    this.sentByMe = true,
    this.partnerJoinedAt,
    this.pausedAt,
    this.totalPausedSeconds = 0,
    required this.createdAt,
  });

  final String id;
  final String planId;
  final String planTitle;
  final FocusMode mode;
  final int plannedDurationMinutes;
  final int actualDurationSeconds;
  final FocusSessionStatus status;
  final int scoreDelta;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? creatorUserId;
  final bool sentByMe;
  final DateTime? partnerJoinedAt;
  final DateTime? pausedAt;
  final int totalPausedSeconds;
  final DateTime createdAt;

  bool get isCompleted => status == FocusSessionStatus.completed;

  bool get isActive =>
      status == FocusSessionStatus.waiting ||
      status == FocusSessionStatus.running ||
      status == FocusSessionStatus.paused;

  bool get canJoin =>
      mode == FocusMode.couple &&
      !sentByMe &&
      partnerJoinedAt == null &&
      (status == FocusSessionStatus.waiting ||
          status == FocusSessionStatus.running ||
          status == FocusSessionStatus.paused);

  int get actualDurationMinutes => (actualDurationSeconds / 60).ceil();

  bool isSameDay(DateTime date) {
    return createdAt.year == date.year &&
        createdAt.month == date.month &&
        createdAt.day == date.day;
  }

  FocusSession copyWith({
    String? id,
    String? planId,
    String? planTitle,
    FocusMode? mode,
    int? plannedDurationMinutes,
    int? actualDurationSeconds,
    FocusSessionStatus? status,
    int? scoreDelta,
    DateTime? startedAt,
    DateTime? endedAt,
    String? creatorUserId,
    bool? sentByMe,
    DateTime? partnerJoinedAt,
    DateTime? pausedAt,
    int? totalPausedSeconds,
    DateTime? createdAt,
    bool clearStartedAt = false,
    bool clearEndedAt = false,
    bool clearPartnerJoinedAt = false,
    bool clearPausedAt = false,
  }) {
    return FocusSession(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      planTitle: planTitle ?? this.planTitle,
      mode: mode ?? this.mode,
      plannedDurationMinutes:
          plannedDurationMinutes ?? this.plannedDurationMinutes,
      actualDurationSeconds:
          actualDurationSeconds ?? this.actualDurationSeconds,
      status: status ?? this.status,
      scoreDelta: scoreDelta ?? this.scoreDelta,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      creatorUserId: creatorUserId ?? this.creatorUserId,
      sentByMe: sentByMe ?? this.sentByMe,
      partnerJoinedAt: clearPartnerJoinedAt
          ? null
          : (partnerJoinedAt ?? this.partnerJoinedAt),
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      totalPausedSeconds: totalPausedSeconds ?? this.totalPausedSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

String focusModeLabel(FocusMode mode) => switch (mode) {
  FocusMode.solo => '自己专注',
  FocusMode.couple => '一起专注',
};

String focusSessionStatusLabel(FocusSessionStatus status) => switch (status) {
  FocusSessionStatus.waiting => '等待加入',
  FocusSessionStatus.running => '进行中',
  FocusSessionStatus.paused => '已暂停',
  FocusSessionStatus.completed => '已完成',
  FocusSessionStatus.cancelled => '已取消',
  FocusSessionStatus.interrupted => '提前结束',
};
