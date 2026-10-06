import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../account_type/domain/account_type.dart';
import '../../tabs/data/tabs_data.dart';
import '../data/account_actions.dart';
import '../data/profile_data.dart';
import 'account_sheets.dart';

/// Profile menu pages, part 1 (website js/wallet.js, dash.js growthView,
/// features.js certsView / portfolioView / teamLinkView).

Widget backHead(BuildContext context, String title, {Widget? action}) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        GlassIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Back', size: 40, onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.profile)),
        const SizedBox(width: 10),
        Expanded(child: DashHead(title, action: action)),
      ]),
    );

/// A key/value line (`.wl-kv`, `.kv`).
class KV extends StatelessWidget {
  const KV(this.k, this.v, {this.strong = false, super.key});
  final String k, v;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        // label on the left, value pushed to the right edge (website `.kv`)
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(width: 14),
          Expanded(child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: strong ? FontWeight.w800 : FontWeight.w600))),
        ]),
      );
}

class Note extends StatelessWidget {
  const Note(this.text, {this.icon = Icons.shield_outlined, super.key});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lineGlass)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: const Color(0xFFCFCFCF)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFFCFCFCF), height: 1.4))),
        ]),
      );
}

class SecLabel extends StatelessWidget {
  const SecLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 0, 8),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 2.2, fontWeight: FontWeight.w700, color: Color(0xFF8C8C8C))),
      );
}

Widget field(String label, TextEditingController c, {String? hint, bool number = false, bool obscure = false, int lines = 1, TextInputType? keyboard, String? helper}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
        const SizedBox(height: 7),
        TextField(
          controller: c,
          obscureText: obscure,
          maxLines: obscure ? 1 : lines,
          keyboardType: keyboard ?? (number ? const TextInputType.numberWithOptions(decimal: true) : null),
          decoration: InputDecoration(hintText: hint, helperText: helper, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
        ),
      ]),
    );

Widget dropdown(String label, String? value, List<(String, String)> opts, ValueChanged<String?> on) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: AppColors.card,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
          items: [for (final o in opts) DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
          onChanged: on,
        ),
      ]),
    );

/// Runs a write with a busy flag, then refreshes and shows the result.
Future<bool> runAction(BuildContext context, Future<void> Function() fn, {String? ok}) async {
  try {
    await fn();
    if (context.mounted && ok != null) toast(context, ok);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
    return false;
  }
}

Future<void> openPaystack(BuildContext context, Future<dynamic> Function() start) async {
  // the sheet that called this is usually closing; keep the app's root screen and providers instead
  final root = Navigator.of(context, rootNavigator: true).context;
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final ck = asMap(await start());
    final reference = '${ck['reference']}';
    final url = await paystackUrl(reference);
    // confirm the payment ourselves when the payer comes back, so it activates even if Paystack's webhook is late
    if (root.mounted) _PaystackReturn.watch(root, container, reference);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (root.mounted) toast(root, friendlyError(e));
  }
}

/// Website confirmReturn: once the app is back in front, verify with the
/// server (which asks Paystack) a few times, then refresh plans and wallet.
class _PaystackReturn with WidgetsBindingObserver {
  _PaystackReturn(this.context, this.container, this.reference);
  final BuildContext context;
  final ProviderContainer container;
  final String reference;
  static _PaystackReturn? _current;
  var _left = false;

  static void watch(BuildContext context, ProviderContainer container, String reference) {
    if (_current != null) WidgetsBinding.instance.removeObserver(_current!);
    _current = _PaystackReturn(context, container, reference);
    WidgetsBinding.instance.addObserver(_current!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _left = true;
    if (state == AppLifecycleState.resumed && _left) {
      WidgetsBinding.instance.removeObserver(this);
      if (_current == this) _current = null;
      _confirm();
    }
  }

  Future<void> _confirm() async {
    if (!context.mounted) return;
    final step = ValueNotifier<int>(2);
    final nav = Navigator.of(context, rootNavigator: true);
    var open = true;
    showGlassSheet(
      context,
      title: 'Confirming your payment',
      child: ValueListenableBuilder<int>(
        valueListenable: step,
        builder: (_, s, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('We\'re checking with Paystack. This takes a few seconds.', style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
          const SizedBox(height: 12),
          for (final (n, t, sub) in const [(1, 'Payment received', 'Back from Paystack'), (2, 'Verifying with Paystack', 'Checking amount and reference'), (3, 'Activating', 'Adding it to your account')])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: n < s
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 22)
                      : n == s
                          ? const Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.muted, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted))])),
              ]),
            ),
        ]),
      ),
    ).whenComplete(() => open = false);
    for (var i = 0; i < 8; i++) {
      final st = await verifyPaystack(reference);
      if (st == 'successful') {
        container.invalidate(billingProvider);
        container.invalidate(walletProvider);
        container.invalidate(accountProfileProvider);
        if (open) nav.pop();
        if (context.mounted) toast(context, 'Payment confirmed. It\'s on your account now.');
        return;
      }
      if (st == 'failed') {
        if (open) nav.pop();
        if (context.mounted) toast(context, 'That payment didn\'t go through. Nothing was charged.');
        return;
      }
      if (i == 1) step.value = 3;
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      if (!open) return; // the payer closed it; the webhook still activates it
    }
    if (open) nav.pop();
    if (context.mounted) toast(context, 'Still waiting for Paystack to confirm. Your purchase activates as soon as it does.');
  }
}

// ======================================================================
// Wallet
// ======================================================================
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  static const _note = {
    'worker': 'Clients pay when they hire you and your money lands here once the work is approved. You can withdraw it to Mobile Money any time.',
    'business': 'When a customer\'s order is delivered and confirmed, the payment lands here. You can withdraw it to Mobile Money any time.',
    'project-manager': 'Your project fees land here when the client approves the work. You can withdraw them to Mobile Money any time.',
    'individual-employer': 'Add money with Paystack (Mobile Money or card), then pay for work and products from your balance. Money held for a job is only released when you approve it.',
    'company': 'Companies both pay and get paid: add money to fund hires and projects, and withdraw what you earn from work you deliver.',
  };
  static const _role = {'worker': 'Professional', 'company': 'Company', 'project-manager': 'Project manager', 'business': 'Supplier', 'individual-employer': 'Client'};
  static const _wd = {'pending': 'Processing', 'processing': 'Processing', 'completed': 'Paid', 'rejected': 'Returned', 'failed': 'Returned', 'cancelled': 'Cancelled'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashPage<WalletData>(
      head: backHead(context, 'Wallet'),
      data: ref.watch(walletProvider),
      onRefresh: () => ref.refresh(walletProvider.future),
      builder: (w) {
        final caps = w.caps;
        if (caps == null) return const [DashEmpty(icon: Icons.account_balance_wallet_outlined, title: 'No wallet', text: 'Your account type doesn\'t have a wallet.')];
        final dep = caps['can_deposit'] == true, wd = caps['can_withdraw'] == true, a = w.account;
        return [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFDFDFD), Color(0xFFDCDCDC)]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(wd && !dep ? 'Available to withdraw' : 'Available balance', style: const TextStyle(fontSize: 12.5, color: Color(0xFF444444), fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0x14000000), borderRadius: BorderRadius.circular(99)),
                  child: Text(_role['${caps['role']}'] ?? 'Account', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(money(a['available_ghs']), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -.5)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _sub(wd ? 'Processing' : 'In use', money(a['pending_ghs']))),
                if (wd) Expanded(child: _sub('Earned', money(a['lifetime_earned_ghs']))),
                if (dep) Expanded(child: _sub('Spent', money(a['lifetime_spent_ghs']))),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (dep) Expanded(child: PillButton(label: 'Add money', icon: Icons.add, height: 46, onPressed: () => _deposit(context, ref))),
            if (dep && wd) const SizedBox(width: 10),
            if (wd) Expanded(child: PillButton(label: dep ? 'Withdraw' : 'Withdraw to Mobile Money', light: !dep, height: 46, onPressed: () => _withdraw(context, ref))),
          ]),
          const SizedBox(height: 12),
          if (w.waiting) const Note('Your payment is being confirmed by Paystack. Your balance updates as soon as it is. Pull to refresh in a moment.', icon: Icons.schedule),
          Note(_note['${caps['role']}'] ?? ''),
          if (w.withdrawals.isNotEmpty) ...[
            const SecLabel('Withdrawals'),
            for (final x in w.withdrawals)
              DashRow(
                icon: Icons.payments_outlined,
                title: '${money(x['amount_ghs'])} · ${x['destination_network'] ?? 'Mobile Money'}',
                sub: '${x['public_id'] ?? ''} · ${ago(x['created_at'])}',
                trailing: StatusPill(x['status'] == 'completed' ? 'completed' : ['rejected', 'failed', 'cancelled'].contains(x['status']) ? '' : 'pending', label: _wd['${x['status']}'] ?? prettyText(x['status'])),
                onTap: () => _track(context, x),
              ),
          ],
          const SecLabel('Activity'),
          if (w.tx.isEmpty)
            DashEmpty(icon: Icons.account_balance_wallet_outlined, title: 'No transactions yet', text: dep ? 'Add money to get started.' : 'Earnings and withdrawals will be listed here.')
          else
            for (final t in w.tx)
              () {
                final plus = ['deposit', 'earning', 'escrow_release', 'escrow_refund'].contains(t['type']);
                return DashRow(
                  icon: plus ? Icons.account_balance_wallet_outlined : Icons.payments_outlined,
                  title: prettyText(t['type']).ifBlank('Transaction'),
                  sub: '${t['description'] ?? ''} · ${ago(t['created_at'])}',
                  trailing: Text('${plus ? '+' : '−'} ${money(t['net_ghs'] ?? t['amount_ghs'])}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: plus ? AppColors.green : null)),
                );
              }(),
        ];
      },
    );
  }

  Widget _sub(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(fontSize: 11.5, color: Color(0xFF555555))),
        Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.black)),
      ]);

  void _deposit(BuildContext context, WidgetRef ref) => showGlassSheet(context, title: 'Add money', child: const _Deposit());
  void _withdraw(BuildContext context, WidgetRef ref) => showGlassSheet(context, title: 'Withdraw', child: _Withdraw(onDone: () => ref.invalidate(walletProvider)));

  void _track(BuildContext context, Json w) {
    final bad = ['rejected', 'failed', 'cancelled'].contains(w['status']), done = w['status'] == 'completed';
    final acct = '${w['destination_account'] ?? ''}';
    showGlassSheet(
      context,
      title: 'Withdrawal',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KV('Amount', money(w['amount_ghs']), strong: true),
        KV('Status', _wd['${w['status']}'] ?? prettyText(w['status'])),
        KV('To', '${w['destination_network'] ?? 'Mobile Money'} · ${acct.length > 3 ? '${'•' * (acct.length - 3)}${acct.substring(acct.length - 3)}' : acct}'),
        KV('Reference', '${w['public_id'] ?? ''}'),
        KV('Requested', ago(w['created_at'])),
        const SizedBox(height: 10),
        Text(
          bad
              ? 'This withdrawal could not be paid${w['admin_note'] != null ? ': ${w['admin_note']}' : ''}. The money is back in your wallet.'
              : done
                  ? 'Paid to your number.'
                  : 'Expected within 24 hours. The money stays safely in BAID X until it is paid to your number.',
          style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
        ),
      ]),
    );
  }
}

extension on String {
  String ifBlank(String v) => trim().isEmpty ? v : this;
}

class _Deposit extends StatefulWidget {
  const _Deposit();
  @override
  State<_Deposit> createState() => _DepositState();
}

class _DepositState extends State<_Deposit> {
  final _amount = TextEditingController(text: '100');
  Json? _q;
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _quote();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _quote() async {
    final n = num.tryParse(_amount.text.replaceAll(',', ''));
    setState(() {
      _q = null;
      _err = null;
    });
    if (n == null || n <= 0) return;
    try {
      final q = asMap(await rpcCall('wallet_deposit_quote', {'p_amount': n}));
      if (mounted && num.tryParse(_amount.text.replaceAll(',', '')) == n) setState(() => _q = q);
    } catch (e) {
      if (mounted) setState(() => _err = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Pay securely with Paystack by Mobile Money or card. Your balance updates the moment the payment is confirmed.', style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
      const SizedBox(height: 12),
      TextField(
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _quote(),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        decoration: const InputDecoration(prefixText: 'GH₵ '),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: [
        for (final n in [50, 100, 200, 500, 1000])
          ChoiceChip(
            label: Text('$n'),
            selected: _amount.text == '$n',
            onSelected: (_) {
              _amount.text = '$n';
              _quote();
            },
          ),
      ]),
      const SizedBox(height: 10),
      if (_q != null) ...[KV('Amount', money(_q!['amount'])), KV('Paystack fee', money(_q!['fee'])), KV('You pay', money(_q!['total']), strong: true), KV('Added to your wallet', money(_q!['amount']))],
      if (_err != null) Text(_err!, style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
      const SizedBox(height: 12),
      PillButton(
        label: 'Continue to Paystack',
        icon: Icons.shield_outlined,
        loading: _busy,
        onPressed: _q == null || _busy
            ? null
            : () async {
                setState(() => _busy = true);
                final n = num.parse(_amount.text.replaceAll(',', ''));
                await openPaystack(context, () => rpcCall('wallet_start_deposit', {'p_amount': n}));
                if (context.mounted) Navigator.of(context).pop();
              },
      ),
      const SizedBox(height: 8),
      const Text('Powered by Paystack · BAID X never sees your card or PIN', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
    ]);
  }
}

class _Withdraw extends StatefulWidget {
  const _Withdraw({required this.onDone});
  final VoidCallback onDone;
  @override
  State<_Withdraw> createState() => _WithdrawState();
}

class _WithdrawState extends State<_Withdraw> {
  final _amount = TextEditingController(), _account = TextEditingController(), _name = TextEditingController(), _pw = TextEditingController();
  String _network = 'MTN MoMo';
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_amount, _account, _name, _pw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    final n = num.tryParse(_amount.text.replaceAll(',', ''));
    if (n == null || n <= 0) return setState(() => _err = 'Enter an amount.');
    if (_pw.text.isEmpty) return setState(() => _err = 'Enter your password to authorize.');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final ref = await requestWithdrawal(amount: n, network: _network, account: _account.text.trim(), name: _name.text.trim(), password: _pw.text);
      widget.onDone();
      if (!mounted) return;
      Navigator.of(context).pop();
      toast(context, 'Withdrawal requested · $ref');
    } catch (e) {
      if (mounted) setState(() => _err = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Flexible(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('The money is sent to your Mobile Money after you authorize it. We process withdrawals within 24 hours. It is held safely until then.', style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 12),
            field('Amount (GH₵)', _amount, number: true),
            dropdown('Network', _network, const [('MTN MoMo', 'MTN MoMo'), ('Telecel Cash', 'Telecel Cash'), ('AirtelTigo Money', 'AirtelTigo Money')], (v) => setState(() => _network = v ?? _network)),
            field('Mobile Money number', _account, hint: '024 123 4567', keyboard: TextInputType.phone),
            field('Name on the account', _name),
            field('Your password', _pw, obscure: true, helper: 'Confirms it\'s really you.'),
            if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_err!, style: const TextStyle(color: AppColors.red, fontSize: 12.5))),
            PillButton(label: 'Authorize withdrawal', icon: Icons.shield_outlined, loading: _busy, onPressed: _busy ? null : _go),
            const SizedBox(height: 8),
            const Text('If the payout can\'t be made, the money returns to your wallet automatically.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ]),
        ),
      );
}

// ======================================================================
// Career growth
// ======================================================================
class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(accountProfileProvider).asData?.value?.row ?? const {};
    final xp = (num.tryParse('${p['xp_total'] ?? 0}') ?? 0).toInt();
    return DashPage<List<Json>>(
      head: backHead(context, 'Career Growth'),
      data: ref.watch(xpEventsProvider),
      onRefresh: () => ref.refresh(xpEventsProvider.future),
      builder: (ev) => [
        SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(prettyText(p['rank_tier']).ifBlank('New worker'), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            Text('$xp XP', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            DashBar((xp / 2000 * 100).clamp(0, 100)),
            const SizedBox(height: 10),
            Text('Trust score ${(num.tryParse('${p['trust_score'] ?? 0}') ?? 0).toStringAsFixed(1)} · Keep going, levels rise with real work', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        const SecLabel('How to earn XP'),
        for (final (t, v) in const [('Verify your identity', '+100 XP'), ('Get accepted for a job', '+80 XP'), ('Complete a job', '+120 XP'), ('Complete your profile', '+50 XP')])
          DashRow(icon: Icons.star_border_rounded, title: t, trailing: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        const SecLabel('Certifications'),
        DashRow(icon: Icons.workspace_premium_outlined, title: 'Trade certificates and licences', sub: 'Upload them to build trust.', onTap: () => context.push(AppRoutes.certs)),
        const SecLabel('Recent XP'),
        if (ev.isEmpty)
          const DashEmpty(icon: Icons.trending_up, title: 'No XP yet', text: 'Complete your profile and apply for jobs to start earning.')
        else
          for (final e in ev) DashRow(icon: Icons.trending_up, title: prettyText(e['kind']), sub: ago(e['created_at']), trailing: Text('+${e['points']} XP', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

// ======================================================================
// Certifications (worker list, project manager certificate form)
// ======================================================================
class CertsScreen extends ConsumerWidget {
  const CertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(accountProfileProvider).asData?.value;
    if (me?.type == AccountType.projectManager) return _PmCert(row: me!.row);
    final add = SmallButton('Add', onPressed: () => showGlassSheet(context, title: 'Add certification', child: _AddCert(onSaved: () => ref.invalidate(certsProvider))));
    return DashPage<List<Json>>(
      head: backHead(context, 'Certifications', action: add),
      data: ref.watch(certsProvider),
      onRefresh: () => ref.refresh(certsProvider.future),
      builder: (list) => list.isEmpty
          ? [DashEmpty(icon: Icons.workspace_premium_outlined, title: 'No certifications yet', text: 'Upload trade certificates and licences to build trust.', action: add)]
          : [
              for (final x in list)
                DashRow(
                  icon: Icons.workspace_premium_outlined,
                  title: '${x['cert_name'] ?? 'Certificate'}',
                  sub: '${x['issuing_body'] ?? 'Issuer not set'} · ${ago(x['created_at'])}',
                  trailing: StatusPill(x['verified'] == true ? 'done' : 'pending', label: x['verified'] == true ? 'Checked' : 'Not checked'),
                  below: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SmallButton('Remove', light: false, onPressed: () async {
                      if (await runAction(context, () => sb.from('worker_certifications').delete().eq('id', '${x['id']}'))) ref.invalidate(certsProvider);
                    }),
                  ),
                ),
            ],
    );
  }
}

class _AddCert extends StatefulWidget {
  const _AddCert({required this.onSaved});
  final VoidCallback onSaved;
  @override
  State<_AddCert> createState() => _AddCertState();
}

class _AddCertState extends State<_AddCert> {
  final _name = TextEditingController(), _issuer = TextEditingController();
  PlatformFile? _doc;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _issuer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return toast(context, 'Name the certificate.');
    if (_doc == null) return toast(context, 'Choose the certificate file.');
    setState(() => _busy = true);
    final ok = await runAction(context, () async {
      final path = await AccountActions().upload('trade-licenses', await _doc!.readAsBytes(), _doc!.name, 'cert');
      await sb.from('worker_certifications').insert({'worker_id': myId, 'cert_name': _name.text.trim(), 'issuing_body': _issuer.text.trim().isEmpty ? null : _issuer.text.trim(), 'document_url': path});
    }, ok: 'Certification added');
    if (ok) {
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        field('Certificate name', _name, hint: 'e.g. NVTI Electrical Installation'),
        field('Issued by', _issuer),
        Row(children: [
          Expanded(child: Text(_doc?.name ?? 'Certificate file · photo or PDF, up to 8 MB', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
          SmallButton('Choose', light: false, onPressed: () async {
            final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf']);
            if (f != null) setState(() => _doc = f);
          }),
        ]),
        const SizedBox(height: 14),
        PillButton(label: 'Save certification', loading: _busy, onPressed: _busy ? null : _save),
      ]);
}

class _PmCert extends ConsumerStatefulWidget {
  const _PmCert({required this.row});
  final Json row;
  @override
  ConsumerState<_PmCert> createState() => _PmCertState();
}

class _PmCertState extends ConsumerState<_PmCert> {
  late final _body = TextEditingController(text: '${widget.row['certification_body'] ?? ''}');
  late final _num = TextEditingController(text: '${widget.row['certification_number'] ?? ''}');
  PlatformFile? _doc;
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    _num.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await runAction(context, () async {
      final patch = <String, dynamic>{'certification_body': _body.text.trim().isEmpty ? null : _body.text.trim(), 'certification_number': _num.text.trim().isEmpty ? null : _num.text.trim()};
      if (_doc != null) patch['certification_doc_url'] = await AccountActions().upload('trade-licenses', await _doc!.readAsBytes(), _doc!.name, 'cert');
      await AccountActions().save(AccountType.projectManager, patch);
      ref.invalidate(accountProfileProvider);
    }, ok: 'Saved');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final has = '${widget.row['certification_doc_url'] ?? ''}'.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: [
          backHead(context, 'Certifications'),
          SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('PROJECT MANAGEMENT CERTIFICATE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: .9, color: Color(0xFFBDBDBD))),
              const SizedBox(height: 12),
              field('Certification body', _body, hint: 'e.g. PMI, PRINCE2'),
              field('Certificate number', _num),
              Row(children: [
                Expanded(child: Text(_doc?.name ?? (has ? 'Uploaded. Choose a file to replace it.' : 'Certificate document · optional'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
                if (has && _doc == null) ...[const StatusPill('done', label: 'Uploaded'), const SizedBox(width: 6)],
                SmallButton(has ? 'Replace' : 'Upload', light: false, onPressed: () async {
                  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf']);
                  if (f != null) setState(() => _doc = f);
                }),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          PillButton(label: 'Save', loading: _busy, onPressed: _busy ? null : _save),
        ]),
      ),
    );
  }
}

// ======================================================================
// Portfolio (photos) and Past projects (project managers)
// ======================================================================
class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});
  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  bool _busy = false;

  Future<void> _addPhotos(AccountType type, List urls) async {
    final files = (await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'])).take(6).toList();
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    await runAction(context, () async {
      final a = AccountActions(), out = <String>[];
      for (final f in files) {
        out.add(a.publicUrl('portfolios', await a.upload('portfolios', await f.readAsBytes(), f.name, 'work')));
      }
      await a.save(type, {'portfolio_photo_urls': [...urls, ...out]});
      ref.invalidate(accountProfileProvider);
    }, ok: 'Photos added');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(accountProfileProvider).asData?.value;
    final type = me?.type;
    final p = me?.row ?? const {};
    if (type == AccountType.projectManager) return _PastProjects(row: p);
    final photos = p['portfolio_photo_urls'] is List ? p['portfolio_photo_urls'] as List : const [];
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: [
          backHead(context, 'Portfolio', action: type == null ? null : SmallButton(_busy ? 'Adding…' : 'Add photos', onPressed: _busy ? null : () => _addPhotos(type, photos))),
          Text('${type == AccountType.worker ? 'Show your best finished work.' : 'Show your products and past supply.'} Photos are public on your profile.', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            const DashEmpty(icon: Icons.photo_library_outlined, title: 'No photos yet', text: 'Add photos of completed work to build trust.')
          else
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < photos.length; i++)
                  Stack(fit: StackFit.expand, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network('${photos[i]}', fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.tile))),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () async {
                          final next = [...photos]..removeAt(i);
                          await runAction(context, () => AccountActions().save(type!, {'portfolio_photo_urls': next}));
                          ref.invalidate(accountProfileProvider);
                        },
                        child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle), child: const Icon(Icons.close, size: 15, color: Colors.white)),
                      ),
                    ),
                  ]),
              ],
            ),
        ]),
      ),
    );
  }
}

class _PastProjects extends ConsumerWidget {
  const _PastProjects({required this.row});
  final Json row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = row['past_projects_json'] is List ? [for (final x in row['past_projects_json'] as List) if (x is Map) Map<String, dynamic>.from(x)] : <Json>[];
    final add = SmallButton('Add', onPressed: () => showGlassSheet(context, title: 'Add a past project', child: _AddPast(existing: list, onSaved: () => ref.invalidate(accountProfileProvider))));
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: [
          backHead(context, 'Past projects', action: add),
          if (list.isEmpty)
            DashEmpty(icon: Icons.folder_outlined, title: 'No past projects yet', text: 'Show projects you have delivered so clients can see your track record.', action: add)
          else
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${list[i]['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
                      Text('${list[i]['year'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF))),
                    ]),
                    const SizedBox(height: 4),
                    Text([list[i]['client'], list[i]['description']].where((v) => v != null && '$v'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    SmallButton('Remove', light: false, onPressed: () async {
                      final next = [...list]..removeAt(i);
                      if (await runAction(context, () => AccountActions().save(AccountType.projectManager, {'past_projects_json': next}))) ref.invalidate(accountProfileProvider);
                    }),
                  ]),
                ),
              ),
        ]),
      ),
    );
  }
}

class _AddPast extends StatefulWidget {
  const _AddPast({required this.existing, required this.onSaved});
  final List<Json> existing;
  final VoidCallback onSaved;
  @override
  State<_AddPast> createState() => _AddPastState();
}

class _AddPastState extends State<_AddPast> {
  final _name = TextEditingController(), _client = TextEditingController(), _year = TextEditingController(), _desc = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _client, _year, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Flexible(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            field('Project name', _name),
            field('Client', _client),
            field('Year', _year, number: true),
            field('What you delivered', _desc, lines: 3),
            PillButton(
              label: 'Add project',
              loading: _busy,
              onPressed: _busy
                  ? null
                  : () async {
                      if (_name.text.trim().isEmpty) return toast(context, 'Name the project.');
                      setState(() => _busy = true);
                      final ok = await runAction(context, () => AccountActions().save(AccountType.projectManager, {
                            'past_projects_json': [
                              ...widget.existing,
                              {'name': _name.text.trim(), 'client': _client.text.trim(), 'year': _year.text.trim(), 'description': _desc.text.trim()},
                            ],
                          }));
                      if (ok) {
                        widget.onSaved();
                        if (context.mounted) Navigator.of(context).pop();
                      }
                      if (mounted) setState(() => _busy = false);
                    },
            ),
          ]),
        ),
      );
}

// ======================================================================
// Team & join code (company) / Link a company (project manager)
// ======================================================================
class TeamLinkScreen extends ConsumerStatefulWidget {
  const TeamLinkScreen({super.key});
  @override
  ConsumerState<TeamLinkScreen> createState() => _TeamLinkScreenState();
}

class _TeamLinkScreenState extends ConsumerState<TeamLinkScreen> {
  final _code = TextEditingController();
  String? _newCode;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Widget _status(String s) => StatusPill(s == 'approved' ? 'done' : s == 'pending' ? 'pending' : '', label: prettyText(s));

  @override
  Widget build(BuildContext context) {
    final isCo = ref.watch(accountProfileProvider).asData?.value?.type == AccountType.company;
    return DashPage<List<Json>>(
      head: backHead(context, isCo ? 'Team & join code' : 'Link a company'),
      top: [
        if (isCo)
          SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Join code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 6),
              const Text('Give this one-time code to a project manager. They enter it, you approve the link. A new code replaces the old one and lasts 30 days.', style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4)),
              if (_newCode != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(text: _newCode!)).then((_) => context.mounted ? toast(context, 'Code copied') : null),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF101010), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF444444))),
                    child: Text(_newCode!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 5)),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Shown once. Tap to copy and share it with your project manager.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
              const SizedBox(height: 12),
              SmallButton(_busy ? 'Creating…' : 'Create a code', onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await runAction(context, () async {
                        final c = await rpcCall('create_join_code');
                        setState(() => _newCode = '$c');
                      });
                      if (mounted) setState(() => _busy = false);
                    }),
            ]),
          )
        else
          Row(children: [
            Expanded(child: TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Enter the company\'s code', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)))),
            const SizedBox(width: 8),
            SmallButton(_busy ? 'Sending…' : 'Request link', onPressed: _busy
                ? null
                : () async {
                    if (_code.text.trim().isEmpty) return toast(context, 'Enter the code.');
                    setState(() => _busy = true);
                    if (await runAction(context, () => rpcCall('request_pm_link', {'p_code': _code.text.trim()}), ok: 'Request sent. The company will review it.')) {
                      _code.clear();
                      ref.invalidate(pmLinksProvider);
                    }
                    if (mounted) setState(() => _busy = false);
                  }),
          ]),
        SecLabel(isCo ? 'Linked project managers' : 'Your links'),
      ],
      data: ref.watch(pmLinksProvider),
      onRefresh: () => ref.refresh(pmLinksProvider.future),
      builder: (links) => links.isEmpty
          ? [isCo ? const DashEmpty(icon: Icons.groups_outlined, title: 'No linked project managers', text: 'Create a code and share it with the project manager you work with.') : const Text('No links yet.', style: TextStyle(color: AppColors.muted, fontSize: 13))]
          : [
              for (final l in links)
                DashRow(
                  leading: InitialsAvatar(name: '${isCo ? l['pm'] ?? 'Project manager' : l['company'] ?? 'Company'}', size: 38, radius: 19),
                  title: '${isCo ? l['pm'] ?? 'Project manager' : l['company'] ?? 'Company'}',
                  sub: ago(l['requested_at']),
                  trailing: _status('${l['status']}'),
                  below: isCo && ['pending', 'approved'].contains(l['status'])
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(spacing: 6, children: [
                            if (l['status'] == 'pending')
                              SmallButton('Approve', onPressed: () async {
                                if (await runAction(context, () => rpcCall('decide_pm_link', {'p_link': l['id'], 'p_approve': true}), ok: 'Linked')) ref.invalidate(pmLinksProvider);
                              }),
                            SmallButton(l['status'] == 'pending' ? 'Decline' : 'Remove', light: false, onPressed: () async {
                              if (await runAction(context, () => rpcCall('decide_pm_link', {'p_link': l['id'], 'p_approve': false}))) ref.invalidate(pmLinksProvider);
                            }),
                          ]),
                        )
                      : null,
                ),
            ],
    );
  }
}
