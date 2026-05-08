import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../shared/widgets/app_icon_tile.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/profile_menu_item.dart';
import '../../shared/widgets/status_pill.dart';
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

        return AppScaffold(
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                128,
              ),
              children: [
                const _ProfilePageTitle(),
                const SizedBox(height: AppSpacing.md),
                _ProfileInfoCard(
                  name: profile.name,
                  partnerName: profile.partnerName,
                  togetherDays: profile.togetherDays,
                  isBound: profile.isBound,
                  inviteCode: profile.inviteCode,
                  hasInviteError: hasError,
                  isSupabaseConfigured: SupabaseConfig.isConfigured,
                  account: data.account,
                  repository: _accountRepository,
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
                const SizedBox(height: AppSpacing.md),
                _SettingsList(
                  onOpenPlans: widget.onOpenPlans,
                  isBound: profile.isBound,
                  repository: _profileRepository,
                  onRelationshipChanged: _refreshProfile,
                ),
              ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我的', style: AppTextStyles.display.copyWith(fontSize: 30)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '账号、绑定和空间设置',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    required this.inviteCode,
    required this.hasInviteError,
    required this.isSupabaseConfigured,
    required this.account,
    required this.repository,
    required this.onAccountChanged,
  });

  final String name;
  final String partnerName;
  final int togetherDays;
  final bool isBound;
  final String inviteCode;
  final bool hasInviteError;
  final bool isSupabaseConfigured;
  final AccountIdentity account;
  final AccountRepository repository;
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

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final accountColor = _accountStatusColor(account);
    final accountLabel = _accountStatusLabel(account);

    return AppCard(
      borderRadius: 26,
      backgroundColor: AppColors.cream,
      padding: const EdgeInsets.all(AppSpacing.lg),
      showDashedBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CuteAvatar(size: 68),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(fontSize: 23),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.isBound
                          ? '和 ${widget.partnerName} 一起进步的第 ${widget.togetherDays} 天'
                          : '还没有绑定另一半哦～',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        StatusPill(
                          label: accountLabel,
                          icon: account.isRecoverable
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          color: accountColor,
                          compact: true,
                        ),
                        StatusPill(
                          label: widget.isBound ? '已绑定' : '待绑定',
                          icon: widget.isBound
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: widget.isBound
                              ? AppColors.deepPink
                              : AppColors.secondaryText,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ProfileQuickAction(
                  icon: Icons.card_giftcard_rounded,
                  label: '我们的空间邀请码',
                  value: '点击查看',
                  color: AppColors.deepPink,
                  onTap: () => _showInviteCodeDialog(
                    context,
                    inviteCode: widget.inviteCode,
                    hasError: widget.hasInviteError,
                    isSupabaseConfigured: widget.isSupabaseConfigured,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ProfileQuickAction(
                  icon: account.isEmailConfirmed
                      ? Icons.lock_rounded
                      : Icons.login_rounded,
                  label: account.isEmailConfirmed ? '设置密码' : '登录账号',
                  value: account.isEmailConfirmed ? '邮箱已认证' : '邮箱登录',
                  color: accountColor,
                  onTap: account.isEmailConfirmed ? _setPassword : _signIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _AccountSecurityPanel(
            account: account,
            color: accountColor,
            title: _accountTitle(account),
            description: account.isConfigured
                ? _accountDescription(account)
                : '当前没有连接 Supabase，账号保护不可用。',
            icon: _accountIcon(account),
            isSubmitting: _isSubmitting,
            onPrimary: account.isEmailConfirmed ? _setPassword : _linkEmail,
            onSignIn: _signIn,
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _accountTitle(AccountIdentity account) {
    if (account.isEmailConfirmed) return '邮箱已认证';
    if (account.hasEmail) return '邮箱待确认';
    return '保护你的账号';
  }

  String _accountDescription(AccountIdentity account) {
    if (account.isEmailConfirmed) {
      return '已认证 ${account.email}。继续设置密码后，换手机也能用邮箱密码登录。';
    }
    if (account.hasEmail) {
      return '已发送验证邮件到 ${account.email}，确认邮箱后再设置密码。';
    }
    return '现在还是临时账号。绑定邮箱后，卸载 App 或换手机也能找回数据。';
  }

  String _accountStatusLabel(AccountIdentity account) {
    if (account.isEmailConfirmed) return '已认证';
    if (account.hasEmail) return '待确认';
    return '临时';
  }

  Color _accountStatusColor(AccountIdentity account) {
    if (account.isEmailConfirmed) return AppColors.success;
    if (account.hasEmail) return AppColors.reminder;
    return AppColors.deepPink;
  }

  IconData _accountIcon(AccountIdentity account) {
    if (account.isEmailConfirmed) return Icons.lock_rounded;
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

class _ProfileQuickAction extends StatelessWidget {
  const _ProfileQuickAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.tiny.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSecurityPanel extends StatelessWidget {
  const _AccountSecurityPanel({
    required this.account,
    required this.color,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSubmitting,
    required this.onPrimary,
    required this.onSignIn,
  });

  final AccountIdentity account;
  final Color color;
  final String title;
  final String description;
  final IconData icon;
  final bool isSubmitting;
  final VoidCallback onPrimary;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.84),
                    ),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.section.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            if (account.isConfigured) ...[
              const SizedBox(height: AppSpacing.md),
              _AccountActionButtons(
                account: account,
                isSubmitting: isSubmitting,
                onPrimary: onPrimary,
                onSignIn: onSignIn,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountActionButtons extends StatelessWidget {
  const _AccountActionButtons({
    required this.account,
    required this.isSubmitting,
    required this.onPrimary,
    required this.onSignIn,
  });

  final AccountIdentity account;
  final bool isSubmitting;
  final VoidCallback onPrimary;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = account.isEmailConfirmed
        ? '设置/更新密码'
        : account.hasEmail
        ? '重发验证'
        : '绑定邮箱';
    final primaryIcon = account.isEmailConfirmed
        ? Icons.lock_rounded
        : Icons.mail_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: isSubmitting ? null : onPrimary,
          icon: Icon(primaryIcon),
          label: Text(primaryLabel),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          onPressed: isSubmitting ? null : onSignIn,
          icon: const Icon(Icons.login_rounded),
          label: const Text('登录已有账号'),
        ),
      ],
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
  const _CuteAvatar({this.size = 78});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: StickerAsset(
            assetPath: AppAssets.bearAvatar,
            placeholderIcon: Icons.face_6_rounded,
            width: size,
            height: size,
            borderRadius: 999,
            backgroundColor: AppColors.lightPink,
          ),
        ),
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

class _SettingsList extends StatelessWidget {
  const _SettingsList({
    required this.onOpenPlans,
    required this.isBound,
    required this.repository,
    required this.onRelationshipChanged,
  });

  final VoidCallback onOpenPlans;
  final bool isBound;
  final ProfileRepository repository;
  final VoidCallback onRelationshipChanged;

  static const _items = [
    _MenuItem(Icons.event_note_rounded, '我的计划', AppColors.lavender),
    _MenuItem(Icons.info_rounded, '关于我们', AppColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      showDashedBorder: false,
      child: Column(
        children: [
          for (var index = 0; index < _items.length; index++)
            ProfileMenuItem(
              icon: _items[index].icon,
              label: _items[index].label,
              color: _items[index].color,
              showDivider: index != _items.length - 1 || isBound,
              onTap: () {
                switch (_items[index].label) {
                  case '我的计划':
                    onOpenPlans();
                  case '关于我们':
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
                      children: [
                        const Text('和 TA 一起，把今天过得更好。'),
                        const SizedBox(height: AppSpacing.md),
                        const SelectableText('联系开发者：song3286791241@gmail.com'),
                      ],
                    );
                }
              },
            ),
          if (isBound)
            _RelationshipMenuPanel(
              repository: repository,
              onEnded: onRelationshipChanged,
            ),
        ],
      ),
    );
  }
}

class _RelationshipMenuPanel extends StatefulWidget {
  const _RelationshipMenuPanel({
    required this.repository,
    required this.onEnded,
  });

  final ProfileRepository repository;
  final VoidCallback onEnded;

  @override
  State<_RelationshipMenuPanel> createState() => _RelationshipMenuPanelState();
}

class _RelationshipMenuPanelState extends State<_RelationshipMenuPanel> {
  bool _isSubmitting = false;

  Future<void> _confirmAndEnd() async {
    if (_isSubmitting) {
      return;
    }

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

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.endCurrentCoupleRelationship();
      if (!mounted) return;
      widget.onEnded();
      _showSnack(context, '已解除绑定');
    } catch (_) {
      if (!mounted) return;
      _showSnack(context, '好像哪里出错啦，请再试一次～');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        12,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconTile(
                icon: Icons.favorite_rounded,
                color: AppColors.deepPink,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '情侣绑定',
                  style: AppTextStyles.section.copyWith(fontSize: 17),
                ),
              ),
              const StatusPill(
                label: '已绑定',
                icon: Icons.favorite_rounded,
                color: AppColors.deepPink,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Text(
              '解除后，你们需要重新输入邀请码才能再次绑定。',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isSubmitting ? null : _confirmAndEnd,
                  icon: const Icon(Icons.heart_broken_rounded, size: 18),
                  label: Text(_isSubmitting ? '解除中...' : '解除绑定'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.deepPink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
