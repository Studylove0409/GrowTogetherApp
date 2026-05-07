import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_page.dart';
import 'features/plans/plans_page.dart';
import 'features/profile/profile_page.dart';
import 'features/reminders/reminders_page.dart';
import 'shared/widgets/app_bottom_nav_bar.dart';

class GrowTogetherApp extends StatelessWidget {
  const GrowTogetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '一起进步呀',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      home: const GrowTogetherShell(),
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
      ProfilePage(onOpenPlans: () => setState(() => _selectedIndex = 1)),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: false,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AppBottomNavBar(
            selectedIndex: _selectedIndex,
            onSelected: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
        ),
      ),
    );
  }
}
