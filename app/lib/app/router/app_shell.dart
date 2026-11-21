import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/extensions.dart';
import '../../features/admin/admin_providers.dart';

/// Main navigation: bottom bar on phones, side rail on wide screens. Each tab
/// keeps its own back stack and scroll position. Admins get a fourth "Admin" tab (D-078); for
/// everyone else the bar is unchanged.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Home'),
    (icon: Icons.person_outline_rounded, selected: Icons.person_rounded, label: 'Profile'),
    (icon: Icons.settings_outlined, selected: Icons.settings_rounded, label: 'Settings'),
  ];

  static const _adminItem = (
    icon: Icons.admin_panel_settings_outlined,
    selected: Icons.admin_panel_settings,
    label: 'Admin',
  );

  // Tapping the current tab returns to that tab's root.
  void _select(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final items = isAdmin ? [..._items, _adminItem] : _items;
    // A non-admin never sits on the admin branch (the router redirects), but keep the bar valid.
    final selected = shell.currentIndex < items.length ? shell.currentIndex : 0;
    if (context.isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selected),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: _select,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selected),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
