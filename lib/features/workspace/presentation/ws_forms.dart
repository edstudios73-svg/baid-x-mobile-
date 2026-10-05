import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../account/data/profile_data.dart';
import '../../account/presentation/account_sheets.dart';
import '../../account/presentation/profile_pages.dart' show KV, Note, field, dropdown;
import '../../account_type/domain/role_categories.dart';
import '../../tabs/data/tabs_data.dart';
import '../data/workspace_data.dart';
import 'ws_common.dart';

/// Workspace forms and actions (website js/projects.js ACT + sheets,
/// js/milestones.js). Each one calls the same database function as the website.

const _reasons = {
  'company_approval_required': 'Your setting requires approval',
  'exceeds_headcount': 'Over the planned team size',
  'exceeds_role_quantity': 'More than planned for this trade',
  'unplanned_role': 'Role not in the project plan',
  'extra_budget': 'Needs extra budget',
  'sensitive_access': 'Sensitive access',
  'supervisor': 'Supervisor / site lead',
  'outside_requirements': 'Outside project requirements',
};
const _flags = [('extra_budget', 'Needs extra budget'), ('sensitive_access', 'Needs sensitive access'), ('supervisor', 'Supervisor or site lead'), ('outside_requirements', 'Outside project requirements')];

String? _blank(String s) => s.trim().isEmpty ? null : s.trim();

// ---------------------------------------------------------------- shared form shell
/// A sheet body with a busy flag so a double tap never submits twice.
class _Form extends StatefulWidget {
  const _Form({required this.fields, required this.submit, required this.label, this.note});
  final List<Widget> Function(StateSetter set) fields;
  final Future<bool> Function() submit;
  final String label;
  final String? note;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  var _busy = false;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...widget.fields(setState),
        if (widget.note != null) Note(widget.note!, icon: Icons.info_outline_rounded),
        PillButton(
          label: widget.label,
          loading: _busy,
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final nav = Navigator.of(context);
                  final ok = await widget.submit();
                  if (!mounted) return;
                  if (ok) {
                    nav.pop();
                  } else {
                    setState(() => _busy = false);
                  }
                },
        ),
      ]);
}

Widget _dateField(BuildContext context, String label, DateTime? value, ValueChanged<DateTime?> on) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
        const SizedBox(height: 7),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, initialDate: value ?? now, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 5));
            on(d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
            child: Row(children: [
              Expanded(child: Text(value == null ? 'Choose a date' : fdate(value.toIso8601String()), style: TextStyle(color: value == null ? AppColors.muted : null))),
              if (value != null) InkWell(onTap: () => on(null), child: const Icon(Icons.close_rounded, size: 16)),
            ]),
          ),
        ),
      ]),
    );

String? _iso(DateTime? d) => d == null ? null : '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

/// Up to four progress photos (website: `<input type=file multiple>`).
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker(this.files, this.on);
  final List<(Uint8List, String)> files;
  final ValueChanged<List<(Uint8List, String)>> on;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: Text(files.isEmpty ? 'Photos (optional, up to 4)' : '${files.length} photo${files.length > 1 ? 's' : ''} chosen', style: const TextStyle(fontSize: 13, color: Color(0xFFDDDDDD)))),
          SmallButton(files.isEmpty ? 'Add photos' : 'Change', light: false, onPressed: () async {
            final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
            final out = <(Uint8List, String)>[];
            for (final f in picked.take(4)) {
              out.add((await f.readAsBytes(), f.name));
            }
            on(out);
          }),
        ]),
      );
}

// ---------------------------------------------------------------- tasks
void taskSheet(BuildContext context, WidgetRef ref, String pid, List<Json> workers, Json? t) {
  final title = TextEditingController(text: '${t?['title'] ?? ''}'), desc = TextEditingController(text: '${t?['description'] ?? ''}');
  String assignee = '${t?['assignee_worker_id'] ?? ''}', priority = '${t?['priority'] ?? 'medium'}', status = '${t?['status'] ?? 'todo'}';
  DateTime? due = DateTime.tryParse('${t?['due_on'] ?? ''}');
  final isNew = t == null;
  wsSheet(
    context,
    isNew ? 'New task' : 'Edit task',
    _Form(
      label: isNew ? 'Create task' : 'Save changes',
      fields: (set) => [
        field('Task', title, hint: 'e.g. Wire the second floor'),
        field('Details', desc, hint: 'What needs to be done', lines: 3),
        dropdown('Assign to', assignee, [('', 'Unassigned'), for (final w in workers) ('${w['profile_id']}', '${w['name']} (${w['project_role'] ?? ''})')], (v) => assignee = v ?? ''),
        _dateField(context, 'Due date', due, (d) => set(() => due = d)),
        dropdown('Priority', priority, const [('low', 'Low'), ('medium', 'Medium'), ('high', 'High'), ('urgent', 'Urgent')], (v) => priority = v ?? 'medium'),
        if (!isNew) dropdown('Status', status, const [('todo', 'To do'), ('in_progress', 'In progress'), ('done', 'Completed'), ('blocked', 'Blocked')], (v) => status = v ?? status),
      ],
      submit: () async {
        if (title.text.trim().isEmpty) {
          toast(context, 'Name the task.');
          return false;
        }
        return wsAct(
          context,
          ref,
          pid,
          () => isNew
              ? rpcCall('create_task', {'p_project': pid, 'p_title': title.text.trim(), 'p_description': _blank(desc.text), 'p_assignee': assignee.isEmpty ? null : assignee, 'p_due': _iso(due), 'p_priority': priority})
              : rpcCall('update_task', {
                  'p_task': t['id'],
                  'p_patch': {'title': title.text.trim(), 'description': desc.text, 'assignee': assignee, 'due_on': _iso(due) ?? '', 'priority': priority, 'status': status},
                }),
          ok: isNew ? 'Task created' : 'Task saved',
        );
      },
    ),
  );
}

void progressSheet(BuildContext context, WidgetRef ref, String pid, Json t, {required bool complete}) {
  final note = TextEditingController();
  var photos = <(Uint8List, String)>[];
  wsSheet(
    context,
    complete ? 'Complete task' : 'Add update',
    _Form(
      label: complete ? 'Mark complete' : 'Post update',
      fields: (set) => [
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${t['title']}', style: const TextStyle(fontWeight: FontWeight.w700))),
        field(complete ? 'Final note (optional)' : 'Update', note, hint: complete ? 'Anything the project manager should know' : 'What have you done?', lines: 3),
        _PhotoPicker(photos, (p) => set(() => photos = p)),
      ],
      submit: () async {
        if (!complete && note.text.trim().isEmpty) {
          toast(context, 'Write what you have done.');
          return false;
        }
        return wsAct(context, ref, pid, () async {
          final paths = photos.isEmpty ? <String>[] : await uploadProjectPhotos(pid, photos);
          return rpcCall('task_progress', {'p_task': t['id'], 'p_action': complete ? 'complete' : 'note', 'p_note': _blank(note.text), 'p_photos': paths});
        }, ok: complete ? 'Task completed' : 'Update posted');
      },
    ),
  );
}

// ---------------------------------------------------------------- reports
void reportSheet(BuildContext context, WidgetRef ref, String pid) {
  final work = TextEditingController(), pct = TextEditingController(), present = TextEditingController(), problems = TextEditingController(), materials = TextEditingController(), next = TextEditingController();
  var kind = 'daily';
  var photos = <(Uint8List, String)>[];
  wsSheet(
    context,
    'New report',
    _Form(
      label: 'Submit report',
      fields: (set) => [
        dropdown('Type', kind, const [('daily', 'Daily'), ('weekly', 'Weekly')], (v) => kind = v ?? 'daily'),
        field('Progress (%)', pct, number: true, keyboard: TextInputType.number),
        field('Work completed', work, hint: 'What was done?', lines: 3),
        field('Workers present', present, number: true, keyboard: TextInputType.number),
        field('Problems', problems, hint: 'Any delays or issues?', lines: 2),
        field('Materials needed', materials, lines: 2),
        field('Next steps', next, lines: 2),
        _PhotoPicker(photos, (p) => set(() => photos = p)),
      ],
      submit: () async {
        if (work.text.trim().isEmpty) {
          toast(context, 'Describe the work completed.');
          return false;
        }
        return wsAct(context, ref, pid, () async {
          final paths = photos.isEmpty ? <String>[] : await uploadProjectPhotos(pid, photos);
          return rpcCall('submit_report', {
            'p_project': pid,
            'p': {'kind': kind, 'work_completed': work.text.trim(), 'progress_pct': _blank(pct.text), 'workers_present': _blank(present.text), 'problems': _blank(problems.text), 'materials_needed': _blank(materials.text), 'next_steps': _blank(next.text), 'photo_urls': paths},
          });
        }, ok: 'Report submitted');
      },
    ),
  );
}

Future<void> reviewReport(BuildContext context, WidgetRef ref, String? pid, String id, String d) async {
  String? comment;
  if (d != 'approve') {
    comment = await askNote(context, d == 'changes' ? 'Request changes' : 'Reject report', 'What should change?', required: true);
    if (comment == null) return;
  }
  if (!context.mounted) return;
  await wsAct(context, ref, pid, () => rpcCall('review_report', {'p_report': id, 'p_decision': d, 'p_comment': comment}), ok: d == 'approve' ? 'Report approved' : 'Sent to your project manager');
}

// ---------------------------------------------------------------- finance
void requestSheet(BuildContext context, WidgetRef ref, String pid) {
  final title = TextEditingController(), qty = TextEditingController(), amount = TextEditingController(), purpose = TextEditingController();
  var kind = 'material';
  wsSheet(
    context,
    'Request materials or expenses',
    _Form(
      label: 'Send request',
      note: 'The company approves or rejects. You cannot approve your own request.',
      fields: (set) => [
        dropdown('What do you need?', kind, const [('material', 'Materials'), ('equipment', 'Equipment'), ('expense', 'Expense')], (v) => kind = v ?? 'material'),
        field('Item', title, hint: 'e.g. Cement, 40 bags'),
        field('Quantity', qty, hint: 'e.g. 40 bags'),
        field('Estimated cost (GH₵)', amount, number: true),
        field('Purpose', purpose, hint: 'What is it for?', lines: 2),
      ],
      submit: () async {
        final amt = double.tryParse(amount.text.trim());
        if (title.text.trim().isEmpty || amt == null || amt < 0) {
          toast(context, 'Add the item and an estimated cost.');
          return false;
        }
        return wsAct(context, ref, pid, () => rpcCall('submit_request', {'p_project': pid, 'p_kind': kind, 'p_title': title.text.trim(), 'p_purpose': _blank(purpose.text), 'p_quantity': _blank(qty.text), 'p_amount': amt}), ok: 'Request sent to the company');
      },
    ),
  );
}

void paymentSheet(BuildContext context, WidgetRef ref, String pid, List<Json> team, {required bool record}) {
  final people = team.where((m) => record ? m['role_type'] != 'company' : true).toList();
  if (people.isEmpty) return toast(context, 'Add a team member first.');
  final amount = TextEditingController(), purpose = TextEditingController();
  final me = sb.auth.currentUser?.id;
  var payee = record ? '${people.first['profile_id']}' : (people.any((m) => m['profile_id'] == me) ? me : '${people.first['profile_id']}');
  var type = record ? 'worker' : 'monthly';
  wsSheet(
    context,
    record ? 'Record a payment' : 'Payment request',
    _Form(
      label: record ? 'Record payment' : 'Send request',
      note: record ? 'Records only. BAID X does not send money.' : 'The company approves. You cannot approve your own request.',
      fields: (set) => [
        dropdown('Pay to', payee, [for (final m in people) ('${m['profile_id']}', '${m['name']} (${m['project_role'] ?? ''})')], (v) => payee = v ?? payee),
        field('Amount (GH₵)', amount, number: true),
        dropdown(
          'Type',
          type,
          record ? const [('worker', 'Worker pay'), ('milestone', 'Milestone'), ('project', 'Project fee'), ('monthly', 'Monthly')] : const [('monthly', 'Monthly fee'), ('project', 'Project fee'), ('milestone', 'Milestone'), ('percentage', 'Percentage'), ('worker', 'Worker pay')],
          (v) => type = v ?? type,
        ),
        field('Purpose', purpose, hint: 'What is this payment for?'),
      ],
      submit: () async {
        final amt = double.tryParse(amount.text.trim());
        if (amt == null || amt <= 0 || purpose.text.trim().isEmpty) {
          toast(context, 'Add an amount and what the payment is for.');
          return false;
        }
        return wsAct(context, ref, pid, () => rpcCall(record ? 'record_payment' : 'submit_payment_request', {'p_project': pid, 'p_payee': payee, 'p_amount': amt, 'p_purpose': purpose.text.trim(), 'p_type': type}), ok: record ? 'Payment recorded' : 'Payment request sent');
      },
    ),
  );
}

/// Approve / Reject for a finance request or a payment request.
List<Widget> decideButtons(BuildContext context, WidgetRef ref, String? pid, String kind, String id) {
  Future<void> go(String d) async {
    String? note;
    if (d == 'reject') {
      note = await askNote(context, kind == 'request' ? 'Reject request' : 'Reject payment', 'Optional note');
      if (note == null) return;
    }
    if (!context.mounted) return;
    final fn = kind == 'request' ? 'decide_request' : 'decide_payment';
    final key = kind == 'request' ? 'p_request' : 'p_payment';
    await wsAct(context, ref, pid, () => rpcCall(fn, {key: id, 'p_decision': d, 'p_note': _blank(note ?? '')}),
        ok: d == 'approve' ? (kind == 'request' ? 'Request approved' : 'Payment approved') : (kind == 'request' ? 'Request rejected' : 'Payment rejected'));
  }

  return [SmallButton('Approve', onPressed: () => go('approve')), SmallButton('Reject', light: false, onPressed: () => go('reject'))];
}

Future<void> markPaid(BuildContext context, WidgetRef ref, String pid, String id) async {
  final refNo = await askNote(context, 'Mark as paid', 'Payment reference, e.g. the Mobile Money transaction ID', required: true);
  if (refNo == null || refNo.isEmpty || !context.mounted) return;
  await wsAct(context, ref, pid, () => rpcCall('mark_payment_paid', {'p_payment': id, 'p_reference': refNo}), ok: 'Marked as paid');
}

// ---------------------------------------------------------------- completion + reviews
List<Widget> completionButtons(BuildContext context, WidgetRef ref, String requestId, String? pid) {
  Future<void> go(String d) async {
    String? note;
    if (d == 'reject') {
      note = await askNote(context, 'Not ready yet', 'What is still missing?', required: true);
      if (note == null) return;
    }
    if (!context.mounted) return;
    await wsAct(context, ref, pid, () => rpcCall('decide_completion', {'p_request': requestId, 'p_decision': d, 'p_note': note}), ok: d == 'approve' ? 'Project completed. Reviews are open.' : 'Sent back to the project manager');
  }

  return [SmallButton('Approve completion', onPressed: () => go('approve')), SmallButton('Not yet', light: false, onPressed: () => go('reject'))];
}

Future<void> requestCompletion(BuildContext context, WidgetRef ref, String pid) async {
  final note = await askNote(context, 'Request completion', 'Anything the company should know? (optional)');
  if (note == null || !context.mounted) return;
  try {
    final r = asMap(await rpcCall('request_completion', {'p_project': pid, 'p_note': _blank(note)}));
    refreshWorkspace(ref, pid);
    if (!context.mounted) return;
    if (r['ok'] == true) return toast(context, 'Completion request sent to the company');
    const labels = {'open_tasks': 'open tasks', 'reports_waiting_review': 'reports waiting for review', 'pending_requests': 'pending requests', 'pending_payments': 'pending payments', 'workers_waiting_approval': 'workers waiting for approval'};
    final b = asMap(r['blockers']).entries.where((e) => (num.tryParse('${e.value}') ?? 0) > 0).toList();
    await wsSheet(
      context,
      'Not ready yet',
      Builder(
        builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Clear these first, then request completion again:', style: TextStyle(fontSize: 13.5)),
          const SizedBox(height: 8),
          for (final e in b) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${e.value} ${labels[e.key] ?? e.key}', style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          PillButton(label: 'OK', onPressed: () => Navigator.of(ctx).pop()),
        ]),
      ),
    );
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
}

class ReviewCard extends ConsumerStatefulWidget {
  const ReviewCard({required this.member, required this.pid, super.key});
  final Json member;
  final String pid;
  @override
  ConsumerState<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<ReviewCard> {
  var _rating = 0, _busy = false;
  final _comment = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return WsCard(children: [
      Row(children: [
        WsAvatar(m['name'], m['photo']),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w700)), Text('${m['project_role'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted))])),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        for (var n = 1; n <= 5; n++)
          IconButton(
            tooltip: '$n star${n > 1 ? 's' : ''}',
            onPressed: () => setState(() => _rating = n),
            icon: Icon(n <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: n <= _rating ? const Color(0xFFE8C46A) : AppColors.muted),
          ),
      ]),
      TextField(controller: _comment, maxLines: 2, maxLength: 400, decoration: const InputDecoration(hintText: 'Optional comment')),
      WsButtons([
        SmallButton(_busy ? 'Please wait…' : 'Submit review', onPressed: _busy
            ? null
            : () async {
                if (_rating == 0) return toast(context, 'Choose a star rating first.');
                setState(() => _busy = true);
                final ok = await wsAct(context, ref, widget.pid, () => rpcCall('submit_review', {'p_project': widget.pid, 'p_reviewee': m['profile_id'], 'p_rating': _rating, 'p_comment': _blank(_comment.text)}), ok: 'Review submitted');
                if (!ok && mounted) setState(() => _busy = false);
              }),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- invitations
/// An invitation on the Team tab or in Approvals (website invitationCard).
class InvitationCard extends ConsumerWidget {
  const InvitationCard({required this.inv, required this.role, this.pid, this.projectName, super.key});
  final Json inv;
  final String role;
  final String? pid;
  final String? projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = inv;
    final pending = i['status'] == 'pending_company_approval';
    final reasons = [for (final r in (i['reasons'] is List ? i['reasons'] as List : const [])) _reasons['$r'] ?? prettyText(r)];
    Future<void> decide(String d) async {
      if (d == 'approve') {
        await wsAct(context, ref, pid, () => rpcCall('decide_restricted_worker', {'p_invitation': i['id'], 'p_decision': 'approve', 'p_note': null}), ok: 'Worker approved');
        return;
      }
      final note = await askNote(context, d == 'reject' ? 'Reject worker' : 'Ask the project manager', d == 'reject' ? 'Optional note' : 'Your question', required: d != 'reject');
      if (note == null || !context.mounted) return;
      await wsAct(context, ref, pid, () => rpcCall('decide_restricted_worker', {'p_invitation': i['id'], 'p_decision': d, 'p_note': _blank(note)}), ok: d == 'reject' ? 'Worker not approved' : 'Question sent');
    }

    final rate = i['rate_ghs'] != null ? ' · ${money(i['rate_ghs'])}/${i['rate_unit'] ?? 'day'}' : '';
    return WsCard(kicker: projectName, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WsAvatar(i['name'], i['photo']),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${i['trade_label'] ?? prettyText(i['invite_role'])}$rate · invited by ${i['invited_by_name'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        WsPill(i['status'], label: pending ? 'Needs approval' : null),
      ]),
      if (reasons.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final r in reasons) WsPill('pending', label: r)])),
      if ('${i['reason_note'] ?? ''}'.isNotEmpty) WsQuote('Reason from the project manager', i['reason_note']),
      if ('${i['response_note'] ?? ''}'.isNotEmpty) WsQuote('${i['name']} wrote', i['response_note']),
      if ('${i['decision_note'] ?? ''}'.isNotEmpty) WsQuote('Company note', i['decision_note']),
      WsButtons([
        if (pending && role == 'company') ...[
          SmallButton('Approve', onPressed: () => decide('approve')),
          SmallButton('Reject', light: false, onPressed: () => decide('reject')),
          SmallButton('Ask PM', light: false, onPressed: () => decide('ask_pm')),
        ],
        if (projectName == null && ['sent', 'info_requested', 'pending_company_approval'].contains(i['status']))
          SmallButton('Cancel invite', light: false, onPressed: () => wsAct(context, ref, pid, () => rpcCall('cancel_invitation', {'p_invitation': i['id']}), ok: 'Invitation cancelled')),
      ]),
    ]);
  }
}

Json _person(String kind, Json p) => {
      'id': p['id'],
      'name': p['full_name'] ?? 'Selected person',
      'photo': p['profile_photo_url'],
      'trade': kind == 'worker' ? (jobCategories.where((j) => j.id == p['primary_job_category_id']).map((j) => j.name).firstOrNull ?? '${p['specialty'] ?? 'Professional'}') : (p['specialization'] == null ? 'Project manager' : prettyText(p['specialization'])),
      'place': placeOf(p),
      'rate': p['daily_rate_ghs'],
    };

/// Company invites a PM or worker, a PM invites a worker (website openInvite).
/// [personId] comes from a member's profile in Discover; otherwise a picker opens.
Future<void> openInvite(BuildContext context, WidgetRef ref, {required String kind, String? projectId, String? personId}) async {
  try {
    final all = asList(await rpcCall('my_projects'));
    final ownRole = kind == 'pm' ? 'company' : null;
    final mine = all.where((p) {
      final r = p['my_role'];
      final manages = ownRole != null ? r == ownRole : (r == 'company' || r == 'pm');
      return manages && !['completed', 'cancelled'].contains(p['status']) && (kind != 'pm' || p['pm_id'] == null);
    }).toList();
    if (!context.mounted) return;
    if (mine.isEmpty) return toast(context, kind == 'pm' ? 'Create a project that still needs a project manager first.' : 'You have no open project to invite people to.');
    if (personId != null) {
      final row = await sb
          .from(kind == 'pm' ? 'project_manager_profiles' : 'worker_profiles')
          .select(kind == 'pm' ? 'id,full_name,specialization,city_town,region,profile_photo_url' : 'id,full_name,primary_job_category_id,specialty,city_town,region,profile_photo_url,daily_rate_ghs')
          .eq('id', personId)
          .maybeSingle();
      if (!context.mounted) return;
      return _inviteForm(context, ref, kind, mine, projectId, _person(kind, row ?? {'id': personId}));
    }
    final person = await wsSheet<Json>(context, kind == 'pm' ? 'Invite a project manager' : 'Invite a worker', _PersonPicker(kind: kind));
    if (person != null && context.mounted) _inviteForm(context, ref, kind, mine, projectId, person);
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
}

class _PersonPicker extends ConsumerStatefulWidget {
  const _PersonPicker({required this.kind});
  final String kind;
  @override
  ConsumerState<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends ConsumerState<_PersonPicker> {
  var _q = '';
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(invitePoolProvider(widget.kind));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(onChanged: (v) => setState(() => _q = v.toLowerCase()), decoration: const InputDecoration(hintText: 'Search by name, trade or town', prefixIcon: Icon(Icons.search_rounded))),
      const SizedBox(height: 10),
      WsAsync<List<Json>>(data, onRetry: () => ref.invalidate(invitePoolProvider(widget.kind)), (list) {
        final people = [for (final p in list) _person(widget.kind, p)].where((p) => _q.isEmpty || '${p['name']} ${p['trade']} ${p['place']}'.toLowerCase().contains(_q)).toList();
        if (people.isEmpty) return WsCaption('No verified ${widget.kind == 'pm' ? 'project managers' : 'workers'} found.');
        return Column(children: [
          for (final p in people)
            DashRow(
              leading: WsAvatar(p['name'], p['photo'], size: 34),
              title: '${p['name']}',
              sub: [p['trade'], if ('${p['place']}'.isNotEmpty) p['place']].join(' · '),
              trailing: const Icon(Icons.add_rounded, size: 18),
              onTap: () => Navigator.of(context).pop(p),
            ),
        ]);
      }),
    ]);
  }
}

void _inviteForm(BuildContext context, WidgetRef ref, String kind, List<Json> projects, String? preferred, Json person) {
  final isPmInviter = projects.any((p) => p['my_role'] == 'pm') && !projects.any((p) => p['my_role'] == 'company');
  var project = projects.any((p) => p['id'] == preferred) ? preferred! : '${projects.first['id']}';
  final resp = TextEditingController(), duration = TextEditingController(), rate = TextEditingController(text: person['rate'] == null ? '' : '${person['rate']}'), message = TextEditingController(), reason = TextEditingController();
  final trade = TextEditingController(text: '${person['trade'] ?? ''}');
  var unit = kind == 'pm' ? 'month' : 'day';
  final flags = <String>{};
  wsSheet(
    context,
    kind == 'pm' ? 'Invite project manager' : 'Invite worker',
    _Form(
      label: 'Send invitation',
      fields: (set) => [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            WsAvatar(person['name'], person['photo']),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${person['name']}', style: const TextStyle(fontWeight: FontWeight.w700)), Text([person['trade'], if ('${person['place'] ?? ''}'.isNotEmpty) person['place']].join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.muted))])),
          ]),
        ),
        if (projects.length > 1) dropdown('Project', project, [for (final p in projects) ('${p['id']}', '${p['name']} · ${p['public_code'] ?? ''}')], (v) => project = v ?? project),
        if (kind == 'pm') ...[
          field('Responsibilities', resp, hint: 'What will they be responsible for?', lines: 3),
          field('Expected duration', duration, hint: 'e.g. 6 months'),
          field('Compensation (GH₵)', rate, number: true),
          dropdown('Paid', unit, const [('month', 'per month'), ('project', 'for the project'), ('milestone', 'per milestone'), ('percent', '% of budget')], (v) => unit = v ?? unit),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: trade.text),
              optionsBuilder: (v) => v.text.isEmpty ? const Iterable<String>.empty() : jobCategories.map((j) => j.name).where((n) => n.toLowerCase().contains(v.text.toLowerCase())).take(6),
              onSelected: (v) => trade.text = v,
              fieldViewBuilder: (ctx, c, f, _) => TextField(controller: c, focusNode: f, onChanged: (v) => trade.text = v, decoration: const InputDecoration(labelText: 'Trade on this project', hintText: 'e.g. Electrician')),
            ),
          ),
          field('Rate (GH₵)', rate, number: true),
          dropdown('Per', unit, const [('day', 'day'), ('week', 'week'), ('month', 'month'), ('project', 'project')], (v) => unit = v ?? unit),
        ],
        field('Message', message, hint: kind == 'pm' ? 'Optional note' : 'Optional note to the worker', lines: 2),
        if (kind == 'worker' && isPmInviter) ...[
          const Text('Does this need the company\'s approval?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
          for (final (k, l) in _flags)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: flags.contains(k),
              title: Text(l, style: const TextStyle(fontSize: 13)),
              onChanged: (v) => set(() => v == true ? flags.add(k) : flags.remove(k)),
            ),
          field('Reason for the company', reason, hint: 'Why is this worker needed? Required if the company must approve.', lines: 2),
          const WsCaption('The server checks your plan, team size and the company\'s rules. If approval is needed, the worker joins only after the company says yes.'),
          const SizedBox(height: 10),
        ],
      ],
      submit: () async {
        try {
          if (kind == 'pm') {
            await rpcCall('invite_pm', {'p_project': project, 'p_pm': person['id'], 'p_responsibilities': _blank(resp.text), 'p_duration': _blank(duration.text), 'p_rate': double.tryParse(rate.text.trim()), 'p_unit': unit, 'p_message': _blank(message.text)});
            if (context.mounted) toast(context, 'Invitation sent');
          } else {
            if (trade.text.trim().isEmpty) {
              toast(context, 'Add the trade on this project.');
              return false;
            }
            final r = asMap(await rpcCall('invite_worker', {'p_project': project, 'p_worker': person['id'], 'p_trade': trade.text.trim(), 'p_rate': double.tryParse(rate.text.trim()), 'p_unit': unit, 'p_flags': flags.toList(), 'p_reason': _blank(reason.text), 'p_message': _blank(message.text)}));
            if (context.mounted) toast(context, r['restricted'] == true ? 'Invitation sent. The company approves after the worker accepts.' : 'Invitation sent');
          }
          refreshWorkspace(ref, project);
          return true;
        } catch (e) {
          if (context.mounted) toast(context, friendlyError(e));
          return false;
        }
      },
    ),
  );
}

// ---------------------------------------------------------------- milestones (js/milestones.js)
const _msStatus = {'planned': ('Not funded', ''), 'funded': ('Funded · in escrow', 'pending'), 'submitted': ('Awaiting approval', 'pending'), 'released': ('Paid', 'paid'), 'disputed': ('In dispute', 'rejected'), 'refunded': ('Refunded', '')};
const _disputeReasons = ['The work was not delivered', 'The work is not as agreed', 'Not responding', 'Payment disagreement', 'Something else'];

String _msMsg(Object e) {
  final m = friendlyError(e);
  final s = RegExp(r'insufficient_funds:([\d.]+)').firstMatch(m);
  return s != null ? 'You need ${money(s[1])} more in your wallet.' : m;
}

class MilestonesTab extends ConsumerWidget {
  const MilestonesTab({required this.ov, required this.pid, super.key});
  final Json ov;
  final String pid;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<dynamic> Function() fn, String ok) async {
    try {
      await fn();
      if (context.mounted) toast(context, ok);
      refreshWorkspace(ref, pid);
      ref.invalidate(walletProvider);
    } catch (e) {
      if (context.mounted) toast(context, _msMsg(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = wsRole(ov) == 'company';
    final closed = !wsOpen(ov);
    return WsAsync<List<Json>>(ref.watch(projectMilestonesProvider(pid)), onRetry: () => ref.invalidate(projectMilestonesProvider(pid)), (list) {
      double sum(bool Function(Json) f) => list.where(f).fold(0.0, (t, m) => t + (double.tryParse('${m['amount_ghs']}') ?? 0));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (owner && !closed) WsButtons(top: true, [SmallButton('+ Add milestone', onPressed: () => _newSheet(context, ref))]),
        if (list.isNotEmpty)
          WsCard(children: [
            KV('Planned', money(sum((m) => m['status'] == 'planned'))),
            KV('In escrow', money(sum((m) => ['funded', 'submitted', 'disputed'].contains(m['status'])))),
            KV('Paid out', money(sum((m) => m['status'] == 'released')), strong: true),
          ]),
        if (list.isEmpty)
          DashEmpty(
            icon: Icons.flag_outlined,
            title: 'No milestones yet',
            text: owner ? 'Break the work into milestones. Fund each one into escrow and pay your team as they deliver.' : 'When the project owner adds milestones for you, they appear here with the payment already held in escrow.',
          ),
        for (final m in list) _card(context, ref, m, owner),
        Note(owner
            ? 'Funding moves the money from your wallet into escrow. It is released to your team member only when you approve, or 5 days after they submit.'
            : 'The owner\'s payment is held by BAID X once a milestone is funded. It is released to you when they approve, or automatically 5 days after you submit.'),
      ]);
    });
  }

  Widget _card(BuildContext context, WidgetRef ref, Json m, bool owner) {
    final s = '${m['status']}';
    final mine = m['mine'] == true;
    final st = _msStatus[s];
    final acts = <Widget>[
      if (owner && s == 'planned') ...[
        SmallButton('Fund ${money(m['amount_ghs'])}', onPressed: () => _fundSheet(context, ref, m)),
        SmallButton('Remove', light: false, onPressed: () => _cancel(context, ref, m)),
      ] else if (owner && (s == 'funded' || s == 'submitted')) ...[
        SmallButton('Approve and release', onPressed: () async {
          if (await confirmBox(context, 'Release payment', 'This pays your team member. You can\'t undo it, so only approve if the milestone is done.', yes: 'Yes, release payment') && context.mounted) {
            await _run(context, ref, () => rpcCall('milestone_approve', {'p_id': m['id']}), 'Payment released.');
          }
        }),
        SmallButton('Report a problem', light: false, onPressed: () => _dispute(context, ref, m)),
        if (s == 'funded') SmallButton('Cancel', light: false, onPressed: () => _cancel(context, ref, m)),
      ] else if (mine && s == 'funded') ...[
        SmallButton('Submit milestone', onPressed: () => _submit(context, ref, m)),
        SmallButton('Report a problem', light: false, onPressed: () => _dispute(context, ref, m)),
        SmallButton('Decline', light: false, onPressed: () => _cancel(context, ref, m)),
      ] else if (mine && s == 'submitted')
        SmallButton('Report a problem', light: false, onPressed: () => _dispute(context, ref, m)),
    ];
    final note = s == 'submitted' && m['auto_release_at'] != null
        ? 'Releases automatically ${fdate(m['auto_release_at'])} if not reviewed.'
        : s == 'released' && m['net_ghs'] != null
            ? (mine ? 'You received ${money(m['net_ghs'])} after the ${money(m['commission_ghs'])} BAID X fee.' : 'Paid ${money(m['amount_ghs'])}.')
            : s == 'disputed'
                ? 'In dispute${'${m['dispute_reason'] ?? ''}'.isNotEmpty ? ': ${m['dispute_reason']}' : ''}.'
                : '';
    return WsCard(title: '${m['title'] ?? ''}', right: WsPill(st?.$2 ?? s, label: st?.$1), children: [
      Text([m['payee_name'] ?? 'Team member', money(m['amount_ghs']), if (m['due_on'] != null) 'Due ${fdate(m['due_on'])}'].join(' · '), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      if ('${m['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${m['description']}', style: const TextStyle(fontSize: 13.5, height: 1.4))),
      if ('${m['submit_note'] ?? ''}'.isNotEmpty) WsQuote('Note from team member', m['submit_note']),
      if ('${m['resolution_note'] ?? ''}'.isNotEmpty) WsQuote('BAID X decision', m['resolution_note']),
      if (note.isNotEmpty) WsCaption(note),
      WsButtons(acts),
    ]);
  }

  Future<void> _newSheet(BuildContext context, WidgetRef ref) async {
    final team = asList((await ref.read(projectTeamProvider(pid).future))['members']).where((m) => ['worker', 'pm', 'business'].contains(m['role_type'])).toList();
    if (!context.mounted) return;
    if (team.isEmpty) return toast(context, 'Add someone to the project team first.');
    var payee = '${team.first['profile_id']}';
    final title = TextEditingController(), desc = TextEditingController(), amount = TextEditingController();
    DateTime? due;
    await wsSheet(
      context,
      'Add milestone',
      _Form(
        label: 'Add milestone',
        note: 'Nothing is charged until you fund the milestone.',
        fields: (set) => [
          dropdown('Who is it for?', payee, [for (final m in team) ('${m['profile_id']}', '${m['name']} · ${m['project_role'] ?? prettyText(m['role_type'])}')], (v) => payee = v ?? payee),
          field('Milestone', title, hint: 'e.g. Foundation poured and cured'),
          field('What must be delivered', desc, lines: 3),
          field('Amount (GH₵)', amount, number: true),
          _dateField(context, 'Due date', due, (d) => set(() => due = d)),
        ],
        submit: () async {
          final amt = double.tryParse(amount.text.trim());
          if (title.text.trim().isEmpty || amt == null || amt < 1) {
            toast(context, 'Add a title and an amount.');
            return false;
          }
          try {
            await rpcCall('milestone_create', {'p_project': pid, 'p_payee': payee, 'p_title': title.text.trim(), 'p_amount': amt, 'p_description': _blank(desc.text), 'p_due': _iso(due)});
            if (context.mounted) toast(context, 'Milestone added.');
            refreshWorkspace(ref, pid);
            return true;
          } catch (e) {
            if (context.mounted) toast(context, _msMsg(e));
            return false;
          }
        },
      ),
    );
  }

  Future<void> _fundSheet(BuildContext context, WidgetRef ref, Json m) async {
    final bal = double.tryParse('${(await ref.refresh(walletProvider.future)).account['available_ghs'] ?? 0}') ?? 0;
    final amt = double.tryParse('${m['amount_ghs']}') ?? 0;
    final short = ((amt - bal) * 100).roundToDouble() / 100;
    if (!context.mounted) return;
    await wsSheet(
      context,
      'Fund milestone',
      Builder(
        builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${m['title']} for ${m['payee_name'] ?? 'your team member'}. The money moves from your wallet into escrow and is released only when you approve.', style: const TextStyle(fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 10),
          KV('Held in escrow', money(amt), strong: true),
          KV('Your balance', money(bal)),
          KV('Balance after', money(bal - amt < 0 ? 0 : bal - amt)),
          const SizedBox(height: 12),
          if (short > 0) ...[
            Note('You need ${money(short)} more in your wallet.', icon: Icons.account_balance_wallet_outlined),
            PillButton(label: 'Add money', onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoutes.wallet);
            }),
          ] else
            _FundButton(onFund: () async {
              try {
                await rpcCall('milestone_fund', {'p_id': m['id']});
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) toast(context, 'Funded. The money is held in escrow.');
                refreshWorkspace(ref, pid);
                ref.invalidate(walletProvider);
              } catch (e) {
                if (ctx.mounted) toast(ctx, _msMsg(e));
              }
            }),
        ]),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref, Json m) async {
    final note = await askNote(context, 'Submit milestone', 'What was completed. The owner has 5 days to review; if they don\'t respond, your payment is released automatically.');
    if (note == null || !context.mounted) return;
    await _run(context, ref, () => rpcCall('milestone_submit', {'p_id': m['id'], 'p_note': _blank(note)}), 'Submitted for approval.');
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Json m) async {
    if (await confirmBox(context, 'Cancel milestone?', 'If it was funded, the money returns to the owner\'s wallet.', yes: 'Yes, cancel') && context.mounted) {
      await _run(context, ref, () => rpcCall('milestone_cancel', {'p_id': m['id']}), 'Cancelled.');
    }
  }

  Future<void> _dispute(BuildContext context, WidgetRef ref, Json m) async {
    var reason = _disputeReasons.first;
    final details = TextEditingController();
    await wsSheet(
      context,
      'Report a problem',
      _Form(
        label: 'Open dispute',
        note: 'The money stays frozen in escrow while BAID X reviews.',
        fields: (set) => [
          dropdown('What is the problem?', reason, [for (final r in _disputeReasons) (r, r)], (v) => reason = v ?? reason),
          field('Details', details, lines: 4),
        ],
        submit: () async {
          try {
            await rpcCall('milestone_dispute', {'p_id': m['id'], 'p_reason': reason, 'p_details': _blank(details.text)});
            if (context.mounted) toast(context, 'Dispute opened. BAID X will review.');
            refreshWorkspace(ref, pid);
            return true;
          } catch (e) {
            if (context.mounted) toast(context, _msMsg(e));
            return false;
          }
        },
      ),
    );
  }
}

class _FundButton extends StatefulWidget {
  const _FundButton({required this.onFund});
  final Future<void> Function() onFund;
  @override
  State<_FundButton> createState() => _FundButtonState();
}

class _FundButtonState extends State<_FundButton> {
  var _busy = false;
  @override
  Widget build(BuildContext context) => PillButton(
        label: 'Fund and hold in escrow',
        icon: Icons.shield_outlined,
        loading: _busy,
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                await widget.onFund();
                if (mounted) setState(() => _busy = false);
              },
      );
}
