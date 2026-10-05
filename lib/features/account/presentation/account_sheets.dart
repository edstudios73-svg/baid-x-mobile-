import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, UserAttributes;

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../data/account_actions.dart';

/// Bottom sheets behind the website's account rows (js/features.js FX):
/// add email, change phone and change password.

Future<void> showGlassSheet(BuildContext context, {required String title, required Widget child}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xF20E0E0E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.3)),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

String friendlyError(Object e) => switch (e) {
      AppException(:final message) => message,
      AuthException(:final message) => message,
      _ => 'Something went wrong. Check your connection and try again.',
    };

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

/// The "current email / waiting for confirmation" line (`emailStatus`).
class EmailStatus extends StatelessWidget {
  const EmailStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final (cur, pending) = SupabaseConfig.client != null ? AccountActions().emailState() : ('', '');
    final rows = <Widget>[
      if (cur.isNotEmpty) _line('Current email', cur, ok: true),
      if (pending.isNotEmpty) _line('Waiting for confirmation', pending),
      if (cur.isEmpty && pending.isEmpty) _line('No email yet', 'You sign in with your phone number.'),
    ];
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows));
  }

  Widget _line(String k, String v, {bool ok = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: TextStyle(fontSize: 11.5, color: AppColors.muted, letterSpacing: .3)),
            Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
          if (ok) const Pill('Confirmed', tone: PillTone.ok),
        ]),
      );
}

/// Email field + "Send confirmation link"; used by the sheet and the Email step.
class AddEmailForm extends StatefulWidget {
  const AddEmailForm({this.onSent, super.key});
  final VoidCallback? onSent;

  @override
  State<AddEmailForm> createState() => _AddEmailFormState();
}

class _AddEmailFormState extends State<AddEmailForm> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AccountActions().addEmail(_c.text);
      if (!mounted) return;
      toast(context, 'Check your inbox and open the link to confirm.');
      widget.onSent?.call();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _c, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Email address', hintText: 'you@example.com', helperText: 'We send a link to confirm it.')),
      const SizedBox(height: 16),
      PillButton(label: 'Send confirmation link', loading: _busy, onPressed: _busy ? null : _send),
    ]);
  }
}

void openAddEmail(BuildContext context) => showGlassSheet(context, title: 'Sign-in email', child: Builder(builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const EmailStatus(), AddEmailForm(onSent: () => Navigator.of(c).pop())])));

void openChangePhone(BuildContext context) => showGlassSheet(context, title: 'Change phone', child: const _ChangePhone());

class _ChangePhone extends StatefulWidget {
  const _ChangePhone();
  @override
  State<_ChangePhone> createState() => _ChangePhoneState();
}

class _ChangePhoneState extends State<_ChangePhone> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final phone = _c.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\+?\d{9,15}$').hasMatch(phone)) return toast(context, 'Enter the number with its country code.');
    setState(() => _busy = true);
    try {
      await SupabaseConfig.client!.auth.updateUser(UserAttributes(phone: phone));
      if (!mounted) return;
      Navigator.of(context).pop();
      toast(context, 'We texted you a code.');
    } catch (_) {
      // same wording as the website: Supabase phone change needs its own SMS hook
      if (mounted) toast(context, "Phone changes need SMS, which isn't switched on yet.");
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _c, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'New mobile number', hintText: '+233201234567', helperText: 'Include the country code. We text a code to confirm.')),
        const SizedBox(height: 16),
        PillButton(label: 'Send code', loading: _busy, onPressed: _busy ? null : _send),
      ]);
}

void openChangePassword(BuildContext context) => showGlassSheet(context, title: 'Change password', child: const _ChangePassword());

class _ChangePassword extends ConsumerStatefulWidget {
  const _ChangePassword();
  @override
  ConsumerState<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<_ChangePassword> {
  final _a = TextEditingController(), _b = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final weak = Validators.strongPassword(_a.text);
    if (weak != null) return toast(context, weak);
    if (_a.text != _b.text) return toast(context, "The two passwords don't match.");
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_a.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      toast(context, 'Password updated');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _a, obscureText: true, decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters.')),
        const SizedBox(height: 12),
        TextField(controller: _b, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
        const SizedBox(height: 16),
        PillButton(label: 'Update password', loading: _busy, onPressed: _busy ? null : _save),
      ]);
}
