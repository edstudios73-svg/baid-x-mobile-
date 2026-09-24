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

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final error = action.hasError ? action.error : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'Create the same BAID X account used on the website. Confirm your email before using account actions.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Full name',
                    controller: _name,
                    validator: Validators.name,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    validator: Validators.password,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Confirm password',
                    controller: _confirm,
                    validator: (value) => Validators.confirmPassword(value, _password.text),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SizedBox(height: 0),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error is AppException
                    ? error.message
                    : 'Couldn\'t create the account.',
                style: AppTextStyles.bodyMuted,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Create account',
              isLoading: action.isLoading,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await ref.read(authActionProvider.notifier).run(() {
                  return ref.read(authRepositoryProvider).signUp(
                    displayName: _name.text.trim(),
                    email: _email.text.trim(),
                    password: _password.text,
                  );
                });
                if (ok && context.mounted) {
                  context.go(AppRoutes.emailVerification);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
