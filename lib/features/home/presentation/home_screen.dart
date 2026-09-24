import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../account_type/domain/account_type.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final accountType = AccountType.fromDatabase(stored);
    return Scaffold(
      appBar: AppBar(
        title: const Text('BAID X'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text('Hello.', style: AppTextStyles.display),
          const SizedBox(height: AppSpacing.xs),
          Text(
            accountType == null
                ? 'Choose an account type to shape this home screen.'
                : '${accountType.label} account.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.lg),
          const TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: 'Search is ready when live data is connected',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppEmptyState(
            title: 'Nothing listed yet',
            message:
                'Jobs, workers, projects, and businesses will appear here from the existing BAID X database. No sample records are shown.',
          ),
          if (accountType == null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => context.push(AppRoutes.accountType),
              child: const Text('Choose account type'),
            ),
          ],
        ],
      ),
    );
  }
}
