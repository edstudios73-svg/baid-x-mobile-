import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../account/data/profile_data.dart';
import '../../account/presentation/account_sheets.dart';
import '../../account/presentation/profile_pages.dart' show KV, SecLabel;
import '../../tabs/data/tabs_data.dart';
import '../../hiring/job_card_screen.dart';
import '../data/workspace_data.dart';
import 'ws_common.dart';
import 'ws_forms.dart';

/// The project workspace (website js/projects.js wsView): one project, tabs by
/// role. Company: overview, team, tasks, reports, finance, milestones,
/// activity. PM: the same without activity. Worker: overview, my tasks,
/// milestones, updates.
class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({required this.projectId, this.tab, super.key});
  final String projectId;
  final String? tab;

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  late String _pid = widget.projectId;
  late String? _tab = widget.tab;

  // A notification or link can open another project or tab while this screen
  // is already showing; follow it instead of keeping the old one.
  @override
  void didUpdateWidget(WorkspaceScreen old) {
    super.didUpdateWidget(old);
    if (old.projectId != widget.projectId || old.tab != widget.tab) {
      _pid = widget.projectId;
      _tab = widget.tab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ovAsync = ref.watch(projectOverviewProvider(_pid));
    final projects = ref.watch(projectsTabProvider).asData?.value ?? const <Json>[];
    return DashPage<Json>(
      head: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          GlassIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Back', size: 40, onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.projects)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Workspace', style: TextStyle(fontSize: 13, color: AppColors.muted))),
        ]),
      ),
      data: ovAsync,
      onRefresh: () async {
        refreshWorkspace(ref, _pid);
        await ref.read(projectOverviewProvider(_pid).future);
      },
      builder: (ov) {
        final role = wsRole(ov);
        final tabs = wsTabs[role] ?? wsTabs['worker']!;
        final tab = tabs.any((t) => t.$1 == _tab) ? _tab! : 'overview';
        return [
          const SizedBox(height: 14),
          Text('${ov['name'] ?? 'Project'}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.3)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (ov['public_code'] != null)
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: '${ov['public_code']}'));
                  if (context.mounted) toast(context, 'Project ID copied');
                },
                child: CodeTag('${ov['public_code']}'),
              ),
            WsPill(ov['status']),
            if (placeOf(ov).isNotEmpty) Text(placeOf(ov), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ]),
          if (projects.length > 1) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: projects.any((p) => p['id'] == _pid) ? _pid : null,
              isExpanded: true,
              dropdownColor: AppColors.card,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              items: [for (final p in projects) DropdownMenuItem(value: '${p['id']}', child: Text('${p['name']} · ${p['public_code'] ?? ''}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => v == null ? null : setState(() => _pid = v),
            ),
          ],
          const SizedBox(height: 12),
          DashSegs(items: tabs, active: tab, onTap: (k) => setState(() => _tab = k)),
          switch (tab) {
            'team' => _TeamTab(ov: ov, pid: _pid),
            'tasks' => _TasksTab(ov: ov, pid: _pid),
            'mytasks' => _MyTasksTab(pid: _pid),
            'updates' => _UpdatesTab(pid: _pid),
            'reports' => _ReportsTab(ov: ov, pid: _pid),
            'finance' => _FinanceTab(ov: ov, pid: _pid),
            'milestones' => MilestonesTab(ov: ov, pid: _pid),
            'activity' => _ActivityTab(pid: _pid),
            _ => _OverviewTab(ov: ov, pid: _pid),
          },
        ];
      },
    );
  }
}

// ---------------------------------------------------------------- Overview
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.ov, required this.pid});
  final Json ov;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = wsRole(ov);
    final pct = num.tryParse('${ov['progress_pct'] ?? 0}') ?? 0;
    final company = asMap(ov['company']), pm = asMap(ov['pm']);
    final skills = [for (final s in (ov['required_skills'] is List ? ov['required_skills'] as List : const [])) '$s'];
    final waiting = int.tryParse('${ov['awaiting_approval'] ?? 0}') ?? 0;
    final mode = '${ov['worker_addition_mode'] ?? 'automatic'}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (final (v, l) in [('${ov['team_active'] ?? 0}', 'Workers'), ('${ov['tasks_done'] ?? 0}/${ov['tasks_total'] ?? 0}', 'Tasks done'), ('${ov['tasks_overdue'] ?? 0}', 'Overdue')]) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lineGlass)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.4)),
                const SizedBox(height: 4),
                Text(l, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ),
          ),
          if (l != 'Overdue') const SizedBox(width: 8),
        ],
      ]),
      const SizedBox(height: 10),
      WsCard(title: 'Progress', right: Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w700)), children: [DashBar(pct), const WsCaption('Updates automatically as tasks are completed.')]),
      if (role == 'company' && waiting > 0)
        WsInboxCard(
          warn: true,
          icon: Icons.task_alt_rounded,
          title: '$waiting item${waiting > 1 ? 's' : ''} waiting for you',
          sub: 'Workers, requests, payments or reports',
          count: waiting,
          onTap: () => context.push(AppRoutes.approvals),
        ),
      if (role == 'company' || role == 'pm') ProjectJobCards(pid: pid),
      WsCard(title: 'About this project', children: [
        if ('${ov['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${ov['description']}', style: const TextStyle(fontSize: 13.5, height: 1.45))),
        KV('Company', '${company['name'] ?? ''}'),
        KV('Project manager', pm.isEmpty ? 'Not assigned yet' : '${pm['name'] ?? ''}'),
        KV('Type', prettyText(ov['project_type'])),
        KV('Dates', '${ov['starts_on'] != null ? fdate(ov['starts_on']) : '—'} to ${ov['ends_on'] != null ? fdate(ov['ends_on']) : '—'}'),
        if (ov['team_size'] != null) KV('Planned team', '${ov['team_size']} people'),
        if (skills.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final s in skills) WsPill(null, label: s)])),
        if ('${ov['requirements'] ?? ''}'.isNotEmpty) WsQuote('Requirements', ov['requirements']),
      ]),
      if (role == 'company') ...[
        const SecLabel('Approval settings'),
        WsCard(title: 'Adding workers', children: [
          DashSegs(
            items: const [('automatic', 'Automatic'), ('company_approval', 'Company approval')],
            active: mode,
            onTap: (k) => wsAct(context, ref, pid, () => rpcCall('set_worker_addition_mode', {'p_project': pid, 'p_mode': k}), ok: 'Approval setting saved'),
          ),
          WsCaption(mode == 'automatic'
              ? 'Workers your project manager invites within the plan join as soon as they accept. Anything outside the plan still needs your approval.'
              : 'Every worker your project manager invites needs your approval before they join.'),
          const WsCaption('Expenses, materials, equipment and payments always need your approval.'),
        ]),
        _OrgCard(pid: pid),
      ],
      _CompletionPanel(ov: ov, pid: pid),
      if (ov['status'] == 'completed') _ReviewsPanel(ov: ov, pid: pid),
    ]);
  }
}

/// Owner only: attach the project to one of your organizations.
class _OrgCard extends ConsumerStatefulWidget {
  const _OrgCard({required this.pid});
  final String pid;
  @override
  ConsumerState<_OrgCard> createState() => _OrgCardState();
}

class _OrgCardState extends ConsumerState<_OrgCard> {
  String? _org;
  bool _picked = false;

  @override
  Widget build(BuildContext context) {
    final orgs = (ref.watch(myOrgsProvider).asData?.value ?? const <Json>[]).where((o) => o['status'] == 'ACTIVE').toList();
    if (!_picked) _org = ref.watch(projectOrgProvider(widget.pid)).asData?.value;
    if (orgs.isEmpty && _org == null) return const SizedBox.shrink();
    return WsCard(title: 'Organization', children: [
      DropdownButtonFormField<String>(
        key: ValueKey(_org),
        initialValue: _org ?? '',
        isExpanded: true,
        dropdownColor: AppColors.card,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        items: [
          const DropdownMenuItem(value: '', child: Text('None (just me)')),
          for (final o in orgs) DropdownMenuItem(value: '${o['org_id']}', child: Text('${o['name']}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() {
          _picked = true;
          _org = (v ?? '').isEmpty ? null : v;
        }),
      ),
      WsButtons([SmallButton('Save', onPressed: () => wsAct(context, ref, widget.pid, () => rpcCall('link_project_org', {'p_project': widget.pid, 'p_org': _org}), ok: 'Organization saved'))]),
      const WsCaption('Members with a project director, finance manager or owner role can then act for the company on this project. Removing someone from the organization removes their access at once.'),
    ]);
  }
}

class _CompletionPanel extends ConsumerWidget {
  const _CompletionPanel({required this.ov, required this.pid});
  final Json ov;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = wsRole(ov);
    if (ov['status'] == 'completed') {
      return const WsCard(children: [Row(children: [Icon(Icons.task_alt_rounded, size: 18, color: AppColors.green), SizedBox(width: 8), Expanded(child: Text('Project completed · reviews are open', style: TextStyle(fontWeight: FontWeight.w700)))])]);
    }
    if (ov['completion_pending'] == true) {
      if (role != 'company') {
        return const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SecLabel('Completion'), WsCard(title: 'Waiting for the company', children: [WsCaption('Your completion request was sent. The company decides.')])]);
      }
      final r = ref.watch(completionNoteProvider(pid)).asData?.value ?? const {};
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SecLabel('Completion'),
        WsCard(warn: true, title: 'Completion requested', right: Text(ago(r['created_at'] ?? DateTime.now().toIso8601String()), style: const TextStyle(fontSize: 12, color: Color(0xFFE8A93A))), children: [
          WsCaption('${r['note'] ?? 'Your project manager says the work is finished.'}'),
          if (r['id'] != null) WsButtons(completionButtons(context, ref, '${r['id']}', pid)),
        ]),
      ]);
    }
    if (role == 'pm') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SecLabel('Completion'),
        WsCard(title: 'Finished the work?', children: [
          const WsCaption('BAID X checks for open tasks, unreviewed reports and pending requests first. The company then approves.'),
          WsButtons([SmallButton('Request completion', onPressed: () => requestCompletion(context, ref, pid))]),
        ]),
      ]);
    }
    if (role == 'company' && asMap(ov['pm']).isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SecLabel('Completion'),
        WsCard(title: 'Mark as completed', children: [
          const WsCaption('This project has no project manager, so you can complete it yourself.'),
          WsButtons([
            SmallButton('Complete project', onPressed: () async {
              if (!await confirmBox(context, 'Complete this project?', 'This closes the project for everyone.')) return;
              if (context.mounted) await wsAct(context, ref, pid, () => rpcCall('complete_structured_project', {'target_project_id': pid}), ok: 'Project completed');
            }),
          ]),
        ]),
      ]);
    }
    return const SizedBox.shrink();
  }
}

class _ReviewsPanel extends ConsumerWidget {
  const _ReviewsPanel({required this.ov, required this.pid});
  final Json ov;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = wsRole(ov);
    if (role == 'worker') return const SizedBox.shrink();
    final team = ref.watch(projectTeamProvider(pid)).asData?.value;
    final done = ref.watch(myReviewedProvider(pid)).asData?.value;
    if (team == null || done == null) return const SizedBox.shrink();
    final me = ref.watch(authStateProvider).asData?.value?.id ?? '';
    final who = asList(team['members']).where((m) => m['profile_id'] != me && !done.contains('${m['profile_id']}') && (role == 'company' ? ['pm', 'worker'] : ['company', 'worker']).contains(m['role_type'])).toList();
    if (who.isEmpty) return const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SecLabel('Reviews'), WsCard(children: [WsCaption('Thanks. You have reviewed everyone on this project.')])]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SecLabel('Leave reviews'), for (final m in who) ReviewCard(member: m, pid: pid)]);
  }
}

// ---------------------------------------------------------------- Team
class _TeamTab extends ConsumerWidget {
  const _TeamTab({required this.ov, required this.pid});
  final Json ov;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = wsRole(ov);
    final manager = role == 'company' || role == 'pm';
    final open = wsOpen(ov);
    final canInvitePm = role == 'company' && asMap(ov['pm']).isEmpty && ov['status'] != 'completed';
    return WsAsync<Json>(ref.watch(projectTeamProvider(pid)), onRetry: () => ref.invalidate(projectTeamProvider(pid)), (t) {
      final members = asList(t['members']), invs = asList(t['invitations']);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (manager && open)
          WsButtons(top: true, [
            if (canInvitePm) SmallButton('+ Invite project manager', onPressed: () => openInvite(context, ref, kind: 'pm', projectId: pid)),
            SmallButton('+ Invite worker', onPressed: () => openInvite(context, ref, kind: 'worker', projectId: pid)),
          ]),
        const SecLabel('Team'),
        for (final m in members)
          DashRow(
            leading: WsAvatar(m['name'], m['photo'], size: 34),
            title: '${m['name'] ?? ''}',
            sub: '${m['project_role'] ?? ''}${m['rate_ghs'] != null && manager ? ' · ${money(m['rate_ghs'])}' : ''}',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              m['role_type'] == 'company' ? const WsPill('active', label: 'Owner') : WsPill(m['status']),
              if (role == 'company' && m['role_type'] != 'company' && ov['status'] != 'completed')
                IconButton(
                  tooltip: 'Remove ${m['name']}',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () async {
                    final note = await askNote(context, 'Remove ${m['name']}?', 'Reason (optional). They lose access immediately.');
                    if (note == null || !context.mounted) return;
                    await wsAct(context, ref, pid, () => rpcCall('remove_member', {'p_project': pid, 'p_profile': m['profile_id'], 'p_reason': note.isEmpty ? null : note}), ok: 'Removed from the project');
                  },
                ),
            ]),
          ),
        if (manager && invs.isNotEmpty) ...[const SecLabel('Invitations'), for (final i in invs) InvitationCard(inv: i, role: role, pid: pid)],
        if (!members.any((m) => m['role_type'] == 'worker') && invs.isEmpty)
          DashEmpty(icon: Icons.groups_outlined, title: 'No workers yet', text: manager ? 'Invite workers by trade, location and rating. Workers inside your plan join as soon as they accept.' : 'Your teammates will appear here.'),
      ]);
    });
  }
}

// ---------------------------------------------------------------- Tasks
class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.ov, required this.pid});
  final Json ov;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(projectTeamProvider(pid)).asData?.value ?? const {};
    final members = asList(team['members']);
    final names = {for (final m in members) '${m['profile_id']}': '${m['name']}'};
    final workers = members.where((m) => m['role_type'] == 'worker').toList();
    return WsAsync<List<Json>>(ref.watch(projectTasksProvider(pid)), onRetry: () => ref.invalidate(projectTasksProvider(pid)), (tasks) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (wsOpen(ov)) WsButtons(top: true, [SmallButton('+ New task', onPressed: () => taskSheet(context, ref, pid, workers, null))]),
        if (tasks.isEmpty) const DashEmpty(icon: Icons.task_alt_rounded, title: 'No tasks yet', text: 'Break the work into tasks, assign each to a worker on your team and track progress here.'),
        for (final t in tasks)
          DashRow(
            icon: t['status'] == 'done' ? Icons.check_circle_rounded : Icons.task_alt_rounded,
            title: '${t['title'] ?? ''}',
            sub: [
              t['assignee_worker_id'] != null ? (names['${t['assignee_worker_id']}'] ?? 'Worker') : 'Unassigned',
              if (t['due_on'] != null) '${overdue(t['due_on'], t['status']) ? 'overdue, ' : ''}due ${fdate(t['due_on'])}',
            ].join(' · '),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (t['priority'] == 'high' || t['priority'] == 'urgent') ...[WsPill(t['priority']), const SizedBox(width: 6)],
              WsPill(t['status']),
            ]),
            onTap: () => taskSheet(context, ref, pid, workers, t),
          ),
      ]);
    });
  }
}

class _MyTasksTab extends ConsumerWidget {
  const _MyTasksTab({required this.pid});
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WsAsync<List<Json>>(ref.watch(projectTasksProvider(pid)), onRetry: () => ref.invalidate(projectTasksProvider(pid)), (all) {
      final me = ref.watch(authStateProvider).asData?.value?.id ?? '';
      final tasks = all.where((t) => t['assignee_worker_id'] == me).toList();
      if (tasks.isEmpty) return const DashEmpty(icon: Icons.task_alt_rounded, title: 'No tasks assigned to you', text: 'When your project manager assigns you a task it appears here.');
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final t in tasks)
          WsCard(title: '${t['title'] ?? ''}', right: WsPill(t['status']), children: [
            if ('${t['description'] ?? ''}'.isNotEmpty) Text('${t['description']}', style: const TextStyle(fontSize: 13.5, height: 1.45)),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (t['due_on'] != null) Text('Due ${fdate(t['due_on'])}', style: TextStyle(fontSize: 12.5, color: overdue(t['due_on'], t['status']) ? const Color(0xFFF87171) : AppColors.muted)),
                WsPill(t['priority']),
              ]),
            ),
            WsButtons([
              if (t['status'] == 'todo' && t['accepted_at'] == null) SmallButton('Accept', light: false, onPressed: () => wsAct(context, ref, pid, () => rpcCall('task_progress', {'p_task': t['id'], 'p_action': 'accept', 'p_note': null, 'p_photos': <String>[]}), ok: 'Task accepted')),
              if (t['status'] == 'todo') SmallButton('Start work', onPressed: () => wsAct(context, ref, pid, () => rpcCall('task_progress', {'p_task': t['id'], 'p_action': 'start', 'p_note': null, 'p_photos': <String>[]}), ok: 'Work started')),
              if (t['status'] == 'in_progress' || t['status'] == 'blocked') ...[
                SmallButton('Add update', light: false, onPressed: () => progressSheet(context, ref, pid, t, complete: false)),
                SmallButton('Mark complete', onPressed: () => progressSheet(context, ref, pid, t, complete: true)),
              ],
            ]),
            if (t['status'] == 'done') const Padding(padding: EdgeInsets.only(top: 8), child: Text('Completed', style: TextStyle(fontSize: 12.5, color: AppColors.green, fontWeight: FontWeight.w700))),
          ]),
      ]);
    });
  }
}

class _UpdatesTab extends ConsumerWidget {
  const _UpdatesTab({required this.pid});
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(projectTasksProvider(pid)).asData?.value ?? const <Json>[];
    final titles = {for (final t in tasks) '${t['id']}': '${t['title']}'};
    return WsAsync<List<Json>>(ref.watch(myUpdatesProvider(pid)), onRetry: () => ref.invalidate(myUpdatesProvider(pid)), (ups) {
      if (ups.isEmpty) return const DashEmpty(icon: Icons.description_outlined, title: 'No updates yet', text: 'Notes, photos and progress you post on your tasks are listed here.');
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final u in ups)
          DashRow(
            icon: u['kind'] == 'completed' ? Icons.task_alt_rounded : Icons.description_outlined,
            title: '${titles['${u['task_id']}'] ?? 'Task'} · ${prettyText(u['kind'])}',
            sub: '${u['body'] ?? ''}',
            below: WsThumbs(u['photo_urls']),
            trailing: Text(ago(u['created_at']), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ),
      ]);
    });
  }
}

// ---------------------------------------------------------------- Reports
class _ReportsTab extends ConsumerWidget {
  const _ReportsTab({required this.ov, required this.pid});
  final Json ov;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = wsRole(ov);
    return WsAsync<List<Json>>(ref.watch(projectReportsProvider(pid)), onRetry: () => ref.invalidate(projectReportsProvider(pid)), (list) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (role == 'pm' && wsOpen(ov)) WsButtons(top: true, [SmallButton('+ New report', onPressed: () => reportSheet(context, ref, pid))]),
        if (list.isEmpty)
          DashEmpty(
            icon: Icons.description_outlined,
            title: 'No reports yet',
            text: role == 'pm' ? 'File a daily or weekly report: work done, who was on site, problems, materials and next steps.' : 'Your project manager\'s daily and weekly reports will appear here for review.',
          ),
        for (final r in list) ReportCard(report: r, role: role, pid: pid),
      ]);
    });
  }
}

class ReportCard extends ConsumerWidget {
  const ReportCard({required this.report, required this.role, this.pid, this.projectName, super.key});
  final Json report;
  final String role;
  final String? pid;
  final String? projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = report;
    return WsCard(title: '${prettyText(r['kind'])} report · ${fdate(r['report_date'])}', right: projectName == null ? WsPill(r['status']) : null, kicker: projectName, children: [
      KV('Work completed', '${r['work_completed'] ?? ''}'),
      if (r['progress_pct'] != null) KV('Progress', '${r['progress_pct']}%'),
      if (r['workers_present'] != null) KV('Workers present', '${r['workers_present']}'),
      if ('${r['problems'] ?? ''}'.isNotEmpty) KV('Problems', '${r['problems']}'),
      if ('${r['materials_needed'] ?? ''}'.isNotEmpty) KV('Materials needed', '${r['materials_needed']}'),
      if ('${r['next_steps'] ?? ''}'.isNotEmpty) KV('Next steps', '${r['next_steps']}'),
      WsThumbs(r['photo_urls']),
      if ('${r['company_comment'] ?? ''}'.isNotEmpty) WsQuote('Company comment', r['company_comment']),
      if (role == 'company' && (r['status'] == 'submitted' || projectName != null))
        WsButtons([
          SmallButton('Approve', onPressed: () => reviewReport(context, ref, pid, '${r['id']}', 'approve')),
          SmallButton('Request changes', light: false, onPressed: () => reviewReport(context, ref, pid, '${r['id']}', 'changes')),
          if (projectName == null) SmallButton('Reject', light: false, onPressed: () => reviewReport(context, ref, pid, '${r['id']}', 'reject')),
        ]),
    ]);
  }
}

// ---------------------------------------------------------------- Finance
class _FinanceTab extends ConsumerWidget {
  const _FinanceTab({required this.ov, required this.pid});
  final Json ov;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = wsRole(ov);
    final open = wsOpen(ov);
    final team = asList((ref.watch(projectTeamProvider(pid)).asData?.value ?? const {})['members']);
    final names = {for (final m in team) '${m['profile_id']}': '${m['name']}'};
    return WsAsync<FinanceData>(ref.watch(projectFinanceProvider(pid)), onRetry: () => ref.invalidate(projectFinanceProvider(pid)), (f) {
      final fin = f.totals;
      // two tiles per row at any phone width (website `.fin` grid)
      final tileW = (MediaQuery.sizeOf(context).width - 32 - 8) / 2;
      Widget tile(String l, Object? v) {
        final neg = l == 'Available' && v != null && (num.tryParse('$v') ?? 0) < 0;
        return Container(
          width: tileW,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lineGlass)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            const SizedBox(height: 3),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v == null ? '—' : money(v), maxLines: 1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: neg ? const Color(0xFFF87171) : null))),
          ]),
        );
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (role == 'company') tile('Budget', fin['budget']),
          tile('Allocated', fin['allocated']),
          tile('Committed', fin['committed']),
          tile('Spent', fin['spent']),
          if (role == 'company') tile('Available', fin['available']),
        ]),
        const WsCaption('Allocated is everything the company has approved. Committed is approved money not yet paid. Spent is paid. These are records; BAID X does not move money here.'),
        const SizedBox(height: 10),
        if (role == 'pm' && open)
          WsButtons(top: true, [
            SmallButton('+ Request materials or expenses', onPressed: () => requestSheet(context, ref, pid)),
            SmallButton('+ Payment request', light: false, onPressed: () => paymentSheet(context, ref, pid, team, record: false)),
          ]),
        if (role == 'company' && open) WsButtons(top: true, [SmallButton('+ Record a payment', light: false, onPressed: () => paymentSheet(context, ref, pid, team, record: true))]),
        const SecLabel('Requests'),
        if (f.requests.isEmpty) WsCaption('No requests yet. ${role == 'pm' ? 'Ask for materials, equipment or expenses; the company approves.' : ''}'),
        for (final r in f.requests)
          DashRow(
            icon: r['kind'] == 'equipment' ? Icons.construction_outlined : r['kind'] == 'material' ? Icons.inventory_2_outlined : Icons.payments_outlined,
            title: '${r['title'] ?? ''}',
            sub: [prettyText(r['kind']), if ('${r['quantity'] ?? ''}'.isNotEmpty) '${r['quantity']}', money(r['amount_ghs']), if ('${r['decision_note'] ?? ''}'.isNotEmpty) '${r['decision_note']}'].join(' · '),
            trailing: WsPill(r['status']),
            below: role == 'company' && r['status'] == 'pending' ? WsButtons(decideButtons(context, ref, pid, 'request', '${r['id']}')) : null,
          ),
        const SecLabel('Payment records'),
        if (f.payments.isEmpty) const WsCaption('No payment records yet.'),
        for (final p in f.payments)
          DashRow(
            icon: Icons.account_balance_wallet_outlined,
            title: '${money(p['amount_ghs'])} · ${p['purpose'] ?? ''}',
            sub: ['To ${names['${p['payee_id']}'] ?? 'member'}', prettyText(p['payment_type']), if ('${p['reference'] ?? ''}'.isNotEmpty) 'ref ${p['reference']}'].join(' · '),
            trailing: WsPill(p['status']),
            below: role == 'company' && p['status'] == 'pending'
                ? WsButtons(decideButtons(context, ref, pid, 'payment', '${p['id']}'))
                : role == 'company' && p['status'] == 'approved'
                    ? WsButtons([SmallButton('Mark paid', onPressed: () => markPaid(context, ref, pid, '${p['id']}'))])
                    : null,
          ),
      ]);
    });
  }
}

// ---------------------------------------------------------------- Activity
class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.pid});
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WsAsync<List<Json>>(ref.watch(projectActivityProvider(pid)), onRetry: () => ref.invalidate(projectActivityProvider(pid)), (ev) {
      if (ev.isEmpty) return const DashEmpty(icon: Icons.timeline_rounded, title: 'No activity yet', text: 'Every important change on this project is recorded here.');
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final e in ev)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 5, right: 12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${e['detail'] ?? ''}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(ago(e['created_at']), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
      ]);
    });
  }
}
