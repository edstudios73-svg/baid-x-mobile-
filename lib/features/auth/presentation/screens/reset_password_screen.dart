import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/auth_header.dart';
import '../../../../shared/widgets/form_message.dart';

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
      body: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const AuthHeader(
            title: 'New password',
            subtitle: 'Open the reset link from your email first. Then choose a new password here.',
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            if (_saved) ...[
              const FormMessage('Your password is updated. Sign in with the new one.', success: true),
              const SizedBox(height: AppSpacing.md),
            ],
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
              FormMessage(error is AppException ? error.message : 'Couldn\'t update the password.'),
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
        ],
      ),
    );
  }
}
