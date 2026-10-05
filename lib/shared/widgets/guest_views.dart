import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'baid_ui.dart';

/// The website's signed-out Profile tab (#profileGuest): the BAID X mark in a
/// glass frame and two glass options, one for professionals and one for hiring.
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
              Text('Get started', textAlign: TextAlign.center, style: AppTextStyles.section.copyWith(fontWeight: FontWeight.w800, letterSpacing: .3)),
              const SizedBox(height: 36),
              const Center(child: BrandFrame(size: 132)),
              const SizedBox(height: 34),
              _GuestOption(
                icon: Icons.work_outline,
                title: 'I\'m a professional',
                sub: 'Workers, project managers and suppliers. Get verified and get hired.',
                onTap: () => context.push('${AppRoutes.signIn}?group=pro'),
              ),
              const SizedBox(height: 12),
              _GuestOption(
                icon: Icons.home_outlined,
                title: 'I\'m hiring',
                sub: 'Homeowners and companies. Hire safely and pay through escrow.',
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
                      const SizedBox(width: 150, height: 130, child: CustomPaint(painter: _SecureBubbles())),
                      const SizedBox(height: 30),
                      Text('Your messages live here', style: AppTextStyles.section.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text('Sign in to message verified professionals, companies and suppliers. Conversations are private and end-to-end encrypted.', textAlign: TextAlign.center, style: AppTextStyles.body.copyWith(color: AppColors.muted, fontSize: 14)),
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

/// The website's signed-out Chats illustration: two chat bubbles, one locked.
class _SecureBubbles extends CustomPainter {
  const _SecureBubbles();

  @override
  void paint(Canvas canvas, Size size) {
    // drawn on the website's 150x130 grid, then scaled
    canvas.scale(size.width / 150, size.height / 130);
    final line = Paint()
      ..color = const Color(0xFFD9D9D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    void bubble(Rect r, double radius, Path tail, Color fill) {
      final body = RRect.fromRectAndRadius(r, Radius.circular(radius));
      canvas.drawRRect(body, Paint()..color = fill);
      canvas.drawPath(tail, Paint()..color = fill);
      canvas.drawRRect(body, line);
      canvas.drawPath(tail, line);
    }

    bubble(const Rect.fromLTWH(14, 18, 84, 56), 18, Path()..moveTo(34, 74)..lineTo(34, 92)..lineTo(52, 74), const Color(0xFF2B2B2B));
    final grey = Paint()
      ..color = const Color(0xFF7A7A7A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(34, 40), const Offset(78, 40), grey);
    canvas.drawLine(const Offset(34, 54), const Offset(62, 54), grey);
    bubble(const Rect.fromLTWH(72, 58, 64, 44), 15, Path()..moveTo(118, 102)..lineTo(118, 116)..lineTo(104, 102), const Color(0xFF1F1F1F));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(95, 77, 18, 14), const Radius.circular(3)), Paint()..color = const Color(0xFFD9D9D9));
    canvas.drawArc(const Rect.fromLTWH(98, 67, 12, 12), 3.1416, 3.1416, false, line);
    canvas.drawLine(const Offset(98, 73), const Offset(98, 77), line);
    canvas.drawLine(const Offset(110, 73), const Offset(110, 77), line);
  }

  @override
  bool shouldRepaint(_SecureBubbles oldDelegate) => false;
}
