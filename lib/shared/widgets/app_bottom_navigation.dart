import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

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

/// The website's floating glass tab bar (`.nav`): frosted dark glass, a hairline
/// on top, grey icons, the active tab white with a small glowing dot.
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
    var index = -1, best = 0;
    for (var i = 0; i < destinations.length; i++) {
      final p = destinations[i].path;
      if (currentPath.startsWith(p) && p.length > best) {
        index = i;
        best = p.length;
      }
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xC70E0F12), border: Border(top: BorderSide(color: AppColors.lineGlass))),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(child: _Tab(item: destinations[i], on: i == index, onTap: () => onSelected(destinations[i].path))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.on, required this.onTap});
  final AppDestination item;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? Colors.white : const Color(0xFF7C818A);
    return Semantics(
      selected: on,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(item.label, style: AppTextStyles.caption.copyWith(fontSize: 11.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: color)),
            const SizedBox(height: 3),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: on ? 1 : 0,
              child: Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.white, blurRadius: 10)])),
            ),
          ],
        ),
      ),
    );
  }
}
