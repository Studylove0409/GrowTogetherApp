import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/supabase_config.dart';
import 'core/notification/fcm_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/mock/mock_store.dart';
import 'data/store/store.dart';
import 'data/supabase/supabase_store.dart';
import 'features/focus/focus_page.dart';
import 'features/home/home_page.dart';
import 'features/plans/plans_page.dart';
import 'features/profile/profile_page.dart';
import 'features/reminders/reminders_page.dart';
import 'shared/widgets/app_bottom_nav_bar.dart';

class GrowTogetherApp extends StatelessWidget {
  const GrowTogetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<Store>.value(
      value: SupabaseConfig.isConfigured ? SupabaseStore() : MockStore.instance,
      child: MaterialApp(
        title: '一起进步呀',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.light,
        home: const GrowTogetherShell(),
      ),
    );
  }
}

class GrowTogetherShell extends StatefulWidget {
  const GrowTogetherShell({super.key});

  @override
  State<GrowTogetherShell> createState() => _GrowTogetherShellState();
}

class _GrowTogetherShellState extends State<GrowTogetherShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Future<void>? _resumeRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(FcmService.syncTokenToCurrentUser());
    _resumeRefresh ??= context.read<Store>().refreshAll().whenComplete(() {
      _resumeRefresh = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final reminderBadgeCount = context.select<Store, int>(
      (store) => store.reminderBadgeCount,
    );
    final pages = [
      HomePage(isSelected: _selectedIndex == 0),
      PlansPage(isSelected: _selectedIndex == 1),
      FocusPage(isSelected: _selectedIndex == 2),
      RemindersPage(
        isSelected: _selectedIndex == 3,
        onOpenFocus: () => setState(() => _selectedIndex = 2),
      ),
      ProfilePage(
        isSelected: _selectedIndex == 4,
        onOpenPlans: () => setState(() => _selectedIndex = 1),
      ),
    ];

    final mediaQuery = MediaQuery.of(context);
    final bottomSafeArea = mediaQuery.padding.bottom;
    final dockAvoidanceInset =
        AppBottomNavBar.height + AppBottomNavBar.bottomGap;
    final contentMediaQuery = mediaQuery.copyWith(
      padding: mediaQuery.padding.copyWith(
        bottom: bottomSafeArea + dockAvoidanceInset,
      ),
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: contentMediaQuery,
              child: IndexedStack(index: _selectedIndex, children: pages),
            ),
          ),
          Positioned(
            left: AppBottomNavBar.horizontalMargin,
            right: AppBottomNavBar.horizontalMargin,
            bottom: bottomSafeArea + AppBottomNavBar.bottomGap,
            child: AppBottomNavBar(
              selectedIndex: _selectedIndex,
              onSelected: (index) {
                if (index == _selectedIndex) return;
                setState(() => _selectedIndex = index);
                if (index == 2) {
                  unawaited(store.refreshFocusSessions());
                }
                if (index == 3) {
                  unawaited(store.refreshFocusSessions());
                  unawaited(store.refreshReminders());
                  unawaited(store.markReceivedRemindersRead());
                }
              },
              reminderBadgeCount: reminderBadgeCount,
            ),
          ),
        ],
      ),
    );
  }
}
