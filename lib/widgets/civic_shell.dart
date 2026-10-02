import 'save_civic_action.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/citizen/citizen_screens.dart';
import '../features/projects/project_screens.dart';
import '../features/reports/report_screens.dart';
import '../state/app_scope.dart';
import 'app_widgets.dart';

class CitizenShell extends StatefulWidget {
  const CitizenShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CitizenShell> createState() => _CitizenShellState();
}

class _CitizenShellState extends State<CitizenShell> {
  late int _index;

  static const _items = <_NavItem>[
    _NavItem('Home', Icons.home_outlined, Icons.home),
    _NavItem('Explore', Icons.forum_outlined, Icons.forum),
    _NavItem('Report', Icons.add_location_alt_outlined, Icons.add_location_alt),
    _NavItem('Projects', Icons.account_tree_outlined, Icons.account_tree),
    _NavItem(
      'Notifications',
      Icons.notifications_none_outlined,
      Icons.notifications,
    ),
    _NavItem('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final size = MediaQuery.sizeOf(context);
    final desktop =
        size.width >= 900 &&
        size.height >= 640 &&
        MediaQuery.textScalerOf(context).scale(16) <= 24;
    final visibleIndexes = [0, 1, 2, 3, 4, 5];
    final items = visibleIndexes
        .map(
          (index) => controller.usesPersistentData && index == 0
              ? const _NavItem(
                  'My reports',
                  Icons.assignment_outlined,
                  Icons.assignment,
                )
              : _items[index],
        )
        .toList();
    if (!visibleIndexes.contains(_index)) _index = 0;
    final pages = <Widget>[
      controller.usesPersistentData
          ? const MyReportsScreen(embedded: true)
          : const CitizenHomeScreen(),
      const CivicFeedScreen(),
      const ReportWizardScreen(embedded: true),
      const ProjectExplorerScreen(embedded: true),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];
    final appBar = AppBar(
      title: AppLogo(compact: size.width < 380),
      actions: <Widget>[
        if (controller.usesPersistentData)
          IconButton(
            tooltip: 'Refresh data',
            icon: const Icon(Icons.refresh),
            onPressed: () => saveCivicAction(context, controller.refreshData),
          ),
        if (!controller.usesPersistentData)
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Search Smart Sabha',
          ),
        if (!controller.usesPersistentData)
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/map'),
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Map',
          ),
        PopupMenuButton<String>(
          tooltip: 'More services',
          onSelected: (value) async {
            switch (value) {
              case 'reports':
                Navigator.pushNamed(context, '/my-reports');
              case 'announcements':
                Navigator.pushNamed(context, '/announcements');
              case 'proposals':
                Navigator.pushNamed(context, '/proposals');
              case 'consultations':
                Navigator.pushNamed(context, '/consultations');
              case 'admin':
                Navigator.pushNamed(context, '/admin');
              case 'logout':
                if (!await saveCivicAction(context, controller.signOut)) return;
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
            }
          },
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            const PopupMenuItem(
              value: 'reports',
              child: ListTile(
                leading: Icon(Icons.assignment_outlined),
                title: Text('My reports'),
              ),
            ),
            const PopupMenuItem(
              value: 'announcements',
              child: ListTile(
                leading: Icon(Icons.campaign_outlined),
                title: Text('Announcements'),
              ),
            ),
            if (!controller.usesPersistentData)
              const PopupMenuItem(
                value: 'proposals',
                child: ListTile(
                  leading: Icon(Icons.lightbulb_outline),
                  title: Text('Community proposals'),
                ),
              ),
            if (!controller.usesPersistentData)
              const PopupMenuItem(
                value: 'consultations',
                child: ListTile(
                  leading: Icon(Icons.forum_outlined),
                  title: Text('Consultations'),
                ),
              ),
            if (controller.isOfficer)
              const PopupMenuItem(
                value: 'admin',
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings_outlined),
                  title: Text('Officer dashboard'),
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: Text(
                  controller.isGuest ? 'Leave guest mode' : 'Sign out',
                ),
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
    final main = Scaffold(
      appBar: appBar,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: visibleIndexes.indexOf(_index),
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (value) =>
                  setState(() => _index = visibleIndexes[value]),
              destinations: items
                  .map(
                    (item) => NavigationDestination(
                      icon:
                          item.outlinedIcon == Icons.notifications_none_outlined
                          ? _NotificationIcon(
                              icon: item.outlinedIcon,
                              active: false,
                              count: controller.unreadNotificationCount,
                            )
                          : Icon(item.outlinedIcon),
                      selectedIcon: item.filledIcon == Icons.notifications
                          ? _NotificationIcon(
                              icon: item.filledIcon,
                              active: true,
                              count: controller.unreadNotificationCount,
                            )
                          : Icon(item.filledIcon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
    );
    if (!desktop) return main;
    return Scaffold(
      body: Row(
        children: <Widget>[
          SafeArea(
            child: NavigationRail(
              selectedIndex: visibleIndexes.indexOf(_index),
              labelType: NavigationRailLabelType.all,
              minWidth: 86,
              leading: const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 20),
                child: AppLogo(compact: true),
              ),
              onDestinationSelected: (value) =>
                  setState(() => _index = visibleIndexes[value]),
              destinations: items
                  .map(
                    (item) => NavigationRailDestination(
                      icon:
                          item.outlinedIcon == Icons.notifications_none_outlined
                          ? _NotificationIcon(
                              icon: item.outlinedIcon,
                              active: false,
                              count: controller.unreadNotificationCount,
                            )
                          : Icon(item.outlinedIcon),
                      selectedIcon: item.filledIcon == Icons.notifications
                          ? _NotificationIcon(
                              icon: item.filledIcon,
                              active: true,
                              count: controller.unreadNotificationCount,
                            )
                          : Icon(item.filledIcon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
              trailing: const Expanded(child: SizedBox()),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: main),
        ],
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({
    required this.icon,
    required this.active,
    required this.count,
  });

  final IconData icon;
  final bool active;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -7,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.outlinedIcon, this.filledIcon);

  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;
}
