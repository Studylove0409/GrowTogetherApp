import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/plan.dart';
import '../../data/store/store.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/primary_button.dart';

enum _FocusStage { setup, waiting, running, result }

class FocusPage extends StatefulWidget {
  const FocusPage({super.key, this.isSelected = true});

  final bool isSelected;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> with WidgetsBindingObserver {
  static const _durationOptions = [25, 45, 60];
  static const _effectiveFocusSeconds = 5 * 60;
  static const _scorePerCompletedSession = 5;
  static const _visibleRefreshInterval = Duration(seconds: 4);

  _FocusStage _stage = _FocusStage.setup;
  Plan? _selectedPlan;
  int _selectedMinutes = 25;
  FocusMode _mode = FocusMode.solo;
  int _remainingSeconds = 25 * 60;
  int _actualDurationSeconds = 0;
  bool _paused = false;
  bool _finishing = false;
  bool _busy = false;
  DateTime? _startedAt;
  DateTime? _lastTickAt;
  Timer? _timer;
  FocusSession? _activeSession;
  FocusSession? _resultSession;
  bool _syncScheduled = false;
  bool _refreshInFlight = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateVisibleRefreshTimer();
      if (widget.isSelected) {
        unawaited(_refreshVisibleFocusData());
      }
    });
  }

  @override
  void didUpdateWidget(covariant FocusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateVisibleRefreshTimer();
    if (!oldWidget.isSelected && widget.isSelected) {
      unawaited(_refreshVisibleFocusData());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_stage != _FocusStage.running || _paused || _activeSession != null) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lastTickAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed && _lastTickAt != null) {
      final elapsed = DateTime.now().difference(_lastTickAt!).inSeconds;
      _lastTickAt = DateTime.now();
      if (elapsed > 0) _consumeSeconds(elapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.isSelected
        ? context.watch<Store>()
        : context.read<Store>();
    final plans = store
        .getPlans()
        .where((plan) => plan.canCurrentUserCheckin && !plan.isEnded)
        .toList();
    if (widget.isSelected) {
      _scheduleStoreSync(plans: plans, focusSessions: store.getFocusSessions());
    }

    return AppScaffold(
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_stage) {
            _FocusStage.setup => _FocusSetupView(
              key: const ValueKey('focus-setup'),
              plans: plans,
              selectedPlan: _selectedPlan,
              selectedMinutes: _selectedMinutes,
              durationOptions: _durationOptions,
              mode: _mode,
              sessions: store.getTodayFocusSessions(),
              busy: _busy,
              onSelectPlan: (plan) => setState(() => _selectedPlan = plan),
              onSelectDuration: _selectDuration,
              onCustomDuration: _showCustomDurationDialog,
              onSelectMode: (mode) => setState(() => _mode = mode),
              onStart: _selectedPlan == null
                  ? null
                  : () => unawaited(_startFocus()),
              onRefresh: _refreshVisibleFocusData,
            ),
            _FocusStage.waiting => _FocusWaitingView(
              key: const ValueKey('focus-waiting'),
              session: _activeSession,
              onStartNow: _startCoupleSessionNow,
              onCancel: () =>
                  unawaited(_finishSession(FocusSessionStatus.cancelled)),
            ),
            _FocusStage.running => _FocusRunningView(
              key: const ValueKey('focus-running'),
              planTitle: _selectedPlan?.title ?? '',
              mode: _mode,
              timeText: _formatSeconds(_remainingSeconds),
              progress: 1 - _remainingSeconds / (_selectedMinutes * 60),
              paused: _paused,
              partnerStateText: _partnerStateText,
              onTogglePause: _togglePause,
              onEndEarly: () => unawaited(_confirmEndEarly()),
            ),
            _FocusStage.result => _FocusResultView(
              key: const ValueKey('focus-result'),
              session: _resultSession,
              todaySessions: store.getTodayFocusSessions(),
              onAgain: _backToSetup,
            ),
          },
        ),
      ),
    );
  }

  void _scheduleStoreSync({
    required List<Plan> plans,
    required List<FocusSession> focusSessions,
  }) {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      _syncSelectedPlan(plans);
      _syncActiveSession(focusSessions, plans);
    });
  }

  void _syncSelectedPlan(List<Plan> plans) {
    final selected = _selectedPlan;
    if (selected == null) return;
    final latest = plans.where((plan) => plan.id == selected.id).firstOrNull;
    if (latest == null) {
      setState(() => _selectedPlan = null);
    } else if (!identical(latest, selected)) {
      setState(() => _selectedPlan = latest);
    }
  }

  void _syncActiveSession(List<FocusSession> focusSessions, List<Plan> plans) {
    final active = _activeSession;
    if (active == null) {
      _adoptExistingActiveSession(focusSessions, plans);
      return;
    }

    final latest = focusSessions
        .where((item) => item.id == active.id)
        .firstOrNull;
    if (latest == null) {
      if (_stage == _FocusStage.waiting || _stage == _FocusStage.running) {
        setState(() {
          _activeSession = null;
          _stage = _FocusStage.setup;
          _timer?.cancel();
          _timer = null;
          _paused = false;
          _finishing = false;
        });
      }
      return;
    }

    if (!latest.isActive) {
      _timer?.cancel();
      _timer = null;
      setState(() {
        _activeSession = null;
        _resultSession = latest;
        _stage = _FocusStage.result;
        _paused = false;
        _finishing = false;
        _lastTickAt = null;
      });
      return;
    }

    if (!identical(latest, active)) {
      setState(() => _activeSession = latest);
    }

    if (_stage == _FocusStage.waiting &&
        latest.status != FocusSessionStatus.waiting &&
        latest.startedAt != null) {
      final plan = plans.where((item) => item.id == latest.planId).firstOrNull;
      _beginSyncedRunning(latest, plan: plan);
    }
  }

  void _adoptExistingActiveSession(
    List<FocusSession> focusSessions,
    List<Plan> plans,
  ) {
    if (!widget.isSelected ||
        (_stage != _FocusStage.setup && _stage != _FocusStage.result)) {
      return;
    }

    final session = focusSessions
        .where(
          (session) =>
              session.isActive &&
              !session.canJoin &&
              (session.status != FocusSessionStatus.waiting ||
                  session.sentByMe),
        )
        .firstOrNull;
    if (session == null) return;

    final plan = plans.where((item) => item.id == session.planId).firstOrNull;
    if (session.status == FocusSessionStatus.waiting) {
      setState(() {
        _activeSession = session;
        _selectedPlan = plan ?? _selectedPlan;
        _selectedMinutes = session.plannedDurationMinutes;
        _mode = session.mode;
        _stage = _FocusStage.waiting;
        _remainingSeconds = session.plannedDurationMinutes * 60;
        _actualDurationSeconds = 0;
        _paused = false;
        _finishing = false;
        _resultSession = null;
      });
      return;
    }

    _beginSyncedRunning(session, plan: plan);
  }

  void _updateVisibleRefreshTimer() {
    if (!widget.isSelected) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }

    _refreshTimer ??= Timer.periodic(_visibleRefreshInterval, (_) {
      unawaited(_refreshVisibleFocusData());
    });
  }

  Future<void> _refreshVisibleFocusData() async {
    if (!mounted || !widget.isSelected || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      await context.read<Store>().refreshFocusSessions();
    } finally {
      _refreshInFlight = false;
    }
  }

  void _selectDuration(int minutes) {
    if (_stage == _FocusStage.running) return;
    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
    });
  }

  Future<void> _showCustomDurationDialog() async {
    if (_stage == _FocusStage.running) return;

    final minutes = await showDialog<int>(
      context: context,
      builder: (context) =>
          _CustomDurationDialog(initialMinutes: _selectedMinutes),
    );
    if (minutes == null || !mounted) return;
    _selectDuration(minutes);
  }

  Future<void> _startFocus() async {
    if (_selectedPlan == null) return;
    final plan = _selectedPlan!;

    if (_mode == FocusMode.couple) {
      await _runWithFeedback(() async {
        final session = await context.read<Store>().createCoupleFocusInvite(
          plan: plan,
          plannedDurationMinutes: _selectedMinutes,
        );
        if (!mounted) return;
        setState(() {
          _activeSession = session;
          _stage = _FocusStage.waiting;
          _remainingSeconds = _selectedMinutes * 60;
          _actualDurationSeconds = 0;
          _paused = false;
          _finishing = false;
          _startedAt = null;
          _lastTickAt = null;
          _resultSession = null;
        });
      });
      return;
    }

    _timer?.cancel();
    setState(() {
      _stage = _FocusStage.running;
      _remainingSeconds = _selectedMinutes * 60;
      _actualDurationSeconds = 0;
      _paused = false;
      _finishing = false;
      _startedAt = DateTime.now();
      _lastTickAt = DateTime.now();
      _resultSession = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused || _stage != _FocusStage.running) return;
      _consumeSeconds(1);
    });
  }

  Future<void> _confirmEndEarly() async {
    if (_stage != _FocusStage.running || _finishing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('提前结束专注？'),
        content: const Text('这次专注会保留记录；未满 5 分钟不会增加执行分。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续专注'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('提前结束'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _finishSession(FocusSessionStatus.interrupted);
    }
  }

  Future<void> _startCoupleSessionNow() async {
    final session = _activeSession;
    if (session == null) return;
    await _runWithFeedback(() async {
      final updated = await context.read<Store>().startFocusSessionNow(
        session.id,
      );
      if (!mounted || updated == null) return;
      _beginSyncedRunning(updated, plan: _selectedPlan);
    });
  }

  void _beginSyncedRunning(FocusSession session, {Plan? plan}) {
    _timer?.cancel();
    final remaining = _remainingForSession(session);
    setState(() {
      _activeSession = session;
      _selectedPlan = plan ?? _selectedPlan;
      _selectedMinutes = session.plannedDurationMinutes;
      _mode = session.mode;
      _stage = _FocusStage.running;
      _remainingSeconds = remaining;
      _actualDurationSeconds = _elapsedForSession(session);
      _paused = session.status == FocusSessionStatus.paused;
      _finishing = false;
      _startedAt = session.startedAt;
      _lastTickAt = null;
      _resultSession = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncCoupleTimer();
    });
  }

  void _togglePause() {
    if (_stage != _FocusStage.running) return;

    final active = _activeSession;
    if (active != null) {
      if (active.status == FocusSessionStatus.paused) {
        unawaited(_resumeCoupleSession(active.id));
      } else {
        unawaited(_pauseCoupleSession(active.id));
      }
      return;
    }

    setState(() {
      _paused = !_paused;
      _lastTickAt = _paused ? null : DateTime.now();
    });
  }

  Future<void> _pauseCoupleSession(String sessionId) async {
    await _runWithFeedback(() async {
      final session = await context.read<Store>().pauseFocusSession(sessionId);
      if (!mounted || session == null) return;
      setState(() {
        _activeSession = session;
        _paused = true;
        _actualDurationSeconds = _elapsedForSession(session);
        _remainingSeconds = _remainingForSession(session);
      });
    });
  }

  Future<void> _resumeCoupleSession(String sessionId) async {
    await _runWithFeedback(() async {
      final session = await context.read<Store>().resumeFocusSession(sessionId);
      if (!mounted || session == null) return;
      setState(() {
        _activeSession = session;
        _paused = false;
        _actualDurationSeconds = _elapsedForSession(session);
        _remainingSeconds = _remainingForSession(session);
      });
    });
  }

  void _consumeSeconds(int seconds) {
    if (!mounted || _stage != _FocusStage.running || _paused || _finishing) {
      return;
    }

    final consumed = math.min(seconds, _remainingSeconds);
    final nextRemaining = _remainingSeconds - consumed;
    if (nextRemaining > 0) {
      setState(() {
        _remainingSeconds = nextRemaining;
        _actualDurationSeconds += consumed;
      });
      return;
    }

    setState(() {
      _remainingSeconds = 0;
      _actualDurationSeconds += consumed;
    });
    unawaited(_finishSession(FocusSessionStatus.completed));
  }

  Future<void> _finishSession(FocusSessionStatus status) async {
    if (_finishing || !mounted) return;
    final plan = _selectedPlan;
    final active = _activeSession;
    final startedAt = _startedAt;
    if (plan == null && active == null) return;
    if (active == null && startedAt == null) return;

    _finishing = true;
    _timer?.cancel();
    _timer = null;

    final endedAt = DateTime.now();
    final actualSeconds = active == null
        ? (status == FocusSessionStatus.completed
              ? _selectedMinutes * 60
              : _actualDurationSeconds)
        : (status == FocusSessionStatus.completed
              ? active.plannedDurationMinutes * 60
              : _elapsedForSession(active));
    final scoreDelta =
        status == FocusSessionStatus.completed &&
            actualSeconds >= _effectiveFocusSeconds
        ? _scorePerCompletedSession
        : 0;

    final FocusSession session;
    try {
      if (active != null) {
        final saved = await context.read<Store>().finishFocusSession(
          sessionId: active.id,
          status: status,
          actualDurationSeconds: actualSeconds,
          scoreDelta: scoreDelta,
        );
        session =
            saved ??
            active.copyWith(
              status: status,
              actualDurationSeconds: actualSeconds,
              scoreDelta: scoreDelta,
              endedAt: endedAt,
              clearPausedAt: true,
            );
      } else {
        session = FocusSession(
          id: 'focus_${DateTime.now().microsecondsSinceEpoch}',
          planId: plan!.id,
          planTitle: plan.title,
          mode: _mode,
          plannedDurationMinutes: _selectedMinutes,
          actualDurationSeconds: actualSeconds,
          status: status,
          scoreDelta: scoreDelta,
          startedAt: startedAt,
          endedAt: endedAt,
          createdAt: endedAt,
        );
        await context.read<Store>().saveFocusSession(session);
      }
    } catch (error) {
      if (!mounted) return;
      _showFocusError(error);
      setState(() => _finishing = false);
      if (_stage == _FocusStage.running && _timer == null) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          active == null ? _consumeSeconds(1) : _syncCoupleTimer();
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _stage = _FocusStage.result;
      _paused = false;
      _lastTickAt = null;
      _activeSession = null;
      _resultSession = session;
    });
  }

  void _backToSetup() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _stage = _FocusStage.setup;
      _remainingSeconds = _selectedMinutes * 60;
      _actualDurationSeconds = 0;
      _paused = false;
      _finishing = false;
      _startedAt = null;
      _lastTickAt = null;
      _activeSession = null;
      _busy = false;
    });
  }

  Future<void> _runWithFeedback(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      _showFocusError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showFocusError(Object error) {
    final message = _friendlyFocusError(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _friendlyFocusError(Object error) {
    final text = error.toString();
    if (text.contains('create_focus_invite') ||
        text.contains('focus_sessions') ||
        text.contains('schema cache')) {
      return '后端专注功能还没部署，请先应用 focus_sessions migration 后再试。';
    }
    if (text.contains('authentication required') ||
        text.contains('AuthException')) {
      return '需要先登录并完成情侣绑定，才能使用一起专注。';
    }
    if (text.contains('no active couple') ||
        text.contains('active couple relationship')) {
      return '还没有可用的情侣关系，先完成绑定后再一起专注。';
    }
    if (text.contains('not joinable')) {
      return '这次专注邀请已经结束啦。';
    }
    if (text.contains('not allowed after completion')) {
      return 'TA 今天已经完成这个计划啦，可以换个计划一起专注。';
    }
    return '专注操作暂时没有成功，请稍后再试。';
  }

  void _syncCoupleTimer() {
    final session = _activeSession;
    if (!mounted || session == null || _stage != _FocusStage.running) return;

    if (!session.isActive) {
      setState(() {
        _stage = _FocusStage.result;
        _activeSession = null;
        _resultSession = session;
      });
      return;
    }

    final remaining = _remainingForSession(session);
    final elapsed = _elapsedForSession(session);
    if (remaining <= 0 && !_finishing) {
      unawaited(_finishSession(FocusSessionStatus.completed));
      return;
    }

    setState(() {
      _remainingSeconds = remaining;
      _actualDurationSeconds = elapsed;
      _paused = session.status == FocusSessionStatus.paused;
    });
  }

  int _elapsedForSession(FocusSession session) {
    final startedAt = session.startedAt;
    if (startedAt == null) return 0;
    final end = session.status == FocusSessionStatus.paused
        ? (session.pausedAt ?? DateTime.now())
        : DateTime.now();
    final elapsed =
        end.difference(startedAt).inSeconds - session.totalPausedSeconds;
    return elapsed.clamp(0, session.plannedDurationMinutes * 60);
  }

  int _remainingForSession(FocusSession session) {
    return (session.plannedDurationMinutes * 60 - _elapsedForSession(session))
        .clamp(0, session.plannedDurationMinutes * 60);
  }

  String get _partnerStateText {
    final session = _activeSession;
    if (session == null || session.mode != FocusMode.couple) return '';
    if (session.partnerJoinedAt != null) return 'TA 已加入';
    return '已邀请 TA，可先开始';
  }

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

class _FocusSetupView extends StatelessWidget {
  const _FocusSetupView({
    super.key,
    required this.plans,
    required this.selectedPlan,
    required this.selectedMinutes,
    required this.durationOptions,
    required this.mode,
    required this.sessions,
    required this.busy,
    required this.onSelectPlan,
    required this.onSelectDuration,
    required this.onCustomDuration,
    required this.onSelectMode,
    required this.onStart,
    required this.onRefresh,
  });

  final List<Plan> plans;
  final Plan? selectedPlan;
  final int selectedMinutes;
  final List<int> durationOptions;
  final FocusMode mode;
  final List<FocusSession> sessions;
  final bool busy;
  final ValueChanged<Plan> onSelectPlan;
  final ValueChanged<int> onSelectDuration;
  final VoidCallback onCustomDuration;
  final ValueChanged<FocusMode> onSelectMode;
  final VoidCallback? onStart;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.deepPink,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          _FocusPageHeading(mode: mode),
          const SizedBox(height: AppSpacing.md),
          _FocusHeader(sessions: sessions),
          const SizedBox(height: AppSpacing.lg),
          const _FocusSectionHeader(title: '开始专注'),
          const SizedBox(height: AppSpacing.sm),
          _FocusConfigCard(
            plans: plans,
            selectedPlan: selectedPlan,
            selectedMinutes: selectedMinutes,
            options: durationOptions,
            mode: mode,
            busy: busy,
            onSelectPlan: onSelectPlan,
            onSelectDuration: onSelectDuration,
            onCustomDuration: onCustomDuration,
            onSelectMode: onSelectMode,
            onStart: onStart,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FocusSectionHeader(
            title: '今日专注记录',
            actionLabel: sessions.length > 3 ? '查看全部' : null,
            onAction: sessions.length > 3
                ? () => _showAllFocusRecords(context)
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _TodayFocusRecords(sessions: sessions),
        ],
      ),
    );
  }

  Future<void> _showAllFocusRecords(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FocusRecordsSheet(sessions: sessions),
    );
  }
}

class _FocusPageHeading extends StatelessWidget {
  const _FocusPageHeading({required this.mode});

  final FocusMode mode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('专注', style: AppTextStyles.display.copyWith(fontSize: 38)),
              const SizedBox(height: 6),
              Text(
                '选一件事，安静推进今天的小目标',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            mode == FocusMode.couple
                ? Icons.favorite_rounded
                : Icons.timer_rounded,
            color: AppColors.deepPink,
            size: 30,
          ),
        ),
      ],
    );
  }
}

class _FocusHeader extends StatelessWidget {
  const _FocusHeader({required this.sessions});

  final List<FocusSession> sessions;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = sessions.fold<int>(
      0,
      (total, session) => total + session.actualDurationSeconds,
    );
    final completedCount = sessions
        .where((session) => session.status == FocusSessionStatus.completed)
        .length;
    final coupleSeconds = sessions
        .where((session) => session.mode == FocusMode.couple)
        .fold<int>(
          0,
          (total, session) => total + session.actualDurationSeconds,
        );
    final score = sessions.fold<int>(
      0,
      (total, session) => total + session.scoreDelta,
    );

    return AppCard(
      showDashedBorder: true,
      borderColor: Colors.white.withValues(alpha: 0.86),
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.50),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今天已经专注',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                _FocusMinutesDisplay(minutes: _formatMinutes(totalSeconds)),
                const SizedBox(height: 8),
                Text(
                  totalSeconds > 0 ? '慢慢来，也是在一起变好' : '从一小段安静开始',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _FocusHeroBadge(
                  coupleMinutes: _formatMinutes(coupleSeconds),
                  completedCount: completedCount,
                  score: score,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const SizedBox(width: 132, height: 138, child: _FocusClockGarden()),
        ],
      ),
    );
  }
}

class _FocusMinutesDisplay extends StatelessWidget {
  const _FocusMinutesDisplay({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$minutes',
              style: AppTextStyles.display.copyWith(
                color: AppColors.deepPink,
                fontSize: 50,
                height: 1,
              ),
            ),
            TextSpan(
              text: ' 分钟',
              style: AppTextStyles.display.copyWith(fontSize: 38, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusHeroBadge extends StatelessWidget {
  const _FocusHeroBadge({
    required this.coupleMinutes,
    required this.completedCount,
    required this.score,
  });

  final int coupleMinutes;
  final int completedCount;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.favorite_rounded,
            color: AppColors.deepPink,
            size: 17,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '共同专注 $coupleMinutes 分钟 · 完成 $completedCount 次 · +$score',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusClockGarden extends StatelessWidget {
  const _FocusClockGarden();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: 4,
          child: Container(
            width: 126,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.reminder.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 22,
          child: Icon(
            Icons.eco_rounded,
            color: AppColors.grassDeep.withValues(alpha: 0.72),
            size: 42,
          ),
        ),
        Positioned(
          right: 2,
          bottom: 18,
          child: Icon(
            Icons.local_florist_rounded,
            color: AppColors.primary.withValues(alpha: 0.72),
            size: 40,
          ),
        ),
        Positioned(
          top: 28,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.paper,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.deepPink,
                  size: 28,
                ),
                Positioned(
                  top: 12,
                  child: Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.deepPink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  child: Transform.rotate(
                    angle: math.pi / 2.8,
                    child: Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 18,
          left: 38,
          child: _ClockBell(color: AppColors.primary),
        ),
        Positioned(
          top: 18,
          right: 38,
          child: _ClockBell(color: AppColors.deepPink),
        ),
        Positioned(
          top: 36,
          left: 0,
          child: Icon(
            Icons.favorite_rounded,
            color: AppColors.primary.withValues(alpha: 0.32),
            size: 24,
          ),
        ),
        Positioned(
          top: 20,
          right: 8,
          child: Icon(
            Icons.favorite_rounded,
            color: AppColors.primary.withValues(alpha: 0.36),
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _ClockBell extends StatelessWidget {
  const _ClockBell({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.16,
      child: Container(
        width: 26,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(999)),
        ),
      ),
    );
  }
}

class _FocusSectionHeader extends StatelessWidget {
  const _FocusSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.deepPink,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(title, style: AppTextStyles.title.copyWith(fontSize: 23)),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.deepPink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.deepPink,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FocusPlanSelector extends StatelessWidget {
  const _FocusPlanSelector({
    required this.plans,
    required this.selectedPlan,
    required this.onSelectPlan,
  });

  final List<Plan> plans;
  final Plan? selectedPlan;
  final ValueChanged<Plan> onSelectPlan;

  @override
  Widget build(BuildContext context) {
    final selected = selectedPlan;
    return _FocusFieldButton(
      label: '计划',
      title: selected?.title ?? '选择一个计划',
      subtitle: selected == null ? '本次专注为了哪个计划？' : selected.dailyTask,
      icon: selected?.icon ?? Icons.flag_rounded,
      iconColor: selected?.iconColor ?? AppColors.deepPink,
      iconBackgroundColor: selected?.iconBackgroundColor ?? AppColors.blush,
      enabled: plans.isNotEmpty,
      onTap: () => _showPlanPicker(context),
    );
  }

  Future<void> _showPlanPicker(BuildContext context) async {
    if (plans.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlanPickerSheet(
        plans: plans,
        selectedPlan: selectedPlan,
        onSelectPlan: onSelectPlan,
      ),
    );
  }
}

class _FocusFieldButton extends StatelessWidget {
  const _FocusFieldButton({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.line.withValues(alpha: enabled ? 0.72 : 0.36),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.tiny.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: enabled ? AppColors.deepPink : AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanPickerSheet extends StatelessWidget {
  const _PlanPickerSheet({
    required this.plans,
    required this.selectedPlan,
    required this.onSelectPlan,
  });

  final List<Plan> plans;
  final Plan? selectedPlan;
  final ValueChanged<Plan> onSelectPlan;

  @override
  Widget build(BuildContext context) {
    final myPlans = plans
        .where((plan) => plan.owner == PlanOwner.me)
        .toList(growable: false);
    final togetherPlans = plans
        .where((plan) => plan.owner == PlanOwner.together)
        .toList(growable: false);
    final otherPlans = plans
        .where(
          (plan) =>
              plan.owner != PlanOwner.me && plan.owner != PlanOwner.together,
        )
        .toList(growable: false);
    final sections = [
      if (myPlans.isNotEmpty)
        _PlanPickerSection(
          title: '我的计划',
          subtitle: '适合自己安静推进的小目标',
          icon: Icons.person_rounded,
          plans: myPlans,
        ),
      if (togetherPlans.isNotEmpty)
        _PlanPickerSection(
          title: '共同计划',
          subtitle: '两个人一起往前走的约定',
          icon: Icons.favorite_rounded,
          plans: togetherPlans,
        ),
      if (otherPlans.isNotEmpty)
        _PlanPickerSection(
          title: '其他计划',
          subtitle: '可用于本次专注的计划',
          icon: Icons.flag_rounded,
          plans: otherPlans,
        ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.secondaryText.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('选择计划', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text('先看分类，再选择本次专注绑定的计划。', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView.separated(
                itemCount: sections.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) => _PlanPickerSectionView(
                  section: sections[index],
                  selectedPlan: selectedPlan,
                  onSelectPlan: (plan) {
                    onSelectPlan(plan);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanPickerSection {
  const _PlanPickerSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.plans,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Plan> plans;
}

class _PlanPickerSectionView extends StatelessWidget {
  const _PlanPickerSectionView({
    required this.section,
    required this.selectedPlan,
    required this.onSelectPlan,
  });

  final _PlanPickerSection section;
  final Plan? selectedPlan;
  final ValueChanged<Plan> onSelectPlan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(12),
      showDashedBorder: false,
      backgroundColor: Colors.white.withValues(alpha: 0.60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.lightPink.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(section.icon, color: AppColors.deepPink, size: 19),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      section.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.tiny.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              _PlanCountPill(count: section.plans.length),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < section.plans.length; index++) ...[
            _PlanChoiceTile(
              plan: section.plans[index],
              selected: selectedPlan?.id == section.plans[index].id,
              onTap: () => onSelectPlan(section.plans[index]),
            ),
            if (index != section.plans.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PlanCountPill extends StatelessWidget {
  const _PlanCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.70)),
      ),
      child: Text(
        '$count 个',
        style: AppTextStyles.tiny.copyWith(
          color: AppColors.deepPink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PlanChoiceTile extends StatelessWidget {
  const _PlanChoiceTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(12),
      showDashedBorder: false,
      backgroundColor: selected
          ? AppColors.lightPink.withValues(alpha: 0.70)
          : Colors.white.withValues(alpha: 0.78),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: plan.iconBackgroundColor,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(plan.icon, color: plan.iconColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '专注分 ${plan.focusScore}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _PlanOwnerTag(owner: plan.owner),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.deepPink : AppColors.mutedText,
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _PlanOwnerTag extends StatelessWidget {
  const _PlanOwnerTag({required this.owner});

  final PlanOwner owner;

  @override
  Widget build(BuildContext context) {
    final label = switch (owner) {
      PlanOwner.me => '我的',
      PlanOwner.together => '共同',
      PlanOwner.partner => 'TA 的',
    };
    final icon = switch (owner) {
      PlanOwner.me => Icons.person_rounded,
      PlanOwner.together => Icons.favorite_rounded,
      PlanOwner.partner => Icons.favorite_border_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: owner == PlanOwner.together
            ? AppColors.lightPink.withValues(alpha: 0.72)
            : AppColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.deepPink, size: 13),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.tiny.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusDurationSelector extends StatelessWidget {
  const _FocusDurationSelector({
    required this.selectedMinutes,
    required this.options,
    required this.onSelectDuration,
    required this.onCustomDuration,
  });

  final int selectedMinutes;
  final List<int> options;
  final ValueChanged<int> onSelectDuration;
  final VoidCallback onCustomDuration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '时长',
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final minutes in options)
              _ChoicePill(
                label: '$minutes 分钟',
                selected: selectedMinutes == minutes,
                onTap: () => onSelectDuration(minutes),
              ),
            _ChoicePill(
              label: options.contains(selectedMinutes)
                  ? '自定义'
                  : '$selectedMinutes 分钟',
              selected: !options.contains(selectedMinutes),
              onTap: onCustomDuration,
            ),
          ],
        ),
      ],
    );
  }
}

class _FocusConfigCard extends StatelessWidget {
  const _FocusConfigCard({
    required this.plans,
    required this.selectedPlan,
    required this.selectedMinutes,
    required this.options,
    required this.mode,
    required this.busy,
    required this.onSelectPlan,
    required this.onSelectDuration,
    required this.onCustomDuration,
    required this.onSelectMode,
    required this.onStart,
  });

  final List<Plan> plans;
  final Plan? selectedPlan;
  final int selectedMinutes;
  final List<int> options;
  final FocusMode mode;
  final bool busy;
  final ValueChanged<Plan> onSelectPlan;
  final ValueChanged<int> onSelectDuration;
  final VoidCallback onCustomDuration;
  final ValueChanged<FocusMode> onSelectMode;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      showDashedBorder: true,
      padding: const EdgeInsets.all(18),
      borderColor: AppColors.dashedLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FocusPlanSelector(
            plans: plans,
            selectedPlan: selectedPlan,
            onSelectPlan: onSelectPlan,
          ),
          if (plans.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '还没有可专注的计划，先创建一个自己的计划或共同计划，再回来开始专注。',
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _FocusModeSelector(mode: mode, onSelectMode: onSelectMode),
          const SizedBox(height: AppSpacing.md),
          _FocusDurationSelector(
            selectedMinutes: selectedMinutes,
            options: options,
            onSelectDuration: onSelectDuration,
            onCustomDuration: onCustomDuration,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: selectedPlan == null ? '先选择计划' : '开始专注',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
            isLoading: busy,
          ),
        ],
      ),
    );
  }
}

class _FocusModeSelector extends StatelessWidget {
  const _FocusModeSelector({required this.mode, required this.onSelectMode});

  final FocusMode mode;
  final ValueChanged<FocusMode> onSelectMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _ChoicePill(
                label: '自己专注',
                icon: Icons.timer_rounded,
                selected: mode == FocusMode.solo,
                onTap: () => onSelectMode(FocusMode.solo),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ChoicePill(
                label: '一起专注',
                icon: Icons.favorite_border_rounded,
                selected: mode == FocusMode.couple,
                onTap: () => onSelectMode(FocusMode.couple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '一起专注会把邀请放到 TA 的提醒页，不会打断当前页面哦。',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _FocusWaitingView extends StatelessWidget {
  const _FocusWaitingView({
    super.key,
    required this.session,
    required this.onStartNow,
    required this.onCancel,
  });

  final FocusSession? session;
  final VoidCallback onStartNow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final current = session;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        96,
      ),
      children: [
        AppCard(
          showDashedBorder: false,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.lightPink.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.deepPink,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('已邀请 TA 一起专注', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Text(
                current == null
                    ? '正在准备这次专注邀请。'
                    : '等待 TA 加入：${current.planTitle} · ${current.plannedDurationMinutes} 分钟',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: '自己先开始',
                icon: Icons.play_arrow_rounded,
                onPressed: current == null ? null : onStartNow,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: current == null ? null : onCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('取消邀请'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondaryText,
                  side: BorderSide(
                    color: AppColors.secondaryText.withValues(alpha: 0.28),
                  ),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'TA 加入后，双方会看到同一个倒计时。提醒消息也会发到 TA 那边。',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.deepPink : AppColors.secondaryText;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.lightPink.withValues(alpha: 0.86)
                : Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foreground.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusRunningView extends StatelessWidget {
  const _FocusRunningView({
    super.key,
    required this.planTitle,
    required this.mode,
    required this.timeText,
    required this.progress,
    required this.paused,
    required this.partnerStateText,
    required this.onTogglePause,
    required this.onEndEarly,
  });

  final String planTitle;
  final FocusMode mode;
  final String timeText;
  final double progress;
  final bool paused;
  final String partnerStateText;
  final VoidCallback onTogglePause;
  final VoidCallback onEndEarly;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        96,
      ),
      children: [
        AppCard(
          showDashedBorder: false,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              _FocusTimer(timeText: timeText, progress: progress),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '正在专注：$planTitle',
                textAlign: TextAlign.center,
                style: AppTextStyles.section,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '模式：${focusModeLabel(mode)}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (partnerStateText.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  partnerStateText,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.deepPink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: paused ? '继续' : '暂停',
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onPressed: onTogglePause,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onEndEarly,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('提前结束'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondaryText,
                  side: BorderSide(
                    color: AppColors.secondaryText.withValues(alpha: 0.28),
                  ),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FocusTimer extends StatelessWidget {
  const _FocusTimer({required this.timeText, required this.progress});

  final String timeText;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth * 0.82, 260.0);
          return CustomPaint(
            painter: _TimerRingPainter(progress: progress.clamp(0, 1)),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Text(
                  timeText,
                  style: AppTextStyles.display.copyWith(
                    fontSize: size * 0.21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  const _TimerRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..color = AppColors.paperWarm.withValues(alpha: 0.72),
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [AppColors.primary, AppColors.deepPink, AppColors.reminder],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _FocusResultView extends StatelessWidget {
  const _FocusResultView({
    super.key,
    required this.session,
    required this.todaySessions,
    required this.onAgain,
  });

  final FocusSession? session;
  final List<FocusSession> todaySessions;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final current = session;
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final todaySeconds = todaySessions.fold<int>(
      0,
      (total, session) => total + session.actualDurationSeconds,
    );
    final title = current.status == FocusSessionStatus.completed
        ? '完成啦！'
        : '这次没有完成，也没关系';
    final feedback = current.status == FocusSessionStatus.completed
        ? '今天又靠近目标一点点。'
        : '休息一下，下次再慢慢进入状态。';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        96,
      ),
      children: [
        AppCard(
          showDashedBorder: false,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: current.status == FocusSessionStatus.completed
                      ? AppColors.success.withValues(alpha: 0.18)
                      : AppColors.lightPink.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  current.status == FocusSessionStatus.completed
                      ? Icons.check_rounded
                      : Icons.spa_rounded,
                  color: current.status == FocusSessionStatus.completed
                      ? AppColors.successText
                      : AppColors.deepPink,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.lg),
              _ResultLine(
                label: '本次专注',
                value: '${_formatMinutes(current.actualDurationSeconds)} 分钟',
              ),
              _ResultLine(label: '绑定计划', value: current.planTitle),
              _ResultLine(label: '获得执行分', value: '+${current.scoreDelta}'),
              _ResultLine(
                label: '今日累计',
                value: '${_formatMinutes(todaySeconds)} 分钟',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                current.scoreDelta > 0
                    ? '为「${current.planTitle}」增加 +${current.scoreDelta} 执行分'
                    : '未满 5 分钟不计执行分，记录也会好好保留。',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(feedback, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: '回到专注',
                icon: Icons.refresh_rounded,
                onPressed: onAgain,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.caption),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayFocusRecords extends StatelessWidget {
  const _TodayFocusRecords({required this.sessions});

  final List<FocusSession> sessions;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      showDashedBorder: false,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('今天还没有专注记录，选一个计划开始吧。', style: AppTextStyles.caption),
            )
          else
            for (final entry in sessions.take(3).indexed) ...[
              _FocusRecordTile(session: entry.$2),
              if (entry.$1 != math.min(sessions.length, 3) - 1)
                Divider(
                  height: 1,
                  color: AppColors.line.withValues(alpha: 0.60),
                ),
            ],
        ],
      ),
    );
  }
}

class _FocusRecordTile extends StatelessWidget {
  const _FocusRecordTile({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.blush.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              session.isCompleted
                  ? Icons.favorite_rounded
                  : Icons.local_florist_rounded,
              color: AppColors.deepPink,
              size: 23,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.planTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatMinutes(session.actualDurationSeconds)} 分钟 · '
                  '${focusSessionStatusLabel(session.status)} · '
                  '${_formatClock(session.endedAt ?? session.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '+${session.scoreDelta}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.deepPink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusRecordsSheet extends StatelessWidget {
  const _FocusRecordsSheet({required this.sessions});

  final List<FocusSession> sessions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.secondaryText.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('全部专注记录', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text('今天的每一段安静推进都在这里。', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: AppCard(
                showDashedBorder: false,
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: AppColors.line.withValues(alpha: 0.60),
                  ),
                  itemBuilder: (context, index) {
                    return _FocusRecordTile(session: sessions[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomDurationDialog extends StatefulWidget {
  const _CustomDurationDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initialMinutes}',
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('自定义专注时长'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: '分钟',
          hintText: '输入 1-180',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _apply, child: const Text('应用')),
      ],
    );
  }

  void _apply() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 1 || value > 180) {
      setState(() => _errorText = '请输入 1-180 分钟');
      return;
    }
    Navigator.of(context).pop(value);
  }
}

int _formatMinutes(int seconds) => seconds ~/ 60;

String _formatClock(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}
