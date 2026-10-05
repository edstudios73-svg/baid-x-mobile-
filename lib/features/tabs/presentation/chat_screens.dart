import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../../shared/widgets/guest_views.dart';
import '../../../shared/widgets/member_ui.dart';
import '../../account/presentation/account_sheets.dart';
import '../../account_type/domain/account_type.dart';
import '../data/tabs_data.dart';

/// Chats (website js/chat.js): the conversation list from `my_conversations`
/// and a thread from `chat_thread`, sending with `send_chat`.
class ChatsTabScreen extends ConsumerWidget {
  const ChatsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) return const GuestChatsView();
    final me = ref.watch(accountProfileProvider).asData?.value;
    final worker = me?.type == AccountType.worker;
    return DashPage<List<Json>>(
      art: true,
      head: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MemberAppBar(name: me?.displayName ?? '', photo: null),
        const DashHead('Chats'),
      ]),
      data: ref.watch(conversationsProvider),
      onRefresh: () => ref.refresh(conversationsProvider.future),
      builder: (list) => list.isEmpty
          ? [
              DashEmpty(
                icon: Icons.chat_bubble_outline,
                title: 'No conversations yet',
                text: 'Open someone\'s profile in Discover and tap Message to start a chat.',
                action: SmallButton(worker ? 'Browse jobs' : 'Find people', onPressed: () => context.go(worker ? AppRoutes.work : AppRoutes.discover)),
              ),
            ]
          : [
              for (final x in list) _ChatRow(x: x, onTap: () => context.push('${AppRoutes.messages}/${x['id']}')),
            ],
    );
  }
}

/// `.row.chat` on the website's glass Chats page.
class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.x, required this.onTap});
  final Json x;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = num.tryParse('${x['unread'] ?? 0}') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        radius: 22,
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(children: [
          InitialsAvatar(name: '${x['peer_name'] ?? 'Chat'}', photoUrl: x['peer_photo'] as String?, size: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text('${x['peer_name'] ?? 'Chat'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
                if (x['peer_admin'] == true) const OfficialTag(),
              ]),
              const SizedBox(height: 2),
              Text(_preview(x['preview']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFD0D0D0))),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            if (x['last_message_at'] != null) Text(_when(x['last_message_at']), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            if (unread > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

/// Today: "07:05 am"; earlier: "5 Oct" (website hhmmShort).
String _when(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (t == null) return '';
  final n = DateTime.now();
  if (t.year == n.year && t.month == n.month && t.day == n.day) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
  }
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]}';
}

/// Encrypted previews never show ciphertext.
String _preview(Object? p) {
  final s = '${p ?? ''}'.trim();
  if (s.isEmpty) return 'No messages yet';
  if (s.startsWith('{') && s.contains('"ct"')) return 'Encrypted message';
  return s;
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _pending = <String>[];
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    markConversationRead(widget.id);
    // new messages arrive by a light poll until realtime chat comes to the app
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => ref.invalidate(chatThreadProvider(widget.id)));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _pending.add(text);
      _input.clear();
    });
    try {
      await sendChat(widget.id, text);
      ref.invalidate(chatThreadProvider(widget.id));
      ref.invalidate(conversationsProvider);
      await ref.read(chatThreadProvider(widget.id).future);
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(e));
        _input.text = text;
      }
    }
    if (mounted) {
      setState(() {
        _sending = false;
        _pending.remove(text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(chatThreadProvider(widget.id));
    final t = data.asData?.value ?? (data.hasValue ? data.value : null);
    final peer = t?['peer'] is Map ? Map<String, dynamic>.from(t!['peer'] as Map) : <String, dynamic>{};
    final admin = peer['admin'] == true;
    final msgs = [for (final m in (t?['messages'] is List ? t!['messages'] as List : const [])) if (m is Map) Map<String, dynamic>.from(m)];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // head: back, avatar, name, role
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Back', size: 40, onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.messages)),
              const SizedBox(width: 10),
              InitialsAvatar(name: '${peer['name'] ?? 'Chat'}', photoUrl: peer['photo'] as String?, size: 38, radius: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text('${peer['name'] ?? 'Chat'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                    if (admin) const OfficialTag(),
                  ]),
                  Text(admin ? 'BAID X support · messages only' : '${prettyText(peer['role'])} · Not encrypted yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1, color: AppColors.lineGlass),
          Expanded(
            child: t == null
                ? (data.hasError
                    ? DashEmpty(icon: Icons.wifi_off_rounded, title: 'Couldn\'t open this chat', text: 'Check your connection and try again.', action: SmallButton('Try again', onPressed: () => ref.invalidate(chatThreadProvider(widget.id))))
                    : const Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
                : ListView(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    children: [
                      for (final p in _pending.reversed) _Bubble(text: p, mine: true, time: 'Sending…'),
                      for (final m in msgs.reversed) _bubbleFor(m),
                      if (msgs.isEmpty && _pending.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('Say hello', style: TextStyle(color: AppColors.muted)))),
                    ],
                  ),
          ),
          // composer
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineGlass))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Message', counterText: '', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11)),
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(icon: Icons.send_rounded, tooltip: 'Send', size: 44, onTap: _sending ? null : _send),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bubbleFor(Json m) {
    final at = DateTime.tryParse('${m['at'] ?? ''}')?.toLocal();
    final time = at == null ? '' : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final mine = m['mine'] == true;
    if (m['type'] == 'system') return _Bubble(text: '${m['body'] ?? ''}', mine: false, time: '', system: true);
    final encrypted = (num.tryParse('${m['v'] ?? 0}') ?? 0) > 0;
    if (encrypted) return _Bubble(text: 'Can\'t be decrypted on this device', mine: mine, time: time, locked: true);
    final type = '${m['type'] ?? 'text'}';
    final text = type == 'text' ? '${m['body'] ?? ''}' : type == 'image' ? 'Photo' : type == 'audio' ? 'Voice note' : 'File';
    return _Bubble(text: text, mine: mine, time: time);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, required this.time, this.locked = false, this.system = false});
  final String text, time;
  final bool mine, locked, system;

  @override
  Widget build(BuildContext context) {
    if (system) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted))));
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine ? Colors.white : AppColors.card,
            borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16)),
            border: mine ? null : Border.all(color: AppColors.lineGlass),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (locked) ...[Icon(Icons.lock_outline, size: 14, color: mine ? Colors.black54 : AppColors.muted), const SizedBox(width: 4)],
              Flexible(child: Text(text, style: TextStyle(fontSize: 14, height: 1.35, color: mine ? Colors.black : AppColors.textLight, fontStyle: locked ? FontStyle.italic : null))),
            ]),
            if (time.isNotEmpty) ...[const SizedBox(height: 2), Text(time, style: TextStyle(fontSize: 10.5, color: mine ? Colors.black54 : AppColors.muted))],
          ]),
        ),
      ),
    );
  }
}
