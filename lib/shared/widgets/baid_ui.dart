import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Building blocks of the BAID X website look (css/theme.css, auth-glass.css):
/// the black backdrop with a faint grid and glow, the glassmorphism art
/// (ring + soft shapes), frosted glass panels and the glowing white pill button.

/// Full-screen backdrop. [art] adds the ring and the two soft shapes the website
/// uses behind sign-in, chats, notifications and the guest profile.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({this.art = false, this.child, super.key});

  final bool art;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.bg),
        // radial-gradient(800px 380px at 80% -140px, rgba(255,255,255,.10), transparent 60%)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(0.6, -1.35), radius: 1.1, colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)], stops: [0, .6]),
          ),
        ),
        const _Grid(),
        if (art) ...[
          Positioned(
            left: size.width / 2 - 150,
            top: 40,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x2EFFFFFF), width: 26))),
          ),
          Positioned(
            right: -120,
            top: size.height * .46,
            child: Opacity(
              opacity: .36,
              child: Container(width: 250, height: 250, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFF6D6D6D)]))),
            ),
          ),
          Positioned(
            left: -90,
            top: size.height * .64,
            child: Transform.rotate(
              angle: 18 * math.pi / 180,
              child: Opacity(opacity: .3, child: Container(width: 190, height: 190, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(58)))),
            ),
          ),
        ],
        ?child,
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const RadialGradient(center: Alignment(0, -.3), radius: .9, colors: [Colors.black, Colors.transparent]).createShader(r),
        child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frosted glass panel (`.type`, `.field`, `.opt` on the website).
class Glass extends StatelessWidget {
  const Glass({required this.child, this.radius = 22, this.padding = const EdgeInsets.all(16), this.selected = false, this.onTap, super.key});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 14))]),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: r,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: selected
                        ? const [Color(0x4DFFFFFF), Color(0x1AFFFFFF)]
                        : const [Color(0x9E0E0E0E), Color(0x570E0E0E), Color(0x24FFFFFF)],
                    stops: selected ? null : const [0, .55, 1],
                  ),
                  border: Border.all(color: selected ? Colors.white : const Color(0x4DFFFFFF), width: 1.5),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: r,
                    border: const Border(top: BorderSide(color: Color(0x73FFFFFF), width: 1.5)),
                  ),
                  padding: padding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The website's card surface (`.dcard`, `.tile`, `.row`): a faint top-lit gradient over #0e0e0e.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({required this.child, this.padding = const EdgeInsets.all(16), this.radius = 20, this.onTap, this.borderColor, super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: r,
            color: AppColors.card,
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF151515), Color(0xFF101010)]),
            border: Border.all(color: borderColor ?? AppColors.lineGlass),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// White "ember" pill with the soft white glow (`.btn-light`), or the dark glass
/// pill (`.btn-dark`) when [light] is false.
class PillButton extends StatelessWidget {
  const PillButton({required this.label, required this.onPressed, this.light = true, this.loading = false, this.icon, this.expand = true, this.height = 54, super.key});

  final String label;
  final VoidCallback? onPressed;
  final bool light;
  final bool loading;
  final IconData? icon;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = light ? Colors.black : AppColors.textLight;
    // website: 50px buttons use 15px text, small (.sm) ones 13px
    final fontSize = height >= 50 ? 15.5 : height >= 42 ? 14.0 : 13.0;
    final body = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        else ...[
          if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: AppTextStyles.button.copyWith(color: fg, fontSize: fontSize))),
        ],
      ],
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled || loading ? 1 : .45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: light ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFE4E4E4)]) : null,
          color: light ? null : const Color(0x0AFFFFFF),
          border: light ? null : Border.all(color: const Color(0x1FFFFFFF)),
          boxShadow: light && enabled ? const [BoxShadow(color: Color(0x8CFFFFFF), blurRadius: 30, spreadRadius: -10, offset: Offset(0, 10))] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: enabled ? onPressed : null,
            child: Padding(padding: EdgeInsets.symmetric(horizontal: height >= 50 ? 22 : 15), child: body),
          ),
        ),
      ),
    );
  }
}

/// The round glass frame with the BAID X mark and a slowly turning dashed ring
/// (`.ab-frame` on sign-in, `.guest-avatar` on the guest profile).
class BrandFrame extends StatefulWidget {
  const BrandFrame({this.size = 92, super.key});

  final double size;

  @override
  State<BrandFrame> createState() => _BrandFrameState();
}

class _BrandFrameState extends State<BrandFrame> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size, ring = s * .14;
    return SizedBox(
      width: s + ring * 2,
      height: s + ring * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(turns: _spin, child: CustomPaint(size: Size.square(s + ring * 2), painter: _DashedCircle())),
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x47FFFFFF), Color(0x12FFFFFF)]),
              border: Border.all(color: const Color(0x80FFFFFF), width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 50, offset: Offset(0, 20)), BoxShadow(color: Color(0x0FFFFFFF), spreadRadius: 8)],
            ),
            alignment: Alignment.center,
            child: ClipRRect(borderRadius: BorderRadius.circular(s * .185), child: Image.asset('assets/images/logo/baidx_mark.png', width: s * .63, height: s * .63)),
          ),
        ],
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = size.width / 2 - .5, c = size.center(Offset.zero);
    const n = 72;
    for (var i = 0; i < n; i += 2) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * 2 * math.pi / n, 2 * math.pi / n, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Uppercase, letter-spaced section label (`.sec`).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: AppTextStyles.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: const Color(0xFF7F858F))),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: AppColors.lineGlass)),
        ],
      ),
    );
  }
}

/// Small rounded status pill (`.pill`, `.pill.ok`, `.pill.warn`).
class Pill extends StatelessWidget {
  const Pill(this.text, {this.tone = PillTone.plain, super.key});

  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.ok => (const Color(0x2434D399), AppColors.green),
      PillTone.warn => (const Color(0x24FFFFFF), const Color(0xFFD6D6D6)),
      PillTone.bad => (const Color(0x24F87171), AppColors.red),
      PillTone.solid => (Colors.white, Colors.black),
      PillTone.plain => (const Color(0x12FFFFFF), const Color(0xFFD7DAE0)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

enum PillTone { plain, ok, warn, bad, solid }

/// Square glass icon button (`.icon-btn`, `.bell`).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({required this.icon, required this.onTap, this.badge = 0, this.tooltip, this.size = 42, super.key});

  final IconData icon;
  final VoidCallback? onTap;
  final int badge;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lineGlass)),
          child: Icon(icon, size: 21, color: const Color(0xFFE8E9EC)),
        ),
      ),
    );
    return Tooltip(
      message: tooltip ?? '',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          btn,
          if (badge > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 19),
                height: 19,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.bg, width: 2)),
                child: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(fontFamily: AppTextStyles.family, fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Initials or photo avatar with the website's tinted gradient (`.av`).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({required this.name, this.photoUrl, this.size = 42, this.radius, super.key});

  final String name;
  final String? photoUrl;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    final initials = parts.map((w) => w[0].toUpperCase()).join();
    final r = BorderRadius.circular(radius ?? size / 2);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF262626), Color(0xFF111111)]),
        border: Border.all(color: const Color(0x47FFFFFF)),
        image: photoUrl != null && photoUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover) : null,
      ),
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? null
          : Text(initials.isEmpty ? '?' : initials, style: TextStyle(fontFamily: AppTextStyles.family, fontWeight: FontWeight.w800, fontSize: size * .36, color: Colors.white)),
    );
  }
}

/// A card with the website's dashed outline (`.banner`, `.acc-card.check`).
class DashedCard extends StatelessWidget {
  const DashedCard({required this.child, this.padding = const EdgeInsets.all(13), this.radius = 18, this.onTap, super.key});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRect(radius),
      child: Material(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius), child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  const _DashedRRect(this.radius);
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x59FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.radius != radius;
}
