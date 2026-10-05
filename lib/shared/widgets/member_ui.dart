import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'baid_ui.dart';
import 'brand_logo.dart';
import 'verified_badge.dart';

/// Member screens from the website (js/dash.js, css/theme.css): the app bar,
/// the white greeting card, stat tiles, quick-access tiles, cards and the
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
  const GreetingHero({required this.title, required this.subtitle, this.chips = const [], this.badge, this.wave = false, super.key});
  final String title;
  final String subtitle;
  final List<String> chips;
  final String? badge; // verification tier when verified
  final bool wave;

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
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(begin: Alignment(-.6, -1), end: Alignment(.6, 1), colors: [Colors.white, Color(0xFFECECEC), Color(0xFFD9D9D9)], stops: [0, .55, 1]),
        boxShadow: const [BoxShadow(color: Color(0x59FFFFFF), blurRadius: 60, spreadRadius: -30, offset: Offset(0, 30))],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(begin: Alignment(-.8, -1), end: Alignment(1, 1), colors: [Colors.transparent, Colors.black], stops: [.3, 1]).createShader(r),
              child: CustomPaint(painter: _HeroGrid()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 17, color: const Color(0xFF0A0A0A)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(greet.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: Color(0xFF0A0A0A)))),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(time, style: AppTextStyles.label.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0A0A0A), fontFeatures: const [FontFeature.tabularFigures()])),
                      Text(date, style: AppTextStyles.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF555555))),
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Flexible(child: Text(widget.title, style: AppTextStyles.display.copyWith(fontSize: 32, height: 1.12, letterSpacing: -1.2, color: const Color(0xFF050505)))),
                  if (widget.wave) ...[const SizedBox(width: 8), const _Wave()],
                ]),
                const SizedBox(height: 4),
                Text(widget.subtitle, style: AppTextStyles.body.copyWith(fontSize: 13.5, color: const Color(0xFF3A3A3A), fontWeight: FontWeight.w500)),
                if (chips.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: chips)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x0D000000);
    for (double x = 0; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The waving hand next to the name: a gentle wave that settles.
class _Wave extends StatefulWidget {
  const _Wave();
  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // a few quick waves that settle (same feel as the website's .wave)
        final angle = math.sin(t * 6 * math.pi) * .35 * (1 - t);
        return Transform.rotate(angle: angle, alignment: const Alignment(.4, .8), child: child);
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(colors: [Color(0xFFDFF1FF), Color(0xFFA8DCFB)])),
        child: const Icon(Icons.waving_hand_outlined, size: 20, color: Color(0xFF0E7490)),
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
        color: dark ? const Color(0xFF050505) : const Color(0x12000000),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: dark ? const Color(0xFF050505) : const Color(0x1A000000)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (badge != null) ...[VerifiedBadge(badge, size: 14), const SizedBox(width: 6)],
        Text(text, style: AppTextStyles.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? Colors.white : const Color(0xFF111111))),
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
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF131313), Color(0xFF0F0F0F)]),
                border: Border.all(color: AppColors.lineGlass),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Icon(stats[i].$3, size: 16, color: Colors.black)),
                const SizedBox(height: 10),
                Text(stats[i].$1, style: AppTextStyles.display.copyWith(fontSize: 26, letterSpacing: -.5, fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 2),
                Text(stats[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ),
          ),
          if (i < stats.length - 1) const SizedBox(width: 10),
        ],
      ],
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
                    Text(t.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(t.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.muted)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x24FFFFFF), Color(0x14FFFFFF)]),
        border: Border.all(color: const Color(0x4DFFFFFF)),
      ),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.star_border_rounded, color: Colors.black, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your profile isn\'t public yet. Complete the required items to be approved.', style: AppTextStyles.caption.copyWith(fontSize: 12.5, color: const Color(0xFFF6E9CF))),
            const SizedBox(height: 3),
            Text('$done/$total complete', style: AppTextStyles.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 8),
        PillButton(label: 'Continue setup', expand: false, height: 38, onPressed: () => context.push(AppRoutes.checklist)),
      ]),
    );
  }
}
