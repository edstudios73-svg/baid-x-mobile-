import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Signed-out Home, matching the website landing (css/landing.css, js/landing.js):
/// a still architect's drawing behind the glass, and the trust stack, four glass
/// layers that fold into one verified card as the visitor scrolls. The stage stays
/// in place while it folds (the website's sticky `.stage`), then scrolls away.

/// Scroll distance over which the stack folds into one card.
const double kStackTravel = 360;

/// The trust stack as a sliver. Uses its own scroll offset, so the stage holds still
/// for [kStackTravel] pixels while `p` runs from 0 to 1. Reduced motion gets the
/// finished card and no hold.
class GuestTrustStackSliver extends StatelessWidget {
  const GuestTrustStackSliver({super.key});

  static double _ease(double t) => t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    final travel = calm ? 0.0 : kStackTravel;
    return SliverLayoutBuilder(
      builder: (context, c) {
        final scrolled = c.scrollOffset.clamp(0.0, travel);
        final raw = calm ? 1.0 : (scrolled / travel);
        final p = _ease(((raw - .05) / .85).clamp(0.0, 1.0));
        return SliverToBoxAdapter(
          child: SizedBox(
            height: GuestTrustStage.height + travel,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: scrolled,
                  height: GuestTrustStage.height,
                  child: GuestTrustStage(p: p, progress: raw),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One screen of the stack: the 3D scene, the heading, four checks and the stats pill.
class GuestTrustStage extends StatelessWidget {
  const GuestTrustStage({required this.p, required this.progress, super.key});

  static const double height = 640;
  final double p; // 0 = spread in 3D, 1 = one flat card
  final double progress; // raw scroll progress, ticks the checks

  static const _checks = [
    ('Profile reviewed', 'A person at BAID X looks at every profile.'),
    ('Ghana Card checked', 'Identity matched to an official ID.'),
    ('Trade proven', 'Certificates and past work verified.'),
    ('Money held in escrow', 'GH₵900 waits until the client approves.'),
  ];

  @override
  Widget build(BuildContext context) {
    // the stage has a fixed height (the sliver holds it still while it folds); on small
    // phones or with large text the whole stage scales down rather than overflow
    return LayoutBuilder(
      builder: (context, box) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(width: box.maxWidth, child: _content()),
      ),
    );
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 300,
            child: Center(child: TrustStackScene(p: p)),
          ),
          const SizedBox(height: 4),
          const Text(
            'How a badge is earned',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFA3A3A3)),
          ),
          const SizedBox(height: 6),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Four checks. '),
                TextSpan(
                  text: 'One card you can trust.',
                  style: TextStyle(color: Color(0xFF7A7A7A)),
                ),
              ],
            ),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -.8),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _checks.length; i++)
            _Check(title: _checks[i].$1, body: _checks[i].$2, on: progress > .12 + i * .18 || p >= 1),
          const SizedBox(height: 14),
          const StatsPill(),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.title, required this.body, required this.on});
  final String title;
  final String body;
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 350),
    opacity: on ? 1 : .3,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? Colors.white : Colors.transparent,
              border: Border.all(color: on ? Colors.white : const Color(0xFF4A4A4A), width: 2),
            ),
            child: on ? const Icon(Icons.check_rounded, size: 13, color: Colors.black) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                Text(body, style: const TextStyle(fontSize: 12.5, color: Color(0xFF9A9A9A))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Four glass layers seen from above at an angle; each sits higher in z the
/// further it is from the base. As [p] reaches 1 the scene flattens and turns
/// square-on, and the layers merge into the top card.
class TrustStackScene extends StatelessWidget {
  const TrustStackScene({required this.p, super.key});
  final double p;

  static const _layers = [
    ('Profile reviewed', 'By a person at BAID X', '01'),
    ('Identity verified', 'Ghana Card checked', '02'),
    ('Trade proven', 'Certificates checked', '03'),
    ('GH₵900 held', 'Released when the work is approved', '04'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = math.min(310.0, box.maxWidth - 48);
        final h = w / 1.55;
        final q = 1 - p;
        // CSS: rotateX(58deg * q) rotateZ(-34deg * q) scale(.84 + .16p); layers translateZ(i * q * 36px)
        Matrix4 at(double z) => Matrix4.identity()
          ..setEntry(3, 2, 1 / 1100)
          ..rotateX(-58 * math.pi / 180 * q)
          ..rotateZ(-34 * math.pi / 180 * q)
          ..scaleByDouble(.84 + .16 * p, .84 + .16 * p, 1, 1)
          ..translateByDouble(0, 0, -z, 1);
        final under = (q * 6).clamp(0.0, 1.0); // layers under the card fade once it has formed
        Widget layer(int i, Widget child) => Transform(
          alignment: Alignment.center,
          transform: at(i * q * 26),
          child: SizedBox(width: w, height: h, child: child),
        );
        // the layers rise as they spread out, so the spread scene sits lower to stay centred
        return Transform.translate(
          offset: Offset(0, 80 * q),
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (under > 0) Opacity(opacity: under, child: layer(0, const _BaseLayer())),
                for (var i = 0; i < _layers.length; i++)
                  if (under > 0)
                    Opacity(
                      opacity: under,
                      child: layer(i + 1, _TierLayer(title: _layers[i].$1, body: _layers[i].$2, n: _layers[i].$3)),
                    ),
                layer(5, _TopCard(p: p)),
              ],
            ),
          ),
        );
      },
    );
  }
}

BoxDecoration _glass({double a = .06, double line = .2}) => BoxDecoration(
  borderRadius: BorderRadius.circular(22),
  color: Colors.white.withValues(alpha: a),
  border: Border.all(color: Colors.white.withValues(alpha: line)),
  boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, spreadRadius: -18, offset: Offset(0, 24))],
);

class _BaseLayer extends StatelessWidget {
  const _BaseLayer();
  @override
  Widget build(BuildContext context) => Container(
    decoration: _glass(a: .03, line: .14),
    alignment: Alignment.center,
    child: const Text(
      'BAID X',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 4, color: Color(0x33FFFFFF)),
    ),
  );
}

class _TierLayer extends StatelessWidget {
  const _TierLayer({required this.title, required this.body, required this.n});
  final String title;
  final String body;
  final String n;
  @override
  Widget build(BuildContext context) => Container(
    decoration: _glass(a: .07),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    alignment: Alignment.bottomLeft,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.black),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(
                body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFFA3A3A3)),
              ),
            ],
          ),
        ),
        Text(
          n,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF7A7A7A)),
        ),
      ],
    ),
  );
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.p});
  final double p;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A2A2A), Color(0xFF131313)],
        stops: [0, .6],
      ),
      border: Border.all(color: const Color(0x57FFFFFF)),
      boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 50, spreadRadius: -20, offset: Offset(0, 30))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(12)),
              child: const Text('KA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kwame A.', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  Text(
                    'Electrician · East Legon',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFA3A3A3)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: const Color(0x29FFFFFF), borderRadius: BorderRadius.circular(99)),
              child: const Text('Held', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IN ESCROW', style: TextStyle(fontSize: 10, letterSpacing: 1, color: Color(0xFFA3A3A3))),
            Text(
              'GH₵900.00',
              style: TextStyle(
                fontSize: 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Opacity(
                opacity: ((p - .55) * 3).clamp(0.0, 1.0),
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Flexible(
                child: Text(
                  'Verified by BAID X',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The website's hero stats as one slim glass pill.
class StatsPill extends StatelessWidget {
  const StatsPill({super.key});
  static const _items = [('5', 'account types'), ('50', 'trades'), ('16', 'regions'), ('Free', 'to join')];
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0x12FFFFFF),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0x29FFFFFF)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < _items.length; i++)
          Expanded(
            flex: i == 0 ? 13 : 10,
            child: Container(
              decoration: i == 0
                  ? null
                  : const BoxDecoration(
                      border: Border(left: BorderSide(color: Color(0x29FFFFFF))),
                    ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _items[i].$1,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                      TextSpan(text: ' ${_items[i].$2}'),
                    ],
                  ),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFA3A3A3)),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The website's `.lp-bg`: a faint white architect's sheet (ground floor plan above,
/// front elevation below) with two soft pools of white light, still.
class BlueprintBackdrop extends StatelessWidget {
  const BlueprintBackdrop({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.65, -.8),
              radius: .9,
              colors: [Color(0x1CFFFFFF), Color(0x00FFFFFF)],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.8, .6),
              radius: .8,
              colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
            ),
          ),
        ),
        CustomPaint(painter: BlueprintPainter()),
      ],
    ),
  );
}

class BlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // drawn on the website's portrait sheet (640 x 1386) and scaled to cover
    const sheet = Size(640, 1386);
    final s = math.max(size.width / sheet.width, size.height / sheet.height);
    canvas.save();
    canvas.translate((size.width - sheet.width * s) / 2, (size.height - sheet.height * s) / 2);
    canvas.scale(s);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x1FFFFFFF);
    final dim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x14FFFFFF);
    void label(String t, double x, double y, {bool title = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: title ? 12 : 13,
            letterSpacing: title ? 1.7 : .8,
            fontWeight: FontWeight.w600,
            color: Color(title ? 0x40FFFFFF : 0x2EFFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y - tp.height + 3));
    }

    // ground floor plan (website group #bpPlan, moved -660, 40)
    canvas.save();
    canvas.translate(-660, 40);
    canvas.drawRect(const Rect.fromLTRB(700, 140, 1120, 470), line);
    final plan = Path()
      ..moveTo(700, 300)
      ..lineTo(880, 300)
      ..moveTo(880, 140)
      ..lineTo(880, 470)
      ..moveTo(980, 300)
      ..lineTo(980, 470)
      ..moveTo(880, 300)
      ..lineTo(1120, 300)
      ..addArc(const Rect.fromLTWH(760, 260, 80, 80), math.pi, math.pi / 2)
      ..addArc(const Rect.fromLTWH(880, 340, 80, 80), math.pi / 2, math.pi / 2)
      ..addArc(const Rect.fromLTWH(960, 260, 80, 80), 0, math.pi / 2);
    canvas.drawPath(plan, line);
    final pd = Path()
      ..moveTo(700, 110)
      ..lineTo(1120, 110)
      ..moveTo(700, 102)
      ..lineTo(700, 118)
      ..moveTo(1120, 102)
      ..lineTo(1120, 118)
      ..moveTo(880, 102)
      ..lineTo(880, 118)
      ..moveTo(1150, 140)
      ..lineTo(1150, 470)
      ..moveTo(1142, 140)
      ..lineTo(1158, 140)
      ..moveTo(1142, 470)
      ..lineTo(1158, 470);
    canvas.drawPath(pd, dim);
    label('3600', 760, 96);
    label('4800', 970, 96);
    label('6600', 1158, 310);
    label('Living', 745, 225);
    label('Bedroom 1', 935, 225);
    label('Kitchen', 745, 390);
    label('Bath', 905, 450);
    label('Bedroom 2', 1010, 390);
    label('GROUND FLOOR PLAN  1:100', 700, 510, title: true);
    canvas.restore();

    // front elevation (website group #bpElev, moved 10, 560)
    canvas.save();
    canvas.translate(10, 560);
    final elev = Path()
      ..moveTo(120, 760)
      ..lineTo(600, 760)
      ..moveTo(150, 760)
      ..lineTo(150, 560)
      ..lineTo(570, 560)
      ..lineTo(570, 760)
      ..moveTo(130, 566)
      ..lineTo(360, 430)
      ..lineTo(590, 566)
      ..addRect(const Rect.fromLTWH(190, 610, 70, 60))
      ..addRect(const Rect.fromLTWH(455, 610, 70, 60))
      ..moveTo(330, 760)
      ..lineTo(330, 640)
      ..lineTo(390, 640)
      ..lineTo(390, 760)
      ..moveTo(225, 610)
      ..lineTo(225, 670)
      ..moveTo(490, 610)
      ..lineTo(490, 670)
      ..moveTo(190, 640)
      ..lineTo(260, 640)
      ..moveTo(455, 640)
      ..lineTo(525, 640);
    canvas.drawPath(elev, line);
    final ed = Path()
      ..moveTo(150, 800)
      ..lineTo(570, 800)
      ..moveTo(150, 792)
      ..lineTo(150, 808)
      ..moveTo(570, 792)
      ..lineTo(570, 808)
      ..moveTo(360, 792)
      ..lineTo(360, 808)
      ..moveTo(100, 560)
      ..lineTo(100, 760)
      ..moveTo(92, 560)
      ..lineTo(108, 560)
      ..moveTo(92, 760)
      ..lineTo(108, 760);
    canvas.drawPath(ed, dim);
    label('5400', 255, 822);
    label('5400', 465, 822);
    label('3000', 40, 664);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
