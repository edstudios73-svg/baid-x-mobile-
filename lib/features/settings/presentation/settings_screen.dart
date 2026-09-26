import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../billing/presentation/billing_providers.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/page_body.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authStateProvider).asData?.value?.email ?? '';
    final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final reviewer = ref.watch(reviewerFlagProvider).asData?.value == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        children: [
          const _GroupLabel('Account'),
          AppListGroup(
            children: [
              AppListRow(
                leading: AppAvatar(name: email.isEmpty ? 'Signed in' : email, size: 40),
                title: 'Signed in',
                subtitle: email.isEmpty ? 'Signed in' : email,
              ),
              AppListRow(
                leading: const AppAvatar.icon(Icons.person_outline, size: 40),
                title: 'Profile',
                onTap: () => context.go(AppRoutes.profile),
              ),
              AppListRow(
                leading: const AppAvatar.icon(Icons.notifications_none, size: 40),
                title: 'Notifications',
                subtitle: 'No notifications yet',
                onTap: () => context.go(AppRoutes.notifications),
              ),
            ],
          ),
          const _GroupLabel('Trust and billing'),
          AppListGroup(
            children: [
              AppListRow(
                leading: const AppAvatar.icon(Icons.receipt_long_outlined, size: 40),
                title: 'Billing',
                subtitle: 'Plans and payments. A payment is confirmed by BAID X, not this phone.',
                subtitleLines: 2,
                onTap: () => context.push(AppRoutes.billing),
              ),
              AppListRow(
                leading: const AppAvatar.icon(Icons.verified_user_outlined, size: 40),
                title: 'Verification',
                subtitle: 'Buy a check. Payment does not mark you verified.',
                subtitleLines: 2,
                onTap: () => context.push(AppRoutes.verification),
              ),
              AppListRow(
                leading: const AppAvatar.icon(Icons.badge_outlined, size: 40),
                title: 'XID',
                subtitle: 'Basic is free. Paid services start after payment is confirmed.',
                subtitleLines: 2,
                onTap: () => context.push(AppRoutes.xid),
              ),
              if (type == 'business')
                AppListRow(
                  leading: const AppAvatar.icon(Icons.campaign_outlined, size: 40),
                  title: 'Marketplace promotion',
                  subtitle: 'Promote your own listings.',
                  onTap: () => context.push(AppRoutes.promotions),
                ),
              if (type == 'company')
                AppListRow(
                  leading: const AppAvatar.icon(Icons.apartment_outlined, size: 40),
                  title: 'Company billing',
                  subtitle: 'Company owners only.',
                  onTap: () => context.push(AppRoutes.companyBilling),
                ),
              if (reviewer)
                AppListRow(
                  leading: const AppAvatar.icon(Icons.fact_check_outlined, size: 40),
                  title: 'Review verifications',
                  onTap: () => context.push(AppRoutes.verificationReview),
                ),
            ],
          ),
          const _GroupLabel('About'),
          const AppListGroup(
            children: [
              AppListRow(
                leading: AppAvatar.icon(Icons.lock_outline, size: 40),
                title: 'Privacy',
                subtitle: 'Your phone number stays private. Location is a place name, not a map pin.',
                subtitleLines: 3,
              ),
              AppListRow(
                leading: AppAvatar.icon(Icons.help_outline, size: 40),
                title: 'Help',
                subtitle: 'BAID X support will be available in a later release.',
                subtitleLines: 2,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Sign out',
            outlined: true,
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go(AppRoutes.marketplace);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The service-role key is never used in this app.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: context.palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxs, AppSpacing.md, 0, AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.caption.copyWith(color: context.palette.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      ),
    );
  }
}
