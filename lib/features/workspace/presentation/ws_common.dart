import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../account/presentation/account_sheets.dart';
import '../../tabs/data/tabs_data.dart';
import '../data/workspace_data.dart';

/// Pieces shared by the workspace, invitations and approvals screens
/// (website js/projects.js: pill, avatar, dcard, sheets, askNote, confirmBox).

const _ok = ['active', 'approved', 'paid', 'done', 'completed', 'accepted', 'verified', 'released'];
const _warn = ['pending', 'submitted', 'planning', 'in_progress', 'changes_requested', 'info_requested', 'pending_company_approval', 'sent', 'blocked', 'high', 'urgent', 'funded', 'disputed'];
const _bad = ['rejected', 'declined', 'cancelled', 'removed'];
const _labels = {'todo': 'To do', 'in_progress': 'In progress', 'pending_company_approval': 'Needs approval', 'changes_requested': 'Changes requested', 'info_requested': 'Question asked'};

/// `.pill` with the project colours (ok green, warn amber, bad red).
class WsPill extends StatelessWidget {
  const WsPill(this.status, {this.label, super.key});
  final Object? status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final s = '${status ?? ''}'.toLowerCase();
    final (bg, fg) = _ok.contains(s)
        ? (const Color(0x263DDC84), AppColors.green)
        : _warn.contains(s)
            ? (const Color(0x1FFFFFFF), const Color(0xFFF2F2F2))
            : _bad.contains(s)
                ? (const Color(0x26F87171), const Color(0xFFF87171))
                : (const Color(0xFF2D2D2D), const Color(0xFFCFCFCF));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label ?? _labels[s] ?? prettyText(s), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

String initialsOf(Object? name) {
  final parts = '${name ?? '?'}'.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
  return parts.map((w) => w[0]).join().toUpperCase();
}

/// `.av`: photo or initials.
class WsAvatar extends StatelessWidget {
  const WsAvatar(this.name, this.photo, {this.size = 38, this.square = false, super.key});
  final Object? name, photo;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final url = '${photo ?? ''}';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(square ? 12 : size / 2)),
      child: url.isNotEmpty
          ? Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => Text(initialsOf(name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))
          : Text(initialsOf(name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

/// `.dcard`: flat dark card with an optional title row.
class WsCard extends StatelessWidget {
  const WsCard({this.title, this.right, this.kicker, this.warn = false, required this.children, super.key});
  final String? title;
  final String? kicker; // small uppercase project name above the title (Approvals)
  final Widget? right;
  final bool warn;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warn ? const Color(0x0FFFFFFF) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: warn ? const Color(0x40FFFFFF) : AppColors.lineGlass),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (kicker != null && kicker!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(kicker!.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: Color(0xFF8C8C8C))),
            ),
          if (title != null) ...[
            Row(children: [
              Expanded(child: Text(title!, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
              ?right,
            ]),
            const SizedBox(height: 8),
          ],
          ...children,
        ]),
      );
}

/// `.req`: a small caption over a quoted paragraph.
class WsQuote extends StatelessWidget {
  const WsQuote(this.caption, this.text, {super.key});
  final String caption;
  final Object? text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(caption, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          const SizedBox(height: 3),
          Text('${text ?? ''}', style: const TextStyle(fontSize: 13, height: 1.4)),
        ]),
      );
}

class WsCaption extends StatelessWidget {
  const WsCaption(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4)),
      );
}

/// `.btn-row`: wrapping buttons.
class WsButtons extends StatelessWidget {
  const WsButtons(this.buttons, {this.top = false, this.end = false, super.key});
  final List<Widget> buttons;
  final bool top, end; // end: right-aligned like `.es-ap-act`
  @override
  Widget build(BuildContext context) => buttons.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: EdgeInsets.only(top: top ? 0 : 10, bottom: top ? 12 : 0),
          child: SizedBox(width: double.infinity, child: Wrap(alignment: end ? WrapAlignment.end : WrapAlignment.start, spacing: 8, runSpacing: 8, children: buttons)),
        );
}

String fdate(Object? d) {
  final t = DateTime.tryParse('${d ?? ''}');
  if (t == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]} ${t.year}';
}

bool overdue(Object? due, Object? status) {
  final t = DateTime.tryParse('${due ?? ''}');
  return t != null && status != 'done' && DateTime(t.year, t.month, t.day, 23, 59, 59).isBefore(DateTime.now());
}

String placeOf(Json p) => [p['city_town'], p['region']].where((v) => v != null && '$v'.isNotEmpty && v != 'Pending').join(', ');

/// The website's bottom sheet, scrollable so long forms fit small phones.
Future<T?> wsSheet<T>(BuildContext context, String title, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    elevation: 0,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0E0E0E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.3)),
                const SizedBox(height: 14),
                child,
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

/// askNote: returns the typed text, '' when optional and left blank, or null
/// when cancelled.
Future<String?> askNote(BuildContext context, String title, String hint, {bool required = false}) {
  final c = TextEditingController();
  return wsSheet<String>(
    context,
    title,
    StatefulBuilder(
      builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: c, maxLines: 3, maxLength: 500, autofocus: true, decoration: InputDecoration(hintText: hint)),
        const SizedBox(height: 10),
        PillButton(
          label: 'Continue',
          onPressed: () {
            final v = c.text.trim();
            if (required && v.isEmpty) return toast(ctx, 'Write a short note first.');
            Navigator.of(ctx).pop(v);
          },
        ),
        const SizedBox(height: 8),
        PillButton(label: 'Cancel', light: false, onPressed: () => Navigator.of(ctx).pop()),
      ]),
    ),
  );
}

Future<bool> confirmBox(BuildContext context, String title, String text, {String yes = 'Yes, continue'}) async {
  final r = await wsSheet<bool>(
    context,
    title,
    Builder(
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45)),
        const SizedBox(height: 16),
        PillButton(label: yes, onPressed: () => Navigator.of(ctx).pop(true)),
        const SizedBox(height: 8),
        PillButton(label: 'Cancel', light: false, onPressed: () => Navigator.of(ctx).pop(false)),
      ]),
    ),
  );
  return r == true;
}

/// Runs a workspace action, shows the result and refreshes the workspace.
Future<bool> wsAct(BuildContext context, WidgetRef ref, String? pid, Future<dynamic> Function() fn, {String? ok}) async {
  try {
    await fn();
    if (context.mounted && ok != null) toast(context, ok);
    if (pid != null) {
      refreshWorkspace(ref, pid);
    } else {
      ref.invalidate(approvalsProvider);
      ref.invalidate(invitationsProvider);
    }
    return true;
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
    return false;
  }
}

/// A section that loads its own data: skeleton on first load, retry on error.
class WsAsync<T> extends StatelessWidget {
  const WsAsync(this.value, this.builder, {this.onRetry, super.key});
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final v = value.asData?.value ?? (value.hasValue ? value.value : null);
    if (v != null) return builder(v as T);
    if (value.hasError) {
      return DashEmpty(icon: Icons.wifi_off_rounded, title: 'Couldn\'t load this', text: friendlyError(value.error!), action: onRetry == null ? null : SmallButton('Try again', onPressed: onRetry));
    }
    return Column(children: [
      for (final h in const [80.0, 64.0, 64.0])
        Container(height: h, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lineGlass))),
    ]);
  }
}

/// Signed thumbnails for private progress photos.
class WsThumbs extends ConsumerWidget {
  const WsThumbs(this.paths, {super.key});
  final Object? paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = [for (final p in (paths is List ? paths as List : const [])) '$p'];
    if (list.isEmpty) return const SizedBox.shrink();
    final urls = ref.watch(signedPhotosProvider(list.join('|'))).asData?.value ?? const [];
    if (urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final u in urls)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(u, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 72, height: 72)),
          ),
      ]),
    );
  }
}

/// `.inv-card`: a tappable inbox line with a round icon and a count pill;
/// amber when something waits for a decision.
class WsInboxCard extends StatelessWidget {
  const WsInboxCard({required this.icon, required this.title, required this.sub, required this.count, required this.onTap, this.warn = false, super.key});
  final IconData icon;
  final String title, sub;
  final int count;
  final VoidCallback onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: warn ? const Color(0x0FFFFFFF) : AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: warn ? const Color(0x40FFFFFF) : AppColors.lineGlass)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFF1C1C1C), shape: BoxShape.circle), child: Icon(icon, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                if (count > 0) WsPill(warn ? 'pending' : null, label: '$count'),
              ]),
            ),
          ),
        ),
      );
}
