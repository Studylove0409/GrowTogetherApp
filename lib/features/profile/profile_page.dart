import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart'
    show UpdateException, UpdateStatus;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/config/supabase_config.dart';
import '../../core/notification/fcm_service.dart';
import '../../core/update/shorebird_update_service.dart';
import '../../data/models/account_identity.dart';
import '../../data/models/couple_invitation.dart';
import '../../data/models/plan.dart';
import '../../data/models/profile.dart';
import '../../data/models/reminder_settings.dart';
import '../../data/store/store.dart';
import '../../data/supabase/account_repository.dart';
import '../../data/supabase/profile_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/avatar_preview.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/sticker_asset.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.isSelected,
    required this.onOpenPlans,
  });

  final bool isSelected;
  final VoidCallback onOpenPlans;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  final _profileRepository = const ProfileRepository();
  final _accountRepository = const AccountRepository();
  late Future<_ProfilePageData> _profileFuture;
  bool _isAvatarPickerActive = false;
  bool _skipNextResumeRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  void _setAvatarPickerActive(bool active) {
    _isAvatarPickerActive = active;
    if (active) {
      _skipNextResumeRefresh = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !widget.isSelected) return;

    if (_isAvatarPickerActive || _skipNextResumeRefresh) {
      _skipNextResumeRefresh = false;
      return;
    }

    if (mounted) {
      _refreshProfile();
    }
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isSelected && widget.isSelected) {
      _refreshProfile();
    }
  }

  Future<_ProfilePageData> _loadProfile() async {
    if (!SupabaseConfig.isConfigured) {
      return _ProfilePageData(
        profile: _unboundFallbackProfile,
        account: const AccountIdentity(isConfigured: false, isAnonymous: true),
      );
    }

    try {
      final results = await Future.wait<Object>([
        _profileRepository.getCurrentProfile(),
        _accountRepository.getCurrentIdentity(),
      ]);
      final profile = results[0] as Profile;
      final account = results[1] as AccountIdentity;
      final invitations = profile.isBound
          ? const <CoupleInvitation>[]
          : await _profileRepository.getPendingIncomingCoupleInvitations();
      return _ProfilePageData(
        profile: profile,
        account: account,
        invitations: invitations,
      );
    } catch (error, stackTrace) {
      debugPrint('Profile load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfilePageData>(
      future: _profileFuture,
      initialData: _fallbackProfileData,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _fallbackProfileData;
        final profile = data.profile;
        final hasError = snapshot.hasError;
        final bottomPadding = 120 + MediaQuery.paddingOf(context).bottom;

        return AppScaffold(
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.deepPink,
              onRefresh: () async {
                final nextProfile = _loadProfile();
                setState(() {
                  _profileFuture = nextProfile;
                });
                await nextProfile;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  bottomPadding,
                ),
                children: [
                  const _ProfilePageTitle(),
                  const SizedBox(height: 14),
                  _ProfileInfoCard(
                    name: profile.name,
                    partnerName: profile.partnerName,
                    togetherDays: profile.togetherDays,
                    isBound: profile.isBound,
                    avatarUrl: profile.avatarUrl,
                    partnerAvatarUrl: profile.partnerAvatarUrl,
                    anniversaryDate: profile.anniversaryDate,
                    inviteCode: profile.inviteCode,
                    hasInviteError: hasError,
                    isSupabaseConfigured: SupabaseConfig.isConfigured,
                    account: data.account,
                    repository: _accountRepository,
                    profileRepository: _profileRepository,
                    onOpenPlans: widget.onOpenPlans,
                    onRelationshipChanged: _refreshProfile,
                    onAvatarPickerActiveChanged: _setAvatarPickerActive,
                    onAccountChanged: () async {
                      await FcmService.syncTokenToCurrentUser();
                      if (!context.mounted) return;
                      await context.read<Store>().refreshAll();
                      _refreshProfile();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!profile.isBound) ...[
                    if (data.invitations.isNotEmpty) ...[
                      _IncomingInvitationCard(
                        invitation: data.invitations.first,
                        repository: _profileRepository,
                        onChanged: _refreshProfile,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _BindPartnerCard(
                      repository: _profileRepository,
                      onSent: _refreshProfile,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Profile get _unboundFallbackProfile {
    final current = context.read<Store>().getProfile();
    return Profile(
      name: current.name,
      partnerName: '还没有绑定 TA',
      togetherDays: 0,
      inviteCode: '',
      isBound: false,
      avatarUrl: current.avatarUrl,
      partnerAvatarUrl: null,
    );
  }

  _ProfilePageData get _fallbackProfileData => _ProfilePageData(
    profile: _unboundFallbackProfile,
    account: const AccountIdentity(isConfigured: false, isAnonymous: true),
  );
}

class _ProfilePageData {
  const _ProfilePageData({
    required this.profile,
    required this.account,
    this.invitations = const [],
  });

  final Profile profile;
  final AccountIdentity account;
  final List<CoupleInvitation> invitations;
}

class _AppVersionInfo {
  const _AppVersionInfo({
    required this.appVersion,
    this.patchNumber,
    this.updaterAvailable = false,
    this.readFailed = false,
  });

  final String appVersion;
  final int? patchNumber;
  final bool updaterAvailable;
  final bool readFailed;

  String get appVersionLabel => 'v$appVersion';

  String get patchLabel {
    if (readFailed) return '读取失败';
    if (!updaterAvailable) return '未安装补丁';
    return patchNumber == null ? '未安装补丁' : 'Patch $patchNumber';
  }

  String get shortLabel {
    if (patchNumber != null) return 'Patch $patchNumber';
    return patchLabel;
  }

  String get description {
    if (readFailed) return '暂时无法读取远程补丁信息，请重启 App 后再查看。';
    if (!updaterAvailable) {
      return '当前构建不支持 Shorebird 更新。Debug 模式或非 Shorebird release 构建下，这是正常情况。';
    }
    if (patchNumber == null) {
      return '当前安装的是基础 release，还没有应用远程补丁。';
    }
    return '当前已经应用 Shorebird 远程补丁 Patch $patchNumber。';
  }
}

enum _ManualUpdateState {
  idle,
  checking,
  downloading,
  readyToRestart,
  upToDate,
  failed,
  unavailable,
}

class _ProfilePageTitle extends StatelessWidget {
  const _ProfilePageTitle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '我的',
            style: AppTextStyles.section.copyWith(
              color: AppColors.text,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          Positioned(
            left: 0,
            child: Navigator.of(context).canPop()
                ? _CircleIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : const SizedBox(width: 38, height: 38),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: AppColors.secondaryText, size: 22),
        ),
      ),
    );
  }
}

class _ProfileInfoCard extends StatefulWidget {
  const _ProfileInfoCard({
    required this.name,
    required this.partnerName,
    required this.togetherDays,
    required this.isBound,
    required this.avatarUrl,
    required this.partnerAvatarUrl,
    required this.anniversaryDate,
    required this.inviteCode,
    required this.hasInviteError,
    required this.isSupabaseConfigured,
    required this.account,
    required this.repository,
    required this.profileRepository,
    required this.onOpenPlans,
    required this.onRelationshipChanged,
    required this.onAvatarPickerActiveChanged,
    required this.onAccountChanged,
  });

  final String name;
  final String partnerName;
  final int togetherDays;
  final bool isBound;
  final String? avatarUrl;
  final String? partnerAvatarUrl;
  final DateTime? anniversaryDate;
  final String inviteCode;
  final bool hasInviteError;
  final bool isSupabaseConfigured;
  final AccountIdentity account;
  final AccountRepository repository;
  final ProfileRepository profileRepository;
  final VoidCallback onOpenPlans;
  final VoidCallback onRelationshipChanged;
  final ValueChanged<bool> onAvatarPickerActiveChanged;
  final Future<void> Function() onAccountChanged;

  @override
  State<_ProfileInfoCard> createState() => _ProfileInfoCardState();
}

class _ProfileInfoCardState extends State<_ProfileInfoCard> {
  static const _appVersion = '1.0.0+3';
  static const _updateService = ShorebirdUpdateService();

  bool _isSubmitting = false;
  _ManualUpdateState _manualUpdateState = _ManualUpdateState.idle;
  String? _manualUpdateMessage;
  late Future<_AppVersionInfo> _appVersionInfoFuture;

  @override
  void initState() {
    super.initState();
    _appVersionInfoFuture = _loadAppVersionInfo();
  }

  Future<_AppVersionInfo> _loadAppVersionInfo() async {
    try {
      final updaterAvailable = _updateService.isUpdaterAvailable;
      final patch = await _updateService.getCurrentPatch();
      return _AppVersionInfo(
        appVersion: _appVersion,
        patchNumber: patch?.number,
        updaterAvailable: updaterAvailable,
      );
    } catch (error) {
      debugPrint('Read Shorebird patch failed: $error');
      return const _AppVersionInfo(
        appVersion: _appVersion,
        patchNumber: null,
        updaterAvailable: true,
        readFailed: true,
      );
    }
  }

  Future<void> _checkForShorebirdUpdate() async {
    if (_manualUpdateState == _ManualUpdateState.checking ||
        _manualUpdateState == _ManualUpdateState.downloading) {
      return;
    }

    setState(() {
      _manualUpdateState = _ManualUpdateState.checking;
      _manualUpdateMessage = '正在检查...';
    });

    try {
      final status = await _updateService.checkForUpdate();
      if (!mounted) return;

      switch (status) {
        case UpdateStatus.upToDate:
          setState(() {
            _manualUpdateState = _ManualUpdateState.upToDate;
            _manualUpdateMessage = '已是最新版本';
            _appVersionInfoFuture = _loadAppVersionInfo();
          });
          _showSnack(context, '已是最新版本');
        case UpdateStatus.outdated:
          setState(() {
            _manualUpdateState = _ManualUpdateState.downloading;
            _manualUpdateMessage = '发现更新，正在下载...';
          });
          _showSnack(context, '发现更新，正在下载...');
          await _updateService.downloadUpdate();
          if (!mounted) return;
          setState(() {
            _manualUpdateState = _ManualUpdateState.readyToRestart;
            _manualUpdateMessage = '更新已准备好，重启 App 后生效';
            _appVersionInfoFuture = _loadAppVersionInfo();
          });
          _showSnack(context, '更新已准备好，重启 App 后生效');
        case UpdateStatus.restartRequired:
          setState(() {
            _manualUpdateState = _ManualUpdateState.readyToRestart;
            _manualUpdateMessage = '更新已下载，重启 App 后生效';
            _appVersionInfoFuture = _loadAppVersionInfo();
          });
          _showSnack(context, '更新已下载，重启 App 后生效');
        case UpdateStatus.unavailable:
          setState(() {
            _manualUpdateState = _ManualUpdateState.unavailable;
            _manualUpdateMessage = '当前构建不支持 Shorebird 更新';
            _appVersionInfoFuture = _loadAppVersionInfo();
          });
          _showSnack(context, '当前构建不支持 Shorebird 更新');
      }
    } on UpdateException catch (error) {
      debugPrint('Shorebird update failed: $error');
      if (!mounted) return;
      setState(() {
        _manualUpdateState = _ManualUpdateState.failed;
        _manualUpdateMessage = '检查失败，请切换网络后重试';
      });
      _showSnack(context, '检查失败，请切换网络后重试');
    } catch (error, stackTrace) {
      debugPrint('Shorebird update check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _manualUpdateState = _ManualUpdateState.failed;
        _manualUpdateMessage = '检查失败，请切换网络后重试';
      });
      _showSnack(context, '检查失败，请切换网络后重试');
    }
  }

  bool get _isCheckingForUpdate =>
      _manualUpdateState == _ManualUpdateState.checking ||
      _manualUpdateState == _ManualUpdateState.downloading;

  String get _versionUpdateButtonLabel {
    return switch (_manualUpdateState) {
      _ManualUpdateState.checking => '正在检查...',
      _ManualUpdateState.downloading => '正在下载...',
      _ => '检查更新',
    };
  }

  String _versionSubtitle(_AppVersionInfo? info) {
    final version = info?.appVersionLabel ?? 'v$_appVersion';
    final patch = info?.patchLabel ?? '读取中';
    final message = _manualUpdateMessage;
    if (message == null || message.isEmpty) return '$version · $patch';
    return '$version · $patch\n$message';
  }

  Future<void> _linkEmail() async {
    final email = await _showTextInputDialog(
      context,
      title: '绑定邮箱',
      hintText: '输入你的邮箱',
      icon: Icons.mail_outline_rounded,
      keyboardType: TextInputType.emailAddress,
      validator: (value) => _isValidEmail(value) ? null : '请输入有效邮箱',
    );
    if (email == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.linkEmail(email);
      if (!mounted) return;
      await widget.onAccountChanged();
      if (!mounted) return;
      _showSnack(context, '验证邮件已发送，请打开邮箱完成确认。');
    } on AuthException catch (error) {
      if (!mounted) return;
      _showSnack(context, _accountErrorMessage(error.message));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _setPassword() async {
    final password = await _showTextInputDialog(
      context,
      title: '设置密码',
      hintText: '至少 6 位密码',
      icon: Icons.lock_outline_rounded,
      obscureText: true,
      validator: (value) => value.length >= 6 ? null : '密码至少 6 位',
    );
    if (password == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.setPassword(password);
      if (!mounted) return;
      await widget.onAccountChanged();
      if (!mounted) return;
      _showSnack(context, '密码已设置，之后可以用邮箱登录啦。');
    } on AuthException catch (error) {
      if (!mounted) return;
      _showSnack(context, _accountErrorMessage(error.message));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signIn() async {
    final credentials = await _showEmailPasswordDialog(context);
    if (credentials == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.signInWithEmailPassword(
        email: credentials.email,
        password: credentials.password,
      );
      if (!mounted) return;
      await widget.onAccountChanged();
      if (!mounted) return;
      _showSnack(context, '已登录你的账号。');
    } on AuthException catch (error) {
      if (!mounted) return;
      _showSnack(context, _accountErrorMessage(error.message));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isSubmitting) return;

    if (!widget.isSupabaseConfigured) {
      _showSnack(context, '当前没有连接 Supabase，暂时不能上传头像。');
      return;
    }

    if (widget.account.isAnonymous || !widget.account.hasEmail) {
      _showSnack(context, '登录邮箱账号后，就可以上传自己的头像啦。');
      return;
    }

    XFile? pickedImage;
    try {
      widget.onAvatarPickerActiveChanged(true);
      pickedImage = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 86,
      );
    } finally {
      widget.onAvatarPickerActiveChanged(false);
    }

    if (pickedImage == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final bytes = await pickedImage.readAsBytes();
      final extension = _fileExtensionOf(pickedImage.name);
      await widget.profileRepository.uploadCurrentUserAvatar(
        bytes: bytes,
        fileExtension: extension,
        contentType: pickedImage.mimeType ?? '',
      );
      if (!mounted) return;
      await widget.onAccountChanged();
      if (!mounted) return;
      _showSnack(context, '头像已更新，TA 也能看到啦。');
    } on StorageException catch (error) {
      if (!mounted) return;
      _showSnack(context, _avatarUploadErrorMessage(error.message));
    } on AuthException catch (_) {
      if (!mounted) return;
      _showSnack(context, '登录状态已失效，请重新登录后再上传头像。');
    } catch (error) {
      debugPrint('Avatar upload failed: $error');
      if (!mounted) return;
      _showSnack(context, '头像上传失败，请稍后再试。');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _editNickname() async {
    if (_isSubmitting) return;

    if (!widget.isSupabaseConfigured) {
      _showSnack(context, '当前没有连接 Supabase，暂时不能修改昵称。');
      return;
    }

    final nickname = await _showTextInputDialog(
      context,
      title: '修改昵称',
      hintText: '输入新的昵称',
      initialValue: widget.name,
      icon: Icons.person_rounded,
      validator: (value) {
        if (value.trim().isEmpty) return '昵称不能为空';
        if (value.characters.length > 16) return '昵称最多 16 个字';
        return null;
      },
    );
    if (nickname == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.profileRepository.updateCurrentUserNickname(nickname);
      if (!mounted) return;
      await widget.onAccountChanged();
      if (!mounted) return;
      _showSnack(context, '昵称已更新');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showSnack(context, _profileUpdateErrorMessage(error.message));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAnniversaryDate() async {
    if (_isSubmitting) return;

    if (!widget.isBound) {
      _showInfoDialog(
        context,
        title: '情侣纪念日',
        message: '绑定另一半后，这里会自动记录你们的一起进步天数。',
      );
      return;
    }

    if (!widget.isSupabaseConfigured) {
      _showSnack(context, '当前没有连接 Supabase，暂时不能修改纪念日。');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fallback = widget.anniversaryDate ?? today;
    final initialDate = fallback.isAfter(today) ? today : fallback;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: '选择情侣纪念日',
      cancelText: '取消',
      confirmText: '保存',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.deepPink,
              onPrimary: Colors.white,
              surface: const Color(0xFFFFF6F9),
              onSurface: AppColors.text,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.profileRepository.updateCurrentCoupleAnniversary(picked);
      if (!mounted) return;
      await widget.onAccountChanged();
      if (!mounted) return;
      _showSnack(context, '情侣纪念日已更新');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showSnack(context, _profileUpdateErrorMessage(error.message));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signOut() async {
    if (_isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出当前账号'),
        content: const Text('退出后会切换为新的临时账号。你可以之后再用邮箱和密码登录回来。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed != true || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.signOutToAnonymous();
      if (!mounted) return;
      await widget.onAccountChanged();
      if (!mounted) return;
      _showSnack(context, '已退出账号，当前是新的临时账号。');
    } on AuthException catch (error) {
      if (!mounted) return;
      _showSnack(context, _accountErrorMessage(error.message));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmAndDeleteAccount() async {
    if (_isSubmitting) return;

    if (!widget.isSupabaseConfigured || !widget.account.isConfigured) {
      _showSnack(context, '当前没有连接 Supabase，暂时不能注销账号。');
      return;
    }

    final confirmation = await _showTextInputDialog(
      context,
      title: '注销账号',
      hintText: '输入“注销账号”确认',
      icon: Icons.person_remove_rounded,
      validator: (value) => value.trim() == '注销账号' ? null : '请完整输入“注销账号”再继续',
    );
    if (confirmation == null || _isSubmitting) return;
    if (!mounted) return;

    final confirmed = await showAppCuteDialog<bool>(
      context,
      builder: (dialogContext) => AppCuteDialog(
        title: '确认注销账号',
        description: '这会永久删除你的账号、资料、计划、打卡、提醒和情侣关系。操作完成后会自动切换为新的临时账号。',
        icon: const DialogIconBadge(
          icon: Icons.warning_amber_rounded,
          color: AppColors.deepPink,
        ),
        primaryText: '永久注销',
        cancelText: '再想想',
        isDanger: true,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onPrimary: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.deleteCurrentUserAccount();
      if (!mounted) return;
      await widget.onAccountChanged();
      if (!mounted) return;
      _showSnack(context, '账号已注销，当前已切换为新的临时账号。');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showSnack(context, _deleteAccountErrorMessage(error.message));
    } on AuthException catch (error) {
      if (!mounted) return;
      _showSnack(context, _accountErrorMessage(error.message));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showPersonalProfileDialog(BuildContext context) {
    showAppCuteDialog(
      context,
      builder: (dialogContext) => AppCuteDialog(
        title: '个人资料',
        description: '可以更新头像和昵称，TA 会在情侣空间里看到你的最新资料。',
        icon: _CuteAvatar(
          size: 72,
          imageUrl: widget.avatarUrl,
          isUploading: _isSubmitting,
          shadowOpacity: 0.12,
          borderWidth: 4,
        ),
        primaryText: '更换头像',
        secondaryText: '修改昵称',
        cancelText: '取消',
        onCancel: () => Navigator.of(dialogContext).pop(),
        onSecondary: _isSubmitting
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                _editNickname();
              },
        onPrimary: _isSubmitting
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                _pickAndUploadAvatar();
              },
        children: [
          DialogInfoCard(
            icon: Icons.person_rounded,
            title: '昵称',
            body: widget.name.isEmpty ? '一起进步的你' : widget.name,
          ),
        ],
      ),
    );
  }

  void _showDataSyncDialog(BuildContext context, AccountIdentity account) {
    _showInfoDialog(
      context,
      title: '数据同步状态',
      message: account.isConfigured
          ? '当前已连接 Supabase。你的资料、计划、打卡、提醒和情侣关系会通过云端同步。'
          : '当前未连接 Supabase，页面使用本地 Mock 数据展示。发布或真机联调时需要提供 SUPABASE_ANON_KEY。',
    );
  }

  void _showAccountSecurityDialog(
    BuildContext context,
    AccountIdentity account,
  ) {
    final primaryText = account.isEmailConfirmed ? '设置密码' : '绑定邮箱';

    showAppCuteDialog(
      context,
      builder: (dialogContext) => AppCuteDialog(
        title: '账号与安全',
        description: '你现在使用的是临时账号。绑定邮箱后，卸载 App 或换手机也可以找回数据。',
        icon: const DialogIconBadge(icon: Icons.shield_rounded),
        primaryText: primaryText,
        secondaryText: account.isRecoverable ? null : '登录已有账号',
        cancelText: '稍后再说',
        onCancel: () => Navigator.of(dialogContext).pop(),
        onSecondary: account.isRecoverable || _isSubmitting
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                _signIn();
              },
        onPrimary: _isSubmitting
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                if (account.isEmailConfirmed) {
                  _setPassword();
                } else {
                  _linkEmail();
                }
              },
        children: const [
          DialogInfoCard(
            icon: Icons.lock_clock_rounded,
            title: '数据保护提醒',
            body: '建议尽快绑定邮箱，避免数据丢失。',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('将清理当前页面的临时展示缓存。你的计划、打卡和账号数据不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      imageCache.clear();
      imageCache.clearLiveImages();
      _showSnack(context, '缓存已清理');
    }
  }

  Future<void> _saveReminderSettings(ReminderSettings settings) async {
    await context.read<Store>().updateReminderSettings(settings);
    if (!mounted) return;
    _showSnack(context, '提醒设置已更新');
  }

  Future<void> _pickDailyReminderTime(ReminderSettings settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.dailyReminderTime,
      helpText: '选择每日提醒时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;

    await _saveReminderSettings(
      settings.copyWith(dailyReminderEnabled: true, dailyReminderTime: picked),
    );
  }

  Future<void> _pickDoNotDisturbTime(
    ReminderSettings settings, {
    required bool pickStart,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: pickStart
          ? settings.doNotDisturbStart
          : settings.doNotDisturbEnd,
      helpText: pickStart ? '选择免打扰开始时间' : '选择免打扰结束时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;

    await _saveReminderSettings(
      settings.copyWith(
        doNotDisturbEnabled: true,
        doNotDisturbStart: pickStart ? picked : null,
        doNotDisturbEnd: pickStart ? null : picked,
      ),
    );
  }

  Future<void> _showDoNotDisturbSheet(ReminderSettings settings) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _DoNotDisturbSheet(
        settings: settings,
        onToggle: (enabled) async {
          Navigator.of(sheetContext).pop();
          await _saveReminderSettings(
            settings.copyWith(doNotDisturbEnabled: enabled),
          );
        },
        onPickStart: () {
          Navigator.of(sheetContext).pop();
          _pickDoNotDisturbTime(settings, pickStart: true);
        },
        onPickEnd: () {
          Navigator.of(sheetContext).pop();
          _pickDoNotDisturbTime(settings, pickStart: false);
        },
      ),
    );
  }

  Future<void> _showPlanReminderSheet(BuildContext context) async {
    final plans = context
        .read<Store>()
        .getPlans()
        .where(_shouldShowPlanReminder)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PlanReminderSheet(
        plans: plans,
        onOpenPlans: () {
          Navigator.of(sheetContext).pop();
          widget.onOpenPlans();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final accountColor = _accountStatusColor(account);
    final accountLabel = _accountStatusLabel(account);
    final store = context.watch<Store>();
    final reminderSettings = store.getReminderSettings();
    final planReminderCount = store
        .getPlans()
        .where(_shouldShowPlanReminder)
        .length;
    final anniversaryDateLabel = widget.anniversaryDate == null
        ? null
        : _formatDateLabel(widget.anniversaryDate!);
    final anniversarySubtitle = widget.isBound
        ? anniversaryDateLabel == null
              ? '你们已经一起进步第 ${widget.togetherDays} 天'
              : '$anniversaryDateLabel · 第 ${widget.togetherDays} 天'
        : '绑定后自动记录你们的一起进步天数';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileHeader(
          name: widget.name,
          partnerName: widget.partnerName,
          togetherDays: widget.togetherDays,
          isBound: widget.isBound,
          avatarUrl: widget.avatarUrl,
          partnerAvatarUrl: widget.partnerAvatarUrl,
          accountLabel: accountLabel,
          accountColor: accountColor,
          isUploading: _isSubmitting,
          onAvatarTap: () => showAvatarPreview(
            context,
            title: '我的头像',
            imageUrl: widget.avatarUrl,
          ),
          onPartnerAvatarTap: widget.isBound
              ? () => showAvatarPreview(
                  context,
                  title:
                      '${widget.partnerName.trim().isEmpty ? 'TA' : widget.partnerName.trim()}的头像',
                  imageUrl: widget.partnerAvatarUrl,
                )
              : null,
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: '账号',
          children: [
            SettingsTile(
              icon: Icons.person_rounded,
              iconColor: AppColors.deepPink,
              title: '个人资料',
              subtitle: '头像、昵称和成长空间资料',
              onTap: () => _showPersonalProfileDialog(context),
            ),
            SettingsTile(
              icon: _accountIcon(account),
              iconColor: accountColor,
              title: '账号与安全',
              subtitle: account.isConfigured
                  ? _accountDescription(account)
                  : '当前没有连接 Supabase，账号保护不可用。',
              trailing: account.isEmailConfirmed
                  ? const _MutedTag('已保护')
                  : const _ActionHint('去绑定'),
              onTap: account.isConfigured
                  ? () => _showAccountSecurityDialog(context, account)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 26),
        _SettingsSection(
          title: '情侣关系',
          children: [
            SettingsTile(
              icon: widget.isBound
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: widget.isBound
                  ? AppColors.deepPink
                  : AppColors.secondaryText,
              title: '情侣绑定',
              subtitle: widget.isBound
                  ? '和 ${widget.partnerName} 一起进步'
                  : '输入邀请码后，等待 TA 同意绑定',
              trailing: _StatusBadge(
                label: widget.isBound ? '已绑定' : '待绑定',
                color: widget.isBound
                    ? AppColors.deepPink
                    : AppColors.secondaryText,
              ),
            ),
            SettingsTile(
              icon: Icons.card_giftcard_rounded,
              iconColor: AppColors.deepPink,
              title: '邀请另一半',
              subtitle: '查看邀请码，让 TA 加入你的成长空间',
              onTap: () => _showInviteCodeDialog(
                context,
                inviteCode: widget.inviteCode,
                hasError: widget.hasInviteError,
                isSupabaseConfigured: widget.isSupabaseConfigured,
              ),
            ),
            SettingsTile(
              icon: Icons.event_available_rounded,
              iconColor: AppColors.reminder,
              title: '情侣纪念日',
              subtitle: anniversarySubtitle,
              trailing: widget.isBound
                  ? _MutedTag('第 ${widget.togetherDays} 天')
                  : null,
              onTap: _isSubmitting ? null : _pickAnniversaryDate,
            ),
            widget.isBound
                ? DangerSettingsTile(
                    title: _isSubmitting ? '解除中...' : '解除绑定',
                    subtitle: '解除后，你们需要重新输入邀请码才能再次绑定。',
                    onTap: _isSubmitting ? null : _confirmAndEndRelationship,
                  )
                : SettingsTile(
                    icon: Icons.heart_broken_rounded,
                    iconColor: AppColors.secondaryText,
                    title: '解除绑定',
                    subtitle: '当前未绑定，无需解除',
                    trailing: const _MutedTag('不可用'),
                  ),
          ],
        ),
        const SizedBox(height: 26),
        _SettingsSection(
          title: '提醒',
          children: [
            SettingsTile(
              icon: Icons.today_rounded,
              iconColor: AppColors.deepPink,
              title: '每日提醒',
              subtitle: reminderSettings.dailyReminderEnabled
                  ? '每天 ${reminderSettings.dailyReminderTime.format(context)} 提醒看看今日计划'
                  : '已关闭每日计划提醒',
              trailing: _SettingsSwitch(
                value: reminderSettings.dailyReminderEnabled,
                onChanged: (enabled) => _saveReminderSettings(
                  reminderSettings.copyWith(dailyReminderEnabled: enabled),
                ),
              ),
              onTap: () => _pickDailyReminderTime(reminderSettings),
            ),
            SettingsTile(
              icon: Icons.alarm_rounded,
              iconColor: AppColors.reminder,
              title: '打卡提醒',
              subtitle: '计划中的提醒时间会自动安排通知',
              trailing: _MutedTag('$planReminderCount 个'),
              onTap: () => _showPlanReminderSheet(context),
            ),
            SettingsTile(
              icon: Icons.favorite_rounded,
              iconColor: AppColors.deepPink,
              title: '另一半动态提醒',
              subtitle: 'TA 打卡、提醒或邀请时通知你',
              trailing: widget.isBound
                  ? _SettingsSwitch(
                      value: reminderSettings.partnerActivityReminderEnabled,
                      onChanged: (enabled) => _saveReminderSettings(
                        reminderSettings.copyWith(
                          partnerActivityReminderEnabled: enabled,
                        ),
                      ),
                    )
                  : const _MutedTag('未绑定'),
              onTap: widget.isBound
                  ? () => _saveReminderSettings(
                      reminderSettings.copyWith(
                        partnerActivityReminderEnabled:
                            !reminderSettings.partnerActivityReminderEnabled,
                      ),
                    )
                  : null,
            ),
            SettingsTile(
              icon: Icons.nights_stay_rounded,
              iconColor: AppColors.secondaryText,
              title: '免打扰时间',
              subtitle: reminderSettings.doNotDisturbEnabled
                  ? '${reminderSettings.doNotDisturbStart.format(context)} - ${reminderSettings.doNotDisturbEnd.format(context)} 减少提醒打扰'
                  : '关闭，夜间仍会接收提醒',
              trailing: _SettingsSwitch(
                value: reminderSettings.doNotDisturbEnabled,
                onChanged: (enabled) => _saveReminderSettings(
                  reminderSettings.copyWith(doNotDisturbEnabled: enabled),
                ),
              ),
              onTap: () => _showDoNotDisturbSheet(reminderSettings),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _SettingsSection(
          title: '数据',
          children: [
            SettingsTile(
              icon: Icons.cloud_done_rounded,
              iconColor: account.isConfigured
                  ? AppColors.success
                  : AppColors.secondaryText,
              title: '数据同步状态',
              subtitle: account.isConfigured
                  ? '已连接 Supabase，计划和资料会自动同步'
                  : '当前使用本地 Mock 数据',
              trailing: _MutedTag(account.isConfigured ? '已同步' : '本地'),
              onTap: () => _showDataSyncDialog(context, account),
            ),
            SettingsTile(
              icon: Icons.cleaning_services_rounded,
              iconColor: AppColors.lavender,
              title: '清除缓存',
              subtitle: '清理临时图片和本地展示缓存',
              onTap: () => _confirmClearCache(context),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _SettingsSection(
          title: '关于',
          children: [
            SettingsTile(
              icon: Icons.feedback_rounded,
              iconColor: AppColors.reminder,
              title: '反馈与建议',
              subtitle: '告诉我们你希望一起进步呀变得更好',
              onTap: () => _showInfoDialog(
                context,
                title: '反馈与建议',
                message: '可以把建议发送到：song3286791241@gmail.com',
              ),
            ),
            SettingsTile(
              icon: Icons.info_rounded,
              iconColor: AppColors.success,
              title: '关于 App',
              onTap: () => _showAboutUsDialog(context),
            ),
            FutureBuilder<_AppVersionInfo>(
              future: _appVersionInfoFuture,
              initialData: const _AppVersionInfo(appVersion: _appVersion),
              builder: (context, snapshot) {
                final info = snapshot.data;
                return SettingsTile(
                  icon: Icons.new_releases_rounded,
                  iconColor: AppColors.lavender,
                  title: '当前版本',
                  subtitle: _versionSubtitle(info),
                  trailing: _VersionCheckButton(
                    label: _versionUpdateButtonLabel,
                    isBusy: _isCheckingForUpdate,
                    onPressed: _isCheckingForUpdate
                        ? null
                        : _checkForShorebirdUpdate,
                  ),
                  onTap: () => _showAppVersionDialog(
                    context,
                    versionInfoFuture: _appVersionInfoFuture,
                    statusMessage: _manualUpdateMessage,
                    onCheckUpdate: _isCheckingForUpdate
                        ? null
                        : _checkForShorebirdUpdate,
                    checkButtonLabel: _versionUpdateButtonLabel,
                    isChecking: _isCheckingForUpdate,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 26),
        _SettingsSection(
          title: '底部',
          children: [
            DangerSettingsTile(
              icon: Icons.logout_rounded,
              title: _isSubmitting ? '退出中...' : '退出登录',
              subtitle: account.isAnonymous ? '当前是临时账号，无需退出' : '退出后会切换为新的临时账号。',
              onTap: account.isAnonymous || _isSubmitting ? null : _signOut,
            ),
            DangerSettingsTile(
              icon: Icons.person_remove_rounded,
              title: _isSubmitting ? '注销中...' : '注销账号',
              subtitle: '永久删除账号需要额外确认',
              onTap: _isSubmitting ? null : _confirmAndDeleteAccount,
            ),
          ],
        ),
      ],
    );
  }

  bool _shouldShowPlanReminder(Plan plan) {
    return plan.hasReminder &&
        plan.owner != PlanOwner.partner &&
        !plan.isDoneForCurrentUser;
  }

  Future<void> _confirmAndEndRelationship() async {
    if (_isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认解除绑定'),
        content: const Text('解除绑定后，你们都将无法继续查看这段关系里的历史计划和打卡记录。确定要解除绑定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定解绑'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.profileRepository.endCurrentCoupleRelationship();
      if (!mounted) return;
      widget.onRelationshipChanged();
      _showSnack(context, '已解除绑定');
    } catch (_) {
      if (!mounted) return;
      _showSnack(context, '好像哪里出错啦，请再试一次～');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _accountDescription(AccountIdentity account) {
    if (!account.isAnonymous && account.hasEmail) {
      return '当前已登录 ${account.email}。设置密码后，换手机也能用邮箱密码登录。';
    }
    if (account.hasEmail) {
      return '已发送验证邮件到 ${account.email}，确认邮箱后再设置密码。';
    }
    return '现在还是临时账号。绑定邮箱后，卸载 App 或换手机也能找回数据。';
  }

  String _fileExtensionOf(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == filename.length - 1) return 'jpg';
    return filename.substring(dotIndex + 1);
  }

  String _avatarUploadErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('bucket') || lower.contains('not found')) {
      return '头像空间还没有创建，请先同步最新数据库迁移。';
    }
    if (lower.contains('mime') || lower.contains('content type')) {
      return '请选择 jpg、png 或 webp 格式的图片。';
    }
    if (lower.contains('size') || lower.contains('too large')) {
      return '图片太大啦，请换一张 2MB 以内的头像。';
    }
    return '头像上传失败，请稍后再试。';
  }

  String _formatDateLabel(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _accountStatusLabel(AccountIdentity account) {
    if (!account.isAnonymous && account.hasEmail) return '已登录';
    if (account.hasEmail) return '待确认';
    return '临时';
  }

  Color _accountStatusColor(AccountIdentity account) {
    if (!account.isAnonymous && account.hasEmail) return AppColors.success;
    if (account.hasEmail) return AppColors.reminder;
    return AppColors.deepPink;
  }

  IconData _accountIcon(AccountIdentity account) {
    if (!account.isAnonymous && account.hasEmail) {
      return Icons.verified_user_rounded;
    }
    if (account.hasEmail) return Icons.mark_email_unread_rounded;
    return Icons.shield_outlined;
  }

  String _accountErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already') || lower.contains('registered')) {
      return '这个邮箱已经注册过，请直接登录已有账号。';
    }
    if (lower.contains('invalid login') || lower.contains('invalid')) {
      return '邮箱或密码不正确，请检查后再试。';
    }
    if (lower.contains('email not confirmed')) {
      return '邮箱还没有确认，请先完成邮箱验证。';
    }
    return '账号操作失败，请稍后再试。';
  }

  String _profileUpdateErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('anniversary') || lower.contains('function')) {
      return '纪念日功能还没同步到数据库，请先应用最新 Supabase 迁移。';
    }
    if (lower.contains('future')) {
      return '纪念日不能选择未来日期。';
    }
    if (lower.contains('active couple')) {
      return '需要先绑定另一半，才能设置情侣纪念日。';
    }
    return '资料更新失败，请稍后再试。';
  }

  String _deleteAccountErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('function') || lower.contains('delete_current_user')) {
      return '注销账号功能还没同步到数据库，请先应用最新 Supabase 迁移。';
    }
    if (lower.contains('authentication')) {
      return '登录状态已失效，请重新进入 App 后再试。';
    }
    return '注销失败，请稍后再试。';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.partnerName,
    required this.togetherDays,
    required this.isBound,
    required this.avatarUrl,
    required this.partnerAvatarUrl,
    required this.accountLabel,
    required this.accountColor,
    required this.isUploading,
    required this.onAvatarTap,
    this.onPartnerAvatarTap,
  });

  final String name;
  final String partnerName;
  final int togetherDays;
  final bool isBound;
  final String? avatarUrl;
  final String? partnerAvatarUrl;
  final String accountLabel;
  final Color accountColor;
  final bool isUploading;
  final VoidCallback onAvatarTap;
  final VoidCallback? onPartnerAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 146,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE6F0), Color(0xFFFFFBFD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.line.withValues(alpha: 0.54),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _ProfileAvatarCluster(
            avatarUrl: avatarUrl,
            partnerAvatarUrl: partnerAvatarUrl,
            isBound: isBound,
            isUploading: isUploading,
            onAvatarTap: onAvatarTap,
            onPartnerAvatarTap: onPartnerAvatarTap,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.section.copyWith(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isBound
                      ? '和 $partnerName 一起进步的第 $togetherDays 天'
                      : '还没有绑定另一半哦～',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    _StatusBadge(label: accountLabel, color: accountColor),
                    _StatusBadge(
                      label: isBound ? '已绑定' : '未绑定',
                      color: isBound
                          ? AppColors.deepPink
                          : AppColors.secondaryText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatarCluster extends StatelessWidget {
  const _ProfileAvatarCluster({
    required this.avatarUrl,
    required this.partnerAvatarUrl,
    required this.isBound,
    required this.isUploading,
    required this.onAvatarTap,
    this.onPartnerAvatarTap,
  });

  final String? avatarUrl;
  final String? partnerAvatarUrl;
  final bool isBound;
  final bool isUploading;
  final VoidCallback onAvatarTap;
  final VoidCallback? onPartnerAvatarTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _CuteAvatar(
            size: 76,
            imageUrl: avatarUrl,
            onTap: onAvatarTap,
            isUploading: isUploading,
            semanticLabel: '预览我的头像',
            borderWidth: 5,
          ),
          if (isBound)
            Positioned(
              left: 50,
              top: 44,
              child: _CuteAvatar(
                size: 38,
                imageUrl: partnerAvatarUrl,
                onTap: onPartnerAvatarTap,
                semanticLabel: 'TA 的头像',
                shadowOpacity: 0.12,
                borderWidth: 3.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 11),
          child: Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.text.withValues(alpha: 0.78),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFFFE1EA).withValues(alpha: 0.78),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Divider(
                      height: 1,
                      indent: 74,
                      endIndent: 18,
                      color: const Color(0xFFF8DCE6).withValues(alpha: 0.72),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return Semantics(
      button: onTap != null,
      label: title,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: hasSubtitle ? 12 : 11,
          ),
          child: Row(
            children: [
              _SettingsIcon(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        color: titleColor ?? AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondaryText,
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class DangerSettingsTile extends StatelessWidget {
  const DangerSettingsTile({
    super.key,
    this.icon = Icons.heart_broken_rounded,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      iconColor: AppColors.deepPink,
      title: title,
      subtitle: subtitle,
      titleColor: AppColors.deepPink,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.deepPink.withValues(alpha: 0.72),
        size: 22,
      ),
      onTap: onTap,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.11)),
      ),
      child: Icon(icon, color: color.withValues(alpha: 0.88), size: 20),
    );
  }
}

class _ActionHint extends StatelessWidget {
  const _ActionHint(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.tiny.copyWith(
            color: AppColors.deepPink.withValues(alpha: 0.78),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          Icons.chevron_right_rounded,
          color: AppColors.secondaryText.withValues(alpha: 0.72),
          size: 20,
        ),
      ],
    );
  }
}

class _MutedTag extends StatelessWidget {
  const _MutedTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.line.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: AppTextStyles.tiny.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _VersionCheckButton extends StatelessWidget {
  const _VersionCheckButton({
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.deepPink,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: AppTextStyles.tiny.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBusy) ...[
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: AppColors.deepPink,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Transform.scale(
        scale: 0.78,
        child: Switch.adaptive(
          value: value,
          activeColor: AppColors.deepPink,
          activeTrackColor: AppColors.lightPink,
          inactiveThumbColor: AppColors.secondaryText.withValues(alpha: 0.62),
          inactiveTrackColor: AppColors.line.withValues(alpha: 0.74),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DoNotDisturbSheet extends StatelessWidget {
  const _DoNotDisturbSheet({
    required this.settings,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final ReminderSettings settings;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.62)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _SettingsIcon(
                  icon: Icons.nights_stay_rounded,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '免打扰时间',
                    style: AppTextStyles.section.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _SettingsSwitch(
                  value: settings.doNotDisturbEnabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '开启后，这个时间段内会减少另一半动态和前台提醒打扰。',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _SoftTimeTile(
              label: '开始时间',
              value: settings.doNotDisturbStart.format(context),
              onTap: onPickStart,
            ),
            const SizedBox(height: 10),
            _SoftTimeTile(
              label: '结束时间',
              value: settings.doNotDisturbEnd.format(context),
              onTap: onPickEnd,
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftTimeTile extends StatelessWidget {
  const _SoftTimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.68),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.deepPink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanReminderSheet extends StatelessWidget {
  const _PlanReminderSheet({required this.plans, required this.onOpenPlans});

  final List<Plan> plans;
  final VoidCallback onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6F9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.62)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _SettingsIcon(
                    icon: Icons.alarm_rounded,
                    color: AppColors.reminder,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '打卡提醒',
                      style: AppTextStyles.section.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '这里集中展示已设置提醒时间的计划。需要调整时，可以进入计划详情编辑提醒时间。',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              if (plans.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '还没有计划开启打卡提醒',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: plans.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      return _PlanReminderRow(plan: plan);
                    },
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onOpenPlans,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    '去计划页调整',
                    style: TextStyle(fontWeight: FontWeight.w900),
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

class _PlanReminderRow extends StatelessWidget {
  const _PlanReminderRow({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _SettingsIcon(icon: plan.icon, color: plan.iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plan.repeatLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _MutedTag(plan.reminderTime?.format(context) ?? '--:--'),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: AppTextStyles.tiny.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

void _showInviteCodeDialog(
  BuildContext context, {
  required String inviteCode,
  required bool hasError,
  required bool isSupabaseConfigured,
}) {
  final displayCode = inviteCode.isEmpty
      ? hasError
            ? '加载失败'
            : isSupabaseConfigured
            ? '加载中...'
            : '未配置'
      : inviteCode;

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('空间邀请码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '把这个邀请码发给 TA，就可以绑定到同一个成长空间。',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            displayCode,
            style: AppTextStyles.display.copyWith(
              color: AppColors.deepPink,
              fontSize: 28,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
        FilledButton.icon(
          onPressed: inviteCode.isEmpty
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: inviteCode));
                  Navigator.of(context).pop();
                  _showSnack(context, '邀请码已复制');
                },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('复制'),
        ),
      ],
    ),
  );
}

class _CuteAvatar extends StatelessWidget {
  const _CuteAvatar({
    this.size = 78,
    this.imageUrl,
    this.onTap,
    this.isUploading = false,
    this.semanticLabel,
    this.shadowOpacity = 0.18,
    this.borderWidth = 3,
  });

  final double size;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool isUploading;
  final String? semanticLabel;
  final double shadowOpacity;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final avatar = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: shadowOpacity),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(borderWidth),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _AvatarImage(imageUrl: imageUrl, size: size),
              if (isUploading)
                ColoredBox(
                  color: Colors.white.withValues(alpha: 0.58),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.deepPink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return avatar;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isUploading ? null : onTap,
        child: avatar,
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return StickerAsset(
        assetPath: AppAssets.bearAvatar,
        placeholderIcon: Icons.face_6_rounded,
        width: size,
        height: size,
        borderRadius: 999,
        backgroundColor: AppColors.lightPink,
      );
    }

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => StickerAsset(
        assetPath: AppAssets.bearAvatar,
        placeholderIcon: Icons.face_6_rounded,
        width: size,
        height: size,
        borderRadius: 999,
        backgroundColor: AppColors.lightPink,
      ),
    );
  }
}

Future<T?> showAppCuteDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.40),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class AppCuteDialog extends StatelessWidget {
  const AppCuteDialog({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    required this.primaryText,
    this.secondaryText,
    this.cancelText,
    this.onPrimary,
    this.onSecondary,
    this.onCancel,
    this.isDanger = false,
    this.children = const [],
  });

  final String title;
  final String description;
  final Widget? icon;
  final String primaryText;
  final String? secondaryText;
  final String? cancelText;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final VoidCallback? onCancel;
  final bool isDanger;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final primaryColor = isDanger ? AppColors.deepPink : AppColors.deepPink;

    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6F9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.62)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (icon != null) ...[icon!, const SizedBox(width: 14)],
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTextStyles.section.copyWith(
                                  color: AppColors.text,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.secondaryText,
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (onCancel != null) ...[
                        const SizedBox(width: 10),
                        DialogCloseButton(onPressed: onCancel),
                      ],
                    ],
                  ),
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...children,
                  ],
                  const SizedBox(height: 20),
                  if (secondaryText != null) ...[
                    DialogSecondaryButton(
                      text: secondaryText!,
                      onPressed: onSecondary,
                    ),
                    const SizedBox(height: 10),
                  ],
                  DialogPrimaryButton(
                    text: primaryText,
                    color: primaryColor,
                    onPressed: onPrimary,
                  ),
                  if (cancelText != null && onCancel != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondaryText,
                        minimumSize: const Size.fromHeight(38),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        cancelText!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DialogIconBadge extends StatelessWidget {
  const DialogIconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.deepPink,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.11),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class DialogInfoCard extends StatelessWidget {
  const DialogInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.54)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightPink.withValues(alpha: 0.62),
              ),
              child: Icon(icon, color: AppColors.deepPink, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.secondaryText,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DialogPrimaryButton extends StatelessWidget {
  const DialogPrimaryButton({
    super.key,
    required this.text,
    required this.color,
    this.onPressed,
  });

  final String text;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              color,
              Color.lerp(color, AppColors.primary, 0.35) ?? color,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: onPressed == null ? 0 : 0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}

class DialogSecondaryButton extends StatelessWidget {
  const DialogSecondaryButton({super.key, required this.text, this.onPressed});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.deepPink,
          disabledForegroundColor: AppColors.deepPink.withValues(alpha: 0.42),
          backgroundColor: AppColors.lightPink.withValues(alpha: 0.42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
        ),
        child: Text(text),
      ),
    );
  }
}

class DialogCloseButton extends StatelessWidget {
  const DialogCloseButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.64),
        foregroundColor: AppColors.secondaryText,
        fixedSize: const Size(36, 36),
        shape: const CircleBorder(),
      ),
      icon: const Icon(Icons.close_rounded, size: 20),
      tooltip: '关闭',
    );
  }
}

class _IncomingInvitationCard extends StatefulWidget {
  const _IncomingInvitationCard({
    required this.invitation,
    required this.repository,
    required this.onChanged,
  });

  final CoupleInvitation invitation;
  final ProfileRepository repository;
  final VoidCallback onChanged;

  @override
  State<_IncomingInvitationCard> createState() =>
      _IncomingInvitationCardState();
}

class _IncomingInvitationCardState extends State<_IncomingInvitationCard> {
  bool _isSubmitting = false;

  Future<void> _accept() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.acceptCoupleInvitation(widget.invitation.id);
      if (!mounted) return;
      widget.onChanged();
      _showSnack(context, '绑定成功，你们可以一起进步啦！');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      if (error.message.contains('already has an active couple relationship')) {
        widget.onChanged();
        _showSnack(context, '已经绑定啦，正在刷新状态');
      } else {
        _showSnack(context, '同意失败，请再试一次。');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _decline() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.declineCoupleInvitation(widget.invitation.id);
      if (!mounted) return;
      widget.onChanged();
      _showSnack(context, '已拒绝这条绑定申请');
    } catch (error, stackTrace) {
      debugPrint('Decline couple invitation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showSnack(context, '拒绝失败，请再试一次。');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(AppSpacing.md),
      showDashedBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('收到绑定申请', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '有人想和你成为一起进步的另一半，同意后才会正式绑定。',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _decline,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('拒绝'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _accept,
                  icon: const Icon(Icons.favorite_rounded),
                  label: Text(_isSubmitting ? '处理中...' : '同意'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BindPartnerCard extends StatefulWidget {
  const _BindPartnerCard({required this.repository, required this.onSent});

  final ProfileRepository repository;
  final VoidCallback onSent;

  @override
  State<_BindPartnerCard> createState() => _BindPartnerCardState();
}

class _BindPartnerCardState extends State<_BindPartnerCard> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final code = _controller.text.trim();
    if (code.isEmpty) {
      _showSnack(context, '请输入 TA 的邀请码');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.createCoupleInvitationByInviteCode(code);
      if (!mounted) return;
      _controller.clear();
      widget.onSent();
      _showSnack(context, '绑定申请已发送，等 TA 同意哦。');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = error.message;
      if (message.contains('already has an active couple relationship')) {
        _controller.clear();
        widget.onSent();
        _showSnack(context, '已经绑定啦，正在刷新状态');
      } else if (message.contains('invite code not found')) {
        _showSnack(context, '邀请码不太对哦，检查一下再输入吧。');
      } else if (message.contains('cannot invite yourself')) {
        _showSnack(context, '不能给自己发绑定申请哦。');
      } else {
        _showSnack(context, '申请发送失败，请再试一次。');
      }
    } catch (error, stackTrace) {
      debugPrint('Create couple invitation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showSnack(context, '申请发送失败，请检查网络后再试。');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(AppSpacing.md),
      showDashedBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('发送绑定申请', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: '输入 TA 的邀请码',
              prefixIcon: Icon(Icons.favorite_border_rounded),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: _isSubmitting ? '发送中...' : '发送申请',
            icon: Icons.favorite_rounded,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _EmailPasswordCredentials {
  const _EmailPasswordCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

Future<String?> _showTextInputDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  required IconData icon,
  required String? Function(String value) validator,
  bool obscureText = false,
  TextInputType? keyboardType,
  String? initialValue,
}) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _SingleTextInputDialog(
      title: title,
      hintText: hintText,
      icon: icon,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      initialValue: initialValue,
    ),
  );
}

class _SingleTextInputDialog extends StatefulWidget {
  const _SingleTextInputDialog({
    required this.title,
    required this.hintText,
    required this.icon,
    required this.validator,
    required this.obscureText,
    this.keyboardType,
    this.initialValue,
  });

  final String title;
  final String hintText;
  final IconData icon;
  final String? Function(String value) validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? initialValue;

  @override
  State<_SingleTextInputDialog> createState() => _SingleTextInputDialogState();
}

class _SingleTextInputDialogState extends State<_SingleTextInputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.validator(value);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(widget.icon),
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}

Future<_EmailPasswordCredentials?> _showEmailPasswordDialog(
  BuildContext context,
) async {
  return showDialog<_EmailPasswordCredentials>(
    context: context,
    builder: (_) => const _EmailPasswordDialog(),
  );
}

class _EmailPasswordDialog extends StatefulWidget {
  const _EmailPasswordDialog();

  @override
  State<_EmailPasswordDialog> createState() => _EmailPasswordDialogState();
}

class _EmailPasswordDialogState extends State<_EmailPasswordDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final emailValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    final passwordValid = password.length >= 6;
    if (!emailValid || !passwordValid) {
      setState(() {
        _emailError = emailValid ? null : '请输入有效邮箱';
        _passwordError = passwordValid ? null : '密码至少 6 位';
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(_EmailPasswordCredentials(email: email, password: password));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登录已有账号'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: '邮箱',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              errorText: _emailError,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: '密码',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              errorText: _passwordError,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _submit, child: const Text('登录')),
      ],
    );
  }
}

void _showAboutUsDialog(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: '一起进步呀',
    applicationVersion: '1.0.0',
    applicationIcon: Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.lightPink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.favorite_rounded,
        color: AppColors.deepPink,
        size: 36,
      ),
    ),
    children: const [
      Text('和 TA 一起，把今天过得更好。'),
      SizedBox(height: AppSpacing.md),
      SelectableText('联系开发者：song3286791241@gmail.com'),
    ],
  );
}

void _showAppVersionDialog(
  BuildContext context, {
  required Future<_AppVersionInfo> versionInfoFuture,
  String? statusMessage,
  VoidCallback? onCheckUpdate,
  String checkButtonLabel = '检查更新',
  bool isChecking = false,
}) {
  showAppCuteDialog<void>(
    context,
    builder: (dialogContext) => FutureBuilder<_AppVersionInfo>(
      future: versionInfoFuture,
      initialData: const _AppVersionInfo(
        appVersion: _ProfileInfoCardState._appVersion,
      ),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return AppCuteDialog(
          icon: const DialogIconBadge(
            icon: Icons.system_update_alt_rounded,
            color: AppColors.lavender,
          ),
          title: '当前版本',
          description: info?.description ?? '正在读取当前安装的版本和远程补丁信息。',
          primaryText: '知道了',
          onPrimary: () => Navigator.of(dialogContext).pop(),
          onCancel: () => Navigator.of(dialogContext).pop(),
          children: [
            _VersionInfoCard(
              appVersion: info?.appVersion ?? _ProfileInfoCardState._appVersion,
              patchLabel: info?.patchLabel ?? '读取中',
              statusMessage: statusMessage,
              checkButtonLabel: checkButtonLabel,
              isChecking: isChecking,
              onCheckUpdate: onCheckUpdate,
            ),
          ],
        );
      },
    ),
  );
}

class _VersionInfoCard extends StatelessWidget {
  const _VersionInfoCard({
    required this.appVersion,
    required this.patchLabel,
    this.statusMessage,
    required this.checkButtonLabel,
    required this.isChecking,
    this.onCheckUpdate,
  });

  final String appVersion;
  final String patchLabel;
  final String? statusMessage;
  final String checkButtonLabel;
  final bool isChecking;
  final VoidCallback? onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.58)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            _VersionInfoRow(label: 'App 版本', value: appVersion),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                height: 1,
                color: AppColors.line.withValues(alpha: 0.55),
              ),
            ),
            _VersionInfoRow(label: '远程补丁', value: patchLabel),
            if (statusMessage != null && statusMessage!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: AppColors.line.withValues(alpha: 0.55),
                ),
              ),
              _VersionInfoRow(label: '更新状态', value: statusMessage!),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _VersionCheckButton(
                label: checkButtonLabel,
                isBusy: isChecking,
                onPressed: onCheckUpdate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionInfoRow extends StatelessWidget {
  const _VersionInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

void _showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
