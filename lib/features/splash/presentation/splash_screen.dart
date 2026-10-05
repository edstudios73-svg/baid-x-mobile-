import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';

/// Becomes true after the opening moment, so routing can leave the splash.
final splashReleasedProvider = NotifierProvider<SplashRelease, bool>(SplashRelease.new);

class SplashRelease extends Notifier<bool> {
  @override
  bool build() => false;

  void release() {
    if (!state) state = true;
  }
}

/// The website's opening (index.html #splash, css/theme.css .sp-*): grid and glow,
/// the ring drawing itself around the mark with an orbiting dot, the wordmark
/// wiping in, "Ghana's work network", then "Powered by BAIDEN CREATIVES".
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  static const _total = 4200; // ms
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: _total))..forward();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  Timer? _release;

  @override
  void initState() {
    super.initState();
    _release = Timer(const Duration(milliseconds: _total), () {
      if (mounted) ref.read(splashReleasedProvider.notifier).release();
    });
  }

  @override
  void dispose() {
    _release?.cancel();
    _t.dispose();
    _spin.dispose();
    super.dispose();
  }

  /// Progress of a step that starts at [startMs] and lasts [ms], with [curve].
  double _p(int startMs, int ms, [Curve curve = Curves.easeOutCubic]) {
    final v = ((_t.value * _total - startMs) / ms).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_t, _spin]),
        builder: (context, _) {
          final glow = .55 + .45 * math.sin(_t.value * _total / 3300 * math.pi);
          final logo = _p(150, 1100, const Cubic(.2, .9, .25, 1.15));
          final ring = _p(350, 1500, const Cubic(.6, 0, .2, 1));
          final dash = _p(900, 800, Curves.ease);
          final orbit = _p(500, 3200, const Cubic(.5, 0, .3, 1));
          final wipe = _p(1000, 1000, const Cubic(.6, 0, .2, 1));
          final tag = _p(1600, 900, Curves.ease);
          final line = _p(1900, 1000, Curves.ease);
          final by = _p(2100, 800, Curves.ease);
          final name = _p(2100, 900, Curves.ease);
          final prog = _p(2300, 1700, Curves.easeInOut);
          final shimmer = (_t.value * _total / 2200) % 1;
          final leave = 1 - _p(_total - 350, 350, Curves.easeIn);
          return Opacity(
            opacity: leave,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // grid, masked to a soft circle
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const RadialGradient(center: Alignment(0, -.08), radius: .75, colors: [Colors.black, Colors.transparent], stops: [0, 1]).createShader(r),
                  child: CustomPaint(painter: _Grid()),
                ),
                // breathing glow
                Align(
                  alignment: const Alignment(0, -.08),
                  child: Opacity(
                    opacity: glow.clamp(0, 1),
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x38FFFFFF), Color(0x0DFFFFFF), Color(0x00FFFFFF)], stops: [0, .45, .7])),
                    ),
                  ),
                ),
                // vignette
                const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(radius: 1, colors: [Colors.transparent, Color(0xD9000000)], stops: [.4, 1]))),
                Align(
                  alignment: const Alignment(0, -.08),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(size: const Size.square(150), painter: _Ring(draw: ring, dashOpacity: dash, spin: _spin.value, orbit: orbit)),
                            Opacity(
                              opacity: logo.clamp(0, 1),
                              child: Transform.scale(
                                scale: .6 + .4 * logo,
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: const [BoxShadow(color: Color(0x66FFFFFF), spreadRadius: 1), BoxShadow(color: Color(0x2EFFFFFF), blurRadius: 60, offset: Offset(0, 20))],
                                  ),
                                  child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/images/logo/baidx_mark.png', fit: BoxFit.cover)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // wordmark wipe: the "BAID X" part of the logo, revealed left to right
                      ClipRect(
                        clipper: _Wipe(wipe),
                        child: SizedBox(
                          width: 188,
                          height: 61,
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            maxWidth: 245,
                            child: Transform.translate(offset: const Offset(-63, 0), child: Image.asset('assets/images/logo/baidx_logo_white.png', width: 245)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Opacity(
                        opacity: tag,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - tag)),
                          child: const Text('GHANA\'S WORK NETWORK', style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 3.9, color: Color(0xFF9A9A9A))),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 46 + MediaQuery.paddingOf(context).bottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 1, height: 34 * line, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.transparent]))),
                      const SizedBox(height: 16),
                      Opacity(opacity: by, child: const Text('POWERED BY', style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 3.2, color: Color(0xFF777777)))),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: name,
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (r) => LinearGradient(
                            begin: Alignment(-1 + shimmer * 4 - 2, 0),
                            end: Alignment(1 + shimmer * 4 - 2, 0),
                            colors: const [Color(0xFF7A7A7A), Colors.white, Colors.white, Color(0xFF7A7A7A)],
                            stops: const [.2, .45, .55, .8],
                          ).createShader(r),
                          child: const Text('BAIDEN CREATIVES', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 6)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Opacity(
                        opacity: by,
                        child: Container(
                          width: 120,
                          height: 2,
                          decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(2)),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(widthFactor: prog, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2), boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 8)]))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Wipe extends CustomClipper<Rect> {
  _Wipe(this.v);
  final double v;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * v, size.height);
  @override
  bool shouldReclip(_Wipe old) => old.v != v;
}

class _Grid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x0EFFFFFF);
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

/// Outer ring drawn on, inner dashed ring spinning, and a glowing dot orbiting once.
class _Ring extends CustomPainter {
  _Ring({required this.draw, required this.dashOpacity, required this.spin, required this.orbit});
  final double draw, dashOpacity, spin, orbit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), k = size.width / 200;
    final outer = Paint()
      ..color = const Color(0xD9FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(Rect.fromCircle(center: c, radius: 92 * k), -math.pi / 2, 2 * math.pi * draw, false, outer);
    if (dashOpacity > 0) {
      final inner = Paint()
        ..color = Colors.white.withValues(alpha: .35 * dashOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8;
      const n = 60;
      for (var i = 0; i < n; i++) {
        final a = spin * 2 * math.pi + i * 2 * math.pi / n;
        canvas.drawArc(Rect.fromCircle(center: c, radius: 78 * k), a, 2 * math.pi / n * .3, false, inner);
      }
    }
    if (orbit > 0) {
      final a = -math.pi / 2 + orbit * 2 * math.pi;
      final dot = c + Offset(math.cos(a), math.sin(a)) * 92 * k;
      canvas.drawCircle(dot, 6, Paint()..color = const Color(0x55FFFFFF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(dot, 3.5 * k + .8, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _Ring old) => true;
}
