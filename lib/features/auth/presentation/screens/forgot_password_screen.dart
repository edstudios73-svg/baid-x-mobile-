import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/auth_header.dart';
import '../../domain/auth_repository.dart';
import '../widgets/phone_code_flow.dart';

/// Reset a forgotten password with a code sent to the account's phone number.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const AuthHeader(title: 'Reset your password', subtitle: 'We\'ll text a code to your phone.'),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: PhoneCodeFlow(
                  purpose: PhoneCodePurpose.reset,
                  onDone: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
                    context.go(AppRoutes.home);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
