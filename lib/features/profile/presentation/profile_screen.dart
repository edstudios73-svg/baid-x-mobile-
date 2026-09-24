import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../account_type/domain/account_type.dart';
import '../../dashboard/domain/role_dashboard.dart';
import '../../billing/domain/product_rules.dart';
import '../../billing/presentation/product_screens.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;
    final stored = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final type = AccountType.fromDatabase(stored);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    if (type == null) {
      return const Scaffold(body: Center(child: Text('Choose an account type to finish your profile.')));
    }
    final dashboard = ref.watch(_provider(type));
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: dashboard.when(
        loading: () => const AppLoader(message: 'Loading your profile'),
        error: (_, _) => const Center(child: Text('Unable to load your profile.')),
        data: (data) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.person_outline)),
            const SizedBox(height: AppSpacing.md),
            Text(data.name.isEmpty ? user.email : data.name, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(type.label, style: AppTextStyles.body),
            if (data.location.isNotEmpty) Text(data.location, style: AppTextStyles.bodyMuted),
            if (data.headline.isNotEmpty) Text(data.headline, style: AppTextStyles.bodyMuted),
            if (data.trade.isNotEmpty) Text(data.trade, style: AppTextStyles.bodyMuted),
            const SizedBox(height: AppSpacing.sm),
            Text('Profile ${data.completionPercent}% complete', style: AppTextStyles.label),
            if (data.verified) const Text('Verified', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Verification',
              outlined: true,
              onPressed: () => context.push(AppRoutes.verification),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'XID',
              outlined: true,
              onPressed: () => context.push(AppRoutes.xid),
            ),
            if (profileBoostTarget(stored) != null) ...[
              const SizedBox(height: AppSpacing.lg),
              BoostPanel(targetType: profileBoostTarget(stored)!, targetId: user.id, title: 'Boost profile'),
            ],
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Edit profile',
              outlined: true,
              onPressed: () => context.push(type.setupPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Sign out',
              outlined: true,
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/marketplace');
              },
            ),
          ],
        ),
      ),
    );
  }
}

FutureProvider<RoleDashboard> _provider(AccountType type) {
  return switch (type) {
    AccountType.worker => workerDashboardProvider,
    AccountType.employer => employerDashboardProvider,
    AccountType.business => businessDashboardProvider,
    AccountType.projectManager => projectManagerDashboardProvider,
    AccountType.company => companyDashboardProvider,
  };
}
