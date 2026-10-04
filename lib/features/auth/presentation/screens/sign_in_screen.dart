import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../account_type/domain/account_type.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/auth_header.dart';
import '../../../../shared/widgets/form_message.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  var _showPassword = false;
  var _usePhone = true;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _password.dispose();
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
          const AuthHeader(title: 'Welcome back', subtitle: 'Sign in with the same phone number or email you use on the BAID X website.'),
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
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: true, label: Text('Phone'), icon: Icon(Icons.phone_iphone)),
                                ButtonSegment(value: false, label: Text('Email'), icon: Icon(Icons.alternate_email)),
                              ],
                              selected: {_usePhone},
                              onSelectionChanged: (v) => setState(() => _usePhone = v.first),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (_usePhone)
                              AppTextField(
                                key: const Key('signInPhone'),
                                label: 'Phone number',
                                hint: '024 123 4567',
                                controller: _phone,
                                validator: Validators.ghanaPhone,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.telephoneNumber],
                              )
                            else
                              AppTextField(
                                key: const Key('signInEmail'),
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
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              suffixIcon: IconButton(
                                tooltip: _showPassword ? 'Hide password' : 'Show password',
                                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      FormMessage(error is AppException ? error.message : 'Couldn\'t sign in.'),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Sign in',
                      isLoading: action.isLoading,
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        final ok = await ref.read(authActionProvider.notifier).run(() {
                          final auth = ref.read(authRepositoryProvider);
                          return _usePhone
                              ? auth.signInWithPhone(phone: _phone.text.trim(), password: _password.text)
                              : auth.signInWithEmail(email: _email.text.trim(), password: _password.text);
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
                        final user = ref.read(authRepositoryProvider).currentUser;
                        if (user != null && !user.emailConfirmed) {
                          context.go(AppRoutes.emailVerification);
                          return;
                        }
                        ref.invalidate(accountProfileProvider);
                        final profile = await ref.read(authRepositoryProvider).loadProfile();
                        if (!context.mounted) return;
                        final home = AccountType.fromDatabase(profile?.accountType)?.homePath;
                        context.go(home ?? AppRoutes.accountType);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                      child: const Text('Forgot password'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'New to BAID X?',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMuted.copyWith(color: context.palette.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppButton(
                      label: 'Create account',
                      outlined: true,
                      onPressed: () => context.push(AppRoutes.signUp),
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
