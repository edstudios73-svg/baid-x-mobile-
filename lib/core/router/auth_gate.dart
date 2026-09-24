import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/app_providers.dart';
import '../constants/app_routes.dart';
import 'route_guards.dart';

/// Continues only when the Supabase user exists and the email is confirmed.
void requireAuthentication(
  BuildContext context,
  WidgetRef ref,
  VoidCallback onAllowed,
) {
  final auth = ref.read(authStateProvider);
  final user = auth.asData?.value;
  final gate = sessionGateFor(
    signedIn: user != null,
    emailConfirmed: user?.emailConfirmed ?? false,
  );
  switch (gate) {
    case SessionGate.verified:
      onAllowed();
    case SessionGate.unverified:
      context.go(AppRoutes.emailVerification);
    case SessionGate.signedOut:
    case SessionGate.unknown:
      context.push(AppRoutes.signIn);
  }
}
