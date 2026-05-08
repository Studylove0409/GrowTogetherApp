import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/mock/mock_store.dart';
import 'data/store/store.dart';
import 'data/supabase/supabase_store.dart';
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

class _GrowTogetherShellState extends State<GrowTogetherShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const PlansPage(),
      const RemindersPage(),
      ProfilePage(
        isSelected: _selectedIndex == 3,
        onOpenPlans: () => setState(() => _selectedIndex = 1),
      ),
    ];

    final store = context.watch<Store>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: AppBottomNavBar(
          selectedIndex: _selectedIndex,
          onSelected: (index) {
            setState(() => _selectedIndex = index);
            if (index == 2) {
              store.markReceivedRemindersRead();
            }
          },
          reminderBadgeCount: store.unreadReminderCount,
        ),
      ),
    );
  }
}
