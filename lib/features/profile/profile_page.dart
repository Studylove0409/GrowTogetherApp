import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock/mock_data.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_tile.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/profile_menu_item.dart';
import '../../shared/widgets/status_pill.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.onOpenPlans});

  final VoidCallback onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final profile = MockData.profile;

    return AppScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          32,
        ),
        children: [
            const Center(child: Text('我的', style: AppTextStyles.display)),
            const SizedBox(height: AppSpacing.xl),
            _ProfileInfoCard(
              name: profile.name,
              partnerName: profile.partnerName,
              togetherDays: profile.togetherDays,
            ),
            const SizedBox(height: AppSpacing.lg),
            _InviteCodeCard(inviteCode: profile.inviteCode),
            const SizedBox(height: AppSpacing.lg),
            _SettingsList(onOpenPlans: onOpenPlans),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: '退出登录',
              icon: Icons.logout_rounded,
              onPressed: () => _showSnack(context, '退出登录功能开发中'),
            ),
          ],
        ),
      );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.name,
    required this.partnerName,
    required this.togetherDays,
  });

  final String name;
  final String partnerName;
  final int togetherDays;

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
                  '和 $partnerName 一起进步的第 $togetherDays 天',
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
          const StatusPill(
            label: '已绑定',
            icon: Icons.favorite_rounded,
            color: AppColors.deepPink,
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
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.lightPink, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.face_rounded,
              color: AppColors.deepPink,
              size: 34,
            ),
          ),
          const Positioned(
            top: 7,
            right: 12,
            child: Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.inviteCode});

  final String inviteCode;

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
                  inviteCode,
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

class _SettingsList extends StatelessWidget {
  const _SettingsList({required this.onOpenPlans});

  final VoidCallback onOpenPlans;

  static const _items = [
    _MenuItem(Icons.event_note_rounded, '我的计划', AppColors.lavender),
    _MenuItem(Icons.notifications_rounded, '提醒设置', AppColors.reminder),
    _MenuItem(Icons.volume_up_rounded, '打卡声音', AppColors.success),
    _MenuItem(Icons.lock_rounded, '隐私设置', AppColors.primary),
    _MenuItem(Icons.help_rounded, '帮助与反馈', AppColors.lavender),
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
                if (_items[index].label == '我的计划') {
                  onOpenPlans();
                  return;
                }
                _showSnack(context, '功能开发中');
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
