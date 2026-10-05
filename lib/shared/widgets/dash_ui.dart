import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'baid_ui.dart';

/// Building blocks of the website's dashboard tabs (js/dash.js `ui`):
/// page head, segments, rows, status pills, empty states and the skeleton
/// shown for the first load only.

/// `.d-head`: page title with an optional button on the right.
class DashHead extends StatelessWidget {
  const DashHead(this.title, {this.action, super.key});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.3))),
        ?action,
      ]),
    );
  }
}

/// `.segs`: a row of pill tabs.
class DashSegs extends StatelessWidget {
  const DashSegs({required this.items, required this.active, required this.onTap, super.key});
  final List<(String, String)> items; // (key, label)
  final String active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (k, l) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => onTap(k),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: k == active ? Colors.white : const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: k == active ? Colors.white : AppColors.lineGlass),
                  ),
                  child: Text(l, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: k == active ? Colors.black : const Color(0xFFCFD2D8))),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// `.pill` with the website's status colours.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {this.label, super.key});
  final String? status;
  final String? label;

  static String kindOf(String? s) =>
      const {'open': 'ok', 'active': 'ok', 'accepted': 'ok', 'completed': 'ok', 'done': 'ok', 'shortlisted': 'warn', 'submitted': 'warn', 'pending': 'warn', 'planning': 'warn', 'draft': 'warn'}[(s ?? '').toLowerCase()] ?? '';

  @override
  Widget build(BuildContext context) {
    final kind = kindOf(status);
    final (bg, fg) = switch (kind) {
      'ok' => (const Color(0x263DDC84), AppColors.green),
      'warn' => (const Color(0x26E8A93A), const Color(0xFFE8A93A)),
      _ => (const Color(0xFF2D2D2D), const Color(0xFFCFCFCF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label ?? prettyText(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

String prettyText(Object? v) => (v ?? '').toString().replaceAll(RegExp(r'[_-]'), ' ').trim().replaceAllMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());

/// `.row`: round icon (or avatar), title, small line, optional trailing widget.
class DashRow extends StatelessWidget {
  const DashRow({required this.title, this.sub, this.icon, this.leading, this.trailing, this.below, this.onTap, super.key});
  final String title;
  final String? sub;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              leading ??
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon ?? Icons.circle_outlined, size: 17, color: Colors.black),
                  ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                  ?below,
                ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ]),
          ),
        ),
      ),
    );
  }
}

/// `.d-empty`: icon, title, one line and an optional button.
class DashEmpty extends StatelessWidget {
  const DashEmpty({required this.icon, required this.title, required this.text, this.action, super.key});
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: Column(children: [
        Icon(icon, size: 44, color: const Color(0xFF6D6D6D)),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.4)),
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    );
  }
}

/// Small light button (`.btn-light.sm`).
class SmallButton extends StatelessWidget {
  const SmallButton(this.label, {required this.onPressed, this.light = true, super.key});
  final String label;
  final VoidCallback? onPressed;
  final bool light;

  @override
  Widget build(BuildContext context) => PillButton(label: label, expand: false, height: 34, light: light, onPressed: onPressed);
}

/// `.bar`: thin progress bar.
class DashBar extends StatelessWidget {
  const DashBar(this.pct, {super.key});
  final num? pct;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(value: ((pct ?? 0) / 100).clamp(0, 1).toDouble(), minHeight: 4, color: Colors.white, backgroundColor: const Color(0xFF222222)),
        ),
      );
}

/// A tab page: title, optional segments, then the async body.
///
/// The data providers keep their last result, so coming back to a tab shows it
/// at once and refreshes quietly; only the very first visit shows skeletons.
class DashPage<T> extends ConsumerWidget {
  const DashPage({required this.head, required this.data, required this.builder, required this.onRefresh, this.top = const [], this.art = false, super.key});
  final Widget head;
  final AsyncValue<T> data;
  final List<Widget> Function(T value) builder;
  final Future<void> Function() onRefresh;
  final List<Widget> top;
  final bool art; // the ring art behind the page (website glass pages: Chats)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = data.asData?.value ?? (data.hasValue ? data.value : null);
    final List<Widget> body;
    if (value != null) {
      body = builder(value as T);
    } else if (data.hasError) {
      body = [
        DashEmpty(
          icon: Icons.wifi_off_rounded,
          title: 'Couldn\'t load this',
          text: 'Check your connection and try again.',
          action: SmallButton('Try again', onPressed: onRefresh),
        ),
      ];
    } else {
      body = const [_Skeleton(90), _Skeleton(72), _Skeleton(72), _Skeleton(72)];
    }
    return Scaffold(
      body: AppBackdrop(
        art: art,
        child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: Colors.white,
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            children: [head, ...top, ...body],
          ),
        ),
      ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton(this.height);
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lineGlass)),
      );
}

/// `.code`: a project code in a small mono tag.
class CodeTag extends StatelessWidget {
  const CodeTag(this.code, {super.key});
  final String code;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(6)),
        child: Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, letterSpacing: .4, color: Color(0xFFCFCFCF))),
      );
}

/// `.offi`: the gold "Official" tag on BAID X Admin.
class OfficialTag extends StatelessWidget {
  const OfficialTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF1D58A), Color(0xFFC99A2E)]), borderRadius: BorderRadius.circular(99)),
        child: const Text('OFFICIAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, color: Color(0xFF14110A))),
      );
}
