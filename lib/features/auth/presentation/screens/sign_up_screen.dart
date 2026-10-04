import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/auth_header.dart';
import '../../domain/auth_repository.dart';
import '../widgets/phone_code_flow.dart';

/// Create an account with a Ghana phone number, the same as on the website:
/// phone → SMS code → password, then choose the account type and set up the profile.
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const AuthHeader(title: 'Create your account', subtitle: 'Free. Your phone number is your sign-in.'),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PhoneCodeFlow(
                      purpose: PhoneCodePurpose.signup,
                      onDone: () => context.go(AppRoutes.accountType),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.signIn),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
