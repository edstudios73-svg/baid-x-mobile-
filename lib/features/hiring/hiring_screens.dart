import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/baid_ui.dart';
import '../../shared/widgets/dash_ui.dart';
import '../account/data/profile_data.dart';
import '../account/presentation/account_sheets.dart';
import '../account/presentation/profile_pages.dart' show KV, Note, backHead;
import '../directory/presentation/member_sheet.dart' show startConversationWith;
import '../tabs/data/tabs_data.dart';
import '../workspace/presentation/ws_common.dart';

/// Hire -> escrow -> release for jobs (website js/escrow.js). Money never moves
/// here: hire_worker locks the employer's wallet money in escrow and the
/// engagement_* functions release it (minus commission) only on approval,
/// auto-release or a BAID X decision.

void _follow(Ref ref) => ref.watch(authStateProvider.select((a) => a.asData?.value?.id));

final myEngagementsProvider = FutureProvider<List<Json>>((ref) async {
  _follow(ref);
  return asList(await rpcCall('my_engagements'));
});

class ApplicantsData {
  const ApplicantsData(this.job, this.apps, [this.details = const {}]);
  final Json? job;
  final List<Json> apps;
  final Map<String, Json> details; // profile and reviews by worker id (applicant_details)
}

final jobApplicantsProvider = FutureProvider.family<ApplicantsData, String>((ref, jobId) async {
  _follow(ref);
  final r = await Future.wait(<Future<dynamic>>[
    sb.from('jobs').select('id,title,status,daily_rate_ghs,workers_needed,city_town').eq('id', jobId).maybeSingle(),
    rpcCall('job_applicants', {'p_job': jobId}),
    // reviews are private to each job, so the owner reads applicants' reviews through this function
    rpcCall('applicant_details', {'p_job': jobId}).catchError((Object _) => <Object>[]),
  ]);
  final details = {for (final d in asList(r[2])) '${d['worker_id']}': d};
  return ApplicantsData(r[0] == null ? null : asMap(r[0]), asList(r[1]), details);
});

const escrowAccent = Color(0xFFFFFFFF);

/// `.es-btn`: the white escrow button (ghost: outlined).
class EscrowButton extends StatelessWidget {
  const EscrowButton(this.label, {required this.onPressed, this.icon, this.ghost = false, this.busy = false, super.key});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool ghost, busy;

  @override
  Widget build(BuildContext context) {
    final fg = ghost ? const Color(0xFFE9E9E9) : const Color(0xFF000000);
    return Opacity(
      opacity: onPressed == null ? .4 : busy ? .7 : 1,
      child: Material(
        color: ghost ? Colors.transparent : escrowAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: ghost ? const Color(0x33FFFFFF) : escrowAccent)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            height: 50,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg)) else if (icon != null) Icon(icon, size: 18, color: fg),
              if (busy || icon != null) const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg))),
            ]),
          ),
        ),
      ),
    );
  }
}

const _st = {'active': ('In progress', 'pending'), 'submitted': ('Awaiting approval', 'pending'), 'released': ('Paid', 'paid'), 'disputed': ('In dispute', 'rejected'), 'refunded': ('Refunded', ''), 'cancelled': ('Cancelled', '')};

Widget engagementPill(Object? s) {
  final v = _st['$s'];
  return WsPill(v?.$2 ?? s, label: v?.$1);
}

/// The website's escrow errors in plain words.
String escrowError(Object e) {
  final m = friendlyError(e);
  final s = RegExp(r'insufficient_funds:([\d.]+)').firstMatch(m);
  if (s != null) return 'You need ${money(s[1])} more in your wallet.';
  if (m.contains('not open')) return 'This job is no longer open.';
  if (m.contains('already hired')) return 'You have already hired this person.';
  if (m.contains('can no longer be hired')) return 'This application can no longer be hired.';
  if (m.contains('only the job owner')) return 'Only the person who posted the job can hire.';
  return m;
}

/// Rows for the Hires tab ("Hired professionals") and the Work tab.
List<Widget> engagementRows(BuildContext context, List<Json> list) => [for (final e in list) DashRow(icon: Icons.work_outline, title: '${e['title'] ?? 'Job'}', sub: '${e['counterpart'] ?? ''} · ${money(e['amount_ghs'])} · ${e['days']} day${(num.tryParse('${e['days']}') ?? 1) > 1 ? 's' : ''}', trailing: engagementPill(e['status']), onTap: () => context.push('${AppRoutes.engagement}/${e['id']}'))];

// ---------------------------------------------------------------- Applicants
class ApplicantsScreen extends ConsumerWidget {
  const ApplicantsScreen({required this.jobId, super.key});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(jobApplicantsProvider(jobId));
    final job = data.asData?.value.job;
    return DashPage<ApplicantsData>(
      head: backHead(context, job == null ? 'Applicants' : '${job['title']}'),
      data: data,
      onRefresh: () => ref.refresh(jobApplicantsProvider(jobId).future),
      builder: (d) {
        final j = d.job;
        if (j == null) {
          return [
            DashEmpty(
              icon: Icons.how_to_reg_outlined,
              title: 'Job not found',
              text: 'It may have been removed.',
              action: SmallButton('Back to jobs', onPressed: () => context.go(AppRoutes.myJobs)),
            ),
          ];
        }
        final needed = num.tryParse('${j['workers_needed'] ?? 1}') ?? 1;
        return [
          Text('${prettyText(j['status'])} · ${j['city_town'] ?? 'Ghana'} · needs $needed worker${needed > 1 ? 's' : ''}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 12),
          if (d.apps.isEmpty) const DashEmpty(icon: Icons.how_to_reg_outlined, title: 'No applicants yet', text: 'When professionals apply, they are listed here so you can message and hire them.'),
          for (final a in d.apps) _ApplicantCard(app: a, job: j, details: d.details['${a['worker_id']}']),
          const Note('Pay safely. When you hire, the money is held in escrow. It is released to the worker only when you approve the work.'),
        ];
      },
    );
  }
}

class _ApplicantCard extends ConsumerWidget {
  const _ApplicantCard({required this.app, required this.job, this.details});
  final Json app, job;
  final Json? details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = app;
    final hired = a['status'] == 'accepted';
    final years = '${a['years'] ?? ''}';
    final line = [if ('${a['trade'] ?? ''}'.isNotEmpty) '${a['trade']}', if (years.isNotEmpty && years != 'null') prettyText(years)].join(' · ');
    final asking = a['proposed_rate'] != null
        ? '${money(a['proposed_rate'])}/day'
        : job['daily_rate_ghs'] != null
        ? '${money(job['daily_rate_ghs'])}/day'
        : 'Not set';
    final canHire = job['status'] == 'open' && ['submitted', 'shortlisted'].contains(a['status']);
    return WsCard(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WsAvatar(a['name'], a['photo']),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${a['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (a['verified'] == true) const WsPill('verified', label: 'Verified'),
                    ],
                  ),
                  Text('${line.isEmpty ? 'Professional' : line} · applied ${ago(a['applied_at'])}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
        if (details != null) _ApplicantProfile(details!),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Meta('Asking', asking)),
            const SizedBox(width: 8),
            Expanded(child: _Meta('Trust score', (num.tryParse('${a['trust'] ?? 0}') ?? 0).toStringAsFixed(1))),
          ],
        ),
        WsButtons([
          if (hired)
            SmallButton('View job card', light: false, onPressed: a['engagement_id'] == null ? null : () => context.push('${AppRoutes.engagement}/${a['engagement_id']}'))
          else if (canHire) ...[
            SmallButton('Message', light: false, onPressed: () => startConversationWith(context, '${a['worker_id']}')),
            SmallButton('Hire', onPressed: () => _hireSheet(context, ref, a, job)),
          ] else
            WsPill(a['status']),
        ]),
      ],
    );
  }
}

/// Five small stars, white up to [rating].
class _Stars extends StatelessWidget {
  const _Stars(this.rating);
  final num rating;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++) Icon(Icons.star_rounded, size: 14, color: i <= rating.round() ? const Color(0xFFFFFFFF) : const Color(0xFF3A3A3A)),
      ]);
}

/// An applicant's profile and reviews, opened from the card (website `.ap-more`).
class _ApplicantProfile extends StatefulWidget {
  const _ApplicantProfile(this.d);
  final Json d;
  @override
  State<_ApplicantProfile> createState() => _ApplicantProfileState();
}

class _ApplicantProfileState extends State<_ApplicantProfile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final count = (num.tryParse('${d['review_count'] ?? 0}') ?? 0).toInt();
    final rating = num.tryParse('${d['rating'] ?? 0}') ?? 0;
    final place = [d['city_town'], d['region']].where((v) => v != null && '$v'.isNotEmpty).join(', ');
    final reviews = asList(d['reviews']);
    final pics = asList(d['portfolio']).map((u) => '$u').where((u) => u.startsWith('http')).take(4).toList();
    Widget chip(String t, {Color? c}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(99), border: Border.all(color: c?.withValues(alpha: .4) ?? const Color(0x1FFFFFFF))),
          child: Text(t, style: TextStyle(fontSize: 12, color: c ?? Colors.white)),
        );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x1AFFFFFF)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              if (count > 0) ...[
                _Stars(rating),
                const SizedBox(width: 6),
                Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 6),
                Text('$count review${count > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ] else
                const Text('No reviews yet', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              const Spacer(),
              Text('Profile and reviews ${_open ? '−' : '+'}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        if (_open) ...[
          if ('${d['bio'] ?? ''}'.isNotEmpty && d['bio'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d['bio']}', style: const TextStyle(fontSize: 13.5, color: Color(0xFFCFCFCF), height: 1.45))),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (place.isNotEmpty) chip(place),
            if (d['daily_rate'] != null) chip('${money(d['daily_rate'])}/day'),
            if (d['rank'] != null) chip('${prettyText(d['rank'])} · ${d['xp'] ?? 0} XP'),
            if (d['available'] == true) chip('Available for work', c: const Color(0xFF34D399)),
          ]),
          if (pics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: i < pics.length
                        ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(pics[i], fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1A1A1A))))
                        : const SizedBox.shrink(),
                  ),
                ),
                if (i < 3) const SizedBox(width: 6),
              ],
            ]),
          ],
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            const Text('No reviews yet. Reviews appear here after this professional finishes jobs on BAID X.', style: TextStyle(fontSize: 12.5, color: AppColors.muted))
          else
            for (final r in reviews)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x1AFFFFFF))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _Stars(num.tryParse('${r['rating'] ?? 0}') ?? 0),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${r['by'] ?? 'A client'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                    Text(ago(r['at']), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  ]),
                  if ('${r['comment'] ?? ''}'.isNotEmpty && r['comment'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${r['comment']}', style: const TextStyle(fontSize: 13, color: Color(0xFFD0D0D0), height: 1.4))),
                ]),
              ),
        ],
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

Future<void> _hireSheet(BuildContext context, WidgetRef ref, Json a, Json job) async {
  double bal = 0;
  try {
    bal = double.tryParse('${(await ref.refresh(walletProvider.future)).account['available_ghs'] ?? 0}') ?? 0;
  } catch (_) {
    // the quote still works; hire_worker re-checks the balance itself
  }
  if (!context.mounted) return;
  final rate = '${a['proposed_rate'] ?? job['daily_rate_ghs'] ?? ''}';
  await wsSheet(context, 'Hire ${a['name'] ?? ''}', _HireForm(app: a, job: job, balance: bal, rate: rate == 'null' ? '' : rate));
}

class _HireForm extends ConsumerStatefulWidget {
  const _HireForm({required this.app, required this.job, required this.balance, required this.rate});
  final Json app, job;
  final double balance;
  final String rate;
  @override
  ConsumerState<_HireForm> createState() => _HireFormState();
}

class _HireFormState extends ConsumerState<_HireForm> {
  late final _rate = TextEditingController(text: widget.rate);
  final _days = TextEditingController(text: '1');
  var _busy = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    final rate = double.tryParse(_rate.text.trim()) ?? 0, days = int.tryParse(_days.text.trim()) ?? 0;
    final ok = rate > 0 && days >= 1 && days <= 365;
    final total = (rate * days * 100).roundToDouble() / 100;
    final short = ok ? (((total - widget.balance) * 100).roundToDouble() / 100) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Set the daily rate and how many days. The total is held in escrow until you approve the work.', style: TextStyle(fontSize: 13.5, height: 1.45)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _input('Daily rate (GH₵)', _rate, decimal: true)),
            const SizedBox(width: 10),
            Expanded(child: _input('Number of days', _days)),
          ],
        ),
        if (ok) ...[KV('Job', '${widget.job['title'] ?? ''}'), KV('Rate × days', '${money(rate)} × $days'), KV('Held in escrow', money(total), strong: true), KV('Your balance after', money(widget.balance - total < 0 ? 0 : widget.balance - total)), const SizedBox(height: 8)],
        if (short > 0) ...[
          Note('You need ${money(short)} more in your wallet.', icon: Icons.account_balance_wallet_outlined),
          PillButton(
            label: 'Add money',
            light: false,
            onPressed: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.wallet);
            },
          ),
          const SizedBox(height: 8),
        ],
        if (_err != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_err!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13)),
          ),
        PillButton(
          label: 'Hire and hold in escrow',
          icon: Icons.shield_outlined,
          loading: _busy,
          onPressed: !ok || short > 0 || _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _err = null;
                  });
                  final nav = Navigator.of(context);
                  final router = GoRouter.of(context);
                  try {
                    final r = asMap(await rpcCall('hire_worker', {'p_application': widget.app['application_id'], 'p_days': days, 'p_rate': rate}));
                    ref.invalidate(myEngagementsProvider);
                    ref.invalidate(jobApplicantsProvider('${widget.job['id']}'));
                    ref.invalidate(walletProvider);
                    if (!context.mounted) return;
                    toast(context, 'Hired. ${money(r['amount'])} is held in escrow.');
                    nav.pop();
                    if (r['engagement_id'] != null) router.push('${AppRoutes.engagement}/${r['engagement_id']}');
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _busy = false;
                        _err = escrowError(e);
                      });
                    }
                  }
                },
        ),
        const SizedBox(height: 8),
        Text(
          'Your wallet balance: ${money(widget.balance)}. Nothing is paid to the worker until you approve.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _input(String label, TextEditingController c, {bool decimal = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD)),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: c,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
        ),
      ],
    ),
  );
}
