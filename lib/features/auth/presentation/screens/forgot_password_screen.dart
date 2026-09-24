import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  var _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final error = action.hasError ? action.error : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              _sent
                  ? 'If this email is registered, a reset link is on the way.'
                  : 'We will email a reset link. The device clock is not used for this.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: AppTextField(
                label: 'Email',
                controller: _email,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error is AppException ? error.message : 'Couldn\'t send the email.',
                style: AppTextStyles.bodyMuted,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Send reset link',
              isLoading: action.isLoading,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await ref.read(authActionProvider.notifier).run(() {
                  return ref
                      .read(authRepositoryProvider)
                      .sendPasswordReset(_email.text.trim());
                });
                if (ok) setState(() => _sent = true);
              },
            ),
            if (_sent)
              TextButton(
                onPressed: () => context.push(AppRoutes.resetPassword),
                child: const Text('I have the reset link'),
              ),
          ],
        ),
      ),
    );
  }
}
