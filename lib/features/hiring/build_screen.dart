import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/dash_ui.dart';
import '../account/data/profile_data.dart';
import '../account/presentation/account_sheets.dart';
import '../account/presentation/profile_pages.dart' show KV, backHead, field;
import '../tabs/data/tabs_data.dart';
import '../workspace/presentation/ws_common.dart';
import 'hiring_screens.dart' show EscrowButton;
import 'job_card_screen.dart' show jobCardPill;

/// My build (website js/build.js): a homeowner's build, made from their job
/// cards. The name, place, budget and finish date are saved by build_save;
/// money, progress, site photos and sign-offs waiting come from my_build.

final myBuildProvider = FutureProvider<Json>((ref) async {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.id));
  return asMap(await rpcCall('my_build'));
});

final buildPhotosProvider = FutureProvider.family<Map<String, String>, String>((ref, joined) async {
  final paths = joined.split('|').where((p) => p.isNotEmpty).toList();
  if (paths.isEmpty) return const {};
  final urls = await sb.storage.from('job-cards').createSignedUrlsResult(paths, 3600);
  return {for (var i = 0; i < urls.length && i < paths.length; i++) if (urls[i] is SignedUrlSuccess) paths[i]: (urls[i] as SignedUrlSuccess).signedUrl};
});

num _n(Object? v) => num.tryParse('${v ?? 0}') ?? 0;

/// Whole cedis, as the website shows budgets (GH₵264,000).
String cedis(Object? n) {
  final v = _n(n).round().abs();
  return 'GH₵${'$v'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
}

bool _today(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}')?.toLocal(), now = DateTime.now();
  return t != null && t.year == now.year && t.month == now.month && t.day == now.day;
}

String _when(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (t == null) return '';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]}, $h:${'${t.minute}'.padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

class BuildScreen extends ConsumerWidget {
  const BuildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myBuildProvider);
    return DashPage<Json>(
      head: backHead(context, 'My build'),
      data: data,
      onRefresh: () => ref.refresh(myBuildProvider.future),
      builder: (d) {
        final b = d['build'] == null ? null : asMap(d['build']);
        final paid = _n(d['paid']), held = _n(d['held']), budget = _n(b?['budget_ghs']), progress = _n(d['progress']);
        final photos = asList(d['photos']);
        final anyToday = photos.any((p) => _today(p['taken_at']));
        final shown = (anyToday ? photos.where((p) => _today(p['taken_at'])).toList() : photos).take(6).toList();
        final urls = ref.watch(buildPhotosProvider(shown.map((p) => '${p['path']}').join('|'))).asData?.value ?? const <String, String>{};
        final waiting = asList(d['waiting']), jobs = asList(d['jobs']);
        Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Text(k, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(width: 12),
            Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
          ]),
        );
        return [
          if (b == null)
            WsCard(children: [
              const Text('Set up your build', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.2)),
              const SizedBox(height: 6),
              const Text('Name your build and set a budget and finish date. Everything else fills in from your job cards: what you\'ve paid, what\'s held in escrow, progress and photos from site.', style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45)),
              const SizedBox(height: 12),
              EscrowButton('Set up my build', icon: Icons.add_rounded, onPressed: () => _editSheet(context, ref, null)),
            ])
          else
            WsCard(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${b['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.2)),
                    if ('${b['location'] ?? ''}'.isNotEmpty) Text('${b['location']}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ]),
                ),
                SmallButton('Edit', light: false, onPressed: () => _editSheet(context, ref, b)),
              ]),
              line('Spent', budget > 0 ? '${cedis(paid)} of ${cedis(budget)}' : cedis(paid)),
              if (budget > 0) DashBar((paid / budget * 100).clamp(0, 100)),
              line('Progress', '${progress.round()}%'),
              DashBar(progress),
              const SizedBox(height: 6),
              if (budget > 0) ...[KV('Committed so far', cedis(paid + held)), KV('Left in your budget', cedis((budget - paid - held).clamp(0, budget)))] else const Text('Add a budget to see what is left as you hire.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              for (final (i, (v, l)) in [(cedis(held), 'Held in escrow'), ('${waiting.length}', 'Waiting for you'), (b?['due_on'] == null ? 'Not set' : fdate(b!['due_on']), 'Finish date')].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x24FFFFFF), width: 1.5)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -.2)),
                      const SizedBox(height: 2),
                      Text(l, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
          WsCard(kicker: anyToday ? 'Today on site' : 'Latest from site', children: [
            if (shown.isEmpty)
              const Text('No site photos yet. Photos your workers add to their job cards appear here.', style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45))
            else ...[
              LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 12) / 3;
                  return Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in shown)
                      GestureDetector(
                        onTap: p['engagement_id'] == null ? null : () => context.push('${AppRoutes.engagement}/${p['engagement_id']}'),
                        child: Container(
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
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 10),
              const Text('From your job cards. Tap a photo to open its card.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ],
          ]),
          if (waiting.isNotEmpty) ...[
            const _Label('Waiting for you'),
            for (final w in waiting)
              DashRow(icon: Icons.task_alt_rounded, title: 'Sign off: ${w['title']}', sub: '${w['worker'] ?? ''} signed off · ${cedis(w['amount'])} held', trailing: const WsPill('pending', label: 'Review'), onTap: () => context.push('${AppRoutes.engagement}/${w['id']}')),
          ],
          const _Label('Jobs in this build'),
          if (jobs.isEmpty)
            DashEmpty(icon: Icons.handshake_outlined, title: 'No jobs yet', text: 'Post a job and hire a professional. Each hire gets a job card that feeds this page.', action: SmallButton('Post a job', onPressed: () => context.push(AppRoutes.postJob)))
          else
            for (final j in jobs)
              DashRow(icon: Icons.assignment_outlined, title: '${j['title'] ?? 'Job'}', sub: '#BX-${j['card_no']} · ${j['worker'] ?? ''} · ${j['progress'] ?? 0}% complete', trailing: jobCardPill(j['status']), onTap: () => context.push('${AppRoutes.engagement}/${j['id']}')),
        ];
      },
    );
  }

  Future<void> _editSheet(BuildContext context, WidgetRef ref, Json? b) async {
    final name = TextEditingController(text: '${b?['name'] ?? ''}'), location = TextEditingController(text: '${b?['location'] ?? ''}');
    final budget = TextEditingController(text: b?['budget_ghs'] == null ? '' : '${_n(b!['budget_ghs']).round()}');
    var due = DateTime.tryParse('${b?['due_on'] ?? ''}');
    var busy = false;
    await wsSheet(
      context,
      b == null ? 'Set up my build' : 'Edit my build',
      StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Only you see this. The money and progress come from your job cards.', style: TextStyle(fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 12),
          field('Build name', name, hint: 'e.g. 4-bedroom house'),
          field('Location', location, hint: 'e.g. Abuakwa, Kumasi'),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: field('Budget (GH₵)', budget, keyboard: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Finish date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
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
          ]),
          EscrowButton(
            'Save',
            busy: busy,
            onPressed: () async {
              set(() => busy = true);
              try {
                await rpcCall('build_save', {
                  'p_name': name.text.trim(),
                  'p_location': location.text.trim().isEmpty ? null : location.text.trim(),
                  'p_budget': num.tryParse(budget.text.trim()),
                  'p_due': due == null ? null : '${due!.year}-${'${due!.month}'.padLeft(2, '0')}-${'${due!.day}'.padLeft(2, '0')}',
                });
                ref.invalidate(myBuildProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) toast(context, 'Build saved.');
              } catch (e) {
                set(() => busy = false);
                final m = friendlyError(e);
                if (ctx.mounted) toast(ctx, m.isEmpty ? m : m[0].toUpperCase() + m.substring(1));
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

/// The client's home: a short summary that opens My build.
class BuildHomeCard extends ConsumerWidget {
  const BuildHomeCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(myBuildProvider).asData?.value;
    if (d == null) return const SizedBox.shrink();
    final b = d['build'] == null ? null : asMap(d['build']);
    final waiting = asList(d['waiting']).length;
    final empty = b == null && asList(d['jobs']).isEmpty;
    return WsInboxCard(
      warn: waiting > 0,
      icon: Icons.location_on_outlined,
      title: empty ? 'Set up my build' : '${b?['name'] ?? 'My build'}',
      sub: empty ? 'Track your budget, progress and site photos in one place' : '${_n(d['progress']).round()}% complete · ${cedis(d['paid'])} paid${waiting > 0 ? ' · $waiting waiting for you' : ''}',
      count: waiting,
      onTap: () => context.push(AppRoutes.build),
    );
  }
}
