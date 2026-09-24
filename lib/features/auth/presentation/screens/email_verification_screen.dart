import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final user = ref.watch(authStateProvider).asData?.value;
    final shownEmail = user?.email.isNotEmpty == true ? user!.email : _email.text;
    final error = action.hasError ? action.error : null;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text(AppConfig.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text('Check your email', style: AppTextStyles.display),
            const SizedBox(height: AppSpacing.sm),
            Text(
              shownEmail.isEmpty
                  ? 'Open the BAID X email and confirm your address. This screen waits for Supabase, not a local switch.'
                  : 'We sent a confirmation link to $shownEmail. Open it, then check again.',
              style: AppTextStyles.body,
            ),
            if (user == null) ...[
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
            ],
            if (_notice != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_notice!, style: AppTextStyles.bodyMuted),
            ],
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error is AppException ? error.message : 'Couldn\'t resend the email.',
                style: AppTextStyles.bodyMuted,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Resend verification email',
              isLoading: action.isLoading,
              onPressed: () async {
                final email = user?.email.isNotEmpty == true
                    ? user!.email
                    : _email.text.trim();
                if (user == null && !_formKey.currentState!.validate()) return;
                final ok = await ref.read(authActionProvider.notifier).run(() {
                  return ref.read(authRepositoryProvider).resendVerification(email);
                });
                if (ok) setState(() => _notice = 'Verification email sent.');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'I\'ve verified my email',
              outlined: true,
              onPressed: () async {
                final ok = await ref.read(authActionProvider.notifier).run(() async {
                  final refreshed = await ref.read(authRepositoryProvider).refreshUser();
                  if (refreshed == null || !refreshed.emailConfirmed) {
                    throw const AuthFlowException(
                      'Email is not confirmed yet. Open the link, then try again.',
                    );
                  }
                });
                if (ok && context.mounted) context.go(AppRoutes.marketplace);
              },
            ),
            TextButton(
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go(AppRoutes.marketplace);
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
