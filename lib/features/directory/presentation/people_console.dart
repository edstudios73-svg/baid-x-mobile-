import 'package:flutter/material.dart';

import '../data/directory_repository.dart';

/// The head of the members section (website `.dir-head`), set straight on the page: a
/// live dot and the member count, the heading, a five-way filter that shows each
/// group's real count under a sliding white highlight, the share of members verified
/// by BAID X, and the search field with a live result count.
class PeopleConsole extends StatelessWidget {
  const PeopleConsole({required this.members, required this.filter, required this.onFilter, required this.search, required this.onSearch, required this.results, super.key});

  final List<DirectoryMember>? members; // null while loading
  final String filter;
  final ValueChanged<String> onFilter;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final int? results; // shown while a search is typed

  static const segments = [('all', 'All'), ('professionals', 'Pros'), ('companies', 'Companies'), ('managers', 'PMs'), ('businesses', 'Suppliers')];

  @override
  Widget build(BuildContext context) {
    final all = members ?? const <DirectoryMember>[];
    int count(String k) => k == 'all' ? all.length : all.where((m) => m.group == k).length;
    final verified = all.isEmpty ? 0.0 : all.where((m) => m.badge != null).length / all.length;
    // open, not boxed: the parts sit straight on the page backdrop
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _LiveDot(),
              const SizedBox(width: 8),
              const Text(
                'LIVE ON BAID X',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: Color(0xFFA3A3A3)),
              ),
              const Spacer(),
              if (members != null)
                _CountUp(
                  value: all.length,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                  suffix: all.length == 1 ? ' member' : ' members',
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'People and companies '),
                TextSpan(
                  text: 'you can trust.',
                  style: TextStyle(color: Color(0xFF8A8A8A)),
                ),
              ],
            ),
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -.9),
          ),
          const SizedBox(height: 18),
          _Segments(filter: filter, onFilter: onFilter, count: members == null ? null : count),
          const SizedBox(height: 16),
          _VerifiedMeter(share: members == null ? null : verified),
          const SizedBox(height: 16),
          _SearchField(controller: search, onChanged: onSearch, results: results),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    height: 14,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          // a ring that grows and fades, like a signal going out
          Container(
            width: 6 + 8 * _c.value,
            height: 6 + 8 * _c.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .6 * (1 - _c.value))),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ],
      ),
    ),
  );
}

/// A number that counts up from zero when it first appears (still under reduced motion).
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style, this.suffix = ''});
  final int value;
  final TextStyle style;
  final String suffix;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text('${v.round()}$suffix', style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
  );
}

/// Five equal parts; the white highlight slides to the chosen one.
class _Segments extends StatelessWidget {
  const _Segments({required this.filter, required this.onFilter, required this.count});
  final String filter;
  final ValueChanged<String> onFilter;
  final int Function(String)? count;

  @override
  Widget build(BuildContext context) {
    const segs = PeopleConsole.segments;
    final at = segs.indexWhere((s) => s.$1 == filter).clamp(0, segs.length - 1);
    final calm = MediaQuery.disableAnimationsOf(context);
    // keep the app's font: an animated text style replaces the inherited one entirely
    final base = DefaultTextStyle.of(context).style;
    return Container(
      height: 62,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x59000000),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: calm ? Duration.zero : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1 + 2 * at / (segs.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / segs.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x66FFFFFF), blurRadius: 24, spreadRadius: -8, offset: Offset(0, 6))],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < segs.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == at,
                    label: segs[i].$2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onFilter(segs[i].$1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: base.merge(TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.4, color: i == at ? Colors.black : Colors.white)),
                            child: count == null ? const Text('–') : _CountUp(value: count!(segs[i].$1), style: const TextStyle()),
                          ),
                          const SizedBox(height: 1),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: base.merge(TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: i == at ? const Color(0xFF3A3A3A) : const Color(0xFF9A9A9A))),
                            child: FittedBox(fit: BoxFit.scaleDown, child: Text(segs[i].$2, maxLines: 1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerifiedMeter extends StatelessWidget {
  const _VerifiedMeter({required this.share});
  final double? share; // 0..1, null while loading
  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: share ?? 0),
      duration: calm ? Duration.zero : const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 15, color: Color(0xFFBDBDBD)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Verified by a person at BAID X',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Color(0xFFBDBDBD)),
                ),
              ),
              Text(
                share == null ? '–' : '${(v * 100).round()}%',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 5,
            decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(99)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: const [BoxShadow(color: Color(0x80FFFFFF), blurRadius: 10)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged, required this.results});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int? results;
  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    padding: const EdgeInsets.only(left: 14, right: 8),
    decoration: BoxDecoration(
      color: const Color(0x66000000),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x24FFFFFF)),
    ),
    child: Row(
      children: [
        const Icon(Icons.search_rounded, size: 21, color: Color(0xFF9A9A9A)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 15, color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Search name, trade or town',
              hintStyle: TextStyle(fontSize: 15, color: Color(0xFF7A7A7A)),
              filled: false,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (results != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(99)),
            child: Text(
              '$results found',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
      ],
    ),
  );
}
