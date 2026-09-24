import 'package:flutter/material.dart';

class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

// TODO: Messages/Chats has no bottom-nav entry for any role; it is only reachable from the message icon on a profile. Product decision pending.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.destinations,
    required this.currentPath,
    required this.onSelected,
    super.key,
  });

  final List<AppDestination> destinations;
  final String currentPath;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final index = destinations.indexWhere(
      (item) => currentPath.startsWith(item.path),
    );
    return NavigationBar(
      selectedIndex: index < 0 ? 0 : index,
      onDestinationSelected: (value) => onSelected(destinations[value].path),
      destinations: [
        for (final item in destinations)
          NavigationDestination(
            icon: Icon(_outlineIcon(item.icon)),
            selectedIcon: Icon(_filledIcon(item.icon)),
            label: item.label,
          ),
      ],
    );
  }
}

IconData _outlineIcon(IconData icon) {
  if (icon == Icons.search) return Icons.search_outlined;
  return icon;
}

IconData _filledIcon(IconData icon) {
  return switch (icon) {
    Icons.home_outlined => Icons.home,
    Icons.person_outline => Icons.person,
    Icons.work_outline => Icons.work,
    Icons.storefront_outlined => Icons.storefront,
    Icons.account_tree_outlined => Icons.account_tree,
    Icons.assignment_outlined => Icons.assignment,
    Icons.people_outline => Icons.people,
    Icons.inventory_2_outlined => Icons.inventory_2,
    Icons.description_outlined => Icons.description,
    Icons.groups_outlined => Icons.groups,
    Icons.search => Icons.search,
    _ => icon,
  };
}
