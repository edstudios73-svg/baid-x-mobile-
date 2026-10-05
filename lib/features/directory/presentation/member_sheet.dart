import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../account/presentation/account_sheets.dart';
import '../data/directory_repository.dart';

/// The website's member sheet (js/features.js openCard): cover, avatar, name,
/// Verified pill, trade and place, description, stats, then Message for
/// members or "Sign in to message" for guests.
Future<void> showMemberSheet(BuildContext context, {required DirectoryMember member, required bool signedIn, bool isMe = false}) {
  final m = member;
  return showGlassSheet(
    context,
    title: m.name,
    child: Flexible(
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (m.cover != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(aspectRatio: 16 / 7, child: Image.network(m.cover!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.tile))),
            ),
            const SizedBox(height: 12),
          ],
          Row(children: [
            InitialsAvatar(name: m.name, photoUrl: m.image, size: 64, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                  Text(m.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  if (m.badge != null) const Pill('Verified', tone: PillTone.ok),
                ]),
                const SizedBox(height: 3),
                Text('${m.tag} · ${m.place}', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text(m.desc, style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFFD4D4D4))),
          const SizedBox(height: 14),
          Row(children: [
            for (var i = 0; i < m.stats.length; i++) ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lineGlass)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.stats[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(m.stats[i].$2, style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ]),
                ),
              ),
              if (i < m.stats.length - 1) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 16),
          if (isMe)
            Text('This is you.', style: TextStyle(fontSize: 12.5, color: AppColors.muted))
          else if (signedIn)
            Builder(builder: (c) => PillButton(label: 'Message', onPressed: () => startMemberChat(c, m)))
          else
            Builder(builder: (c) => PillButton(label: 'Sign in to message', onPressed: () {
                  Navigator.of(c).pop();
                  context.push(AppRoutes.signIn);
                })),
        ]),
      ),
    ),
  );
}

/// Starts (or reopens) a direct conversation the same way the website does
/// (rpc start_conversation) and opens it.
Future<void> startMemberChat(BuildContext context, DirectoryMember m) async {
  final client = SupabaseConfig.client;
  if (client == null) return;
  try {
    final cid = await client.rpc('start_conversation', params: {'p_other': m.id, 'p_subject': null});
    if (!context.mounted) return;
    final router = GoRouter.of(context);
    if (Navigator.of(context).canPop()) Navigator.of(context).maybePop();
    router.push('${AppRoutes.messages}/$cid');
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
}

/// Opens (or starts) a direct chat with a member by id, e.g. "Message supplier".
Future<void> startConversationWith(BuildContext context, String userId) async {
  final client = SupabaseConfig.client;
  if (client == null || userId.isEmpty) return;
  try {
    final cid = await client.rpc('start_conversation', params: {'p_other': userId, 'p_subject': null});
    if (context.mounted) context.push('${AppRoutes.messages}/$cid');
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
}
