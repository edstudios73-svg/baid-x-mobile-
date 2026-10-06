import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/dash_ui.dart';
import '../account/data/profile_data.dart';
import '../account/presentation/account_sheets.dart';
import '../account/presentation/profile_pages.dart' show backHead, field, dropdown;
import '../directory/presentation/member_sheet.dart' show startConversationWith;
import '../tabs/data/tabs_data.dart';
import '../workspace/presentation/ws_common.dart';
import 'hiring_screens.dart' show EscrowButton;

/// House logbook (website js/house.js): who did what in the client's home
/// (completed job cards), maintenance reminders, and the trusted team (everyone
/// they paid through escrow). Reads my_house; reminders change through
/// house_reminder_save / _done / _remove.

final myHouseProvider = FutureProvider<Json>((ref) async {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.id));
  return asMap(await rpcCall('my_house'));
});

const _m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _day(Object? d) {
  final t = DateTime.tryParse('${d ?? ''}'.length >= 10 ? '${d.toString().substring(0, 10)}T00:00:00' : '');
  return t == null ? '' : '${t.day} ${_m[t.month - 1]} ${t.year}';
}

String _month(Object? d) {
  final t = DateTime.tryParse('${d ?? ''}')?.toLocal();
  return t == null ? '' : '${_m[t.month - 1]} ${t.year}';
}

String _every(Object? v) {
  final m = int.tryParse('${v ?? ''}');
  if (m == null) return '';
  if (m == 1) return 'every month';
  if (m == 12) return 'every year';
  if (m % 12 == 0) return 'every ${m ~/ 12} years';
  return 'every $m months';
}

(String, String) _due(int days) => days < 0
    ? ('Overdue', 'rejected')
    : days == 0
    ? ('Today', 'pending')
    : days <= 14
    ? ('$days day${days == 1 ? '' : 's'}', 'pending')
    : ('Later', '');

const _repeat = [('', 'Does not repeat'), ('1', 'Every month'), ('3', 'Every 3 months'), ('6', 'Every 6 months'), ('12', 'Every year')];
const _ideas = ['Service the AC', 'Check the borehole pump', 'Termite treatment', 'Clean the water tank', 'Inspect the roof', 'Service the generator'];

String _err(Object e) {
  final m = friendlyError(e);
  return m.isEmpty ? m : m[0].toUpperCase() + m.substring(1);
}

class HouseScreen extends ConsumerWidget {
  const HouseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myHouseProvider);
    return DashPage<Json>(
      head: backHead(context, 'House logbook'),
      data: data,
      onRefresh: () => ref.refresh(myHouseProvider.future),
      builder: (d) {
        final history = asList(d['history']), reminders = asList(d['reminders']), team = asList(d['team']);
        return [
          WsCard(kicker: 'Who did what', children: [
            if (history.isEmpty)
              const Text('Every job you pay for through BAID X is recorded here when it\'s complete: what was done, who did it and when.', style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45))
            else
              for (final h in history)
                DashRow(icon: Icons.task_alt_rounded, title: '${h['title'] ?? 'Job'}', sub: '${[h['worker'], h['trade']].where((v) => v != null && '$v'.isNotEmpty).join(' · ')} · ${_month(h['done_on'])}', onTap: () => context.push('${AppRoutes.engagement}/${h['id']}')),
          ]),
          const _Label('Coming up'),
          if (reminders.isEmpty)
            const WsCard(children: [Text('Add reminders for the jobs your home needs again and again, like servicing the AC or treating for termites. We\'ll tell you when each one is due.', style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45))])
          else
            for (final r in reminders)
              Builder(builder: (context) {
                final (label, kind) = _due(int.tryParse('${r['days'] ?? 0}') ?? 0);
                final sub = ['Due ${_day(r['due_on'])}', _every(r['repeat_months']), if (r['worker'] != null) 'with ${r['worker']}'].where((s) => s.isNotEmpty).join(' · ');
                return DashRow(icon: Icons.notifications_none_rounded, title: '${r['title']}', sub: sub, trailing: WsPill(kind, label: label), onTap: () => _openSheet(context, ref, r, team));
              }),
          _AddButton('Add reminder', () => _reminderSheet(context, ref, null, team)),
          const _Label('My trusted team'),
          if (team.isEmpty)
            const DashEmpty(icon: Icons.handshake_outlined, title: 'No one yet', text: 'Professionals you pay through BAID X join your trusted team, so you can book them again in one message.')
          else
            for (final t in team)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.lineGlass)),
                  child: Row(children: [
                    WsAvatar(t['name'], t['photo'], size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${t['name'] ?? ''}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                        Text(
                          [if ('${t['trade'] ?? ''}'.isNotEmpty) '${t['trade']}', '${t['jobs']} job${(int.tryParse('${t['jobs']}') ?? 1) > 1 ? 's' : ''}', if (t['rating'] != null) 'you rated ${(num.tryParse('${t['rating']}') ?? 0).toStringAsFixed(1)}'].join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ]),
                    ),
                    SmallButton('Message', onPressed: () => startConversationWith(context, '${t['worker_id']}')),
                  ]),
                ),
              ),
        ];
      },
    );
  }

  Future<bool> _run(BuildContext context, WidgetRef ref, Future<dynamic> Function() fn, String Function(dynamic) ok) async {
    try {
      final r = await fn();
      ref.invalidate(myHouseProvider);
      if (context.mounted) toast(context, ok(r));
      return true;
    } catch (e) {
      if (context.mounted) toast(context, _err(e));
      return false;
    }
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref, Json r, List<Json> team) async {
    final linked = r['worker_id'] != null;
    await wsSheet(
      context,
      '${r['title']}',
      Builder(
        builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(['Due ${_day(r['due_on'])}', _every(r['repeat_months']), if (r['last_done_on'] != null) 'last done ${_day(r['last_done_on'])}'].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13.5, height: 1.45)),
          if ('${r['note'] ?? ''}'.isNotEmpty) WsQuote('Note', r['note']),
          const SizedBox(height: 14),
          if (linked) ...[
            EscrowButton('Message ${r['worker']}', onPressed: () {
              Navigator.of(ctx).pop();
              startConversationWith(context, '${r['worker_id']}');
            }),
            const SizedBox(height: 8),
          ],
          EscrowButton('Mark done', icon: Icons.task_alt_rounded, ghost: linked, onPressed: () async {
            Navigator.of(ctx).pop();
            await _run(context, ref, () => rpcCall('house_reminder_done', {'p_id': r['id']}), (x) => asMap(x)['next'] != null ? 'Done. Next one is due ${_day(asMap(x)['next'])}.' : 'Done.');
          }),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: EscrowButton('Edit', ghost: true, onPressed: () {
                Navigator.of(ctx).pop();
                _reminderSheet(context, ref, r, team);
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: EscrowButton('Remove', ghost: true, onPressed: () async {
                Navigator.of(ctx).pop();
                await _run(context, ref, () => rpcCall('house_reminder_remove', {'p_id': r['id']}), (_) => 'Reminder removed.');
              }),
            ),
          ]),
          const SizedBox(height: 10),
          Text(r['repeat_months'] != null ? 'Marking it done moves it to ${_every(r['repeat_months'])} from today.' : 'Marking it done puts it away.', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ]),
      ),
    );
  }

  Future<void> _reminderSheet(BuildContext context, WidgetRef ref, Json? r, List<Json> team) async {
    final title = TextEditingController(text: '${r?['title'] ?? ''}'), note = TextEditingController(text: '${r?['note'] ?? ''}');
    var due = DateTime.tryParse('${r?['due_on'] ?? ''}');
    var repeat = r?['repeat_months'] == null ? '' : '${r!['repeat_months']}';
    var worker = '${r?['worker_id'] ?? ''}';
    var busy = false;
    await wsSheet(
      context,
      r == null ? 'Add reminder' : 'Edit reminder',
      StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (r == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final i in _ideas)
                  ActionChip(
                    label: Text(i, style: const TextStyle(fontSize: 12.5)),
                    backgroundColor: const Color(0x0DFFFFFF),
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    shape: const StadiumBorder(),
                    onPressed: () => set(() => title.text = i),
                  ),
              ]),
            ),
          field('What needs doing', title, hint: 'e.g. Service the AC'),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Due', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
                  const SizedBox(height: 7),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(context: ctx, initialDate: due ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 10));
                      if (d != null) set(() => due = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
                      child: Text(due == null ? 'Choose' : fdate(due!.toIso8601String()), style: TextStyle(color: due == null ? AppColors.muted : null)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: dropdown('Repeat', repeat, _repeat, (v) => repeat = v ?? '')),
          ]),
          if (team.isNotEmpty) dropdown('Who usually does it (optional)', worker, [('', 'No one yet'), for (final t in team) ('${t['worker_id']}', '${t['name']}${'${t['trade'] ?? ''}'.isEmpty ? '' : ' · ${t['trade']}'}')], (v) => worker = v ?? ''),
          field('Note (optional)', note, hint: 'e.g. Both units, upstairs and living room', lines: 2),
          EscrowButton(
            'Save reminder',
            busy: busy,
            onPressed: () async {
              set(() => busy = true);
              final ok = await _run(
                context,
                ref,
                () => rpcCall('house_reminder_save', {
                  'p_id': r?['id'],
                  'p_title': title.text.trim(),
                  'p_due': due == null ? null : '${due!.year}-${'${due!.month}'.padLeft(2, '0')}-${'${due!.day}'.padLeft(2, '0')}',
                  'p_repeat_months': int.tryParse(repeat),
                  'p_worker': worker.isEmpty ? null : worker,
                  'p_note': note.text.trim().isEmpty ? null : note.text.trim(),
                }),
                (_) => 'Reminder saved.',
              );
              if (ok && ctx.mounted) {
                Navigator.of(ctx).pop();
              } else {
                set(() => busy = false);
              }
            },
          ),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
    child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: Color(0xFFBDBDBD))),
  );
}

class _AddButton extends StatelessWidget {
  const _AddButton(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Material(
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
    ),
  );
}

/// The client's home: what is due next, opening the logbook.
class HouseHomeCard extends ConsumerWidget {
  const HouseHomeCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(myHouseProvider).asData?.value;
    if (d == null) return const SizedBox.shrink();
    final reminders = asList(d['reminders']), n = asList(d['history']).length;
    final next = reminders.isEmpty ? null : reminders.first;
    final days = int.tryParse('${next?['days'] ?? 99}') ?? 99;
    final sub = next != null
        ? 'Next: ${next['title']}, ${days < 0 ? 'overdue' : days == 0 ? 'due today' : 'in $days day${days == 1 ? '' : 's'}'}'
        : n > 0
        ? '$n job${n > 1 ? 's' : ''} recorded · add maintenance reminders'
        : 'Who did what in your home, and what\'s due next';
    return WsInboxCard(warn: next != null && days <= 14, icon: Icons.home_outlined, title: 'House logbook', sub: sub, count: 0, onTap: () => context.push(AppRoutes.house));
  }
}
