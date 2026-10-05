import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/app_providers.dart';

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
      extendBody: true,
      body: child,
      bottomNavigationBar: AppBottomNavigation(
        destinations: destinations,
        currentPath: path,
        onSelected: (next) => context.go(next),
      ),
    );
  }
}
