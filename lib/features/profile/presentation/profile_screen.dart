import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/guest_views.dart';
import '../../account/presentation/member_profile_view.dart';

/// Profile tab: the guest view when signed out, the member account screen
/// (website `#profileMember`) once the account has a role profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) return const GuestProfileView();
    final profile = ref.watch(accountProfileProvider);
    return profile.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
      error: (_, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("We couldn't load your account. Check your connection and try again.", textAlign: TextAlign.center),
              const SizedBox(height: 16),
              PillButton(label: 'Try again', expand: false, height: 44, onPressed: () => ref.invalidate(accountProfileProvider)),
            ]),
          ),
        ),
      ),
      data: (me) {
        if (me == null || me.type == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Choose an account type to finish setting up.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  PillButton(label: 'Choose account type', expand: false, height: 44, onPressed: () => context.go(AppRoutes.accountType)),
                ]),
              ),
            ),
          );
        }
        return MemberProfileView(me: me);
      },
    );
  }
}
