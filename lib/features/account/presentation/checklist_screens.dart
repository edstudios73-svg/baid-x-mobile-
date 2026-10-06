import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../account_type/domain/role_categories.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/account_actions.dart';
import '../domain/account_setup.dart';
import 'account_sheets.dart';

const _amber = Color(0xFFF2F2F2);

/// Shared frame: back button, title, optional right action.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children, this.action});
  final String title;
  final List<Widget> children;
  final Widget? action; // set on step pages: title on the left, button on the right

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            if (action != null)
              Row(children: [
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.3))),
                action!,
              ])
            else
              SizedBox(
                height: 44,
                child: Stack(alignment: Alignment.center, children: [
                  Align(alignment: Alignment.centerLeft, child: GlassIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Back', size: 40, onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.profile))),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

Widget _loading() => const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));

/// "BAID X verification" checklist (website `#/checklist`).
class ChecklistScreen extends ConsumerWidget {
  const ChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(accountProfileProvider).asData?.value;
    final type = me?.type;
    if (me == null || type == null) return _loading();
    final cl = checklistState(type, me.row);
    final pct = (cl.pct * 100).round();
    final status = statusLabel(me.row['verification_status']);
    return _Page(
      title: 'Checklist',
      children: [
        SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: me.isVerified ? AppColors.green.withValues(alpha: .14) : _amber.withValues(alpha: .14)), child: Icon(me.isVerified ? Icons.verified_outlined : Icons.hourglass_empty_rounded, color: me.isVerified ? AppColors.green : _amber, size: 21)),
              const SizedBox(width: 12),
              const Expanded(child: Text('BAID X verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Pill(status, tone: me.isVerified ? PillTone.ok : PillTone.warn),
            ]),
            const SizedBox(height: 8),
            Text('Complete these checks before your profile can be approved.', style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 10),
        SurfaceCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('${cl.done} of ${cl.total} completed', style: const TextStyle(fontSize: 12.5, color: Color(0xFFDDDDDD)))),
              Text('$pct%', style: const TextStyle(fontSize: 12.5, color: Color(0xFFDDDDDD), fontFeatures: [FontFeature.tabularFigures()])),
            ]),
            const SizedBox(height: 8),
            _Bar(cl.pct),
          ]),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < cl.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SurfaceCard(
              radius: 15,
              padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
              onTap: () => context.push('${AppRoutes.checklist}/step/$i'),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: (cl.items[i].$2 ? AppColors.green : _amber).withValues(alpha: .14)),
                  child: Icon(cl.items[i].$2 ? Icons.check_circle_outline_rounded : Icons.hourglass_empty_rounded, size: 19, color: cl.items[i].$2 ? AppColors.green : _amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cl.items[i].$1.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(cl.items[i].$1.desc, style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.3)),
                  ]),
                ),
                const SizedBox(width: 8),
                _StatePill(done: cl.items[i].$2),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
              ]),
            ),
          ),
      ],
    );
  }
}

/// `.st.ok` / `.st.warn`: a green "Done" or amber "Pending" pill.
class _StatePill extends StatelessWidget {
  const _StatePill({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = done ? AppColors.green : _amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
      child: Text(done ? 'Done' : 'Pending', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.value);
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 4, color: const Color(0xFFFFFFFF), backgroundColor: const Color(0xFF222222)),
      );
}

/// One checklist step (website `#/step/n`): the same questions and uploads.
class ChecklistStepScreen extends ConsumerStatefulWidget {
  const ChecklistStepScreen({required this.index, super.key});
  final int index;

  @override
  ConsumerState<ChecklistStepScreen> createState() => _ChecklistStepScreenState();
}

class _ChecklistStepScreenState extends ConsumerState<ChecklistStepScreen> {
  final Map<String, TextEditingController> _text = {};
  final Map<String, Object?> _picked = {}; // select / bool values
  final Map<String, PlatformFile> _files = {}; // column -> chosen file
  PlatformFile? _photo;
  final List<PlatformFile> _gallery = [];
  bool _busy = false;
  String? _seededFor;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(ProfileRow p, StepSpec spec, String key) {
    if (_seededFor == key) return;
    _seededFor = key;
    for (final f in spec.fields) {
      final v = valueOf(p, f.col);
      switch (f.kind) {
        case FieldKind.select || FieldKind.jobcat:
          _picked[f.col] = v?.toString();
        case FieldKind.bool:
          _picked[f.col] = v == true;
        case FieldKind.list:
          _text[f.col] = TextEditingController(text: v is List ? v.join(', ') : '');
        default:
          _text[f.col] = TextEditingController(text: v == null ? '' : '$v');
      }
    }
  }

  Future<PlatformFile?> _pick({bool docs = false}) async {
    try {
      final r = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: docs ? ['jpg', 'jpeg', 'png', 'webp', 'pdf'] : ['jpg', 'jpeg', 'png', 'webp']);
      return r;
    } catch (_) {
      if (mounted) toast(context, 'Could not open your files.');
      return null;
    }
  }

  Future<void> _save(AccountProfile me, StepSpec spec) async {
    if (_busy) return;
    final type = me.type!;
    final p = me.row;
    final a = AccountActions();
    setState(() => _busy = true);
    try {
      final patch = <String, dynamic>{};
      final ps = Map<String, dynamic>.from(p['profile_sections'] is Map ? p['profile_sections'] as Map : const {});
      var usePs = false;
      void put(String col, Object? val) {
        if (col.startsWith('ps.')) {
          ps[col.substring(3)] = val;
          usePs = true;
        } else {
          patch[col] = val;
        }
      }

      for (final f in spec.fields) {
        Object? val;
        switch (f.kind) {
          case FieldKind.bool:
            val = _picked[f.col] == true;
          case FieldKind.select || FieldKind.jobcat:
            final s = _picked[f.col]?.toString() ?? '';
            val = s.isEmpty ? null : s;
          default:
            final raw = _text[f.col]!.text.trim();
            val = switch (f.kind) {
              FieldKind.number => raw.isEmpty ? null : num.tryParse(raw),
              FieldKind.list => raw.isEmpty ? <String>[] : [for (final s in raw.split(',')) if (s.trim().isNotEmpty) s.trim()],
              _ => raw.isEmpty ? null : raw,
            };
            if (f.kind == FieldKind.number && raw.isNotEmpty && val == null) throw const _Msg('Use numbers only.');
        }
        put(f.col, val);
      }
      for (final req in const ['full_name', 'company_name', 'business_name']) {
        if (patch.containsKey(req) && patch[req] == null) throw const _Msg("Name can't be empty.");
      }
      if (_photo != null) {
        final (col, bucket, _) = photoOf(type);
        patch[col] = a.publicUrl(bucket, await a.upload(bucket, await _photo!.readAsBytes(), _photo!.name, 'photo'));
      }
      for (final e in _files.entries) {
        // private documents keep the storage path; only reviewers get signed links
        put(e.key, await a.upload(fileBuckets[e.key]!, await e.value.readAsBytes(), e.value.name, e.key.replaceAll(RegExp(r'\W'), '')));
      }
      if (_gallery.isNotEmpty) {
        final urls = <String>[for (final f in _gallery) a.publicUrl('portfolios', await a.upload('portfolios', await f.readAsBytes(), f.name, 'work'))];
        patch['portfolio_photo_urls'] = [...(p['portfolio_photo_urls'] is List ? p['portfolio_photo_urls'] as List : const []), ...urls];
      }
      if (usePs) patch['profile_sections'] = ps;
      await a.save(type, patch);
      ref.invalidate(accountProfileProvider);
      final fresh = await ref.read(accountProfileProvider.future);
      if (!mounted) return;
      toast(context, 'Saved');
      final cl = checklistState(type, fresh?.row ?? p);
      final next = [for (var i = 0; i < cl.items.length; i++) i].where((i) => i > widget.index && !cl.items[i].$2).firstOrNull;
      if (next != null) {
        context.pushReplacement('${AppRoutes.checklist}/step/$next');
      } else {
        context.pop();
      }
    } on _Msg catch (e) {
      if (mounted) toast(context, e.text);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(accountProfileProvider).asData?.value;
    final type = me?.type;
    if (me == null || type == null) return _loading();
    final list = checklists[type]!;
    final idx = widget.index.clamp(0, list.length - 1);
    final item = list[idx];
    final p = me.row;
    final spec = stepSpec(type, item.title);
    final done = me.isVerified || item.test(p);
    _seed(p, spec, '${type.name}:$idx');

    final top = <Widget>[
      Text('STEP ${idx + 1} OF ${list.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFA8A8A8), letterSpacing: .9)),
      const SizedBox(height: 7),
      _Bar((idx + 1) / list.length),
      const SizedBox(height: 14),
      Text(spec.blurb ?? item.desc, style: TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.45)),
      const SizedBox(height: 14),
    ];
    final back = TextButton(onPressed: () => context.pop(), child: Text('Back to checklist', style: TextStyle(color: AppColors.muted)));
    final checklistBtn = PillButton(label: 'Checklist', light: false, expand: false, height: 36, onPressed: () => context.pop());

    if (spec.phone) {
      final phone = me.phone;
      return _Page(title: item.title, action: checklistBtn, children: [
        ...top,
        _Section('Your number', [
          Row(children: [
            Expanded(child: Text(_mask(phone).isEmpty ? 'Not set' : _mask(phone), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: .5))),
            if (done) const Pill('Verified', tone: PillTone.ok),
          ]),
          const SizedBox(height: 8),
          Text('This number signs you in and receives your one-time codes. It was confirmed when you created your account.', style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4)),
        ]),
        const SizedBox(height: 14),
        PillButton(label: 'Change number', light: false, onPressed: () => openChangePhone(context)),
        back,
      ]);
    }
    if (spec.email) {
      return _Page(title: item.title, action: checklistBtn, children: [
        ...top,
        _Section('Your email', [const EmailStatus(), AddEmailForm(type: type)]),
        back,
      ]);
    }
    if (item.title == 'Portfolio') return _portfolio(me, spec, top, checklistBtn, back);
    if (spec.web) {
      return _Page(title: item.title, action: checklistBtn, children: [
        ...top,
        PillButton(
          label: item.title == 'Certification' ? 'Open certifications' : 'Open past projects',
          onPressed: () => context.push(item.title == 'Certification' ? AppRoutes.certs : AppRoutes.portfolio),
        ),
        back,
      ]);
    }

    final (photoCol, _, photoLabel) = photoOf(type);
    return _Page(
      title: item.title,
      action: checklistBtn,
      children: [
        ...top,
        if (spec.photo)
          _Section(photoLabel, [
            Row(children: [
              _photo != null
                  ? FutureBuilder(future: _photo!.readAsBytes(), builder: (_, s) => ClipOval(child: s.hasData ? Image.memory(s.data!, width: 64, height: 64, fit: BoxFit.cover) : const SizedBox(width: 64, height: 64)))
                  : InitialsAvatar(name: me.displayName, photoUrl: p[photoCol] as String?, size: 64, radius: 32),
              const SizedBox(width: 14),
              PillButton(label: 'Choose photo', light: false, expand: false, height: 38, onPressed: () async {
                final f = await _pick();
                if (f != null) setState(() => _photo = f);
              }),
            ]),
          ]),
        if (spec.fields.isNotEmpty || spec.files.isNotEmpty)
          _Section(item.title, [
            for (final f in spec.fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
            for (final col in spec.files) _doc(col, valueOf(p, col)),
          ]),
        const SizedBox(height: 6),
        PillButton(label: 'Save and continue', loading: _busy, onPressed: _busy ? null : () => _save(me, spec)),
        TextButton(onPressed: () => context.pop(), child: Text("I'll do this later", style: TextStyle(color: AppColors.muted))),
      ],
    );
  }

  Widget _portfolio(AccountProfile me, StepSpec spec, List<Widget> top, Widget action, Widget back) {
    final urls = [for (final u in (me.row['portfolio_photo_urls'] is List ? me.row['portfolio_photo_urls'] as List : const [])) '$u'];
    return _Page(title: 'Portfolio', action: action, children: [
      ...top,
      _Section('Your work', [
        if (urls.isEmpty && _gallery.isEmpty) Text('No photos yet.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final u in urls) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(u, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.tile))),
            for (final f in _gallery)
              ClipRRect(borderRadius: BorderRadius.circular(12), child: FutureBuilder(future: f.readAsBytes(), builder: (_, s) => s.hasData ? Image.memory(s.data!, fit: BoxFit.cover) : const ColoredBox(color: AppColors.tile))),
          ],
        ),
        const SizedBox(height: 12),
        PillButton(label: 'Add photo', light: false, icon: Icons.add_photo_alternate_outlined, onPressed: () async {
          final f = await _pick();
          if (f != null) setState(() => _gallery.add(f));
        }),
      ]),
      const SizedBox(height: 6),
      PillButton(label: 'Save and continue', loading: _busy, onPressed: _busy || _gallery.isEmpty ? null : () => _save(me, spec)),
      back,
    ]);
  }

  Widget _field(StepField f) {
    if (f.kind == FieldKind.bool) return _input(f);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(f.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDDDDDD))),
      const SizedBox(height: 7),
      _input(f),
    ]);
  }

  Widget _input(StepField f) {
    switch (f.kind) {
      case FieldKind.bool:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _picked[f.col] == true,
          activeThumbColor: Colors.black,
          activeTrackColor: Colors.white,
          title: Text(f.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          onChanged: (v) => setState(() => _picked[f.col] = v),
        );
      case FieldKind.select || FieldKind.jobcat:
        final opts = f.kind == FieldKind.jobcat ? [for (final c in jobCategories) (c.id, c.name)] : f.options;
        final cur = _picked[f.col]?.toString();
        return DropdownButtonFormField<String>(
          initialValue: opts.any((o) => o.$1 == cur) ? cur : null,
          isExpanded: true,
          dropdownColor: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
          hint: Text(f.kind == FieldKind.jobcat ? 'Choose a trade' : 'Choose', style: TextStyle(color: AppColors.muted)),
          items: [for (final o in opts) DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => _picked[f.col] = v),
        );
      default:
        return TextField(
          controller: _text[f.col],
          maxLines: f.kind == FieldKind.area ? 4 : 1,
          minLines: f.kind == FieldKind.area ? 3 : 1,
          maxLength: f.max,
          keyboardType: f.kind == FieldKind.number ? const TextInputType.numberWithOptions(decimal: true) : null,
          decoration: InputDecoration(hintText: f.hint, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
        );
    }
  }

  Widget _doc(String col, Object? current) {
    final chosen = _files[col];
    final has = real(current);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0x1FFFFFFF))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fileLabels[col] ?? col, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(chosen != null ? chosen.name : has ? 'Uploaded. Choose a file to replace it.' : 'Required', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          if (has && chosen == null) ...[const Pill('Uploaded', tone: PillTone.ok), const SizedBox(width: 8)],
          PillButton(
            label: has || chosen != null ? 'Replace' : 'Upload',
            light: false,
            expand: false,
            height: 36,
            onPressed: () async {
              final f = await _pick(docs: true);
              if (f != null) setState(() => _files[col] = f);
            },
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: .9, color: Color(0xFFBDBDBD))),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );
}

class _Msg implements Exception {
  const _Msg(this.text);
  final String text;
}

String _mask(String v) {
  final d = v.replaceAll(RegExp(r'[^\d+]'), '');
  if (d.length <= 6) return d;
  return '${d.substring(0, d.startsWith('+') ? 6 : 3)} ••• ${d.substring(d.length - 4)}';
}

