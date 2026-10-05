import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/providers/app_providers.dart';
import 'secure_chat.dart';
import '../../account_type/domain/account_type.dart';

/// Data for the dashboard tabs, read exactly like the website does
/// (js/dash.js, js/market.js, js/projects.js, js/chat.js) from the shared
/// backend. These providers are not auto-disposed: once a tab has loaded,
/// opening it again shows the last result straight away while it refreshes.

typedef Json = Map<String, dynamic>;

SupabaseClient _client() {
  final c = SupabaseConfig.client;
  if (c == null) throw const ConfigurationException('BAID X is not connected yet.');
  return c;
}

String _uid() {
  final u = _client().auth.currentUser;
  if (u == null) throw const AuthFlowException('Your session expired. Sign in again.');
  return u.id;
}

List<Json> _list(Object? v) => [for (final e in (v is List ? v : const [])) if (e is Map) Map<String, dynamic>.from(e)];

String money(Object? n) {
  final v = num.tryParse('${n ?? 0}') ?? 0;
  final s = v.abs().toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${v < 0 ? '-' : ''}GH₵$whole.${parts[1]}';
}

String ago(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}');
  if (t == null) return '';
  final s = DateTime.now().difference(t).inSeconds.clamp(1, 1 << 31);
  if (s < 60) return 'just now';
  if (s < 3600) return '${s ~/ 60}m ago';
  if (s < 86400) return '${s ~/ 3600}h ago';
  if (s < 2592000) return '${s ~/ 86400}d ago';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]}';
}

/// Reloads when the signed-in account changes, so one person never sees another's data.
void _followAccount(Ref ref) => ref.watch(authStateProvider.select((a) => a.asData?.value?.id));

// ---------- Worker: Job Marketplace ----------
class JobsTab {
  const JobsTab(this.jobs, this.applied);
  final List<Json> jobs;
  final Map<String, String> applied; // job id -> application status
}

final jobsTabProvider = FutureProvider<JobsTab>((ref) async {
  _followAccount(ref);
  final c = _client(), uid = _uid();
  final r = await Future.wait([
    c.from('jobs').select('id,title,description,job_category_id,city_town,region,daily_rate_ghs,workers_needed,created_at').eq('status', 'open').order('created_at', ascending: false).limit(50),
    c.from('job_applications').select('job_id,status').eq('worker_id', uid).limit(200),
  ]);
  return JobsTab(r[0], {for (final a in r[1]) '${a['job_id']}': '${a['status']}'});
});

Future<void> applyToJob(String jobId) async {
  try {
    await _client().from('job_applications').insert({'job_id': jobId, 'worker_id': _uid()});
  } on PostgrestException catch (e) {
    if (e.code != '23505') rethrow; // already applied
  }
}

// ---------- Worker: Work ----------
class WorkTab {
  const WorkTab(this.apps, this.jobs);
  final List<Json> apps;
  final Map<String, Json> jobs;
}

final workTabProvider = FutureProvider<WorkTab>((ref) async {
  _followAccount(ref);
  final c = _client(), uid = _uid();
  final apps = await c.from('job_applications').select('id,job_id,status,proposed_rate_ghs,created_at').eq('worker_id', uid).order('created_at', ascending: false).limit(100);
  final ids = {for (final a in apps) a['job_id']}.whereType<String>().toList();
  final jobs = ids.isEmpty ? <Json>[] : await c.from('jobs').select('id,title,city_town,daily_rate_ghs').inFilter('id', ids).limit(100);
  return WorkTab(apps, {for (final j in jobs) '${j['id']}': j});
});

// ---------- Projects ----------
final projectsTabProvider = FutureProvider<List<Json>>((ref) async {
  _followAccount(ref);
  return _list(await _client().rpc('my_projects'));
});

// ---------- Chats ----------
final conversationsProvider = FutureProvider<List<Json>>((ref) async {
  _followAccount(ref);
  return _list(await _client().rpc('my_conversations'));
});

final chatThreadProvider = FutureProvider.family<Json, String>((ref, id) async {
  _followAccount(ref);
  final r = await _client().rpc('chat_thread', params: {'p_conv': id});
  return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
});

/// Same call the website uses. Text to a member with a secure-chat key is
/// end-to-end encrypted (version 1); BAID X support, or someone who has not set
/// up secure chat yet, gets plain text (version 0), exactly like the website.
Future<void> sendChat(String conversationId, String text, {String? peerId, bool peerAdmin = false}) async {
  final client = _uuid4(); // lets the server ignore a duplicate send after a dropped connection
  final sealed = peerId == null || peerAdmin ? null : await SecureChat.instance.encryptFor(peerId, {'t': 'text', 'x': text});
  await _client().rpc('send_chat', params: {'p_conv': conversationId, 'p_body': sealed ?? text, 'p_type': 'text', 'p_client': client, 'p_version': sealed == null ? 0 : 1, 'p_attach': <Object>[]});
}

Future<void> markConversationRead(String id) async {
  try {
    await _client().rpc('mark_conversation_read', params: {'p_conv': id});
  } catch (_) {
    // read receipts are best effort, like the website
  }
}

// ---------- Business ----------
final catalogTabProvider = FutureProvider.family<List<Json>, String>((ref, seg) async {
  _followAccount(ref);
  final table = seg == 'equipment' ? 'business_equipment' : 'business_products';
  return _client().from(table).select('*').eq('business_id', _uid()).order('created_at', ascending: false).limit(60);
});

final inquiriesTabProvider = FutureProvider<List<Json>>((ref) async {
  _followAccount(ref);
  return _client().from('product_inquiries').select('id,inquirer_name,message,status,created_at').eq('business_id', _uid()).order('created_at', ascending: false).limit(50);
});

// ---------- Client / company: Hires and job posts ----------
final hiresTabProvider = FutureProvider<List<Json>>((ref) async {
  _followAccount(ref);
  final type = (await ref.watch(accountProfileProvider.future))?.type;
  final col = type == AccountType.company ? 'company_id' : 'employer_id';
  return _client().from('jobs').select('id,title,status,city_town,daily_rate_ghs,workers_needed,created_at').eq(col, _uid()).order('created_at', ascending: false).limit(50);
});

Future<void> setJobStatus(String id, String status) async {
  await _client().from('jobs').update({'status': status}).eq('id', id);
}

String _uuid4() {
  final r = Random.secure(), b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
