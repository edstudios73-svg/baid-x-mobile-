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
      body: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const AuthHeader(
            title: 'Reset password',
            subtitle: 'We will email a reset link. The device clock is not used for this.',
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_sent) ...[
                      const FormMessage('If this email is registered, a reset link is on the way.', success: true),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Form(
                      key: _formKey,
                      child: AppTextField(
                        label: 'Email',
                        controller: _email,
                        validator: Validators.email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      FormMessage(error is AppException ? error.message : 'Couldn\'t send the email.'),
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
                    if (_sent) ...[
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.resetPassword),
                        child: const Text('I have the reset link'),
                      ),
                    ],
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
