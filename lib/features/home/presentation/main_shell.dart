import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/app_providers.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../account_type/domain/account_type.dart';

class RoleShell extends ConsumerWidget {
  const RoleShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(accountProfileProvider).asData?.value?.accountType;
    return MainShell(
      accountType: AccountType.fromDatabase(stored),
      child: child,
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({
    required this.child,
    required this.accountType,
    super.key,
  });

  final Widget child;
  final AccountType? accountType;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final destinations = destinationsFor(accountType);
    return Scaffold(
      body: Column(
        children: [
          if (!SupabaseConfig.initialized)
            const Material(
              color: AppColors.ink,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    'Supabase is not connected yet. No live BAID X data is loaded.',
                    style: TextStyle(color: AppColors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.palette.line)),
        ),
        child: AppBottomNavigation(
          destinations: destinations,
          currentPath: path,
          onSelected: (next) => context.go(next),
        ),
      ),
    );
  }
}
