import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/page_body.dart';
import '../../../shared/widgets/section_header.dart';
import '../../account_type/domain/account_type.dart';
import '../../discover/presentation/discover_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final accountType = AccountType.fromDatabase(stored);
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BAID X'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Text('Hello.', style: AppTextStyles.headline.copyWith(color: palette.text)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            accountType == null
                ? 'Choose an account type to shape this home screen.'
                : '${accountType.label} account.',
            style: AppTextStyles.bodyMuted.copyWith(color: palette.textMuted),
          ),
          if (accountType == null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Choose account type',
              onPressed: () => context.push(AppRoutes.accountType),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Browse BAID X'),
          const DirectoryLinks(),
        ],
      ),
    );
  }
}
