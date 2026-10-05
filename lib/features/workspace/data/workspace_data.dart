import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/app_providers.dart';
import '../../account/data/profile_data.dart';
import '../../tabs/data/tabs_data.dart';

/// Project workspace, invitations and approvals, read and written exactly like
/// the website (js/projects.js, js/milestones.js). Every action is a database
/// function that re-checks identity, membership and project role, so the
/// screens only show what the database allows.

void _follow(Ref ref) => ref.watch(authStateProvider.select((a) => a.asData?.value?.id));

/// `my_role` from project_overview: company, pm or worker.
String wsRole(Json ov) => '${ov['my_role'] ?? 'worker'}';

bool wsOpen(Json ov) => ov['status'] != 'completed' && ov['status'] != 'cancelled';

const wsTabs = <String, List<(String, String)>>{
  'company': [('overview', 'Overview'), ('team', 'Team'), ('tasks', 'Tasks'), ('reports', 'Reports'), ('finance', 'Finance'), ('milestones', 'Milestones'), ('activity', 'Activity')],
  'pm': [('overview', 'Overview'), ('team', 'Team'), ('tasks', 'Tasks'), ('reports', 'Reports'), ('finance', 'Finance'), ('milestones', 'Milestones')],
  'worker': [('overview', 'Overview'), ('mytasks', 'My Tasks'), ('milestones', 'Milestones'), ('updates', 'Updates')],
};

final projectOverviewProvider = FutureProvider.family<Json, String>((ref, pid) async {
  _follow(ref);
  return asMap(await rpcCall('project_overview', {'p_project': pid}));
});

final projectTeamProvider = FutureProvider.family<Json, String>((ref, pid) async {
  _follow(ref);
  return asMap(await rpcCall('project_team', {'p_project': pid}));
});

final projectTasksProvider = FutureProvider.family<List<Json>, String>((ref, pid) async {
  _follow(ref);
  return asList(await sb.from('project_tasks').select('id,title,description,status,priority,assignee_worker_id,due_on,accepted_at').eq('project_id', pid).order('sort_order', ascending: true));
});

final projectReportsProvider = FutureProvider.family<List<Json>, String>((ref, pid) async {
  _follow(ref);
  return asList(await sb.from('project_reports').select().eq('project_id', pid).order('created_at', ascending: false).limit(30));
});

class FinanceData {
  const FinanceData(this.totals, this.requests, this.payments);
  final Json totals;
  final List<Json> requests, payments;
}

final projectFinanceProvider = FutureProvider.family<FinanceData, String>((ref, pid) async {
  _follow(ref);
  final r = await Future.wait(<Future<dynamic>>[
    rpcCall('project_finance', {'p_project': pid}),
    sb.from('project_requests').select('id,kind,title,purpose,quantity,amount_ghs,status,decision_note,created_at').eq('project_id', pid).order('created_at', ascending: false).limit(40),
    sb.from('project_payments').select('id,payee_id,purpose,payment_type,amount_ghs,status,reference,created_at').eq('project_id', pid).order('created_at', ascending: false).limit(40),
  ]);
  return FinanceData(asMap(r[0]), asList(r[1]), asList(r[2]));
});

final projectMilestonesProvider = FutureProvider.family<List<Json>, String>((ref, pid) async {
  _follow(ref);
  return asList(await rpcCall('project_milestone_list', {'p_project': pid}));
});

final projectActivityProvider = FutureProvider.family<List<Json>, String>((ref, pid) async {
  _follow(ref);
  return asList(await sb.from('project_events').select('id,event_type,detail,created_at').eq('project_id', pid).order('created_at', ascending: false).limit(60));
});

final myUpdatesProvider = FutureProvider.family<List<Json>, String>((ref, pid) async {
  _follow(ref);
  return asList(await sb.from('task_updates').select('id,task_id,kind,body,photo_urls,created_at').eq('project_id', pid).eq('author_id', myId).order('created_at', ascending: false).limit(40));
});

final completionNoteProvider = FutureProvider.family<Json, String>((ref, pid) async {
  _follow(ref);
  final id = await rpcCall('project_pending_completion', {'p_project': pid});
  if (id == null) return const {};
  final row = await sb.from('project_completion_requests').select('note,created_at').eq('id', '$id').maybeSingle();
  return {'id': '$id', ...?row};
});

final myReviewedProvider = FutureProvider.family<Set<String>, String>((ref, pid) async {
  _follow(ref);
  final rows = await sb.from('project_reviews').select('reviewee_id').eq('project_id', pid).eq('reviewer_id', myId);
  return {for (final r in rows) '${r['reviewee_id']}'};
});

/// The organization a project is attached to (owner only).
final projectOrgProvider = FutureProvider.family<String?, String>((ref, pid) async {
  _follow(ref);
  final row = await sb.from('projects').select('org_id').eq('id', pid).maybeSingle();
  return row?['org_id'] as String?;
});

final invitationsProvider = FutureProvider<List<Json>>((ref) async {
  _follow(ref);
  return asList(await rpcCall('my_invitations'));
});

final approvalsProvider = FutureProvider<Json>((ref) async {
  _follow(ref);
  return asMap(await rpcCall('company_approvals'));
});

int approvalsCount(Json a) => ['workers', 'requests', 'payments', 'reports', 'completions'].fold(0, (t, k) => t + asList(a[k]).length);

/// Verified people a company or PM can invite (website pickPerson).
final invitePoolProvider = FutureProvider.family<List<Json>, String>((ref, kind) async {
  _follow(ref);
  final pm = kind == 'pm';
  return asList(await sb
      .from(pm ? 'project_manager_profiles' : 'worker_profiles')
      .select(pm ? 'id,full_name,specialization,city_town,region,profile_photo_url' : 'id,full_name,primary_job_category_id,specialty,city_town,region,profile_photo_url,daily_rate_ghs')
      .eq('verification_status', 'verified')
      .limit(60));
});

/// Refreshes everything a workspace action can change.
void refreshWorkspace(WidgetRef ref, String pid) {
  for (final p in [projectOverviewProvider(pid), projectOrgProvider(pid), projectTeamProvider(pid), projectTasksProvider(pid), projectReportsProvider(pid), projectFinanceProvider(pid), projectMilestonesProvider(pid), projectActivityProvider(pid), myUpdatesProvider(pid), completionNoteProvider(pid), myReviewedProvider(pid)]) {
    ref.invalidate(p);
  }
  ref.invalidate(projectsTabProvider);
  ref.invalidate(approvalsProvider);
  ref.invalidate(invitationsProvider);
}

/// Progress photos live in the private project-photos bucket under
/// `<project>/<uploader>/`, the folder its storage policy checks.
Future<List<String>> uploadProjectPhotos(String pid, List<(Uint8List, String)> files) async {
  final paths = <String>[];
  for (final (bytes, name) in files.take(4)) {
    if (bytes.length > 8 * 1024 * 1024) throw const FormatException('A photo is over 8 MB. Choose a smaller one.');
    final ext = (name.contains('.') ? name.split('.').last : 'jpg').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final path = '$pid/$myId/${DateTime.now().millisecondsSinceEpoch}-${paths.length}.$ext';
    await sb.storage.from('project-photos').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}', upsert: false));
    paths.add(path);
  }
  return paths;
}

final signedPhotosProvider = FutureProvider.family<List<String>, String>((ref, joined) async {
  final paths = joined.split('|').where((p) => p.isNotEmpty).toList();
  if (paths.isEmpty) return const [];
  final urls = await sb.storage.from('project-photos').createSignedUrlsResult(paths, 3600);
  return [for (final u in urls) if (u is SignedUrlSuccess) u.signedUrl];
});
