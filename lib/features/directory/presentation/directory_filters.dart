import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../account/domain/account_setup.dart' show regions;
import '../../account_type/domain/role_categories.dart';
import '../data/directory_repository.dart';

/// Discover filters (website #/filters and #/picker): type, category, location.
class DirFilter {
  const DirFilter({this.type = 'all', this.cat, this.region});
  final String type; // all | companies | professionals | managers | businesses
  final RoleCategory? cat;
  final String? region;

  bool get active => type != 'all' || cat != null || region != null;

  static List<RoleCategory> categoriesFor(String type) => switch (type) {
        'companies' => industries,
        'professionals' => jobCategories,
        'managers' => specializations,
        'businesses' => supplyCategories,
        _ => const [],
      };
}

String _norm(String? s) => (s ?? '').toLowerCase().replaceAll(RegExp(r'\s*region$'), '').trim();

/// The website's visible(): chip or filter type, then category, region, search.
List<DirectoryMember> applyDirFilter(List<DirectoryMember> all, String chip, DirFilter f, String q) {
  final group = f.type != 'all' ? f.type : chip;
  return all
      .where((m) => group == 'all' || m.group == group)
      .where((m) => f.cat == null || m.catId == f.cat!.id)
      .where((m) {
        if (f.region == null) return true;
        final r = _norm(m.region), want = _norm(f.region);
        return r.isNotEmpty && (r.contains(want) || want.contains(r));
      })
      .where((m) => q.isEmpty || '${m.name} ${m.tag} ${m.place} ${m.desc}'.toLowerCase().contains(q))
      .toList();
}

const _typeLabel = {'all': 'Any type', 'companies': 'Companies', 'professionals': 'Professionals', 'managers': 'Project Managers', 'businesses': 'Businesses'};

class DirectoryFiltersScreen extends StatefulWidget {
  const DirectoryFiltersScreen({required this.initial, super.key});
  final DirFilter initial;
  @override
  State<DirectoryFiltersScreen> createState() => _DirectoryFiltersScreenState();
}

class _DirectoryFiltersScreenState extends State<DirectoryFiltersScreen> {
  late var _d = widget.initial;

  Future<void> _pick(String key) async {
    final List<(String, String, String)> items; // id, name, desc
    final String title, current;
    if (key == 'type') {
      title = 'Type';
      items = [for (final e in _typeLabel.entries) (e.key, e.value, '')];
      current = _d.type;
    } else if (key == 'cat') {
      title = 'Category';
      items = [('', 'Any category', ''), for (final c in DirFilter.categoriesFor(_d.type)) (c.id, c.name, c.desc.isNotEmpty ? c.desc : c.group)];
      current = _d.cat?.id ?? '';
    } else {
      title = 'Location';
      items = [('', 'Any location', ''), for (final r in regions) (r, r, '')];
      current = _d.region ?? '';
    }
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => _Picker(title: title, items: items, current: current)));
    if (id == null || !mounted) return;
    setState(() {
      if (key == 'type') {
        _d = DirFilter(type: id, cat: id == _d.type ? _d.cat : null, region: _d.region);
      } else if (key == 'cat') {
        _d = DirFilter(type: _d.type, cat: id.isEmpty ? null : DirFilter.categoriesFor(_d.type).firstWhere((c) => c.id == id), region: _d.region);
      } else {
        _d = DirFilter(type: _d.type, cat: _d.cat, region: id.isEmpty ? null : id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final noType = _d.type == 'all';
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _SubHead('Filters'),
              _Row(icon: Icons.groups_outlined, title: 'Type', value: _typeLabel[_d.type]!, onTap: () => _pick('type')),
              Opacity(
                opacity: noType ? .55 : 1,
                child: _Row(icon: Icons.work_outline, title: 'Category', value: _d.cat?.name ?? (noType ? 'Choose a type first' : 'Any category'), onTap: noType ? () => toastLike(context, 'Choose a type first.') : () => _pick('cat')),
              ),
              _Row(icon: Icons.location_on_outlined, title: 'Location', value: _d.region ?? 'Any location', onTap: () => _pick('region')),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  Expanded(flex: 10, child: PillButton(label: 'Clear', light: false, height: 48, onPressed: () => setState(() => _d = const DirFilter()))),
                  const SizedBox(width: 12),
                  Expanded(flex: 14, child: PillButton(label: 'Apply filters', height: 48, onPressed: () => Navigator.of(context).pop(_d))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

void toastLike(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

class _SubHead extends StatelessWidget {
  const _SubHead(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          GlassIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Back', size: 40, onTap: () => Navigator.of(context).pop()),
          Expanded(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          const SizedBox(width: 40),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.value, required this.onTap});
  final IconData icon;
  final String title, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFF2A2A2A), shape: BoxShape.circle), child: Icon(icon, size: 20, color: const Color(0xFFD6D6D6))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text(value, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ]),
            ),
          ),
        ),
      );
}

class _Picker extends StatelessWidget {
  const _Picker({required this.title, required this.items, required this.current});
  final String title, current;
  final List<(String, String, String)> items;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppBackdrop(
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              _SubHead(title),
              for (final (id, name, desc) in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: id == current ? const Color(0x12FFFFFF) : AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: id == current ? Colors.white : Colors.transparent, width: 1.5)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).pop(id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontSize: 14.5)),
                          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
