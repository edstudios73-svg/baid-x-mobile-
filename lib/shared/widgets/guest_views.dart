import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'baid_ui.dart';

/// The website's signed-out Profile tab (#profileGuest): the BAID X mark in a
/// glass frame and two glass options to sign in as a Pro or as a client.
class GuestProfileView extends StatelessWidget {
  const GuestProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackdrop(
        art: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
            children: [
              const SizedBox(height: 14),
              Text('Profile', textAlign: TextAlign.center, style: AppTextStyles.section.copyWith(fontWeight: FontWeight.w800, letterSpacing: .3)),
              const SizedBox(height: 36),
              const Center(child: BrandFrame(size: 132)),
              const SizedBox(height: 34),
              _GuestOption(
                icon: Icons.work_outline,
                title: 'Sign in as a Pro',
                sub: 'For professionals, project managers and suppliers',
                onTap: () => context.push('${AppRoutes.signIn}?group=pro'),
              ),
              const SizedBox(height: 12),
              _GuestOption(
                icon: Icons.home_outlined,
                title: 'Sign in as a client',
                sub: 'For homeowners hiring, and for companies',
                onTap: () => context.push('${AppRoutes.signIn}?group=client'),
              ),
              const SizedBox(height: 18),
              Text(
                'By continuing you agree to the BAID X Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: const Color(0xFFCFCFCF), shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 8)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestOption extends StatelessWidget {
  const _GuestOption({required this.icon, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 24,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(sub, style: AppTextStyles.caption.copyWith(color: const Color(0xFFCFCFCF), fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}

/// The website's signed-out Chats tab: an empty state asking the visitor to sign in.
class GuestChatsView extends StatelessWidget {
  const GuestChatsView({super.key});

  @override
  Widget build(BuildContext context) {
    // plain grid page like the website (the ring art is only on sign-in and Profile)
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chats', style: AppTextStyles.headline.copyWith(fontSize: 26)),
                const Spacer(),
                Center(
                  child: Column(
                    children: [
                      const SizedBox(width: 120, height: 110, child: CustomPaint(painter: _OpenBox())),
                      const SizedBox(height: 30),
                      Text('Sign in to view chats', style: AppTextStyles.section.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text('Your conversations will appear here after you sign in.', textAlign: TextAlign.center, style: AppTextStyles.body.copyWith(color: AppColors.muted, fontSize: 14)),
                      ),
                      const SizedBox(height: 22),
                      PillButton(label: 'Sign in', expand: false, height: 44, onPressed: () => context.push(AppRoutes.signIn)),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The website's empty-chats illustration: an open box with a dotted arc.
class _OpenBox extends CustomPainter {
  const _OpenBox();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Paint()
      ..color = const Color(0xFFE6E6E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    final top = Offset(w * .5, h * .30), left = Offset(w * .12, h * .45), right = Offset(w * .88, h * .45), mid = Offset(w * .5, h * .60);
    final bl = Offset(w * .12, h * .78), br = Offset(w * .88, h * .78), bm = Offset(w * .5, h * .95);
    // box sides
    canvas.drawPath(Path()..moveTo(left.dx, left.dy)..lineTo(mid.dx, mid.dy)..lineTo(bm.dx, bm.dy)..lineTo(bl.dx, bl.dy)..close(), Paint()..color = const Color(0xFF2E2E2E));
    canvas.drawPath(Path()..moveTo(right.dx, right.dy)..lineTo(mid.dx, mid.dy)..lineTo(bm.dx, bm.dy)..lineTo(br.dx, br.dy)..close(), Paint()..color = const Color(0xFF242424));
    canvas.drawPath(Path()..moveTo(left.dx, left.dy)..lineTo(top.dx, top.dy)..lineTo(right.dx, right.dy)..lineTo(mid.dx, mid.dy)..close(), Paint()..color = const Color(0xFF3A3A3A));
    // open flaps and edges
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(w * .30, h * .36)
        ..lineTo(top.dx, h * .44)
        ..lineTo(w * .70, h * .36)
        ..lineTo(right.dx, right.dy)
        ..moveTo(left.dx, left.dy)
        ..lineTo(bl.dx, bl.dy)
        ..lineTo(bm.dx, bm.dy)
        ..lineTo(br.dx, br.dy)
        ..lineTo(right.dx, right.dy)
        ..moveTo(mid.dx, mid.dy)
        ..lineTo(bm.dx, bm.dy),
      line,
    );
    // dotted arc and sparks
    final dot = Paint()..color = const Color(0xFFBDBDBD);
    for (var i = 0; i < 5; i++) {
      final a = -2.4 + i * .32;
      canvas.drawCircle(Offset(w * .55 + 16 * _cos(a), h * .12 + 10 * _sin(a)), 1.6, dot);
    }
    canvas.drawCircle(Offset(w * .67, h * .12), 4, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * .02, h * .25), 2.5, dot);
    canvas.drawCircle(Offset(w * .98, h * .68), 2.5, dot);
  }

  static double _cos(double a) => math.cos(a);
  static double _sin(double a) => math.sin(a);

  @override
  bool shouldRepaint(_OpenBox oldDelegate) => false;
}
