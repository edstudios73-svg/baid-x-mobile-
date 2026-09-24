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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final error = action.hasError ? action.error : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'Use the same email you use on the BAID X website.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
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
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error is AppException ? error.message : 'Couldn\'t sign in.',
                style: AppTextStyles.bodyMuted,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Sign in',
              isLoading: action.isLoading,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await ref.read(authActionProvider.notifier).run(() {
                  return ref.read(authRepositoryProvider).signIn(
                    email: _email.text.trim(),
                    password: _password.text,
                  );
                });
                if (!context.mounted) return;
                final message = ref.read(authActionProvider).error;
                if (!ok &&
                    message is AppException &&
                    message.message.contains('Confirm your email')) {
                  context.go(AppRoutes.emailVerification);
                  return;
                }
                if (!ok) return;
                final user = ref.read(authStateProvider).asData?.value;
                context.go(
                  user != null && !user.emailConfirmed
                      ? AppRoutes.emailVerification
                      : AppRoutes.marketplace,
                );
              },
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.forgotPassword),
              child: const Text('Forgot password'),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.signUp),
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
