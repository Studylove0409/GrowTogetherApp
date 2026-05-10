import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/config/supabase_config.dart';
import '../../core/notification/fcm_service.dart';
import '../../data/models/account_identity.dart';
import '../../data/models/couple_invitation.dart';
import '../../data/models/profile.dart';
import '../../data/store/store.dart';
import '../../data/supabase/account_repository.dart';
import '../../data/supabase/profile_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && widget.isSelected) {
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
                    inviteCode: profile.inviteCode,
                    hasInviteError: hasError,
                    isSupabaseConfigured: SupabaseConfig.isConfigured,
                    account: data.account,
                    repository: _accountRepository,
                    profileRepository: _profileRepository,
                    onOpenPlans: widget.onOpenPlans,
                    onRelationshipChanged: _refreshProfile,
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
          Positioned(
            right: 0,
            child: _CircleIconButton(
              icon: Icons.tune_rounded,
              tooltip: '设置',
              onPressed: () => _showSnack(context, '设置功能准备中'),
            ),
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
    required this.inviteCode,
    required this.hasInviteError,
    required this.isSupabaseConfigured,
    required this.account,
    required this.repository,
    required this.profileRepository,
    required this.onOpenPlans,
    required this.onRelationshipChanged,
    required this.onAccountChanged,
  });

  final String name;
  final String partnerName;
  final int togetherDays;
  final bool isBound;
  final String? avatarUrl;
  final String? partnerAvatarUrl;
  final String inviteCode;
  final bool hasInviteError;
  final bool isSupabaseConfigured;
  final AccountIdentity account;
  final AccountRepository repository;
  final ProfileRepository profileRepository;
  final VoidCallback onOpenPlans;
  final VoidCallback onRelationshipChanged;
  final Future<void> Function() onAccountChanged;

  @override
  State<_ProfileInfoCard> createState() => _ProfileInfoCardState();
}

class _ProfileInfoCardState extends State<_ProfileInfoCard> {
  bool _isSubmitting = false;

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

    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 86,
    );
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

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final accountColor = _accountStatusColor(account);
    final accountLabel = _accountStatusLabel(account);

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
          onAvatarTap: _pickAndUploadAvatar,
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: '账号与空间',
          children: [
            SettingsTile(
              icon: Icons.card_giftcard_rounded,
              iconColor: AppColors.deepPink,
              title: '我们的空间邀请码',
              onTap: () => _showInviteCodeDialog(
                context,
                inviteCode: widget.inviteCode,
                hasError: widget.hasInviteError,
                isSupabaseConfigured: widget.isSupabaseConfigured,
              ),
            ),
            SettingsTile(
              icon: account.isEmailConfirmed
                  ? Icons.lock_rounded
                  : Icons.login_rounded,
              iconColor: accountColor,
              title: '登录账号',
              subtitle: account.isEmailConfirmed ? account.email : null,
              onTap: account.isEmailConfirmed ? _setPassword : _signIn,
            ),
            SettingsTile(
              icon: _accountIcon(account),
              iconColor: accountColor,
              title: '保护你的账号',
              subtitle: account.isConfigured
                  ? _accountDescription(account)
                  : '当前没有连接 Supabase，账号保护不可用。',
              trailing: account.isEmailConfirmed
                  ? const _MutedTag('已保护')
                  : const _ActionHint('去绑定'),
              onTap: account.isConfigured
                  ? (account.isEmailConfirmed ? _setPassword : _linkEmail)
                  : null,
            ),
            SettingsTile(
              icon: Icons.event_note_rounded,
              iconColor: AppColors.lavender,
              title: '我的计划',
              onTap: widget.onOpenPlans,
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
            if (widget.isBound)
              DangerSettingsTile(
                title: _isSubmitting ? '解除中...' : '解除绑定',
                subtitle: '解除后，你们需要重新输入邀请码才能再次绑定。',
                onTap: _isSubmitting ? null : _confirmAndEndRelationship,
              ),
          ],
        ),
        const SizedBox(height: 26),
        _SettingsSection(
          title: '更多',
          children: [
            SettingsTile(
              icon: Icons.info_rounded,
              iconColor: AppColors.success,
              title: '关于我们',
              onTap: () => _showAboutUsDialog(context),
            ),
            SettingsTile(
              icon: Icons.settings_rounded,
              iconColor: AppColors.secondaryText,
              title: '设置',
              onTap: () => _showSnack(context, '设置功能准备中'),
            ),
            if (!account.isAnonymous)
              DangerSettingsTile(
                icon: Icons.logout_rounded,
                title: _isSubmitting ? '退出中...' : '退出登录',
                subtitle: '退出后会切换为新的临时账号。',
                onTap: _isSubmitting ? null : _signOut,
              ),
          ],
        ),
      ],
    );
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
  });

  final String? avatarUrl;
  final String? partnerAvatarUrl;
  final bool isBound;
  final bool isUploading;
  final VoidCallback onAvatarTap;

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
            semanticLabel: '上传我的头像',
            borderWidth: 5,
          ),
          if (isBound)
            Positioned(
              left: 50,
              top: 44,
              child: _CuteAvatar(
                size: 38,
                imageUrl: partnerAvatarUrl,
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
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isUploading ? null : onTap,
          child: avatar,
        ),
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
  });

  final String title;
  final String hintText;
  final IconData icon;
  final String? Function(String value) validator;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  State<_SingleTextInputDialog> createState() => _SingleTextInputDialogState();
}

class _SingleTextInputDialogState extends State<_SingleTextInputDialog> {
  final _controller = TextEditingController();
  String? _errorText;

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

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
