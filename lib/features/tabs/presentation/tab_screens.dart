import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../account/domain/account_setup.dart';
import '../../account/presentation/account_sheets.dart';
import '../../account_type/domain/account_type.dart';
import '../../account_type/domain/role_categories.dart';
import '../../account/presentation/profile_pages.dart' show SecLabel;
import '../../hiring/hiring_screens.dart';
import '../../market/listing_gallery.dart';
import '../data/tabs_data.dart';

/// The dashboard tabs from the website (js/dash.js, js/market.js,
/// js/projects.js): Jobs, Work, Projects, Catalog, Inquiries, Hires and Post a
/// job, on the same tables and with the same cards.

String? _trade(Object? id) => jobCategories.where((c) => c.id == id).map((c) => c.name).firstOrNull;
String _place(Json r) => [r['city_town'], r['region']].where((v) => v != null && '$v'.isNotEmpty).join(', ').ifEmpty('Ghana');

extension on String {
  String ifEmpty(String v) => isEmpty ? v : this;
}

// ======================================================================
// Worker: Job Marketplace
// ======================================================================
class JobsTabScreen extends ConsumerStatefulWidget {
  const JobsTabScreen({super.key});
  @override
  ConsumerState<JobsTabScreen> createState() => _JobsTabScreenState();
}

class _JobsTabScreenState extends ConsumerState<JobsTabScreen> {
  final _q = TextEditingController();
  final _applying = <String>{};

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _apply(String id) async {
    final me = ref.read(accountProfileProvider).asData?.value;
    final p = me?.row ?? const {};
    final can = p['verification_status'] == 'verified' || ['pending_review', 'verified'].contains(p['profile_status']);
    if (!can) {
      toast(context, 'Complete your profile before you apply.');
      context.push(AppRoutes.checklist);
      return;
    }
    if (_applying.contains(id)) return;
    setState(() => _applying.add(id));
    try {
      await applyToJob(id);
      ref.invalidate(jobsTabProvider);
      await ref.read(jobsTabProvider.future);
      if (mounted) toast(context, 'Application sent.');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _applying.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(jobsTabProvider);
    final s = _q.text.trim().toLowerCase();
    return DashPage<JobsTab>(
      head: const DashHead('Job Marketplace'),
      top: [
        Container(
          height: 44,
          margin: const EdgeInsets.only(top: 4, bottom: 12),
          decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.lineGlass)),
          child: Row(children: [
            const SizedBox(width: 12),
            const Icon(Icons.search, size: 20, color: Color(0xFF9A9A9A)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(hintText: 'Search jobs, trades or towns', filled: false, isCollapsed: true, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
              ),
            ),
          ]),
        ),
      ],
      data: data,
      onRefresh: () => ref.refresh(jobsTabProvider.future),
      builder: (t) {
        final list = t.jobs.where((j) => s.isEmpty || '${j['title']} ${_trade(j['job_category_id']) ?? ''} ${j['city_town'] ?? ''} ${j['region'] ?? ''}'.toLowerCase().contains(s)).toList();
        if (list.isEmpty) {
          return [
            DashEmpty(
              icon: Icons.work_outline,
              title: t.jobs.isEmpty ? 'No open jobs right now' : 'No matching jobs',
              text: t.jobs.isEmpty ? 'New jobs from companies and homeowners will appear here. Check back soon.' : 'Try a different search.',
            ),
          ];
        }
        return [for (final j in list) _JobCard(job: j, applied: t.applied['${j['id']}'], busy: _applying.contains('${j['id']}'), onApply: () => _apply('${j['id']}'))];
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.applied, required this.busy, required this.onApply});
  final Json job;
  final String? applied;
  final bool busy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final trade = _trade(job['job_category_id']);
    const meta = TextStyle(fontSize: 12, color: AppColors.muted);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lineGlass)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (trade != null) Text(trade.toUpperCase(), style: const TextStyle(fontSize: 10.5, letterSpacing: .8, fontWeight: FontWeight.w700, color: Color(0xFFBDBDBD))),
              Text('${job['title'] ?? 'Job'}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 10),
          job['daily_rate_ghs'] != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(job['daily_rate_ghs']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const Text('per day', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                ])
              : const Text('Rate on request', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
        ]),
        if ('${job['description'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${job['description']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFFBDBDBD))),
        ],
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineGlass))),
          child: Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted), const SizedBox(width: 3), Text(_place(job), style: meta)]),
            Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.groups_outlined, size: 14, color: AppColors.muted), const SizedBox(width: 3), Text('${job['workers_needed'] ?? 1} needed', style: meta)]),
            Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.event_outlined, size: 14, color: AppColors.muted), const SizedBox(width: 3), Text(ago(job['created_at']), style: meta)]),
          ]),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: applied != null ? StatusPill(applied) : PillButton(label: busy ? 'Applying…' : 'Apply now', expand: false, height: 34, loading: busy, onPressed: busy ? null : onApply),
        ),
      ]),
    );
  }
}

// ======================================================================
// Worker: Work
// ======================================================================
class WorkTabScreen extends ConsumerStatefulWidget {
  const WorkTabScreen({super.key});
  @override
  ConsumerState<WorkTabScreen> createState() => _WorkTabScreenState();
}

class _WorkTabScreenState extends ConsumerState<WorkTabScreen> {
  var _seg = 'applications';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(workTabProvider);
    final engs = ref.watch(myEngagementsProvider).asData?.value ?? const <Json>[];
    return DashPage<WorkTab>(
      head: const DashHead('Work'),
      top: [
        DashSegs(
          items: const [('applications', 'Applications'), ('active', 'Active'), ('projects', 'Projects'), ('completed', 'Completed'), ('wallet', 'Wallet')],
          active: _seg,
          onTap: (k) {
            if (k == 'projects') return context.go(AppRoutes.projects);
            if (k == 'wallet') {
              context.push(AppRoutes.wallet);
              return;
            }
            setState(() => _seg = k);
          },
        ),
      ],
      data: data,
      onRefresh: () async {
        ref.invalidate(myEngagementsProvider);
        ref.invalidate(workTabProvider);
        await ref.read(workTabProvider.future);
      },
      builder: (w) {
        bool keep(Json a) => switch (_seg) {
              'active' => a['status'] == 'accepted',
              'completed' => a['status'] == 'completed',
              _ => !['accepted', 'completed'].contains(a['status']),
            };
        final list = w.apps.where(keep).toList();
        // hired jobs paid through escrow (website ESCROW.workSection)
        final eng = _seg == 'applications'
            ? const <Json>[]
            : engs.where((e) => e['role'] == 'worker' && (_seg == 'completed' ? ['released', 'refunded'].contains(e['status']) : ['active', 'submitted', 'disputed'].contains(e['status']))).toList();
        final engRows = engagementRows(context, eng);
        if (_seg == 'active' && engRows.isNotEmpty) return engRows;
        if (list.isEmpty) {
          final (t, x) = switch (_seg) {
            'active' => ('No active work', 'Jobs you have been accepted for will show here.'),
            'completed' => ('Nothing completed yet', 'Finished jobs, reviews and earned XP will show here.'),
            _ => ('No applications yet', 'Browse the Job Marketplace and apply to jobs that match your trade.'),
          };
          return [...engRows, DashEmpty(icon: Icons.work_outline, title: t, text: x, action: _seg == 'applications' ? SmallButton('Browse jobs', onPressed: () => context.go(AppRoutes.work)) : null)];
        }
        return [
          ...engRows,
          for (final a in list)
            DashRow(
              icon: Icons.work_outline,
              title: '${w.jobs['${a['job_id']}']?['title'] ?? 'Job'}',
              sub: '${w.jobs['${a['job_id']}']?['city_town'] ?? 'Ghana'} · applied ${ago(a['created_at'])}${a['proposed_rate_ghs'] != null ? ' · you asked ${money(a['proposed_rate_ghs'])}' : ''}',
              trailing: StatusPill('${a['status']}'),
            ),
        ];
      },
    );
  }
}

// ======================================================================
// Projects
// ======================================================================
class ProjectsTabScreen extends ConsumerStatefulWidget {
  const ProjectsTabScreen({super.key});
  @override
  ConsumerState<ProjectsTabScreen> createState() => _ProjectsTabScreenState();
}

class _ProjectsTabScreenState extends ConsumerState<ProjectsTabScreen> {
  var _seg = 'all';

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(accountProfileProvider).asData?.value?.type;
    final isCo = type == AccountType.company;
    final data = ref.watch(projectsTabProvider);
    final newBtn = isCo ? SmallButton('+ New project', onPressed: () => context.push(AppRoutes.createProject)) : null;
    return DashPage<List<Json>>(
      head: DashHead('Projects', action: newBtn),
      top: [DashSegs(items: const [('all', 'All'), ('active', 'Active'), ('completed', 'Completed')], active: _seg, onTap: (k) => setState(() => _seg = k))],
      data: data,
      onRefresh: () => ref.refresh(projectsTabProvider.future),
      builder: (list) {
        final shown = list.where((p) => _seg == 'all' || (_seg == 'completed' ? p['status'] == 'completed' : p['status'] != 'completed')).toList();
        if (shown.isEmpty) {
          return [
            isCo
                ? DashEmpty(icon: Icons.folder_outlined, title: 'No projects yet', text: 'Create a project to set the team you need, invite a project manager and keep everything in one workspace.', action: newBtn)
                : DashEmpty(
                    icon: Icons.folder_outlined,
                    title: 'No projects yet',
                    text: type == AccountType.projectManager ? 'When a company invites you and you accept, their project workspace opens here.' : 'When you accept a project invitation, its workspace opens here.',
                    action: SmallButton('View invitations', onPressed: () => context.push(AppRoutes.invites)),
                  ),
          ];
        }
        return [
          for (final p in shown)
            DashRow(
              icon: Icons.folder_outlined,
              title: '${p['name'] ?? 'Project'}',
              below: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 3),
                Row(children: [
                  if (p['public_code'] != null) ...[CodeTag('${p['public_code']}'), const SizedBox(width: 6)],
                  Expanded(child: Text('${_place(p)}${p['my_role'] != 'company' && p['company_name'] != null ? ' · ${p['company_name']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
                ]),
                DashBar(num.tryParse('${p['progress_pct'] ?? 0}')),
              ]),
              trailing: StatusPill('${p['status'] ?? ''}'),
              onTap: () => context.push('${AppRoutes.workspace}/${p['id']}'),
            ),
        ];
      },
    );
  }
}

// ======================================================================
// Business: Catalog and Inquiries
// ======================================================================
class CatalogTabScreen extends ConsumerStatefulWidget {
  const CatalogTabScreen({super.key});
  @override
  ConsumerState<CatalogTabScreen> createState() => _CatalogTabScreenState();
}

class _CatalogTabScreenState extends ConsumerState<CatalogTabScreen> {
  var _seg = 'products';

  Future<void> _toggle(Json i) async {
    final table = _seg == 'equipment' ? 'business_equipment' : 'business_products';
    try {
      await SupabaseConfig.client!.from(table).update({'available': i['available'] == false}).eq('id', '${i['id']}');
      ref.invalidate(catalogTabProvider(_seg));
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  void _photos(Json i) {
    final seg = _seg;
    showGlassSheet(
      context,
      title: 'Photos · ${i['name'] ?? 'Item'}',
      child: ListingPhotosSheet(table: seg == 'equipment' ? 'business_equipment' : 'business_products', id: '${i['id']}', initial: listingImages(i), onChanged: () => ref.invalidate(catalogTabProvider(seg))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eq = _seg == 'equipment';
    final data = ref.watch(catalogTabProvider(_seg));
    final add = SmallButton(eq ? 'Add equipment' : 'Add product', onPressed: () => _addItemSheet(context, ref, _seg));
    return DashPage<List<Json>>(
      head: DashHead('Catalog', action: add),
      top: [DashSegs(items: const [('products', 'Products'), ('equipment', 'Equipment')], active: _seg, onTap: (k) => setState(() => _seg = k))],
      data: data,
      onRefresh: () => ref.refresh(catalogTabProvider(_seg).future),
      builder: (items) {
        if (items.isEmpty) {
          return [DashEmpty(icon: eq ? Icons.construction_outlined : Icons.inventory_2_outlined, title: 'No $_seg listed', text: 'Add what you supply so companies and clients can find and request it.', action: add)];
        }
        return [
          for (final i in items)
            DashRow(
              leading: (i['image_urls'] is List && (i['image_urls'] as List).isNotEmpty)
                  ? ClipOval(child: Image.network('${(i['image_urls'] as List).first}', width: 38, height: 38, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 38, height: 38)))
                  : null,
              icon: eq ? Icons.construction_outlined : Icons.inventory_2_outlined,
              title: '${i['name'] ?? 'Item'}',
              sub: '${i['category'] ?? 'Uncategorised'}${(i['price'] ?? i['daily_rate']) != null ? ' · ${money(i['price'] ?? i['daily_rate'])}${eq ? '/day' : ''}' : ''} · ${listingImages(i).length} photo${listingImages(i).length == 1 ? '' : 's'}',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                SmallButton('Photos', light: false, onPressed: () => _photos(i)),
                const SizedBox(width: 6),
                StatusPill(i['available'] == false ? '' : 'open', label: i['available'] == false ? 'Hidden' : 'Listed'),
                const SizedBox(width: 6),
                SmallButton(i['available'] == false ? 'Show' : 'Hide', light: false, onPressed: () => _toggle(i)),
              ]),
            ),
        ];
      },
    );
  }
}

void _addItemSheet(BuildContext context, WidgetRef ref, String seg) {
  showGlassSheet(context, title: seg == 'equipment' ? 'Add equipment' : 'Add product', child: _AddItem(seg: seg, onSaved: () => ref.invalidate(catalogTabProvider(seg))));
}

class _AddItem extends StatefulWidget {
  const _AddItem({required this.seg, required this.onSaved});
  final String seg;
  final VoidCallback onSaved;
  @override
  State<_AddItem> createState() => _AddItemState();
}

class _AddItemState extends State<_AddItem> {
  final _name = TextEditingController(), _cat = TextEditingController(), _price = TextEditingController(), _qty = TextEditingController(), _desc = TextEditingController();
  String _condition = 'good';
  List<PlatformFile> _imgs = const [];
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _cat, _price, _qty, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty) return toast(context, 'Give it a name.');
    setState(() => _busy = true);
    try {
      final c = SupabaseConfig.client!, uid = c.auth.currentUser!.id;
      final imgs = await uploadListingPhotos([for (final f in _imgs.take(maxListingPhotos)) (await f.readAsBytes(), f.name)]);
      final eq = widget.seg == 'equipment';
      final row = eq
          ? {'business_id': uid, 'name': _name.text.trim(), 'category': _cat.text.trim().ifEmptyNull, 'daily_rate': num.tryParse(_price.text), 'condition': _condition, 'description': _desc.text.trim().ifEmptyNull, 'available': true, 'status': 'available', 'image_urls': imgs}
          : {'business_id': uid, 'name': _name.text.trim(), 'category': _cat.text.trim().ifEmptyNull, 'price': num.tryParse(_price.text), 'quantity': num.tryParse(_qty.text), 'description': _desc.text.trim().ifEmptyNull, 'listing_type': 'sale', 'available': true, 'status': 'in_stock', 'image_urls': imgs};
      await c.from(eq ? 'business_equipment' : 'business_products').insert(row);
      widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
      toast(context, 'Saved');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final eq = widget.seg == 'equipment';
    return Flexible(
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Field('Name', _name),
          _Field('Category', _cat),
          _Field(eq ? 'Daily rate (GH₵)' : 'Price (GH₵)', _price, number: true),
          if (!eq) _Field('Quantity', _qty, number: true),
          _Field('Description', _desc, lines: 3),
          if (eq)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _condition,
                dropdownColor: AppColors.card,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: const [DropdownMenuItem(value: 'new', child: Text('New')), DropdownMenuItem(value: 'good', child: Text('Good')), DropdownMenuItem(value: 'fair', child: Text('Fair'))],
                onChanged: (v) => setState(() => _condition = v ?? 'good'),
              ),
            ),
          Row(children: [
            Expanded(child: Text(_imgs.isEmpty ? 'Photos · up to $maxListingPhotos. Buyers see the first one first.' : '${_imgs.length} photo${_imgs.length == 1 ? '' : 's'} chosen', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
            SmallButton('Choose', light: false, onPressed: () async {
              final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
              if (f.isNotEmpty) setState(() => _imgs = f.take(maxListingPhotos).toList());
            }),
          ]),
          const SizedBox(height: 16),
          PillButton(label: 'Save', loading: _busy, onPressed: _busy ? null : _save),
        ]),
      ),
    );
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.controller, {this.number = false, this.lines = 1});
  final String label;
  final TextEditingController controller;
  final bool number;
  final int lines;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            maxLines: lines,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
          ),
        ]),
      );
}

class InquiriesTabScreen extends ConsumerWidget {
  const InquiriesTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashPage<List<Json>>(
      head: const DashHead('Inquiries'),
      data: ref.watch(inquiriesTabProvider),
      onRefresh: () => ref.refresh(inquiriesTabProvider.future),
      builder: (list) => list.isEmpty
          ? const [DashEmpty(icon: Icons.mail_outline, title: 'No inquiries yet', text: 'When someone asks about a product or equipment listing, it will land here.')]
          : [
              for (final i in list)
                DashRow(
                  icon: Icons.mail_outline,
                  title: '${i['inquirer_name'] ?? 'Customer'}',
                  sub: '${i['message'] ?? ''}'.length > 80 ? '${'${i['message']}'.substring(0, 80)}…' : '${i['message'] ?? ''}',
                  trailing: Text(ago(i['created_at']), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ),
            ],
    );
  }
}

// ======================================================================
// Client / company: Hires, Job posts and Post a job
// ======================================================================
class HiresTabScreen extends ConsumerWidget {
  const HiresTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = SmallButton('Post a job', onPressed: () => context.push(AppRoutes.postJob));
    final hired = (ref.watch(myEngagementsProvider).asData?.value ?? const <Json>[]).where((e) => e['role'] == 'payer').toList();
    return DashPage<List<Json>>(
      head: DashHead('Job posts', action: post),
      data: ref.watch(hiresTabProvider),
      onRefresh: () async {
        ref.invalidate(myEngagementsProvider);
        ref.invalidate(hiresTabProvider);
        await ref.read(hiresTabProvider.future);
      },
      builder: (jobs) => [
        ...jobs.isEmpty
          ? [DashEmpty(icon: Icons.how_to_reg_outlined, title: 'No jobs yet', text: 'Post a job and professionals can apply. You can also find a trade in Discover and message them.', action: post)]
          : [
              for (final j in jobs)
                DashRow(
                  icon: Icons.how_to_reg_outlined,
                  title: '${j['title'] ?? 'Job'}',
                  sub: '${j['city_town'] ?? 'Ghana'}${j['daily_rate_ghs'] != null ? ' · ${money(j['daily_rate_ghs'])}/day' : ''} · ${ago(j['created_at'])}',
                  trailing: StatusPill('${j['status']}'),
                  below: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                    SmallButton('View applicants', onPressed: () => context.push('${AppRoutes.applicants}/${j['id']}')),
                    SmallButton(j['status'] == 'open' ? 'Close' : 'Reopen', light: false, onPressed: () async {
                      try {
                        await setJobStatus('${j['id']}', j['status'] == 'open' ? 'closed' : 'open');
                        ref.invalidate(hiresTabProvider);
                      } catch (e) {
                        if (context.mounted) toast(context, friendlyError(e));
                      }
                    }),
                  ]),
                  ),
                ),
            ],
        ...hired.isEmpty ? const <Widget>[] : [const SecLabel('Hired professionals'), ...engagementRows(context, hired)],
      ],
    );
  }
}

/// Post a job (website `#/post-job`): same fields, same row.
class PostJobTabScreen extends ConsumerStatefulWidget {
  const PostJobTabScreen({super.key});
  @override
  ConsumerState<PostJobTabScreen> createState() => _PostJobTabScreenState();
}

class _PostJobTabScreenState extends ConsumerState<PostJobTabScreen> {
  final _title = TextEditingController(), _desc = TextEditingController(), _town = TextEditingController(), _rate = TextEditingController(), _needed = TextEditingController(text: '1');
  String? _cat, _region;
  DateTime? _start, _end;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_title, _desc, _town, _rate, _needed]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _d(DateTime? d) => d == null ? null : '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

  Future<void> _publish() async {
    if (_busy) return;
    if (_title.text.trim().isEmpty) return toast(context, 'Give the job a title.');
    setState(() => _busy = true);
    try {
      final c = SupabaseConfig.client!, uid = c.auth.currentUser!.id;
      final isCo = ref.read(accountProfileProvider).asData?.value?.type == AccountType.company;
      await c.from('jobs').insert({
        'title': _title.text.trim(),
        'description': _desc.text.trim().ifEmptyNull,
        'job_category_id': _cat,
        'region': _region,
        'city_town': _town.text.trim().ifEmptyNull,
        'starts_on': _d(_start),
        'ends_on': _d(_end),
        'daily_rate_ghs': num.tryParse(_rate.text),
        'workers_needed': int.tryParse(_needed.text) ?? 1,
        'status': 'open',
        isCo ? 'company_id' : 'employer_id': uid,
      });
      ref.invalidate(hiresTabProvider);
      if (!mounted) return;
      toast(context, 'Job published');
      context.pop();
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
                final d = await showDatePicker(context: context, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 730)), initialDate: v ?? now);
                if (d != null) setState(() => set(d));
              },
              child: InputDecorator(decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)), child: Text(_d(v) ?? 'Choose', style: TextStyle(color: v == null ? AppColors.muted : null))),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget select(String label, String? value, List<(String, String)> opts, ValueChanged<String?> on) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              initialValue: value,
              isExpanded: true,
              dropdownColor: AppColors.card,
              hint: const Text('Choose', style: TextStyle(color: AppColors.muted)),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
              items: [for (final o in opts) DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
              onChanged: on,
            ),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: [
          DashHead('Post a job', action: GlassIconButton(icon: Icons.close_rounded, tooltip: 'Close', size: 38, onTap: () => context.pop())),
          _section('The job', [
            _Field('Job title', _title),
            _Field('Details', _desc, lines: 4),
            select('Trade needed', _cat, [for (final c in jobCategories) (c.id, c.name)], (v) => setState(() => _cat = v)),
          ]),
          _section('Where and when', [
            select('Region', _region, [for (final r in regions) (r, r)], (v) => setState(() => _region = v)),
            _Field('Town', _town),
            Row(children: [_date('Start date', _start, (d) => _start = d), const SizedBox(width: 10), _date('End date', _end, (d) => _end = d)]),
          ]),
          _section('Pay and people', [
            Row(children: [Expanded(child: _Field('Daily rate (GH₵)', _rate, number: true)), const SizedBox(width: 10), Expanded(child: _Field('Workers needed', _needed, number: true))]),
          ]),
          PillButton(label: 'Publish job', loading: _busy, onPressed: _busy ? null : _publish),
        ]),
      ),
    );
  }
}
