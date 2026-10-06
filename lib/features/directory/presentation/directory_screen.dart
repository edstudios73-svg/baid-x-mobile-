import 'dart:ui' show ImageFilter, FontFeature;

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
import 'guest_home_hero.dart';
import 'people_console.dart';
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
  // drives the backdrop's parallax
  final _scrollY = ValueNotifier<double>(0);

  // What each role most likely wants to find first (website DEFAULT_CHIP).
  static const _defaultChip = {AccountType.company: 'professionals', AccountType.employer: 'professionals', AccountType.projectManager: 'companies', AccountType.business: 'companies'};

  @override
  void dispose() {
    _q.dispose();
    _scrollY.dispose();
    super.dispose();
  }

  // signed in: everyone (Discover); visitors: the verified showcase only
  List<DirectoryMember> _visible(List<DirectoryMember> all, bool signedIn, String q) {
    final list = applyDirFilter(all, _filter, _f, q);
    return signedIn ? list : guestShowcase(list);
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          BlueprintBackdrop(scroll: _scrollY),
          SafeArea(
            bottom: false,
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) {
                if (n.depth == 0 && n.metrics.axis == Axis.vertical) _scrollY.value = n.metrics.pixels;
                return false;
              },
              child: RefreshIndicator(
                color: Colors.black,
                backgroundColor: Colors.white,
                onRefresh: () => ref.refresh(directoryProvider.future),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverList.list(
                        children: [
                          Row(
                            children: [
                              const BrandLogo(width: 104),
                              const Spacer(),
                              if (signedIn) ...[
                                GlassIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onTap: () => context.push(AppRoutes.notifications)),
                                const SizedBox(width: 8),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
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
                                    if (_f.active)
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                        ),
                                      ),
                                  ],
                                ),
                              ] else
                                PillButton(label: 'Get verified', expand: false, height: 40, onPressed: () => context.push('${AppRoutes.signUp}?group=pro')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // visitors: the website landing's trust stack folds into one card as they scroll
                    if (!signedIn) const GuestTrustStackSliver(),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      sliver: SliverList.list(
                        children: [
                          SizedBox(height: signedIn ? 18 : 56),
                          PeopleConsole(
                            members: data.asData?.value,
                            filter: _filter,
                            onFilter: (k) => setState(() {
                              _filter = k;
                              _f = DirFilter(region: _f.region);
                            }),
                            search: _q,
                            onSearch: (_) => setState(() {}),
                            results: q.isEmpty ? null : data.asData?.value.let((all) => _visible(all, signedIn, q).length),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
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
                        final list = _visible(all, signedIn, q);
                        if (!signedIn) {
                          // visitors see a short showcase, then the way in to everyone else
                          return [
                            if (list.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                                sliver: SliverList.separated(
                                  itemCount: list.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                                  itemBuilder: (context, i) => MemberCard(member: list[i], signedIn: false),
                                ),
                              ),
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(16, list.isEmpty ? 0 : 22, 16, 120),
                              sliver: SliverToBoxAdapter(child: SignInForMore(shown: list, all: all)),
                            ),
                          ];
                        }
                        if (list.isEmpty) {
                          return [
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _State(title: 'No results', body: 'Try another search, category or location.'),
                            ),
                          ];
                        }
                        return [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                            sliver: SliverList.separated(
                              itemCount: list.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (context, i) => MemberCard(member: list[i], signedIn: signedIn, myId: user.id),
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A member card (website `.card.c3`): liquid glass over the page backdrop, the
/// member's cover photo across the top with their photo or logo on its edge, then
/// name and badge, what they do, three fact tiles, the trust line and the actions.
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
    const r = BorderRadius.all(Radius.circular(26));
    final tiles = <(String, String)>[(m.place.split(',').first, 'Based in'), for (final (v, l) in m.stats) (_fact(v), l)];
    final card = DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: r,
        boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 50, spreadRadius: -14, offset: Offset(0, 24))],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1AFFFFFF), Color(0x05FFFFFF), Color(0x12FFFFFF)], stops: [0, .55, 1]),
              border: Border.all(color: const Color(0x38FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 158,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 124,
                        child: _Cover(url: m.cover, name: m.name),
                      ),
                      Positioned(top: 12, right: 12, child: _GlassTag(m.kindLabel.toUpperCase())),
                      Positioned(
                        left: 16,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: const Color(0xFF0B0B0B),
                            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 20, offset: Offset(0, 8))],
                          ),
                          child: InitialsAvatar(name: m.name, photoUrl: m.image, size: 66, radius: 19),
                        ),
                      ),
                      if (m.joinedLabel != null)
                        Positioned(
                          right: 16,
                          bottom: 6,
                          child: Text(m.joinedLabel!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A9A9A))),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label.copyWith(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.3),
                            ),
                          ),
                          if (m.badge != null) ...[const SizedBox(width: 6), VerifiedBadge(m.badge, size: 18)],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: muted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        m.desc,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 13.5, color: const Color(0xFFC4C4C4), height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (var i = 0; i < tiles.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _FactTile(value: tiles[i].$1, label: tiles[i].$2),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0x0DFFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x1AFFFFFF)),
                        ),
                        child: m.badge == null
                            ? const Text('Verification in progress', style: TextStyle(fontSize: 12.5, color: Color(0xFF9A9A9A)))
                            : Row(
                                children: [
                                  VerifiedBadge(m.badge, size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '${VerifiedBadge.labels[m.badge] ?? 'Verified'} by BAID X',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFE8E8E8)),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CardBtn(label: canInvite ? 'Invite to project' : 'View profile', light: true, onTap: primary),
                          ),
                          if (signedIn && m.id != myId) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CardBtn(label: 'Message', onTap: () => startMemberChat(context, m)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: primary, child: card);
  }

  // the whole card opens the profile sheet, like the website
  void _open(BuildContext context) => showMemberSheet(context, member: member, signedIn: signedIn, isMe: member.id == myId);
}

/// The member's cover photo, fading into the glass below. Without one, a dark
/// panel carrying their initials large and faint, so no card looks empty.
class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x59FFFFFF), Color(0x0DFFFFFF)]),
      ),
      child: Align(
        alignment: const Alignment(.85, .2),
        child: Text(
          initials,
          style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w800, letterSpacing: -4, color: Color(0x14FFFFFF)),
        ),
      ),
    );
    // the photo fades out at the bottom so it melts into the glass instead of ending on a line
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Color(0x00FFFFFF)], stops: [0, .5, 1]).createShader(rect),
      child: url != null && url!.isNotEmpty ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback) : fallback,
    );
  }
}

class _GlassTag extends StatelessWidget {
  const _GlassTag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x59000000),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0x40FFFFFF)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .6, color: Colors.white),
        ),
      ),
    ),
  );
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0x0FFFFFFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x1FFFFFFF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -.2, fontFeatures: [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
        ),
      ],
    ),
  );
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
          decoration: BoxDecoration(
            color: light ? Colors.white : const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: light ? null : Border.all(color: AppColors.lineGlass),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: light ? Colors.black : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0x0DFFFFFF),
        border: Border.all(color: AppColors.lineGlass),
      ),
    );
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
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.section.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.muted, fontSize: 14),
          ),
          if (onRetry != null) ...[const SizedBox(height: 16), PillButton(label: 'Try again', expand: false, onPressed: onRetry)],
        ],
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// The end of a visitor's Home: faces of members still to see and the way in.
class SignInForMore extends StatelessWidget {
  const SignInForMore({required this.shown, required this.all, super.key});
  final List<DirectoryMember> shown;
  final List<DirectoryMember> all;

  @override
  Widget build(BuildContext context) {
    final ids = {for (final m in shown) m.id};
    final rest = all.where((m) => !ids.contains(m.id)).toList();
    final faces = rest.where((m) => (m.image ?? '').isNotEmpty).take(5).toList();
    final extra = rest.length - faces.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // a fading rule, so the list visibly ends here and something more begins
      Container(
        height: 1,
        margin: const EdgeInsets.only(bottom: 26),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x00FFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)])),
      ),
      if (faces.isNotEmpty || extra > 0)
        Center(
          child: SizedBox(
            height: 46,
            width: 46.0 + 32 * (faces.length + (extra > 0 ? 1 : 0) - 1).clamp(0, 9),
            child: Stack(children: [
              for (var i = 0; i < faces.length; i++)
                Positioned(
                  left: 32.0 * i,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Color(0xFF0B0B0B), shape: BoxShape.circle),
                    child: InitialsAvatar(name: faces[i].name, photoUrl: faces[i].image, size: 42),
                  ),
                ),
              if (extra > 0)
                Positioned(
                  left: 32.0 * faces.length,
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0B0B0B), width: 2)),
                    child: Text('+$extra', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                ),
            ]),
          ),
        ),
      const SizedBox(height: 16),
      Text(
        rest.isEmpty ? 'Everyone on BAID X, in one place' : '${rest.length} more ${rest.length == 1 ? 'member is' : 'members are'} on BAID X',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -.6),
      ),
      const SizedBox(height: 8),
      const Text(
        'Sign in to see every professional, company, project manager and supplier, message them and hire through escrow.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF9A9A9A)),
      ),
      const SizedBox(height: 18),
      PillButton(label: 'Sign in to view more', height: 52, onPressed: () => context.push(AppRoutes.signIn)),
      const SizedBox(height: 10),
      PillButton(label: 'Create a free account', light: false, height: 50, onPressed: () => context.push(AppRoutes.signUp)),
    ]);
  }
}
