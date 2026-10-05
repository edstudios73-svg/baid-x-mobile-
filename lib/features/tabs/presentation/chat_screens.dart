import 'dart:async';
import 'dart:typed_data';

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
import '../../account/data/profile_data.dart' show sb;
import '../data/secure_chat.dart';
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
              const _BackupBar(),
              for (final x in list) _ChatRow(x: x, onTap: () => context.push('${AppRoutes.messages}/${x['id']}')),
            ],
    );
  }
}

/// Website `.alertbar[data-chat=backup]`: until this device's key is backed
/// up with a password, offer to do it so old messages survive a new phone.
class _BackupBar extends StatefulWidget {
  const _BackupBar();
  @override
  State<_BackupBar> createState() => _BackupBarState();
}

class _BackupBarState extends State<_BackupBar> {
  bool? _done;

  @override
  void initState() {
    super.initState();
    SecureChat.instance.hasBackupFlag().then((v) => mounted ? setState(() => _done = v) : null).catchError((_) => null);
  }

  Future<void> _open() async {
    final pass = TextEditingController();
    String? err;
    var busy = false;
    await showGlassSheet(
      context,
      title: 'Back up secure chat',
      child: StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Choose a backup password. It encrypts your chat key before it is saved, so BAID X can never read it. If you forget this password it cannot be recovered.', style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(hintText: 'Backup password', helperText: 'At least 8 characters.')),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13))),
          const SizedBox(height: 12),
          PillButton(
            label: 'Save backup',
            loading: busy,
            onPressed: busy
                ? null
                : () async {
                    if (pass.text.length < 8) return set(() => err = 'Use at least 8 characters.');
                    set(() {
                      busy = true;
                      err = null;
                    });
                    try {
                      await SecureChat.instance.backup(pass.text);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) {
                        setState(() => _done = true);
                        toast(context, 'Backup saved');
                      }
                    } catch (_) {
                      set(() {
                        busy = false;
                        err = 'Couldn\'t save the backup. Try again.';
                      });
                    }
                  },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_done != false) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        radius: 16,
        padding: const EdgeInsets.all(12),
        onTap: _open,
        child: const Row(children: [
          Icon(Icons.lock_outline_rounded, size: 16),
          SizedBox(width: 10),
          Expanded(child: Text('Back up your secure-chat key to keep old messages on a new phone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      ),
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
  // decrypted payloads by message id (website decryptMsg), and whether the peer has a key
  final _decoded = <String, ChatPayload>{};
  final _decoding = <String>{};
  bool? _peerKey;
  bool _keysAsked = false;

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
      final t = ref.read(chatThreadProvider(widget.id)).asData?.value;
      final peer = t?['peer'] is Map ? Map<String, dynamic>.from(t!['peer'] as Map) : const <String, dynamic>{};
      await sendChat(widget.id, text, peerId: peer['id'] as String?, peerAdmin: peer['admin'] == true);
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

  /// Loads this device's chat key (offering to restore a password backup),
  /// then checks whether the other person can receive encrypted messages.
  Future<void> _setupKeys(String peerId, bool admin) async {
    _keysAsked = true;
    try {
      await SecureChat.instance.ensureKeys(askRestore: (tryPass) => _askRestore(tryPass));
      final has = admin ? false : await SecureChat.instance.peerHasKey(peerId);
      if (mounted) setState(() => _peerKey = has);
    } catch (_) {
      if (mounted) setState(() => _peerKey = false);
    }
  }

  Future<String?> _askRestore(Future<bool> Function(String) tryPass) async {
    if (!mounted) return null;
    final pass = TextEditingController();
    String? err;
    var busy = false;
    await showGlassSheet(
      context,
      title: 'Restore secure chat',
      child: StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('This account has a secure-chat key backup. Enter your backup password to read your earlier messages on this device, or start fresh (older messages stay unreadable here).', style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(hintText: 'Backup password')),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13))),
          const SizedBox(height: 12),
          PillButton(
            label: 'Restore',
            loading: busy,
            onPressed: busy
                ? null
                : () async {
                    set(() {
                      busy = true;
                      err = null;
                    });
                    final ok = await tryPass(pass.text);
                    if (ok) {
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } else {
                      set(() {
                        busy = false;
                        err = 'That password didn\'t unlock the backup.';
                      });
                    }
                  },
          ),
          const SizedBox(height: 8),
          PillButton(label: 'Start fresh', light: false, onPressed: busy ? null : () => Navigator.of(ctx).pop()),
        ]),
      ),
    );
    return null;
  }

  void _decryptNew(List<Json> msgs, String peerId) {
    for (final m in msgs) {
      final id = '${m['id']}';
      final needs = (num.tryParse('${m['v'] ?? 0}') ?? 0) > 0 || (m['type'] != 'text' && m['type'] != 'system');
      if (!needs || _decoded.containsKey(id) || _decoding.contains(id)) continue;
      _decoding.add(id);
      SecureChat.instance.decrypt(m, peerId).then((p) {
        _decoding.remove(id);
        if (mounted) setState(() => _decoded[id] = p);
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
    final peerId = peer['id'] as String?;
    if (peerId != null) {
      if (!_keysAsked) WidgetsBinding.instance.addPostFrameCallback((_) => _setupKeys(peerId, admin));
      if (SecureChat.instance.hasKeys) _decryptNew(msgs, peerId);
    }
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
                  Text(admin ? 'BAID X support · messages only' : '${prettyText(peer['role'])} · ${_peerKey == true ? 'Encrypted' : 'Not encrypted yet'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
    final type = '${m['type'] ?? 'text'}';
    final p = _decoded['${m['id']}'];
    if (encrypted && p == null) return _Bubble(text: 'Decrypting…', mine: mine, time: time, locked: true);
    if (p != null && p.locked) return _Bubble(text: 'Can\'t be decrypted on this device', mine: mine, time: time, locked: true);
    final kind = p?.type ?? type;
    final att = p?.attachment;
    if (kind == 'image' && att != null) return _Bubble(text: p!.text, mine: mine, time: time, image: att);
    if (kind == 'text') return _Bubble(text: p?.text ?? '${m['body'] ?? ''}', mine: mine, time: time);
    final name = '${att?['name'] ?? ''}';
    return _Bubble(text: kind == 'audio' ? 'Voice note' : kind == 'image' ? 'Photo' : (name.isEmpty ? 'File' : 'File · $name'), mine: mine, time: time);
  }
}

/// An encrypted photo: downloaded from chat-attachments and decrypted on the device.
class _SecureImage extends StatefulWidget {
  const _SecureImage(this.att);
  final Map<String, dynamic> att;
  static final _cache = <String, Uint8List>{};
  @override
  State<_SecureImage> createState() => _SecureImageState();
}

class _SecureImageState extends State<_SecureImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final path = '${widget.att['path']}';
    _bytes = _SecureImage._cache[path];
    if (_bytes == null) _load(path);
  }

  Future<void> _load(String path) async {
    try {
      final raw = await sb.storage.from('chat-attachments').download(path);
      final key = widget.att['key'], iv = widget.att['iv'];
      final bytes = key == null ? raw : SecureChat.decryptBytes(raw, '$key', '$iv');
      _SecureImage._cache[path] = bytes;
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Padding(padding: EdgeInsets.all(8), child: Text('Photo couldn\'t load', style: TextStyle(fontSize: 13, color: AppColors.muted)));
    if (_bytes == null) return const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_bytes!, width: 220, fit: BoxFit.cover));
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, required this.time, this.locked = false, this.system = false, this.image});
  final String text, time;
  final bool mine, locked, system;
  final Map<String, dynamic>? image;

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
            if (image != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: _SecureImage(image!)),
            if (image == null || text.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [
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
