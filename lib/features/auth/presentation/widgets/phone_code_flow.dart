import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/form_message.dart';
import '../../domain/auth_repository.dart';

/// Phone number → SMS code → password. Used for sign-up and for resetting a
/// forgotten password, exactly like the website (the codes come from the same server).
class PhoneCodeFlow extends ConsumerStatefulWidget {
  const PhoneCodeFlow({required this.purpose, required this.onDone, super.key});

  final PhoneCodePurpose purpose;
  final VoidCallback onDone;

  @override
  ConsumerState<PhoneCodeFlow> createState() => _PhoneCodeFlowState();
}

enum _Step { phone, code, password }

class _PhoneCodeFlowState extends ConsumerState<PhoneCodeFlow> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  var _step = _Step.phone;
  var _busy = false;
  var _show = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _signup => widget.purpose == PhoneCodePurpose.signup;

  Future<void> _run(Future<void> Function() action) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        await ref.read(authRepositoryProvider).startPhoneCode(phone: _phone.text.trim(), purpose: widget.purpose);
        setState(() => _step = _Step.code);
      });

  Future<void> _verify() => _run(() async {
        await ref.read(authRepositoryProvider).verifyPhoneCode(phone: _phone.text.trim(), code: _code.text);
        ref.read(pendingPhoneProvider.notifier).set(_phone.text.trim());
        setState(() => _step = _Step.password);
      });

  Future<void> _save() => _run(() async {
        await ref.read(authRepositoryProvider).setPhonePassword(_password.text);
        ref.invalidate(accountProfileProvider);
        widget.onDone();
      });

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.textMuted;
    final (title, help, button, onPressed) = switch (_step) {
      _Step.phone => (
          'Phone number',
          _signup ? 'We\'ll text you a code to confirm the number.' : 'Enter the number on your account. We\'ll text you a code.',
          'Send code',
          _send,
        ),
      _Step.code => ('Confirm the code', 'Enter the code we sent to ${_phone.text.trim()}.', 'Continue', _verify),
      _Step.password => (
          _signup ? 'Create a password' : 'New password',
          'At least 8 characters with a letter, a number, and a capital letter or a symbol.',
          _signup ? 'Create account' : 'Save password',
          _save,
        ),
    };
    final index = _Step.values.indexOf(_step);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Step ${index + 1} of 3', style: AppTextStyles.bodyMuted.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: (index + 1) / 3, minHeight: 6),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xxs),
          Text(help, style: AppTextStyles.bodyMuted.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.lg),
          if (_step == _Step.phone)
            AppTextField(
              key: const Key('phoneField'),
              label: 'Phone number',
              hint: '024 123 4567',
              controller: _phone,
              validator: Validators.ghanaPhone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
          if (_step == _Step.code) ...[
            AppTextField(
              key: const Key('codeField'),
              label: 'Code',
              controller: _code,
              validator: Validators.code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : () => setState(() => _step = _Step.phone),
                child: const Text('Change number or send a new code'),
              ),
            ),
          ],
          if (_step == _Step.password)
            AppTextField(
              key: const Key('passwordField'),
              label: 'Password',
              controller: _password,
              validator: Validators.strongPassword,
              obscureText: !_show,
              autofillHints: const [AutofillHints.newPassword],
              suffixIcon: IconButton(
                tooltip: _show ? 'Hide password' : 'Show password',
                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            FormMessage(_error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: button, isLoading: _busy, onPressed: () {
            HapticFeedback.selectionClick();
            onPressed();
          }),
        ],
      ),
    );
  }
}
