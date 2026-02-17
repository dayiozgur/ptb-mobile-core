import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../dashboard/screens/monitoring_dashboard_screen.dart';
import '../../alarms/screens/global_alarms_screen.dart';
import '../../site/screens/sites_list_screen.dart';
import '../../map/screens/site_map_screen.dart';
import '../../settings/screens/settings_screen.dart';

/// MainShellScreen tab index'ini alt widget'lardan degistirmek icin
class MainShellScope extends InheritedWidget {
  final void Function(int tabIndex) switchTab;

  const MainShellScope({
    super.key,
    required this.switchTab,
    required super.child,
  });

  static MainShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellScope>();
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) => false;
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  int _activeAlarmCount = 0;

  final List<Widget> _pages = const [
    MonitoringDashboardScreen(),
    GlobalAlarmsScreen(),
    SitesListScreen(),
    SiteMapScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadAlarmCount();
  }

  Future<void> _loadAlarmCount() async {
    try {
      final orgId = organizationService.currentOrganizationId;
      if (orgId != null) {
        alarmService.setOrganization(orgId);
      }
      final alarms = await alarmService.getActiveAlarms();
      if (mounted) {
        setState(() {
          _activeAlarmCount = alarms.length;
        });
      }
    } catch (_) {}
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MainShellScope(
      switchTab: _switchTab,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 0) _loadAlarmCount();
          },
          items: [
            const AppBottomNavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Dashboard',
            ),
            AppBottomNavItem(
              icon: Icons.warning_amber,
              activeIcon: Icons.warning_amber_rounded,
              label: 'Alarmlar',
              badgeCount: _activeAlarmCount > 0 ? _activeAlarmCount : null,
              showBadge: _activeAlarmCount > 0,
            ),
            const AppBottomNavItem(
              icon: Icons.location_city_outlined,
              activeIcon: Icons.location_city,
              label: 'Siteler',
            ),
            const AppBottomNavItem(
              icon: Icons.map_outlined,
              activeIcon: Icons.map,
              label: 'Harita',
            ),
            const AppBottomNavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }
}
