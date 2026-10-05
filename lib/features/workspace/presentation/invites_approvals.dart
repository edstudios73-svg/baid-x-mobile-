import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../account/data/profile_data.dart';
import '../../account/presentation/account_sheets.dart';
import '../../account/presentation/profile_pages.dart' show KV, SecLabel, backHead;
import '../../tabs/data/tabs_data.dart';
import '../data/workspace_data.dart';
import 'workspace_screen.dart' show ReportCard;
import 'ws_common.dart';
import 'ws_forms.dart';

/// Invitations for workers and PMs (website invitesView) and the company's
/// Approvals inbox (website approvalsView).
class InvitesScreen extends ConsumerWidget {
  const InvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashPage<List<Json>>(
      head: backHead(context, 'Invitations'),
      data: ref.watch(invitationsProvider),
      onRefresh: () => ref.refresh(invitationsProvider.future),
      builder: (list) {
        if (list.isEmpty) {
          return const [DashEmpty(icon: Icons.mail_outline_rounded, title: 'No invitations', text: 'When a company or project manager invites you to a project, you can accept, decline or ask a question here.')];
        }
        return [for (final i in list) _InviteCard(inv: i)];
      },
    );
  }
}

class _InviteCard extends ConsumerStatefulWidget {
  const _InviteCard({required this.inv});
  final Json inv;
  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  var _busy = false;

  Future<void> _respond(String action) async {
    final i = widget.inv;
    setState(() => _busy = true);
    try {
      final r = asMap(await rpcCall('respond_invitation', {'p_invitation': i['id'], 'p_action': action, 'p_note': null}));
      ref.invalidate(invitationsProvider);
      ref.invalidate(projectsTabProvider);
      if (!mounted) return;
      final st = r['status'];
      if (st == 'accepted' || st == 'approved') {
        toast(context, i['invite_role'] == 'pm' ? 'You are now the project manager.' : 'You joined the project.');
        context.push('${AppRoutes.workspace}/${i['project_id']}');
      } else if (st == 'pending_company_approval') {
        toast(context, 'Accepted. The company must approve before you join.');
      } else {
        toast(context, 'Invitation declined.');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _ask() async {
    final note = await askNote(context, 'Ask a question', 'What would you like to know?', required: true);
    if (note == null || !mounted) return;
    await wsAct(context, ref, null, () => rpcCall('respond_invitation', {'p_invitation': widget.inv['id'], 'p_action': 'request_info', 'p_note': note}), ok: 'Question sent');
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.inv;
    final waiting = i['status'] == 'pending_company_approval';
    return WsCard(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WsAvatar(i['project_name'], null, square: true),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i['project_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (i['public_code'] != null) CodeTag('${i['public_code']}'),
              Text('${i['company_name'] ?? ''} · ${placeOf(i).isEmpty ? 'Ghana' : placeOf(i)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ]),
        ),
        if (waiting) const WsPill('pending_company_approval', label: 'Waiting for company'),
      ]),
      const SizedBox(height: 8),
      KV('Role', i['invite_role'] == 'pm' ? 'Project manager' : '${i['trade_label'] ?? 'Worker'}'),
      if (i['rate_ghs'] != null) KV('Rate', '${money(i['rate_ghs'])} per ${i['rate_unit'] ?? 'day'}'),
      if ('${i['expected_duration'] ?? ''}'.isNotEmpty) KV('Duration', '${i['expected_duration']}'),
      if (i['starts_on'] != null) KV('Starts', fdate(i['starts_on'])),
      if ('${i['responsibilities'] ?? ''}'.isNotEmpty) WsQuote('Responsibilities', i['responsibilities']),
      if ('${i['message'] ?? ''}'.isNotEmpty) WsQuote('Message from ${i['invited_by_name'] ?? 'the company'}', i['message']),
      if (waiting)
        const WsCaption('You accepted. The company is reviewing your addition before you join.')
      else
        WsButtons([
          SmallButton('Accept', onPressed: _busy ? null : () => _respond('accept')),
          SmallButton('Decline', light: false, onPressed: _busy ? null : () => _respond('decline')),
          SmallButton('Ask a question', light: false, onPressed: _busy ? null : _ask),
        ]),
    ]);
  }
}

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashPage<Json>(
      head: backHead(context, 'Approvals'),
      data: ref.watch(approvalsProvider),
      onRefresh: () => ref.refresh(approvalsProvider.future),
      builder: (a) {
        if (approvalsCount(a) == 0) {
          return const [DashEmpty(icon: Icons.task_alt_rounded, title: 'Nothing waiting', text: 'Workers, requests, payments, reports and completion requests that need your decision will show up here.')];
        }
        return [
          const Text('PM requests. You approve. BAID X records.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          if (asList(a['completions']).isNotEmpty) ...[
            const SecLabel('Completion'),
            for (final x in asList(a['completions']))
              WsCard(warn: true, kicker: '${x['project_name'] ?? ''}', children: [
                Text('Completion requested by ${x['requested_by_name'] ?? 'your project manager'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                if ('${x['note'] ?? ''}'.isNotEmpty) WsCaption('${x['note']}'),
                WsButtons(completionButtons(context, ref, '${x['id']}', null)),
              ]),
          ],
          if (asList(a['workers']).isNotEmpty) ...[
            const SecLabel('Workers to approve'),
            for (final x in asList(a['workers']))
              InvitationCard(
                role: 'company',
                projectName: '${x['project_name'] ?? ''}',
                inv: {
                  'id': x['id'], 'name': x['name'], 'photo': x['photo'], 'trade_label': x['trade'], 'rate_ghs': x['rate_ghs'], 'rate_unit': x['rate_unit'], 'invited_by_name': x['invited_by_name'],
                  'reasons': x['reasons'], 'reason_note': x['reason_note'], 'response_note': x['response_note'], 'decision_note': x['decision_note'], 'status': 'pending_company_approval', 'invite_role': 'worker',
                },
              ),
          ],
          if (asList(a['requests']).isNotEmpty) ...[
            const SecLabel('Requests'),
            for (final x in asList(a['requests']))
              WsCard(title: '${x['title'] ?? ''}', kicker: '${x['project_name'] ?? ''}', right: Text(money(x['amount_ghs']), style: const TextStyle(fontWeight: FontWeight.w700)), children: [
                WsCaption([prettyText(x['kind']), if ('${x['quantity'] ?? ''}'.isNotEmpty) '${x['quantity']}', 'from ${x['requester_name'] ?? ''}', if ('${x['purpose'] ?? ''}'.isNotEmpty) '${x['purpose']}'].join(' · ')),
                WsButtons(decideButtons(context, ref, null, 'request', '${x['id']}')),
              ]),
          ],
          if (asList(a['payments']).isNotEmpty) ...[
            const SecLabel('Payment requests'),
            for (final x in asList(a['payments']))
              WsCard(title: '${x['purpose'] ?? ''}', kicker: '${x['project_name'] ?? ''}', right: Text(money(x['amount_ghs']), style: const TextStyle(fontWeight: FontWeight.w700)), children: [
                WsCaption('To ${x['payee_name'] ?? ''} · ${prettyText(x['payment_type'])} · requested by ${x['requester_name'] ?? ''}'),
                WsButtons(decideButtons(context, ref, null, 'payment', '${x['id']}')),
              ]),
          ],
          if (asList(a['reports']).isNotEmpty) ...[
            const SecLabel('Reports to review'),
            for (final x in asList(a['reports'])) ReportCard(report: x, role: 'company', projectName: '${x['project_name'] ?? ''}'),
          ],
        ];
      },
    );
  }
}
