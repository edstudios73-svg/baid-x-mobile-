import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';

/// BAID Bot (website js/baidbot.js): a floating assistant on the visitor Home. Questions
/// go to the Supabase function "baid-bot", which answers with Claude when an AI key is
/// set and from BAID X's own facts otherwise.

typedef BotAsk = Future<String> Function(List<Map<String, String>> messages);

/// How a question reaches the bot; tests replace it.
final baidBotAskProvider = Provider<BotAsk>((ref) => (messages) async {
      final client = SupabaseConfig.client;
      if (client == null) throw StateError('not connected');
      final res = await client.functions.invoke('baid-bot', body: {'messages': messages});
      final data = res.data;
      final reply = data is Map ? data['reply'] : null;
      if (reply is String && reply.trim().isNotEmpty) return reply.trim();
      throw StateError('no reply');
    });

const _greeting = "Hi, I'm BAID Bot. Ask me anything about BAID X: joining, escrow, badges, plans or rates.";
const _suggestions = ['Is BAID X free?', 'How does escrow protect me?', 'What does a badge mean?', 'How much are the plans?'];

// the conversation lasts while the app is open, like the website's tab
final List<Map<String, String>> _session = [];

/// The round white button that opens the chat.
class BaidBotButton extends StatelessWidget {
  const BaidBotButton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Ask BAID Bot',
        child: GestureDetector(
          onTap: () => openBaidBot(context),
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0xB3000000), blurRadius: 40, spreadRadius: -10, offset: Offset(0, 18)), BoxShadow(color: Color(0x73FFFFFF), blurRadius: 30, spreadRadius: -6)],
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.black, size: 27),
          ),
        ),
      );
}

Future<void> openBaidBot(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // the bot draws its own glass panel: no theme sheet, handle or shadow behind it
      showDragHandle: false,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      constraints: const BoxConstraints(),
      barrierColor: const Color(0x99000000),
      builder: (_) => const _BotSheet(),
    );

class _BotSheet extends ConsumerStatefulWidget {
  const _BotSheet();
  @override
  ConsumerState<_BotSheet> createState() => _BotSheetState();
}

class _BotSheetState extends ConsumerState<_BotSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _ask(String text) async {
    final q = text.trim();
    if (q.isEmpty || _busy) return;
    final asked = q.length > 600 ? q.substring(0, 600) : q;
    setState(() {
      _session.add({'role': 'user', 'content': asked});
      _busy = true;
    });
    _toEnd();
    String reply;
    try {
      final recent = _session.length > 8 ? _session.sublist(_session.length - 8) : List.of(_session);
      reply = await ref.read(baidBotAskProvider)(recent);
    } catch (_) {
      reply = "I couldn't reach BAID X just now. Check your connection and try again.";
    }
    if (!mounted) return;
    setState(() {
      _session.add({'role': 'assistant', 'content': reply});
      if (_session.length > 20) _session.removeRange(0, _session.length - 20);
      _busy = false;
    });
    _toEnd();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    const r = BorderRadius.all(Radius.circular(26));
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + mq.viewInsets.bottom + mq.padding.bottom),
      child: SizedBox(
        height: (mq.size.height * .78).clamp(360.0, 640.0),
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: r,
                color: const Color(0xE00A0A0A),
                border: Border.all(color: const Color(0x38FFFFFF)),
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.smart_toy_outlined, color: Colors.black, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('BAID Bot', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                        Row(children: [
                          SizedBox(width: 6, height: 6, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF3DDC84), shape: BoxShape.circle))),
                          SizedBox(width: 6),
                          Text('Answers about BAID X', style: TextStyle(fontSize: 12, color: Color(0xFFA3A3A3))),
                        ]),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ]),
                ),
                const Divider(height: 1, color: Color(0x1AFFFFFF)),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    children: [
                      const _Bubble(text: _greeting, mine: false),
                      for (final m in _session) _Bubble(text: m['content'] ?? '', mine: m['role'] == 'user'),
                      if (_busy) const _Typing(),
                    ],
                  ),
                ),
                if (_session.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final s in _suggestions)
                        GestureDetector(
                          onTap: () => _ask(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x2EFFFFFF))),
                            child: Text(s, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFE6E6E6))),
                          ),
                        ),
                    ]),
                  ),
                const Divider(height: 1, color: Color(0x1AFFFFFF)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0x2EFFFFFF))),
                        child: TextField(
                          controller: _input,
                          maxLength: 600,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (v) {
                            _input.clear();
                            _ask(v);
                          },
                          style: const TextStyle(fontSize: 15, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Ask about BAID X',
                            hintStyle: TextStyle(fontSize: 15, color: Color(0xFF7A7A7A)),
                            counterText: '',
                            filled: false,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Send',
                      child: GestureDetector(
                        onTap: () {
                          final v = _input.text;
                          _input.clear();
                          _ask(v);
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.black),
                        ),
                      ),
                    ),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 2, 14, 10),
                  child: Text('BAID Bot can be wrong. Never share passwords or SMS codes.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF7A7A7A))),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .74),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? Colors.white : const Color(0x14FFFFFF),
            border: mine ? null : Border.all(color: const Color(0x1FFFFFFF)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 6),
              bottomRight: Radius.circular(mine ? 6 : 18),
            ),
          ),
          child: Text(text, style: TextStyle(fontSize: 14, height: 1.45, color: mine ? Colors.black : Colors.white, fontWeight: mine ? FontWeight.w500 : FontWeight.w400)),
        ),
      );
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(18)),
          child: const Text('BAID Bot is typing…', style: TextStyle(fontSize: 12.5, color: Color(0xFFBDBDBD))),
        ),
      );
}
