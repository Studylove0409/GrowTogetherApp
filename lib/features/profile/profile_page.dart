import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/config/supabase_config.dart';
import '../../data/models/couple_invitation.dart';
import '../../data/models/profile.dart';
import '../../data/store/store.dart';
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

class _ProfilePageState extends State<ProfilePage> {
  final _profileRepository = const ProfileRepository();
  late Future<_ProfilePageData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadProfile();
    });
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
      return _ProfilePageData(profile: _unboundFallbackProfile);
    }

    try {
      final profile = await _profileRepository.getCurrentProfile();
      final invitations = profile.isBound
          ? const <CoupleInvitation>[]
          : await _profileRepository.getPendingIncomingCoupleInvitations();
      return _ProfilePageData(profile: profile, invitations: invitations);
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
      initialData: _ProfilePageData(profile: _unboundFallbackProfile),
      builder: (context, snapshot) {
        final data =
            snapshot.data ?? _ProfilePageData(profile: _unboundFallbackProfile);
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
                AppSpacing.lg,
                AppSpacing.md,
                132,
              ),
              children: [
                const Center(child: Text('我的', style: AppTextStyles.display)),
                const SizedBox(height: AppSpacing.xl),
                _ProfileInfoCard(
                  name: profile.name,
                  partnerName: profile.partnerName,
                  togetherDays: profile.togetherDays,
                  isBound: profile.isBound,
                ),
                const SizedBox(height: AppSpacing.lg),
                _InviteCodeCard(
                  inviteCode: profile.inviteCode,
                  hasError: hasError,
                  isSupabaseConfigured: SupabaseConfig.isConfigured,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!profile.isBound) ...[
                  if (data.invitations.isNotEmpty) ...[
                    _IncomingInvitationCard(
                      invitation: data.invitations.first,
                      repository: _profileRepository,
                      onChanged: _refreshProfile,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _BindPartnerCard(
                    repository: _profileRepository,
                    onSent: _refreshProfile,
                  ),
                ] else ...[
                  _EndRelationshipCard(
                    repository: _profileRepository,
                    onEnded: _refreshProfile,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _SettingsList(onOpenPlans: widget.onOpenPlans),
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
}

class _ProfilePageData {
  const _ProfilePageData({required this.profile, this.invitations = const []});

  final Profile profile;
  final List<CoupleInvitation> invitations;
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.name,
    required this.partnerName,
    required this.togetherDays,
    required this.isBound,
  });

  final String name;
  final String partnerName;
  final int togetherDays;
  final bool isBound;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const _CuteAvatar(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isBound
                      ? '和 $partnerName 一起进步的第 $togetherDays 天'
                      : '还没有绑定另一半哦～',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusPill(
            label: isBound ? '已绑定' : '待绑定',
            icon: isBound
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: isBound ? AppColors.deepPink : AppColors.secondaryText,
          ),
        ],
      ),
    );
  }
}

class _CuteAvatar extends StatelessWidget {
  const _CuteAvatar();

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
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const StickerAsset(
            assetPath: AppAssets.bearAvatar,
            placeholderIcon: Icons.face_6_rounded,
            width: 78,
            height: 78,
            borderRadius: 999,
            backgroundColor: AppColors.lightPink,
          ),
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.inviteCode,
    required this.hasError,
    required this.isSupabaseConfigured,
  });

  final String inviteCode;
  final bool hasError;
  final bool isSupabaseConfigured;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      backgroundColor: AppColors.lightPink.withValues(alpha: 0.42),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const AppIconTile(
            icon: Icons.card_giftcard_rounded,
            color: AppColors.deepPink,
            size: 58,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我们的空间邀请码',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  inviteCode.isEmpty
                      ? hasError
                            ? '加载失败'
                            : isSupabaseConfigured
                            ? '加载中...'
                            : '未配置'
                      : inviteCode,
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.deepPink,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: '复制邀请码',
            child: IconButton(
              onPressed: () {
                if (inviteCode.isEmpty) {
                  _showSnack(
                    context,
                    hasError
                        ? '邀请码加载失败，请重启 App 再试'
                        : isSupabaseConfigured
                        ? '邀请码加载中，请稍等一下'
                        : '请用 SUPABASE_ANON_KEY 启动这个模拟器',
                  );
                  return;
                }
                Clipboard.setData(ClipboardData(text: inviteCode));
                _showSnack(context, '邀请码已复制');
              },
              icon: const Icon(
                Icons.copy_rounded,
                color: AppColors.deepPink,
                size: 28,
              ),
            ),
          ),
        ],
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
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.lg),
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

class _EndRelationshipCard extends StatefulWidget {
  const _EndRelationshipCard({required this.repository, required this.onEnded});

  final ProfileRepository repository;
  final VoidCallback onEnded;

  @override
  State<_EndRelationshipCard> createState() => _EndRelationshipCardState();
}

class _EndRelationshipCardState extends State<_EndRelationshipCard> {
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
    return AppCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('情侣绑定', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '解除后，你们需要重新输入邀请码才能再次绑定。',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: _isSubmitting ? '解除中...' : '解除绑定',
            icon: Icons.heart_broken_rounded,
            onPressed: _confirmAndEnd,
          ),
        ],
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({required this.onOpenPlans});

  final VoidCallback onOpenPlans;

  static const _items = [
    _MenuItem(Icons.event_note_rounded, '我的计划', AppColors.lavender),
    _MenuItem(Icons.info_rounded, '关于我们', AppColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < _items.length; index++)
            ProfileMenuItem(
              icon: _items[index].icon,
              label: _items[index].label,
              color: _items[index].color,
              showDivider: index != _items.length - 1,
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
