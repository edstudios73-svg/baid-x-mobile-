import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/baid_ui.dart';
import '../../shared/widgets/dash_ui.dart';
import '../account/data/profile_data.dart';
import '../account/presentation/account_sheets.dart';
import '../account/presentation/profile_pages.dart' show KV, backHead, field, dropdown;
import '../tabs/data/tabs_data.dart';
import '../workspace/presentation/ws_common.dart';
import 'hiring_screens.dart';

/// The Digital Job Card (website js/jobcard.js): one record per hired job with
/// scope, materials, photo evidence, payments and sign-off. Every change is a
/// job_card_* database function; when everyone has signed off the database
/// releases the escrow, never this screen.

final jobCardProvider = FutureProvider.family<Json, String>((ref, id) async {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.id));
  return asMap(await rpcCall('job_card', {'p_eng': id}));
});

final myJobCardsProvider = FutureProvider<List<Json>>((ref) async {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.id));
  return asList(await rpcCall('my_job_cards'));
});

/// Signed links for the card's private photos, by storage path.
final jobCardPhotosProvider = FutureProvider.family<Map<String, String>, String>((ref, joined) async {
  final paths = joined.split('|').where((p) => p.isNotEmpty).toList();
  if (paths.isEmpty) return const {};
  final urls = await sb.storage.from('job-cards').createSignedUrlsResult(paths, 3600);
  return {for (var i = 0; i < urls.length && i < paths.length; i++) if (urls[i] is SignedUrlSuccess) paths[i]: (urls[i] as SignedUrlSuccess).signedUrl};
});

const _status = {'active': ('In progress', 'pending'), 'submitted': ('Awaiting sign-off', 'pending'), 'released': ('Complete', 'paid'), 'disputed': ('In dispute', 'rejected'), 'refunded': ('Refunded', ''), 'cancelled': ('Cancelled', '')};
Widget jobCardPill(Object? s) {
  final v = _status['$s'];
  return WsPill(v?.$2 ?? s, label: v?.$1);
}

const _stages = [('before', 'Before'), ('during', 'During'), ('after', 'After')];
const _party = {'worker': 'Worker', 'client': 'Client', 'pm': 'PM'};
const _disputeReasons = ['The work was not done', 'The work is not as agreed', 'The other person is not responding', 'Payment or pricing disagreement', 'Something else'];

num _n(Object? v) => num.tryParse('${v ?? 0}') ?? 0;
String _num(Object? v) {
  final n = _n(v);
  return n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

int _pct(num done, num total) => total > 0 ? (done / total * 100).round() : 0;
String _when(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (t == null) return '';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]}, $h:${'${t.minute}'.padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

String _err(Object e) {
  final m = friendlyError(e);
  return m.isEmpty ? m : m[0].toUpperCase() + m.substring(1);
}

class JobCardScreen extends ConsumerWidget {
  const JobCardScreen({required this.id, super.key});
  final String id;

  Future<bool> _run(BuildContext context, WidgetRef ref, Future<dynamic> Function() fn, String Function(dynamic) ok) async {
    try {
      final r = await fn();
      if (context.mounted) toast(context, ok(r));
      ref.invalidate(jobCardProvider(id));
      ref.invalidate(myEngagementsProvider);
      ref.invalidate(myJobCardsProvider);
      ref.invalidate(walletProvider);
      return true;
    } catch (e) {
      if (context.mounted) toast(context, _err(e));
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(jobCardProvider(id));
    return DashPage<Json>(
      head: backHead(context, 'Job card'),
      data: data,
      onRefresh: () => ref.refresh(jobCardProvider(id).future),
      builder: (d) {
        if (d.isEmpty) return const [DashEmpty(icon: Icons.work_outline, title: 'Not found', text: 'This job card doesn\'t exist or isn\'t yours.')];
        final me = '${d['my_party'] ?? ''}', s = '${d['status']}';
        final live = s == 'active' || s == 'submitted', edit = live && d['locked'] != true;
        final canProgress = edit && (me == 'worker' || me == 'pm');
        final items = asList(d['items']), mats = asList(d['materials']), photos = asList(d['photos']);
        final signed = {for (final x in asList(d['signoffs'])) '${x['party']}': x};
        final parties = ['worker', 'client', if (d['needs_pm'] == true) 'pm'];
        final urls = ref.watch(jobCardPhotosProvider(photos.map((p) => '${p['path']}').join('|'))).asData?.value ?? const <String, String>{};
        final progress = _n(d['progress']);
        String nameOf(String p) => '${(p == 'worker' ? d['worker_name'] : p == 'client' ? d['client_name'] : d['pm_name']) ?? _party[p]}';

        final waiting = parties.where((p) => p != me && !signed.containsKey(p)).toList();
        final signLabel = me == 'worker' ? 'Sign off: work complete' : waiting.isEmpty ? 'Sign off and release payment' : 'Sign off';
        return [
          WsCard(children: [
            Row(children: [
              Expanded(child: Text('JOB #BX-${d['card_no']}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: Color(0xFFCFCFCF)))),
              jobCardPill(s),
            ]),
            const SizedBox(height: 6),
            Text('${d['title'] ?? 'Job'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.2)),
            const SizedBox(height: 6),
            KV('Client', '${d['client_name'] ?? 'Client'}'),
            KV('Worker', '${d['worker_name'] ?? 'Worker'}'),
            if (d['needs_pm'] == true) KV('Project manager', '${d['pm_name'] ?? 'PM'}'),
            if ('${d['project'] ?? ''}'.isNotEmpty) KV('Project', '${d['project']}'),
            KV('Location', '${d['location'] ?? 'Ghana'}'),
            const SizedBox(height: 6),
            Row(children: [
              const Expanded(child: Text('Complete', style: TextStyle(fontSize: 13, color: AppColors.muted))),
              Text('${progress.round()}%', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            ]),
            DashBar(progress),
          ]),
          WsCard(kicker: 'Scope', children: [
            if (items.isEmpty) _Hint(edit ? 'No scope items yet. Add what the job covers, for example 12 sockets or DB installation.' : 'No scope items yet.'),
            for (final it in items)
              _JcRow(
                done: _n(it['done']) >= _n(it['total']),
                title: '${it['title']}',
                sub: _n(it['total']) > 1 ? '${_num(it['done'])} of ${_num(it['total'])} done' : _n(it['done']) >= _n(it['total']) ? 'Done' : 'Not done yet',
                trailing: '${_pct(_n(it['done']), _n(it['total']))}%',
                onTap: canProgress ? () => _progressSheet(context, ref, it) : null,
                onRemove: edit && (it['mine'] == true || me == 'client' || me == 'pm') ? () => _run(context, ref, () => rpcCall('job_card_item_remove', {'p_id': it['id']}), (_) => 'Item removed.') : null,
              ),
            if (edit) _AddButton('Add scope item', () => _itemSheet(context, ref)),
            if (canProgress && items.isNotEmpty) const _Hint('Tap an item to record how much is done.', top: true),
          ]),
          WsCard(kicker: 'Materials', children: [
            if (mats.isEmpty) const _Hint('No materials listed yet.'),
            for (final m in mats)
              _MatRow(
                m: m,
                onTap: canProgress ? () => _usedSheet(context, ref, m) : null,
                onRemove: edit && (m['mine'] == true || me == 'client' || me == 'pm') ? () => _run(context, ref, () => rpcCall('job_card_material_remove', {'p_id': m['id']}), (_) => 'Material removed.') : null,
              ),
            if (edit) _AddButton('Add material', () => _materialSheet(context, ref)),
            if (canProgress && mats.isNotEmpty) const _Hint('Tap a material to log how much was used.', top: true),
          ]),
          WsCard(kicker: 'Evidence', children: [
            for (final (k, l) in _stages) _Stage(label: l, photos: photos.where((p) => p['stage'] == k).toList(), urls: urls, onAdd: live ? () => _addPhoto(context, ref, k) : null),
            const _Hint('BAID X stamps each photo with the time it is added. Photos can\'t be edited later.', top: true),
          ]),
          WsCard(kicker: 'Payments', children: [
            KV('Contract', money(d['amount'])),
            KV('Paid to worker', money(d['paid'])),
            KV('Held in escrow', money(d['held'])),
            if (s == 'released' && me == 'worker' && d['net'] != null) ...[KV('BAID X fee', '− ${money(d['commission'])}'), KV('You received', money(d['net']), strong: true)],
            const SizedBox(height: 8),
            _PayBar(paid: _n(d['paid']), held: _n(d['held'])),
            _Hint(
              s == 'released'
                  ? 'Paid in full.'
                  : s == 'disputed'
                  ? 'Frozen while BAID X reviews the dispute.'
                  : live
                  ? 'Released when ${d['needs_pm'] == true ? 'the worker, the client and the PM' : 'the worker and the client'} have all signed off, or 3 days after the worker signs off if nobody responds.'
                  : 'This job did not complete.',
              top: true,
            ),
          ]),
          WsCard(kicker: 'Completion', children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, p) in parties.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _SignTile(party: _party[p]!, name: nameOf(p), at: signed[p]?['signed_at'])),
              ],
            ]),
            if (live && me.isNotEmpty && !signed.containsKey(me)) ...[
              const SizedBox(height: 12),
              EscrowButton(signLabel, icon: Icons.task_alt_rounded, onPressed: () => _signSheet(context, ref, me, waiting)),
            ],
          ]),
          if ('${d['submit_note'] ?? ''}'.isNotEmpty) WsQuote('Note from worker', d['submit_note']),
          if (s == 'disputed') WsCard(warn: true, children: [Text('This is in dispute. The money stays safe in escrow while BAID X reviews it. ${d['dispute_reason'] ?? ''}', style: const TextStyle(fontSize: 13, height: 1.4))]),
          if ('${d['resolution_note'] ?? ''}'.isNotEmpty) WsQuote('BAID X decision', d['resolution_note']),
          if (s == 'refunded') WsQuote('Refunded', me == 'worker' ? 'This job was cancelled and the client was refunded.' : 'The money was returned to your wallet.'),
          if (live && (me == 'worker' || me == 'client'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                Expanded(child: EscrowButton('Report a problem', ghost: true, onPressed: () => _dispute(context, ref))),
                if (s == 'active' && signed.isEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(child: EscrowButton(me == 'worker' ? 'Decline job' : 'Cancel and refund', ghost: true, onPressed: () => _cancel(context, ref))),
                ],
              ]),
            ),
          const SizedBox(height: 12),
          Text('Ref ${d['public_id'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ];
      },
    );
  }

  // ------------------------------------------------------------ sheets
  Future<void> _signSheet(BuildContext context, WidgetRef ref, String me, List<String> waiting) async {
    final text = me == 'worker'
        ? 'Signing off tells the client the work is complete. The card locks so the scope and materials can\'t change, and the client has 3 days to sign off before payment releases automatically.'
        : waiting.isNotEmpty
        ? 'Your sign-off is recorded. Payment is released once the ${waiting.map((p) => _party[p]!.toLowerCase()).join(' and the ')} also sign${waiting.length > 1 ? '' : 's'} off.'
        : 'Everyone else has signed off, so this releases the payment to the worker. You can\'t undo it, so only sign off if you\'re happy with the work.';
    final note = TextEditingController();
    await wsSheet(
      context,
      'Sign off',
      _Busy(
        builder: (ctx, run) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 12),
          if (me == 'worker') field('Note to the client (optional)', note, hint: 'What was completed, anything they should check.', lines: 3),
          run('Sign off', () => _run(context, ref, () => rpcCall('job_card_sign', {'p_eng': id, 'p_note': note.text.trim().isEmpty ? null : note.text.trim()}), (r) => asMap(r)['released'] == true ? 'Signed off. The payment was released.' : 'Signed off.')),
          const SizedBox(height: 8),
          PillButton(label: 'Not now', light: false, onPressed: () => Navigator.of(ctx).pop()),
        ]),
      ),
    );
  }

  Future<void> _itemSheet(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController(), qty = TextEditingController(text: '1');
    await wsSheet(
      context,
      'Add scope item',
      _Busy(
        builder: (ctx, run) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('What the job covers. Use a quantity when it can be counted, for example 12 sockets.', style: TextStyle(fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 12),
          field('Item', title, hint: 'e.g. Socket installation'),
          field('Quantity', qty, keyboard: TextInputType.number),
          run('Add item', () => _run(context, ref, () => rpcCall('job_card_item_add', {'p_eng': id, 'p_title': title.text.trim(), 'p_qty': int.tryParse(qty.text.trim()) ?? 1}), (_) => 'Item added.')),
        ]),
      ),
    );
  }

  Future<void> _progressSheet(BuildContext context, WidgetRef ref, Json it) async {
    final done = TextEditingController(text: _num(it['done']));
    await wsSheet(
      context,
      '${it['title']}',
      _Busy(
        builder: (ctx, run) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('How many of ${_num(it['total'])} are done?', style: const TextStyle(fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 12),
          field('Done', done, keyboard: TextInputType.number),
          run('Save progress', () => _run(context, ref, () => rpcCall('job_card_item_progress', {'p_id': it['id'], 'p_done': int.tryParse(done.text.trim())}), (_) => 'Progress saved.')),
        ]),
      ),
    );
  }

  Future<void> _materialSheet(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(), req = TextEditingController(), unit = TextEditingController();
    await wsSheet(
      context,
      'Add material',
      _Busy(
        builder: (ctx, run) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('List what the job needs. The worker logs how much is used as the work goes on.', style: TextStyle(fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 12),
          field('Material', name, hint: 'e.g. 2.5 mm cable'),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: field('Required', req, keyboard: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 10),
            Expanded(child: field('Unit (optional)', unit, hint: 'm, bags, pcs')),
          ]),
          run('Add material', () => _run(context, ref, () => rpcCall('job_card_material_add', {'p_eng': id, 'p_name': name.text.trim(), 'p_unit': unit.text.trim(), 'p_required': num.tryParse(req.text.trim())}), (_) => 'Material added.')),
        ]),
      ),
    );
  }

  Future<void> _usedSheet(BuildContext context, WidgetRef ref, Json m) async {
    final used = TextEditingController(text: _num(m['used']));
    final unit = '${m['unit'] ?? ''}';
    await wsSheet(
      context,
      '${m['name']}',
      _Busy(
        builder: (ctx, run) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('How much has been used so far? Required: ${_num(m['required'])}${unit.isEmpty ? '' : ' $unit'}.', style: const TextStyle(fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 12),
          field(unit.isEmpty ? 'Used' : 'Used ($unit)', used, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          run('Save', () => _run(context, ref, () => rpcCall('job_card_material_used', {'p_id': m['id'], 'p_used': num.tryParse(used.text.trim())}), (_) => 'Saved.')),
        ]),
      ),
    );
  }

  Future<void> _addPhoto(BuildContext context, WidgetRef ref, String stage) async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic']);
    if (f == null || !context.mounted) return;
    toast(context, 'Uploading photo…');
    await _run(context, ref, () async {
      final bytes = await f.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) throw const FormatException('That photo is over 10 MB.');
      final ext = (f.name.contains('.') ? f.name.split('.').last : 'jpg').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final type = ext == 'jpg' ? 'jpeg' : ext;
      final path = '$id/$myId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await sb.storage.from('job-cards').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: 'image/$type', upsert: false));
      return rpcCall('job_card_photo_add', {'p_eng': id, 'p_stage': stage, 'p_path': path});
    }, (_) => 'Photo added.');
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    if (await confirmBox(context, 'Cancel this job?', 'The money held in escrow goes back to the employer\'s wallet and the job reopens.', yes: 'Yes, cancel and refund') && context.mounted) {
      await _run(context, ref, () => rpcCall('engagement_cancel', {'p_id': id}), (_) => 'Cancelled. The escrow was refunded.');
    }
  }

  Future<void> _dispute(BuildContext context, WidgetRef ref) async {
    var reason = _disputeReasons.first;
    final details = TextEditingController();
    await wsSheet(
      context,
      'Report a problem',
      _Busy(
        builder: (ctx, run) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('The money stays frozen in escrow while BAID X reviews. Be specific, the more detail the faster we can decide.', style: TextStyle(fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 12),
          dropdown('What is the problem?', reason, [for (final r in _disputeReasons) (r, r)], (v) => reason = v ?? reason),
          field('Details', details, hint: 'What happened? What was agreed?', lines: 4),
          run('Open dispute', () => _run(context, ref, () => rpcCall('engagement_dispute', {'p_id': id, 'p_reason': reason, 'p_details': details.text.trim().isEmpty ? null : details.text.trim()}), (_) => 'Dispute opened. BAID X will review.')),
        ]),
      ),
    );
  }
}

/// A sheet body whose main button shows a spinner, blocks double taps and
/// closes the sheet only when the action worked.
class _Busy extends StatefulWidget {
  const _Busy({required this.builder});
  final Widget Function(BuildContext context, Widget Function(String label, Future<bool> Function() action) run) builder;
  @override
  State<_Busy> createState() => _BusyState();
}

class _BusyState extends State<_Busy> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    (label, action) => EscrowButton(
      label,
      busy: _busy,
      onPressed: () async {
        setState(() => _busy = true);
        final ok = await action();
        if (!context.mounted) return;
        if (ok) {
          Navigator.of(context).pop();
        } else {
          setState(() => _busy = false);
        }
      },
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.top = false});
  final String text;
  final bool top;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top ? 10 : 0, bottom: top ? 0 : 10),
    child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45)),
  );
}

class _AddButton extends StatelessWidget {
  const _AddButton(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x47FFFFFF), width: 1.5)),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add_rounded, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton(this.onTap);
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Semantics(
      button: true,
      label: 'Remove',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x2EFFFFFF))),
          child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFFBDBDBD)),
        ),
      ),
    ),
  );
}

BoxDecoration get _rowBox => BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x1FFFFFFF), width: 1.5));

class _JcRow extends StatelessWidget {
  const _JcRow({required this.done, required this.title, required this.sub, required this.trailing, this.onTap, this.onRemove});
  final bool done;
  final String title, sub, trailing;
  final VoidCallback? onTap, onRemove;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: _rowBox,
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: done ? AppColors.green : Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Icon(done ? Icons.task_alt_rounded : Icons.schedule_rounded, size: 17, color: done ? const Color(0xFF04210F) : Colors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                Text(trailing, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
          ),
        ),
      ),
      if (onRemove != null) _RemoveButton(onRemove!),
    ]),
  );
}

class _MatRow extends StatelessWidget {
  const _MatRow({required this.m, this.onTap, this.onRemove});
  final Json m;
  final VoidCallback? onTap, onRemove;
  @override
  Widget build(BuildContext context) {
    final unit = '${m['unit'] ?? ''}'.isEmpty ? '' : ' ${m['unit']}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: _rowBox,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: Text('${m['name']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${_num(m['used'])}$unit', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                        TextSpan(text: ' used of ${_num(m['required'])}$unit'),
                      ]),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ]),
                  DashBar(_pct(_n(m['used']), _n(m['required'])).clamp(0, 100)),
                ]),
              ),
            ),
          ),
        ),
        if (onRemove != null) _RemoveButton(onRemove!),
      ]),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.label, required this.photos, required this.urls, this.onAdd});
  final String label;
  final List<Json> photos;
  final Map<String, String> urls;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(child: Text('${photos.length} photo${photos.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.muted))),
        if (onAdd != null) SmallButton('Add', light: false, onPressed: onAdd),
      ]),
      const SizedBox(height: 8),
      if (photos.isEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x24FFFFFF))),
          child: Text('No ${label.toLowerCase()} photos', style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A8A8A))),
        )
      else
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 12) / 3;
            return Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in photos)
                Container(
                  width: w,
                  height: w,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x24FFFFFF))),
                  child: Stack(fit: StackFit.expand, children: [
                    if (urls['${p['path']}'] != null) Image.network(urls['${p['path']}']!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                    Positioned(
                      left: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(6)),
                        child: Text(_when(p['taken_at']), style: const TextStyle(fontSize: 10, color: Color(0xFFEEEEEE))),
                      ),
                    ),
                  ]),
                ),
            ]);
          },
        ),
    ]),
  );
}

class _PayBar extends StatelessWidget {
  const _PayBar({required this.paid, required this.held});
  final num paid, held;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(9),
    child: SizedBox(
      height: 8,
      child: paid + held <= 0
          ? Container(color: const Color(0x1FFFFFFF))
          : Row(children: [
              if (paid > 0) Expanded(flex: (paid * 100).round(), child: Container(color: AppColors.green)),
              if (paid > 0 && held > 0) const SizedBox(width: 2),
              if (held > 0) Expanded(flex: (held * 100).round(), child: Container(color: const Color(0x52FFFFFF))),
            ]),
    ),
  );
}

class _SignTile extends StatelessWidget {
  const _SignTile({required this.party, required this.name, this.at});
  final String party, name;
  final Object? at;
  @override
  Widget build(BuildContext context) {
    final on = at != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: on ? const Color(0x8034D399) : const Color(0x24FFFFFF), width: 1.5)),
      child: Column(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: on ? AppColors.green : Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Icon(on ? Icons.task_alt_rounded : Icons.schedule_rounded, size: 16, color: on ? const Color(0xFF04210F) : Colors.black),
        ),
        const SizedBox(height: 6),
        Text(party, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        Text(on ? _when(at) : 'Waiting', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}

/// Job cards on a project (workspace overview, company and PM).
class ProjectJobCards extends ConsumerWidget {
  const ProjectJobCards({required this.pid, super.key});
  final String pid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = (ref.watch(myJobCardsProvider).asData?.value ?? const <Json>[]).where((x) => x['project_id'] == pid).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.fromLTRB(2, 10, 2, 8), child: Text('JOB CARDS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFFBDBDBD)))),
      for (final x in list) DashRow(icon: Icons.assignment_outlined, title: '${x['title'] ?? 'Job'}', sub: '#BX-${x['card_no']} · ${x['counterpart'] ?? ''} · ${x['progress'] ?? 0}% complete', trailing: jobCardPill(x['status']), onTap: () => context.push('${AppRoutes.engagement}/${x['id']}')),
    ]);
  }
}
