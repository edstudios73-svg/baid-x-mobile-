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
import '../../account_type/domain/account_type.dart';
import '../data/directory_repository.dart';
import '../../workspace/presentation/ws_forms.dart' show openInvite;
import 'directory_filters.dart';
import 'member_sheet.dart';

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
  var _f = const DirFilter();
  var _roleDefaultSet = false;

  // What each role most likely wants to find first (website DEFAULT_CHIP).
  static const _defaultChip = {
    AccountType.company: 'professionals',
    AccountType.employer: 'professionals',
    AccountType.projectManager: 'companies',
    AccountType.business: 'companies',
  };

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    final signedIn = user != null;
    final myType = ref.watch(accountProfileProvider).asData?.value?.type;
    if (!_roleDefaultSet && myType != null) {
      _roleDefaultSet = true;
      _filter = _defaultChip[myType] ?? 'all';
    }
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
                      if (signedIn) ...[
                        GlassIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onTap: () => context.push(AppRoutes.notifications)),
                        const SizedBox(width: 8),
                        Stack(clipBehavior: Clip.none, children: [
                          GlassIconButton(
                            icon: Icons.filter_alt_outlined,
                            tooltip: 'Filters',
                            onTap: () async {
                              final f = await Navigator.of(context).push<DirFilter>(MaterialPageRoute(builder: (_) => DirectoryFiltersScreen(initial: _f)));
                              if (f == null || !mounted) return;
                              setState(() {
                                _f = f;
                                if (f.type != 'all') _filter = f.type;
                              });
                            },
                          ),
                          if (_f.active) Positioned(right: 6, top: 6, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                        ]),
                      ]
                      else
                        PillButton(label: 'Get verified', expand: false, height: 40, onPressed: () => context.push('${AppRoutes.signUp}?group=pro')),
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
                        return _Chip(label: label, on: _filter == k, onTap: () => setState(() {
                          _filter = k;
                          _f = DirFilter(region: _f.region);
                        }));
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!signedIn) const _GuestHero(),
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
                  final list = applyDirFilter(all, _filter, _f, q);
                  if (list.isEmpty) {
                    return [const SliverFillRemaining(hasScrollBody: false, child: _State(title: 'No results', body: 'Try another search, category or location.'))];
                  }
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) => MemberCard(member: list[i], signedIn: signedIn, myId: user?.id),
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
      height: 46,
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

/// A member card (website `.card.c3`): identity row with the avatar beside the
/// name, a short description, one facts line and a trust line.
class MemberCard extends ConsumerWidget {
  const MemberCard({required this.member, required this.signedIn, this.myId, super.key});
  final DirectoryMember member;
  final bool signedIn;
  final String? myId;

  static String _fact(String v) => v.replaceAllMapped(RegExp(r'^(\d+) (\d+)$'), (m) => '${m[1]}–${m[2]}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = member;
    // a company invites workers and PMs to a project from their card, a PM invites workers (website cardHTML)
    final mine = ref.watch(accountProfileProvider).asData?.value?.type;
    final canInvite = signedIn && ((mine == AccountType.company && (m.kind == 'worker' || m.kind == 'pm')) || (mine == AccountType.projectManager && m.kind == 'worker'));
    void primary() => canInvite ? openInvite(context, ref, kind: m.kind, personId: m.id) : _open(context);
    const muted = Color(0xFFB9B9B9);
    final facts = <Widget>[
      Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on_outlined, size: 14, color: muted), const SizedBox(width: 4), Text(m.place, style: const TextStyle(fontSize: 12.5, color: muted))]),
      for (final (v, l) in m.stats)
        Text.rich(TextSpan(children: [
          TextSpan(text: _fact(v), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          TextSpan(text: ' ${l.toLowerCase()}'),
        ]), style: const TextStyle(fontSize: 12.5, color: muted)),
    ];
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lineGlass)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            InitialsAvatar(name: m.name, photoUrl: m.image, size: 52, radius: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.label.copyWith(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -.1)),
                const SizedBox(height: 2),
                Text(m.tag, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: muted)),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.lineGlass)),
              child: Text(m.kindLabel.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: Color(0xFFD6D6D6))),
            ),
          ]),
          const SizedBox(height: 12),
          Text(m.desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(fontSize: 13, color: const Color(0xFFA3A8B1), height: 1.45)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0) Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFF666666), shape: BoxShape.circle)),
              facts[i],
            ],
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(12)),
            child: m.badge == null
                ? const Text('Verification in progress', style: TextStyle(fontSize: 12.5, color: Color(0xFF9A9A9A)))
                : Row(children: [
                    VerifiedBadge(m.badge, size: 16),
                    const SizedBox(width: 6),
                    Text('${VerifiedBadge.labels[m.badge] ?? 'Verified'} by BAID X', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFE8E8E8))),
                  ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _CardBtn(label: canInvite ? 'Invite to project' : 'View profile', light: true, onTap: primary)),
            if (signedIn && m.id != myId) ...[
              const SizedBox(width: 8),
              Expanded(child: _CardBtn(label: 'Message', onTap: () => startMemberChat(context, m))),
            ],
          ]),
        ],
      ),
    );
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: primary, child: card);
  }

  // the whole card opens the profile sheet, like the website
  void _open(BuildContext context) => showMemberSheet(context, member: member, signedIn: signedIn, isMe: member.id == myId);
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

/// Signed-out Home intro (website `.g-hero`): what BAID X does differently.
class _GuestHero extends StatelessWidget {
  const _GuestHero();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lineGlass)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Hire verified people. Pay only when the work is done.', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -.2)),
          const SizedBox(height: 12),
          for (final (t, d) in const [
            ('Ghana Card checked', 'Every profile is reviewed by BAID X before it shows a badge.'),
            ('Money held safely', 'Your payment waits in escrow until you approve the work.'),
            ('Run the whole job', 'Projects, crews, materials and payments in one place.'),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.white, width: 2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(d, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ]),
            ),
          const SizedBox(height: 4),
          PillButton(label: 'Get started', height: 46, onPressed: () => context.push(AppRoutes.signUp)),
        ]),
      );
}
