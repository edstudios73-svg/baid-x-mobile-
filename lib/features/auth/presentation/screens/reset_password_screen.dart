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

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _saved = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final error = action.hasError ? action.error : null;
    return Scaffold(
      appBar: AppBar(title: const Text('New password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              _saved
                  ? 'Your password is updated. Sign in with the new one.'
                  : 'Open the reset link from your email first. Then choose a new password here.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'New password',
                    controller: _password,
                    validator: Validators.password,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Confirm password',
                    controller: _confirm,
                    validator: (value) =>
                        Validators.confirmPassword(value, _password.text),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error is AppException ? error.message : 'Couldn\'t update the password.',
                style: AppTextStyles.bodyMuted,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Update password',
              isLoading: action.isLoading,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await ref.read(authActionProvider.notifier).run(() {
                  return ref.read(authRepositoryProvider).updatePassword(_password.text);
                });
                if (ok) setState(() => _saved = true);
              },
            ),
            if (_saved)
              TextButton(
                onPressed: () => context.go(AppRoutes.signIn),
                child: const Text('Sign in'),
              ),
          ],
        ),
      ),
    );
  }
}
