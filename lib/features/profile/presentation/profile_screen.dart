import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/page_body.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../account_type/domain/account_type.dart';
import '../../dashboard/domain/role_dashboard.dart';
import '../../billing/domain/product_rules.dart';
import '../../billing/presentation/product_screens.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../../shared/widgets/guest_views.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;
    final stored = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final type = AccountType.fromDatabase(stored);
    if (user == null) {
      return const GuestProfileView();
    }
    if (type == null) {
      return const Scaffold(body: Center(child: Text('Choose an account type to finish your profile.')));
    }
    final dashboard = ref.watch(_provider(type));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: dashboard.when(
        loading: () => const AppLoader(message: 'Loading your profile'),
        error: (error, _) {
          ErrorHandler.logSafe(error);
          return const Center(child: Text('Unable to load your profile.'));
        },
        data: (data) {
          final palette = context.palette;
          final name = data.name.isEmpty ? user.email : data.name;
          final details = [data.trade, data.location].where((v) => v.isNotEmpty).join(' · ');
          final percent = data.completionPercent.clamp(0, 100);
          return PageBody(
            children: [
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  AppAvatar(name: name, size: 64),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.title.copyWith(color: palette.text)),
                        Text(type.label, style: AppTextStyles.body.copyWith(color: palette.text)),
                        if (details.isNotEmpty) Text(details, style: AppTextStyles.bodyMuted.copyWith(color: palette.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              if (data.headline.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(data.headline, style: AppTextStyles.body.copyWith(color: palette.text)),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text('Profile $percent% complete', style: AppTextStyles.label.copyWith(color: palette.text)),
                  ),
                  if (data.verified) const StatusBadge.verified(),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: percent / 100,
                  color: AppColors.yellow,
                  backgroundColor: palette.line,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppListGroup(
                children: [
                  AppListRow(
                    leading: const AppAvatar.icon(Icons.edit_outlined, size: 40),
                    title: 'Edit profile',
                    onTap: () => context.push(type.setupPath),
                  ),
                  AppListRow(
                    leading: const AppAvatar.icon(Icons.verified_user_outlined, size: 40),
                    title: 'Verification',
                    subtitle: data.verified ? 'Your identity has been checked.' : 'Get your identity checked.',
                    onTap: () => context.push(AppRoutes.verification),
                  ),
                  AppListRow(
                    leading: const AppAvatar.icon(Icons.badge_outlined, size: 40),
                    title: 'XID',
                    subtitle: 'Your BAID X professional ID.',
                    onTap: () => context.push(AppRoutes.xid),
                  ),
                ],
              ),
              if (profileBoostTarget(stored) != null) ...[
                const SizedBox(height: AppSpacing.lg),
                BoostPanel(targetType: profileBoostTarget(stored)!, targetId: user.id, title: 'Boost profile'),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Sign out',
                outlined: true,
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/marketplace');
                },
              ),
            ],
          );
        },
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
