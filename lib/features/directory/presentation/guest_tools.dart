import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_handler.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../data/directory_repository.dart';
import 'guest_home_hero.dart';
import 'member_sheet.dart';

/// Visitor tabs that no member dashboard has (website landing #lp-check and #lp-rates).
/// Check: look someone up before paying them. Rates: what work costs per day, by trade.

/// The page frame both tools share: the landing's drawing behind, an eyebrow, a
/// two-tone heading and a short line, then the tool.
class _ToolPage extends StatelessWidget {
  const _ToolPage({required this.eyebrow, required this.lead, required this.tail, required this.intro, required this.children});
  final String eyebrow;
  final String lead;
  final String tail;
  final String intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(fit: StackFit.expand, children: [
          const BlueprintBackdrop(),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 130),
              children: [
                Text(eyebrow.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: Color(0xFFA3A3A3))),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(children: [TextSpan(text: lead), TextSpan(text: tail, style: const TextStyle(color: Color(0xFF8A8A8A)))]),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -.9),
                ),
                const SizedBox(height: 10),
                Text(intro, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF9A9A9A))),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ]),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x33FFFFFF))),
        child: Row(children: [
          const Icon(Icons.person_search_outlined, size: 22, color: Color(0xFF9A9A9A)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 16, color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF7A7A7A)),
                filled: false,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ]),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassBox(
          padding: const EdgeInsets.all(14),
          radius: 18,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: Colors.black)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFA3A3A3))),
              ]),
            ),
          ]),
        ),
      );
}

/// Check a badge: type a name, see who BAID X has verified, before any money moves.
class CheckScreen extends ConsumerStatefulWidget {
  const CheckScreen({super.key});
  @override
  ConsumerState<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends ConsumerState<CheckScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(directoryProvider);
    final q = _q.text.trim();
    return _ToolPage(
      eyebrow: 'Check a badge',
      lead: 'Check before ',
      tail: 'you pay anyone.',
      intro: 'Someone says they are on BAID X? Type their name to see if a person at BAID X has checked them.',
      children: [
        _Field(controller: _q, hint: 'Their full name', onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        if (q.length < 2) ...const [
          _Note(icon: Icons.verified_outlined, title: 'A badge is earned, not bought', body: 'Badges come from checks a person at BAID X has done: profile, Ghana Card, trade and background.'),
          _Note(icon: Icons.lock_outline, title: 'Pay through escrow', body: 'On BAID X the money waits safely until you approve the work. Never send cash upfront to someone you have not checked.'),
          _Note(icon: Icons.badge_outlined, title: 'Ask for their BAID X name', body: 'The name on their profile is the one to search here, the same as on their Ghana Card.'),
        ] else
          ...data.when(
            loading: () => const [Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))],
            error: (e, _) => [_Note(icon: Icons.wifi_off_rounded, title: 'Couldn\'t check right now', body: ErrorHandler.toAppException(e).message)],
            data: (all) {
              final hits = checkMembers(all, q);
              if (hits.isEmpty) {
                return const [
                  _Note(
                    icon: Icons.report_gmailerrorred_outlined,
                    title: 'No one by that name is on BAID X',
                    body: 'Check the spelling. If they still don\'t appear, they are not on BAID X: be careful before paying them, and ask them to join and get verified.',
                  ),
                ];
              }
              return [for (final m in hits) _CheckRow(member: m)];
            },
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.member});
  final DirectoryMember member;
  @override
  Widget build(BuildContext context) {
    final m = member;
    final ok = m.badge != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassBox(
        padding: const EdgeInsets.all(14),
        radius: 20,
        onTap: () => showMemberSheet(context, member: m, signedIn: false),
        child: Row(children: [
          InitialsAvatar(name: m.name, photoUrl: m.image, size: 48, radius: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${m.kindLabel} · ${m.place}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF9A9A9A))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: ok ? const Color(0x14FFFFFF) : const Color(0x1AF87171),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: ok ? const Color(0x33FFFFFF) : const Color(0x4DF87171)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (ok) VerifiedBadge(m.badge, size: 14) else const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFF87171)),
                  const SizedBox(width: 5),
                  Text(ok ? '${VerifiedBadge.labels[m.badge] ?? 'Verified'} by BAID X' : 'Not verified yet', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ok ? Colors.white : const Color(0xFFF87171))),
                ]),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF7A7A7A)),
        ]),
      ),
    );
  }
}

/// Rates: the middle daily rate and the range for each trade, from what
/// professionals set on BAID X, for all of Ghana or one region.
class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});
  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  String? _region;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(directoryProvider);
    return _ToolPage(
      eyebrow: 'Price guide',
      lead: 'What work costs ',
      tail: 'in Ghana.',
      intro: 'Daily rates professionals set on BAID X. Use them to budget a job and to spot a quote that is far off.',
      children: data.when(
        loading: () => const [Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))],
        error: (e, _) => [_Note(icon: Icons.wifi_off_rounded, title: 'Couldn\'t load rates', body: ErrorHandler.toAppException(e).message)],
        data: (all) {
          final regions = rateRegions(all);
          final rates = tradeRates(all, region: _region);
          final top = rates.fold<double>(0, (a, r) => r.high > a ? r.high : a);
          return [
            if (regions.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final r in [null, ...regions])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _RegionChip(label: r ?? 'All Ghana', on: _region == r, onTap: () => setState(() => _region = r)),
                    ),
                ]),
              ),
            const SizedBox(height: 16),
            if (rates.isEmpty)
              const _Note(icon: Icons.payments_outlined, title: 'No rates here yet', body: 'Rates appear as professionals add their daily rate. Try All Ghana.')
            else
              for (final r in rates) _RateRow(rate: r, top: top),
            const SizedBox(height: 6),
            const Text('Middle rate shown large; the bar runs from the lowest to the highest rate set. Final prices depend on the job.', style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF7A7A7A))),
          ];
        },
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? Colors.white : const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: on ? Colors.white : const Color(0x29FFFFFF)),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.black : const Color(0xFFD6D6D6))),
        ),
      );
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rate, required this.top});
  final TradeRate rate;
  final double top; // the highest rate on screen, so every bar shares one scale
  static String _c(double v) => 'GH₵${v.round()}';

  @override
  Widget build(BuildContext context) {
    final r = rate;
    final calm = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassBox(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        radius: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(r.trade, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            Text(_c(r.median), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.5, fontFeatures: [FontFeature.tabularFigures()])),
            const Text(' / day', style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A))),
          ]),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: calm ? Duration.zero : const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              double x(double v) => top <= 0 ? 0 : (v / top) * w * t;
              return SizedBox(
                height: 14,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(left: 0, right: 0, top: 5, child: Container(height: 4, decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(99)))),
                  Positioned(
                    left: x(r.low),
                    width: (x(r.high) - x(r.low)).clamp(4.0, w),
                    top: 5,
                    child: Container(height: 4, decoration: BoxDecoration(color: const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(99))),
                  ),
                  Positioned(
                    left: (x(r.median) - 7).clamp(0.0, w - 14),
                    top: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x80FFFFFF), blurRadius: 10)], border: Border.all(color: Colors.black, width: 2)),
                    ),
                  ),
                ]),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text(_c(r.low), style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8A8A))),
            const Spacer(),
            Text(_c(r.high), style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8A8A))),
          ]),
        ]),
      ),
    );
  }
}
