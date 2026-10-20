import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import 'baidx_mark_path.dart';

/// Becomes true after the opening moment, so routing can leave the splash.
final splashReleasedProvider = NotifierProvider<SplashRelease, bool>(
  SplashRelease.new,
);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class SplashRelease extends Notifier<bool> {
  @override
  bool build() => false;

  void release() {
    if (!state) state = true;
  }
}

/// The opening: a pen of light sketches the BAID X tile and its tools on a faint
/// drawing grid, the mark fills in, settles above the wordmark and "Ghana's work
/// network", then zooms through the screen into the app.
class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _total = 3700; // ms
  static const _calm = 700; // ms, when the phone asks for reduced motion
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  );
  late final Path _tools = baidxToolsPath();
  Timer? _release;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_release != null) return;
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _t.value = .78; // the settled logo, no motion
    } else {
      _t.forward();
    }
    _release = Timer(Duration(milliseconds: _reduced ? _calm : _total), () {
      if (mounted) ref.read(splashReleasedProvider.notifier).release();
    });
  }

  @override
  void dispose() {
    _release?.cancel();
    _t.dispose();
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
        animation: _t,
        builder: (context, _) {
          final grid = _p(0, 600, Curves.easeOut);
          final tile = _p(150, 900, const Cubic(.6, 0, .25, 1));
          final tools = _p(700, 1000, const Cubic(.5, 0, .3, 1));
          final fill = _p(1650, 380, Curves.easeOut);
          final pop = _p(1650, 520, const Cubic(.2, .9, .25, 1.25));
          final sweep = _p(1800, 650, Curves.easeInOut);
          final settle = _p(2050, 600, const Cubic(.65, 0, .25, 1));
          final word = _p(2250, 600, const Cubic(.6, 0, .2, 1));
          final tag = _p(2550, 450, Curves.ease);
          final shine = _p(2450, 900, Curves.easeInOut);
          final zoom = _p(3150, 550, const Cubic(.7, 0, .84, 0));
          final away = _p(3150, 220, Curves.easeOut); // the words leave first, so the mark zooms alone
          final size = MediaQuery.sizeOf(context);
          final mark = (size.shortestSide * .34).clamp(110.0, 170.0);
          final scale =
              (1 - .38 * settle) * (.94 + .06 * pop) * (1 + 11 * zoom);
          final lift = -mark * .42 * settle * (1 - _p(3150, 300, Curves.easeInOut));
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: grid * (1 - zoom),
                child: CustomPaint(painter: _Grid(draw: grid)),
              ),
              // a soft pool of light behind the mark once it fills
              Center(
                child: Opacity(
                  opacity: (fill * .9 * (1 - zoom)).clamp(0, 1),
                  child: Container(
                    width: mark * 3,
                    height: mark * 3,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x2EFFFFFF),
                          Color(0x08FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                        stops: [0, .45, .72],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, lift),
                  child: Opacity(
                    opacity: (1 - zoom * 1.15).clamp(0, 1),
                    child: Transform.scale(
                      scale: scale,
                      child: CustomPaint(
                        size: Size.square(mark),
                        painter: _Mark(
                          tools: _tools,
                          tile: tile,
                          toolsDraw: tools,
                          fill: fill,
                          sweep: sweep,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, mark * .36),
                  child: Opacity(
                    opacity: 1 - away,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // the "BAID X" part of the logo, revealed left to right with a pass of light
                        ClipRect(
                          clipper: _Wipe(word),
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (r) => LinearGradient(
                              begin: Alignment(-3 + shine * 5, 0),
                              end: Alignment(-1 + shine * 5, 0),
                              colors: const [
                                Color(0xFFBDBDBD),
                                Colors.white,
                                Color(0xFFBDBDBD),
                              ],
                            ).createShader(r),
                            child: SizedBox(
                              width: 168,
                              height: 55,
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                maxWidth: 220,
                                child: Transform.translate(
                                  offset: const Offset(-56, 0),
                                  child: Image.asset(
                                    'assets/images/logo/baidx_logo_white.png',
                                    width: 220,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: tag,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - tag)),
                            child: const Text(
                              'Ghana\'s work network',
                              style: TextStyle(
                                fontFamily: AppTextStyles.family,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: .2,
                                color: Color(0xFF9A9A9A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

/// Faint drafting lines that draw down the screen, strongest in the middle.
class _Grid extends CustomPainter {
  _Grid({required this.draw});
  final double draw;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 48.0;
    final cx = size.width / 2;
    for (double x = cx % step; x < size.width; x += step) {
      final fade = (1 - ((x - cx).abs() / (size.width * .6))).clamp(0.0, 1.0);
      final p = Paint()..color = Color.fromRGBO(255, 255, 255, .07 * fade);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * draw), p);
    }
    for (double y = size.height / 2 % step; y < size.height * draw; y += step) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = const Color(0x0AFFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Grid old) => old.draw != draw;
}

/// The mark: the tile outline, then the tools' outlines, each traced by a glowing pen;
/// then the tile fills white, the tools fill black, and a band of light crosses it.
class _Mark extends CustomPainter {
  _Mark({
    required this.tools,
    required this.tile,
    required this.toolsDraw,
    required this.fill,
    required this.sweep,
  });
  final Path tools;
  final double tile, toolsDraw, fill, sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 512;
    canvas.save();
    canvas.scale(k);
    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 512, 512),
      const Radius.circular(64),
    );
    final tilePath = Path()..addRRect(rrect);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 / k
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .92 * (1 - fill));

    if (fill > 0) {
      canvas.drawShadow(
        tilePath,
        Colors.white.withValues(alpha: .25 * fill),
        18 / k,
        false,
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = Colors.white.withValues(alpha: fill),
      );
      canvas.drawPath(
        tools,
        Paint()..color = Colors.black.withValues(alpha: fill),
      );
      if (sweep > 0 && sweep < 1) {
        canvas.save();
        canvas.clipRRect(rrect);
        final x = -300 + sweep * 1100;
        canvas.drawRect(
          const Rect.fromLTWH(-400, -400, 1400, 1400),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(x - 160, 0),
              Offset(x + 160, 160),
              [
                const Color(0x00FFFFFF),
                const Color(0x8CFFFFFF),
                const Color(0x00FFFFFF),
              ],
              [0, .5, 1],
            )
            ..blendMode = BlendMode.srcATop,
        );
        canvas.restore();
      }
    }
    if (fill < 1) {
      final head1 = _trace(canvas, tilePath, tile, stroke, startAt: .5);
      final head2 = _trace(canvas, tools, toolsDraw, stroke);
      for (final h in [
        if (tile > 0 && tile < 1) head1,
        if (toolsDraw > 0 && toolsDraw < 1) head2,
      ]) {
        if (h == null) continue;
        canvas.drawCircle(
          h,
          14 / k,
          Paint()
            ..color = const Color(0x66FFFFFF)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 / k),
        );
        canvas.drawCircle(h, 3.2 / k, Paint()..color = Colors.white);
      }
    }
    canvas.restore();
  }

  /// Draws [t] of every contour in [path] (all contours together, in order) and returns the pen's position.
  /// [startAt] starts a closed outline part of the way round (the tile starts at its bottom middle).
  Offset? _trace(
    Canvas canvas,
    Path path,
    double t,
    Paint paint, {
    double startAt = 0,
  }) {
    if (t <= 0) return null;
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var left = total * t;
    Offset? head;
    for (final m in metrics) {
      if (left <= 0) break;
      final len = left.clamp(0.0, m.length);
      final from = m.length * startAt;
      if (from + len <= m.length) {
        canvas.drawPath(m.extractPath(from, from + len), paint);
      } else {
        canvas.drawPath(m.extractPath(from, m.length), paint);
        canvas.drawPath(m.extractPath(0, from + len - m.length), paint);
      }
      head = m.getTangentForOffset((from + len) % m.length)?.position;
      left -= m.length;
    }
    return head;
  }

  @override
  bool shouldRepaint(covariant _Mark old) =>
      old.tile != tile ||
      old.toolsDraw != toolsDraw ||
      old.fill != fill ||
      old.sweep != sweep;
}
