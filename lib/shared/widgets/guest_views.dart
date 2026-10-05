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
                onTap: () => context.push(AppRoutes.signIn),
              ),
              const SizedBox(height: 12),
              _GuestOption(
                icon: Icons.home_outlined,
                title: 'Sign in as a client',
                sub: 'For homeowners hiring, and for companies',
                onTap: () => context.push(AppRoutes.signIn),
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
                Text(title, style: AppTextStyles.label.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(sub, style: AppTextStyles.caption.copyWith(color: const Color(0xFFCFCFCF), fontSize: 13)),
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
    return Scaffold(
      body: AppBackdrop(
        art: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chats', style: AppTextStyles.headline),
                const Spacer(),
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 72, color: Colors.white),
                      const SizedBox(height: 22),
                      Text('Sign in to view chats', style: AppTextStyles.section.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('Your conversations will appear here after you sign in.', textAlign: TextAlign.center, style: AppTextStyles.body.copyWith(color: AppColors.muted, fontSize: 14)),
                      const SizedBox(height: 22),
                      PillButton(label: 'Sign in', expand: false, onPressed: () => context.push(AppRoutes.signIn)),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
