import 'dart:ui';

import 'package:flutter/material.dart';

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

/// The website's floating glass dock (`body.g-on .nav`): frosted dark glass with a
/// bright top edge, grey icons, the active tab white on a soft glass pill.
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
    // floats above the content as a glass dock (body.g-on .nav)
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 50, offset: Offset(0, 18))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xD60C0C0C),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0x42FFFFFF), width: 1.5),
                ),
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), border: const Border(top: BorderSide(color: Color(0x5CFFFFFF), width: 1.5))),
                  height: 66,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: on ? const Color(0x29FFFFFF) : const Color(0x00FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border(top: BorderSide(color: on ? const Color(0x66FFFFFF) : const Color(0x00FFFFFF))),
              ),
              child: Icon(item.icon, size: 23, color: color),
            ),
            const SizedBox(height: 3),
            Text(item.label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: AppTextStyles.caption.copyWith(fontSize: 11.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
