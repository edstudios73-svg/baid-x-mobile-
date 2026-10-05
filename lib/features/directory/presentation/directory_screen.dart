import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../data/directory_repository.dart';

/// The website's member directory (index.html #screen-directory): Home for
/// visitors, Discover for members. Logo bar, search, type chips, member cards.
class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({super.key});

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  final _q = TextEditingController();
  var _filter = 'all';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authStateProvider).asData?.value != null;
    final data = ref.watch(directoryProvider);
    final q = _q.text.trim().toLowerCase();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: Colors.white,
          onRefresh: () => ref.refresh(directoryProvider.future),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverList.list(children: [
                  Row(
                    children: [
                      const BrandLogo(width: 104),
                      const Spacer(),
                      if (signedIn)
                        GlassIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onTap: () => context.push(AppRoutes.notifications))
                      else
                        PillButton(label: 'Join as a Pro', expand: false, height: 42, onPressed: () => context.push(AppRoutes.signUp)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Search(controller: _q, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: directoryChips.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final (k, label) = directoryChips[i];
                        return _Chip(label: label, on: _filter == k, onTap: () => setState(() => _filter = k));
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
              ...data.when(
                loading: () => [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(itemCount: 3, separatorBuilder: (_, _) => const SizedBox(height: 14), itemBuilder: (_, _) => const _Skeleton()),
                  ),
                ],
                error: (e, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _State(title: 'Couldn\'t load the directory', body: ErrorHandler.toAppException(e).message, onRetry: () => ref.invalidate(directoryProvider)),
                  ),
                ],
                data: (all) {
                  final list = all
                      .where((m) => _filter == 'all' || m.group == _filter)
                      .where((m) => q.isEmpty || '${m.name} ${m.tag} ${m.place} ${m.desc}'.toLowerCase().contains(q))
                      .toList();
                  if (list.isEmpty) {
                    return [const SliverFillRemaining(hasScrollBody: false, child: _State(title: 'No results', body: 'Try another search, category or location.'))];
                  }
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) => MemberCard(member: list[i], signedIn: signedIn),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lineGlass)),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, size: 22, color: Color(0xFF9A9A9A)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
              decoration: const InputDecoration(hintText: 'Search', filled: false, isCollapsed: true, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Colors.white : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? Colors.white : AppColors.lineGlass),
          boxShadow: on ? const [BoxShadow(color: Color(0x8CFFFFFF), blurRadius: 30, spreadRadius: -10, offset: Offset(0, 10))] : null,
        ),
        child: Text(label, style: AppTextStyles.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? Colors.black : const Color(0xFFCFD2D8))),
      ),
    );
  }
}

/// A member card (`.card.c2`): cover band with the type tag, overlapping avatar,
/// name with the verification seal, trade, place, short description, two stats.
class MemberCard extends StatelessWidget {
  const MemberCard({required this.member, required this.signedIn, super.key});
  final DirectoryMember member;
  final bool signedIn;

  static const _cover = {
    'worker': [Color(0xFF2B2B2B), Color(0xFF0C0C0C), Color(0xFF1C1C1C)],
    'company': [Color(0xFF262626), Color(0xFF0A0A0A), Color(0xFF161616)],
    'pm': [Color(0xFF1F1F1F), Color(0xFF0B0B0B), Color(0xFF2A2A2A)],
    'business': [Color(0xFF2A2A2A), Color(0xFF090909), Color(0xFF181818)],
  };

  @override
  Widget build(BuildContext context) {
    final m = member;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF131313), Color(0xFF0F0F0F)]),
        border: Border.all(color: AppColors.lineGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 104,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (m.cover != null)
                  Image.network(m.cover!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                else
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _cover[m.kind] ?? _cover['worker']!, stops: const [0, .6, 1])),
                    child: CustomPaint(painter: _Stripes()),
                  ),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment(0, -.2), end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xD908090B)]))),
                Positioned(
                  left: 14,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                    child: Text(m.kindLabel.toUpperCase(), style: const TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .7, color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF0E0E0E), width: 3), boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 22, offset: Offset(0, 8))]),
                    child: InitialsAvatar(name: m.name, photoUrl: m.image, size: 58, radius: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.label.copyWith(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -.1))),
                            const SizedBox(width: 6),
                            VerifiedBadge(m.badge),
                          ]),
                          const SizedBox(height: 1),
                          Text(m.tag.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, letterSpacing: .7, color: Color(0xBFFFFFFF))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFFAEB3BC)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(m.place, style: AppTextStyles.caption.copyWith(fontSize: 12.5, color: const Color(0xFFAEB3BC)))),
                  ]),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 38),
                    child: Text(m.desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(fontSize: 13, color: const Color(0xFFA3A8B1), height: 1.45)),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (var i = 0; i < m.stats.length; i++) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lineGlass)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.stats[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.label.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                            Text(m.stats[i].$2, style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted)),
                          ]),
                        ),
                      ),
                      if (i < m.stats.length - 1) const SizedBox(width: 8),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _CardBtn(label: 'View profile', light: true, onTap: () => _open(context))),
                    if (signedIn) ...[
                      const SizedBox(width: 8),
                      Expanded(child: _CardBtn(label: 'Message', onTap: () => context.push(AppRoutes.messages))),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    if (!signedIn) {
      context.push(AppRoutes.signIn);
      return;
    }
    if (member.kind == 'worker') context.push('/workers/${member.id}');
  }
}

class _CardBtn extends StatelessWidget {
  const _CardBtn({required this.label, required this.onTap, this.light = false});
  final String label;
  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 40,
          decoration: BoxDecoration(color: light ? Colors.white : const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(14), border: light ? null : Border.all(color: AppColors.lineGlass)),
          child: Center(child: Text(label, style: AppTextStyles.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: light ? Colors.black : Colors.white))),
        ),
      ),
    );
  }
}

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Container(height: 280, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: const Color(0x0DFFFFFF), border: Border.all(color: AppColors.lineGlass)));
  }
}

class _State extends StatelessWidget {
  const _State({required this.title, required this.body, this.onRetry});
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.section.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.body.copyWith(color: AppColors.muted, fontSize: 14)),
          if (onRetry != null) ...[const SizedBox(height: 16), PillButton(label: 'Try again', expand: false, onPressed: onRetry)],
        ],
      ),
    );
  }
}
