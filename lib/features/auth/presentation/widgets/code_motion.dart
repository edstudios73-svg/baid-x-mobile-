import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

/// The phone-code moments of sign-up and password reset, matching auth.html:
/// the screen blurs while the code is sent or checked (bouncing dots), and a right
/// code turns a lock into a green check before "You're verified".
enum CodeMoment { none, sending, verifying, verified }

abstract final class CodeMotion {
  /// How long "You're verified" stays before the flow moves on.
  static const verifiedHold = Duration(milliseconds: 2100);
  static const success = Color(0xFF22C55E);
}

/// Lays the moment over [child]: a blur that comes in and out, and what the moment shows.
class CodeMomentLayer extends StatelessWidget {
  const CodeMomentLayer({
    required this.moment,
    required this.phone,
    required this.child,
    super.key,
  });
  final CodeMoment moment;
  final String phone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final on = moment != CodeMoment.none;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          ignoring: !on,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: on ? 1 : 0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            builder: (context, v, content) => v == 0
                ? const SizedBox.shrink()
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14 * v, sigmaY: 14 * v),
                    child: ColoredBox(
                      color: Color.fromRGBO(0, 0, 0, .55 * v),
                      child: Opacity(opacity: v, child: content),
                    ),
                  ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: switch (moment) {
                  CodeMoment.sending => const _Waiting(
                    key: ValueKey('s'),
                    label: 'Sending code',
                  ),
                  CodeMoment.verifying => const _Waiting(
                    key: ValueKey('v'),
                    label: 'Verifying',
                  ),
                  CodeMoment.verified => _Verified(
                    key: const ValueKey('ok'),
                    phone: phone,
                  ),
                  CodeMoment.none => const SizedBox.shrink(),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BouncingDots(),
          const SizedBox(height: 16),
          Text(
            '$label…',
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: const Color(0xFFBDBDBD),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Five dots in a travelling wave, white to grey.
class BouncingDots extends StatefulWidget {
  const BouncingDots({super.key});

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  static const _shades = [
    Colors.white,
    Color(0xFFBDBDBD),
    Colors.white,
    Color(0xFF8A8A8A),
    Colors.white,
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(
                  0,
                  still
                      ? 0
                      : -9 *
                            math.max(
                              0,
                              math.sin((_c.value - i * .12) * 2 * math.pi),
                            ),
                ),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _shades[i],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A lock in a white tile pops in, the tile rounds into a green circle as the lock
/// becomes a check, then "You're verified" and the number.
class _Verified extends StatelessWidget {
  const _Verified({required this.phone, super.key});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      builder: (context, t, _) {
        double seg(double a, double b, [Curve c = Curves.easeOutCubic]) =>
            c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
        final pop = seg(0, .28, const Cubic(.2, 1.4, .3, 1));
        final morph = seg(.3, .58, Curves.easeInOutCubic);
        final check = seg(.5, .72);
        final ring = seg(.55, .95, Curves.easeOut);
        final text = seg(.68, 1);
        const size = 84.0;
        return Semantics(
          liveRegion: true,
          label: 'You\'re verified',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: (1 - ring) * .8,
                      child: Transform.scale(
                        scale: 1 + .75 * ring,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CodeMotion.success,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: pop,
                      child: Transform.rotate(
                        angle: (1 - morph) * -.2 + morph * 0,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              Colors.white,
                              CodeMotion.success,
                              morph,
                            ),
                            borderRadius: BorderRadius.circular(
                              22 + (size / 2 - 22) * morph,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: CodeMotion.success.withValues(
                                  alpha: .45 * morph,
                                ),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: 1 - morph,
                                child: const Icon(
                                  Icons.lock_rounded,
                                  size: 38,
                                  color: Colors.black,
                                ),
                              ),
                              CustomPaint(
                                size: const Size.square(42),
                                painter: _Check(check),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: text,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - text)),
                  child: Column(
                    children: [
                      Text(
                        'You\'re verified',
                        style: AppTextStyles.headline.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$phone is confirmed.',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          color: const Color(0xFFBDBDBD),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Check extends CustomPainter {
  _Check(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final path = Path()
      ..moveTo(size.width * .18, size.height * .52)
      ..lineTo(size.width * .42, size.height * .74)
      ..lineTo(size.width * .84, size.height * .28);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _Check old) => old.t != t;
}

/// The code screen's picture: a soft disc pops in, a phone rises into it, and a
/// message bubble with the hidden code pops out beside it and gently breathes.
class CodeArt extends StatefulWidget {
  const CodeArt({super.key});

  @override
  State<CodeArt> createState() => _CodeArtState();
}

class _CodeArtState extends State<CodeArt> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..forward();
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _in.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) _in.value = 1;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: Listenable.merge([_in, _breathe]),
        builder: (context, _) {
          final t = _in.value;
          double seg(double a, double b, Curve c) =>
              c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
          final disc = seg(0, .4, const Cubic(.2, 1.35, .3, 1));
          final phone = seg(.22, .62, const Cubic(.2, 1.1, .3, 1));
          final bubble = seg(.58, .9, const Cubic(.2, 1.5, .3, 1));
          final b = Curves.easeInOut.transform(_breathe.value);
          return SizedBox(
            width: 140,
            height: 116,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: disc,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x73FFFFFF), Color(0x2EFFFFFF)],
                      ),
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0x33FFFFFF)),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(-4, 40 * (1 - phone)),
                  child: Opacity(
                    opacity: phone,
                    child: Container(
                      width: 46,
                      height: 78,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: const Color(0xFF1A1A1A),
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      alignment: const Alignment(0, .82),
                      child: Container(
                        width: 14,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 10,
                  child: Transform.scale(
                    scale: bubble * (1 + .04 * b),
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                          bottomLeft: Radius.circular(3),
                        ),
                        border: Border.all(color: const Color(0x59FFFFFF)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                              child: Opacity(
                                opacity:
                                    .45 + .55 * (((b * 3) - i).clamp(0.0, 1.0)),
                                child: const Text(
                                  '*',
                                  style: TextStyle(
                                    fontFamily: AppTextStyles.family,
                                    fontSize: 17,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
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
            ),
          );
        },
      ),
    );
  }
}
