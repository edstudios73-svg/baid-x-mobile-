import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'baid_ui.dart';
import 'brand_logo.dart';
import 'verified_badge.dart';

/// Member screens from the website (js/dash.js, css/theme.css): the app bar,
/// the glass greeting card, stat tiles, quick-access tiles, cards and the
/// "profile isn't public yet" banner.

/// Logo, bell and the member's avatar (`.appbar`).
class MemberAppBar extends StatelessWidget {
  const MemberAppBar({required this.name, this.photo, super.key});
  final String name;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Row(
        children: [
          const BrandLogo(width: 104),
          const Spacer(),
          GlassIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onTap: () => context.push(AppRoutes.notifications)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.go(AppRoutes.profile),
            child: InitialsAvatar(name: name, photoUrl: photo, size: 42, radius: 14),
          ),
        ],
      ),
    );
  }
}

/// The greeting card (`.hero2`): reads the clock (late night, morning, afternoon,
/// evening, night), shows the time and date, the name, a line under it and chips.
class GreetingHero extends StatefulWidget {
  const GreetingHero({required this.title, required this.subtitle, this.chips = const [], this.badge, super.key});
  final String title;
  final String subtitle;
  final List<String> chips;
  final String? badge; // verification tier when verified

  @override
  State<GreetingHero> createState() => _GreetingHeroState();
}

class _GreetingHeroState extends State<GreetingHero> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  static (String, IconData) _period(int h) => h < 5
      ? ('Working late', Icons.dark_mode_outlined)
      : h < 12
          ? ('Good morning', Icons.wb_sunny_outlined)
          : h < 17
              ? ('Good afternoon', Icons.wb_sunny_outlined)
              : h < 21
                  ? ('Good evening', Icons.wb_twilight_outlined)
                  : ('Good night', Icons.dark_mode_outlined);

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (greet, icon) = _period(now.hour);
    final h12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final time = '$h12:${now.minute.toString().padLeft(2, '0')} ${now.hour < 12 ? 'am' : 'pm'}';
    final date = '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
    final chips = [
      if (widget.badge != null) _HeroChip(VerifiedBadge.labels[widget.badge] ?? 'Verified', dark: true, badge: widget.badge),
      for (final c in widget.chips) _HeroChip(c),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      child: GlassBox(
      strong: true,
      radius: 28,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          const Positioned.fill(child: _Sheen()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 17, color: Colors.white, shadows: const [Shadow(color: Color(0xB3FFFFFF), blurRadius: 8)]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(greet.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: Colors.white))),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(time, style: AppTextStyles.label.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
                      Text(date, style: AppTextStyles.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFC9C9C9))),
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Flexible(child: Text(widget.title, style: AppTextStyles.display.copyWith(fontSize: 31, height: 1.12, letterSpacing: -1, color: Colors.white, shadows: const [Shadow(color: Color(0x59000000), blurRadius: 24)]))),
                ]),
                const SizedBox(height: 4),
                Text(widget.subtitle, style: AppTextStyles.body.copyWith(fontSize: 13.5, color: const Color(0xFFD6D6D6), fontWeight: FontWeight.w500)),
                if (chips.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: chips)],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// A band of light that crosses the hero every few seconds (`.hero2::before`).
class _Sheen extends StatefulWidget {
  const _Sheen();

  @override
  State<_Sheen> createState() => _SheenState();
}

class _SheenState extends State<_Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // rests for most of the loop, then sweeps across
          final t = ((_c.value - .7) / .3).clamp(0.0, 1.0);
          if (t == 0) return const SizedBox.shrink();
          final x = -1.6 + 3.2 * Curves.easeInOut.transform(t);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(x - .5, -1),
                end: Alignment(x + .5, 1),
                colors: const [Color(0x00FFFFFF), Color(0x29FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.text, {this.dark = false, this.badge});
  final String text;
  final bool dark;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0x2938BDF8) : const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: dark ? const Color(0x7338BDF8) : const Color(0x42FFFFFF)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (badge != null) ...[VerifiedBadge(badge, size: 14), const SizedBox(width: 6)],
        Text(text, style: AppTextStyles.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? const Color(0xFFBAE6FD) : const Color(0xFFF0F0F0))),
      ]),
    );
  }
}

/// Three stat tiles (`.dstats`).
class StatRow extends StatelessWidget {
  const StatRow(this.stats, {super.key});
  final List<(String, String, IconData)> stats;

  @override
  Widget build(BuildContext context) {
    // equal heights even when one label wraps to two lines
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          Expanded(
            child: GlassBox(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x8CFFFFFF), blurRadius: 20, spreadRadius: -8, offset: Offset(0, 8))]), child: Icon(stats[i].$3, size: 16, color: Colors.black)),
                const SizedBox(height: 10),
                Text(stats[i].$1, style: AppTextStyles.display.copyWith(fontSize: 24, letterSpacing: -.5, fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 2),
                Text(stats[i].$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ),
          ),
          if (i < stats.length - 1) const SizedBox(width: 10),
        ],
      ],
      ),
    );
  }
}

/// A card with a title and a right-hand note (`.dcard`).
class DashCard extends StatelessWidget {
  const DashCard({required this.title, this.right, required this.child, super.key});
  final String title;
  final String? right;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SurfaceCard(
        radius: 18,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: AppTextStyles.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700))),
            if (right != null) Text(right!, style: AppTextStyles.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }
}

/// White progress bar with a soft glow (`.bar`).
class GlowBar extends StatelessWidget {
  const GlowBar(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(color: const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(99)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0, 1),
        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x99FFFFFF), blurRadius: 14)])),
      ),
    );
  }
}

/// Two-column quick-access tiles (`.tiles .tile`).
class QuickTiles extends StatelessWidget {
  const QuickTiles(this.tiles, {super.key});
  final List<(IconData, String, String, VoidCallback?)> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final t in tiles)
          SizedBox(
            width: w,
            child: SurfaceCard(
              radius: 18,
              padding: const EdgeInsets.all(12),
              onTap: t.$4,
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Icon(t.$1, size: 18, color: Colors.black)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(t.$3, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
      ]);
    });
  }
}

/// "Your profile isn't public yet" (`.banner`), shown until the checklist is done.
class SetupBanner extends StatelessWidget {
  const SetupBanner({required this.done, required this.total, super.key});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassBox(
        radius: 20,
        padding: const EdgeInsets.all(14),
        tint: const Color(0xFFE8C46A),
        borderColor: const Color(0x73E8C46A),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 34, height: 34, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.star_border_rounded, color: Colors.black, size: 19)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your profile isn\'t public yet. Complete the required items to be approved.', style: AppTextStyles.caption.copyWith(fontSize: 12.5, height: 1.35, color: const Color(0xFFE8E8E8))),
              const SizedBox(height: 3),
              Text('$done/$total complete', style: AppTextStyles.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              PillButton(label: 'Continue setup', expand: false, height: 36, onPressed: () => context.push(AppRoutes.checklist)),
            ]),
          ),
        ]),
      ),
    );
  }
}
