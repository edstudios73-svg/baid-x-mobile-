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
  var _showPassword = false;

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
      body: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const AuthHeader(
            title: 'Create account',
            subtitle: 'Create the same BAID X account used on the website. Confirm your email before using account actions.',
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          children: [
                            AppTextField(
                              label: 'Full name',
                              controller: _name,
                              validator: Validators.name,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Email',
                              controller: _email,
                              validator: Validators.email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Password',
                              controller: _password,
                              validator: Validators.password,
                              obscureText: !_showPassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              suffixIcon: IconButton(
                                tooltip: _showPassword ? 'Hide password' : 'Show password',
                                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Confirm password',
                              controller: _confirm,
                              validator: (value) => Validators.confirmPassword(value, _password.text),
                              obscureText: !_showPassword,
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      FormMessage(error is AppException ? error.message : 'Couldn\'t create the account.'),
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
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.signIn),
                      child: const Text('I already have an account'),
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
