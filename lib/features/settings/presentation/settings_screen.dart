import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../billing/presentation/billing_providers.dart';
import '../../../shared/widgets/app_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authStateProvider).asData?.value?.email ?? '';
    final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final reviewer = ref.watch(reviewerFlagProvider).asData?.value == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(title: const Text('Account'), subtitle: Text(email.isEmpty ? 'Signed in' : email)),
          ListTile(
            title: const Text('Profile'),
            onTap: () => context.go(AppRoutes.profile),
          ),
          ListTile(
            title: const Text('Billing'),
            subtitle: const Text('Plans and payments. A payment is confirmed by BAID X, not this phone.'),
            onTap: () => context.push(AppRoutes.billing),
          ),
          ListTile(
            title: const Text('Verification'),
            subtitle: const Text('Buy a check. Payment does not mark you verified.'),
            onTap: () => context.push(AppRoutes.verification),
          ),
          ListTile(
            title: const Text('XID'),
            subtitle: const Text('Basic is free. Paid services start after payment is confirmed.'),
            onTap: () => context.push(AppRoutes.xid),
          ),
          if (type == 'business')
            ListTile(
              title: const Text('Marketplace promotion'),
              subtitle: const Text('Promote your own listings.'),
              onTap: () => context.push(AppRoutes.promotions),
            ),
          if (type == 'company')
            ListTile(
              title: const Text('Company billing'),
              subtitle: const Text('Company owners only.'),
              onTap: () => context.push(AppRoutes.companyBilling),
            ),
          if (reviewer)
            ListTile(
              title: const Text('Review verifications'),
              onTap: () => context.push(AppRoutes.verificationReview),
            ),
          ListTile(
            title: const Text('Notifications'),
            subtitle: const Text('No notifications yet'),
            onTap: () => context.go(AppRoutes.notifications),
          ),
          const ListTile(
            title: Text('Privacy'),
            subtitle: Text('Your phone number stays private. Location is a place name, not a map pin.'),
          ),
          const ListTile(
            title: Text('Help'),
            subtitle: Text('BAID X support will be available in a later release.'),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppButton(
              label: 'Sign out',
              outlined: true,
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go(AppRoutes.marketplace);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'The service-role key is never used in this app.',
              style: AppTextStyles.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}
