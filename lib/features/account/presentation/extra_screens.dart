import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../account_type/domain/account_type.dart';
import '../../account_type/domain/role_categories.dart';
import '../../tabs/data/tabs_data.dart';
import '../data/profile_data.dart';
import '../domain/account_setup.dart';
import 'account_sheets.dart';
import 'profile_pages.dart';

/// Notifications (website js/notify.js) and New project (js/projects.js).

final notificationsProvider = FutureProvider<List<Json>>((ref) async {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.id));
  return sb.from('notifications').select('id,type,category,title,body,href,read_at,created_at').eq('user_id', myId).order('created_at', ascending: false).limit(60);
});

/// Website hash links (`#/chat/<id>`, `#/wallet`) mapped to app screens.
String? appPathFor(Object? href) {
  final h = '${href ?? ''}';
  if (!h.startsWith('#/')) return null;
  final parts = h.substring(2).split('/');
  final arg = parts.length > 1 ? parts[1] : '';
  return switch (parts.first) {
    'chat' when arg.isNotEmpty => '${AppRoutes.messages}/$arg',
    'chats' => AppRoutes.messages,
    'order' when arg.isNotEmpty => '${AppRoutes.orders}/$arg',
    'orders' => AppRoutes.orders,
    'wallet' => AppRoutes.wallet,
    'projects' || 'ws' || 'invites' || 'approvals' => AppRoutes.projects,
    'jobs' => AppRoutes.work,
    'work' || 'engagement' => AppRoutes.applications,
    'hires' || 'applicants' => AppRoutes.myJobs,
    'catalog' => AppRoutes.listings,
    'inquiries' => AppRoutes.inquiries,
    'orgs' || 'org' => AppRoutes.orgs,
    'billing' => AppRoutes.billing,
    'checklist' || 'step' || 'verification' => AppRoutes.checklist,
    'profile' => AppRoutes.profile,
    _ => null,
  };
}

class NotificationsScreen2 extends ConsumerWidget {
  const NotificationsScreen2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(notificationsProvider);
    final unread = (data.asData?.value ?? const []).where((n) => n['read_at'] == null).length;
    return DashPage<List<Json>>(
      head: backHead(context, 'Notifications',
          action: unread > 0
              ? SmallButton('Mark all read', light: false, onPressed: () async {
                  if (await runAction(context, () => sb.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', myId).isFilter('read_at', null))) {
                    ref.invalidate(notificationsProvider);
                  }
                })
              : null),
      data: data,
      onRefresh: () => ref.refresh(notificationsProvider.future),
      builder: (list) => list.isEmpty
          ? const [DashEmpty(icon: Icons.notifications_none_rounded, title: 'You\'re all caught up', text: 'Messages, invitations, approvals and payment updates will show up here.')]
          : [
              for (final n in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    radius: 18,
                    padding: const EdgeInsets.all(12),
                    onTap: () {
                      if (n['read_at'] == null) {
                        sb.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', '${n['id']}').then((_) => ref.invalidate(notificationsProvider));
                      }
                      final to = appPathFor(n['href']);
                      if (to != null) context.push(to);
                    },
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.notifications_none_rounded, size: 18, color: Colors.black)),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text('${n['title'] ?? 'BAID X'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                            Text(ago(n['created_at']), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                          ]),
                          if ('${n['body'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('${n['body']}', style: const TextStyle(fontSize: 12.5, color: Color(0xFFD0D0D0), height: 1.35))),
                        ]),
                      ),
                      if (n['read_at'] == null) Container(margin: const EdgeInsets.only(left: 8, top: 6), width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    ]),
                  ),
                ),
            ],
    );
  }
}

// ======================================================================
// New project (companies)
// ======================================================================
class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key});
  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends ConsumerState<NewProjectScreen> {
  static const _types = [('building', 'Building & construction'), ('renovation', 'Renovation'), ('electrical', 'Electrical works'), ('plumbing', 'Plumbing & water'), ('civil', 'Civil & roadworks'), ('finishing', 'Fit-out & finishing'), ('maintenance', 'Maintenance'), ('other', 'Other')];
  final _name = TextEditingController(), _desc = TextEditingController(), _town = TextEditingController(), _budget = TextEditingController(), _team = TextEditingController(), _req = TextEditingController();
  String _type = 'building';
  String? _region, _trade;
  DateTime? _start, _end;
  bool _needsPm = true;
  String _mode = 'automatic';
  final Map<String, int> _needs = {};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _desc, _town, _budget, _team, _req]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _d(DateTime? d) => d == null ? null : '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return toast(context, 'Name the project.');
    setState(() => _busy = true);
    try {
      final needs = [for (final e in _needs.entries) {'trade': e.key, 'qty': e.value}];
      final r = asMap(await rpcCall('create_project', {
        'p': {
          'name': _name.text.trim(),
          'description': _desc.text.trim(),
          'project_type': _type,
          'region': _region ?? '',
          'city_town': _town.text.trim(),
          'starts_on': _d(_start) ?? '',
          'ends_on': _d(_end) ?? '',
          'budget_ghs': _budget.text.trim(),
          'team_size': _team.text.trim(),
          'requirements': _req.text.trim(),
          'needs_pm': _needsPm,
          'worker_addition_mode': _mode,
          'required_skills': [for (final n in needs) n['trade']],
          'needs': needs,
        },
      }));
      ref.invalidate(projectsTabProvider);
      if (!mounted) return;
      toast(context, 'Project created · ${r['public_code'] ?? ''}');
      context.go(AppRoutes.projects);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _section(String t, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: .9, color: Color(0xFFBDBDBD))),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );

  Widget _date(String label, DateTime? v, ValueChanged<DateTime> set) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
            const SizedBox(height: 7),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: context, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 1825)), initialDate: v ?? now);
                if (d != null) setState(() => set(d));
              },
              child: InputDecorator(decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)), child: Text(_d(v) ?? 'Choose', style: TextStyle(color: v == null ? AppColors.muted : null))),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isCo = ref.watch(accountProfileProvider).asData?.value?.type == AccountType.company;
    if (!isCo) {
      return Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: [backHead(context, 'New project'), const DashEmpty(icon: Icons.folder_outlined, title: 'Companies create projects', text: 'A company creates the project and invites its project manager and workers.')])));
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: [
          backHead(context, 'New project'),
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Tell us what you are building. You can invite people right after.', style: TextStyle(fontSize: 13, color: AppColors.muted))),
          _section('Basics', [
            field('Project name', _name, hint: 'e.g. Estate block B'),
            field('Description', _desc, hint: 'What is being built or fixed?', lines: 3),
            dropdown('Type of work', _type, _types, (v) => setState(() => _type = v ?? _type)),
          ]),
          _section('Location and timeline', [
            dropdown('Region', _region, [for (final r in regions) (r, r)], (v) => setState(() => _region = v)),
            field('Town', _town, hint: 'e.g. Tema'),
            Row(children: [_date('Start date', _start, (d) => _start = d), const SizedBox(width: 10), _date('Expected completion', _end, (d) => _end = d)]),
            field('Budget (GH₵)', _budget, number: true, hint: 'e.g. 50000', helper: 'Only you can see the budget. Project managers and workers never do.'),
          ]),
          _section('Team you need', [
            field('Planned team size', _team, number: true, hint: 'How many people in total?'),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: dropdown('Trades needed', _trade, [for (final c in jobCategories) (c.name, c.name)], (v) => setState(() => _trade = v))),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SmallButton('Add', onPressed: _trade == null ? null : () => setState(() => _needs[_trade!] = (_needs[_trade!] ?? 0) + 1)),
              ),
            ]),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in _needs.entries)
                Container(
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.lineGlass)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(e.key, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, size: 16), onPressed: () => setState(() => e.value <= 1 ? _needs.remove(e.key) : _needs[e.key] = e.value - 1)),
                    Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 16), onPressed: () => setState(() => _needs[e.key] = e.value + 1)),
                  ]),
                ),
            ]),
            const SizedBox(height: 8),
            const Text('Workers outside this plan need your approval before they join.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            field('Requirements', _req, hint: 'Certificates, safety gear, anything workers must have', lines: 2),
          ]),
          _section('Project manager', [
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _needsPm, activeThumbColor: Colors.black, activeTrackColor: Colors.white, title: const Text('I need a project manager', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)), onChanged: (v) => setState(() => _needsPm = v)),
            const Text('You will invite one from Discover after you create the project.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
          _section('Approval rules', [
            for (final (k, t, s) in const [('automatic', 'Automatic', 'Workers your PM invites within the plan join once they accept.'), ('company_approval', 'Company approval', 'You approve every worker before they join.')])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Glass(
                  radius: 14,
                  selected: _mode == k,
                  padding: const EdgeInsets.all(12),
                  onTap: () => setState(() => _mode = k),
                  child: Row(children: [
                    Icon(_mode == k ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w700)), Text(s, style: const TextStyle(fontSize: 12, color: AppColors.muted))])),
                  ]),
                ),
              ),
            const Text('Expenses, materials, equipment and payments always need your approval.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
          PillButton(label: 'Create project', loading: _busy, onPressed: _busy ? null : _create),
        ]),
      ),
    );
  }
}
