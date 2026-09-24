import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../account_type/domain/account_type.dart';
import '../domain/role_dashboard.dart';
import 'dashboard_providers.dart';

class DashboardListScreen extends ConsumerWidget {
  const DashboardListScreen({
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.itemsOf,
    super.key,
  });

  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final List<ListedItem> Function(RoleDashboard data) itemsOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = AccountType.fromDatabase(
      ref.watch(accountProfileProvider).asData?.value?.accountType,
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: type == null
          ? AppEmptyState(title: emptyTitle, message: emptyMessage)
          : ref.watch(_provider(type)).when(
              loading: () => const AppLoader(),
              error: (_, _) => const AppEmptyState(
                title: 'Something went wrong',
                message: 'Unable to load this list. Try again from your home screen.',
              ),
              data: (data) {
                final items = itemsOf(data);
                if (items.isEmpty) {
                  return AppEmptyState(title: emptyTitle, message: emptyMessage);
                }
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          item.detail.isEmpty ? item.title : '${item.title} · ${item.detail}',
                          style: AppTextStyles.body,
                        ),
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
