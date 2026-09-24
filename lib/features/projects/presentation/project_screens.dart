import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../billing/presentation/product_screens.dart';
import '../../messaging/presentation/messaging_screens.dart';
import '../../trust/presentation/trust_screens.dart';
import '../domain/project_rules.dart';
import 'project_providers.dart';

String _friendly(Object error, String fallback) {
  final message = ErrorHandler.toAppException(error).message;
  if (message.contains('permission') || message.contains('session')) return message;
  return fallback;
}

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final projects = ref.watch(projectListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (canRequestCompanyAccess(type))
            AppButton(label: 'Request company access', outlined: true, onPressed: () => context.push(AppRoutes.companyAccess)),
          if (ref.watch(myCompanyProvider).asData?.value != null)
            AppButton(
              label: 'Company messages',
              outlined: true,
              onPressed: () => openContextConversation(ref, context, contextType: 'company', contextId: ref.read(myCompanyProvider).asData!.value!.id),
            ),
          if (type == 'company' || type == 'project_manager') ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: 'Create project', onPressed: () => context.push(AppRoutes.createProject)),
          ],
          const SizedBox(height: AppSpacing.md),
          projects.when(
            loading: () => const AppLoader(message: 'Loading projects'),
            error: (error, _) => AppErrorView(
              message: _friendly(error, "We couldn't load your projects."),
              onRetry: () => ref.invalidate(projectListProvider),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const AppEmptyState(title: 'No projects yet', message: 'Projects you manage will appear here.');
              }
              return Column(
                children: [
                  for (final project in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(project.title),
                      subtitle: Text(project.status),
                      onTap: () => context.push('/projects/${project.id}'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
    if (type != 'company' && type != 'project_manager' && type != 'employer') {
      return const Scaffold(body: Center(child: Text("You don't have access to create a project.")));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Create project')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(label: 'Title', controller: _title),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Summary', controller: _summary),
          if (_error != null) ...[const SizedBox(height: AppSpacing.md), Text(_error!, style: AppTextStyles.bodyMuted)],
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final problem = validateProjectTitle(_title.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    final type = ref.read(accountProfileProvider).asData?.value?.accountType;
    final company = type == 'company' || type == 'project_manager' ? await ref.read(myCompanyProvider.future) : null;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref.read(projectRepositoryProvider).createProject(newProjectRow(
        userId: user.id,
        title: _title.text,
        summary: _summary.text,
        companyId: company?.id,
      ));
      ref.invalidate(projectListProvider);
      if (mounted) context.go('/projects/$id');
    } catch (error) {
      setState(() => _error = _friendly(error, "We couldn't save this project."));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Project')),
      body: project.when(
        loading: () => const AppLoader(message: 'Loading project'),
        error: (error, _) => AppErrorView(
          message: _friendly(error, "You don't have access to this project."),
          onRetry: () => ref.invalidate(projectDetailProvider(id)),
        ),
        data: (record) {
          if (record == null) {
            return const AppEmptyState(title: "You don't have access to this project.", message: 'Private projects stay with the people authorized to work on them.');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(record.title, style: AppTextStyles.title),
              Text(record.status, style: AppTextStyles.bodyMuted),
              if (record.summary.isNotEmpty) Text(record.summary),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Project messages',
                outlined: true,
                onPressed: () => openContextConversation(ref, context, contextType: 'project', contextId: id),
              ),
              const SizedBox(height: AppSpacing.lg),
              BoostPanel(targetType: 'project', targetId: id, title: 'Boost project'),
              const SizedBox(height: AppSpacing.lg),
              const Text('Members', style: AppTextStyles.label),
              _MemberSection(projectId: id, companyId: record.companyId),
              const SizedBox(height: AppSpacing.lg),
              const Text('Tasks', style: AppTextStyles.label),
              _TaskSection(projectId: id),
              const SizedBox(height: AppSpacing.lg),
              const Text('Reports', style: AppTextStyles.label),
              _ReportSection(projectId: id),
              const SizedBox(height: AppSpacing.lg),
              const Text('Expenses', style: AppTextStyles.label),
              _ExpenseSection(projectId: id),
            ],
          );
        },
      ),
    );
  }
}

class _MemberSection extends ConsumerStatefulWidget {
  const _MemberSection({required this.projectId, required this.companyId});

  final String projectId;
  final String? companyId;

  @override
  ConsumerState<_MemberSection> createState() => _MemberSectionState();
}

class _MemberSectionState extends ConsumerState<_MemberSection> {
  String? _profileId;
  String _role = 'worker';
  String? _error;
  late final _members = FutureProvider.autoDispose((ref) => ref.watch(projectRepositoryProvider).projectMembers(widget.projectId));
  late final _companyMembers = FutureProvider.autoDispose((ref) async {
    final companyId = widget.companyId;
    if (companyId == null) return const <Map<String, dynamic>>[];
    return ref.watch(projectRepositoryProvider).members(companyId);
  });

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(_members);
    final companyMembers = ref.watch(_companyMembers);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        members.when(
          loading: () => const AppLoader(),
          error: (error, _) => Text(_friendly(error, "You don't have access to this project.")),
          data: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rows.isEmpty) const Text('No project members yet'),
              for (final member in rows) ...[
                Text(
                  member['display_name'] == null
                      ? '${member['member_role']}'
                      : '${member['display_name']} · ${member['member_role']}',
                ),
                if (ref.watch(authStateProvider).asData?.value?.id != '${member['profile_id']}')
                  ReviewForm(subjectId: '${member['profile_id']}', projectId: widget.projectId),
              ],
            ],
          ),
        ),
        companyMembers.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (rows) {
            if (rows.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Choose a company member'),
                  value: _profileId,
                  items: [
                    for (final member in rows)
                      DropdownMenuItem(value: '${member['profile_id']}', child: Text('${member['member_role']}')),
                  ],
                  onChanged: (value) => setState(() => _profileId = value),
                ),
                DropdownButton<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'worker', child: Text('Worker')),
                    DropdownMenuItem(value: 'project_manager', child: Text('Project manager')),
                  ],
                  onChanged: (value) => setState(() => _role = value ?? 'worker'),
                ),
                TextButton(onPressed: _add, child: const Text('Add member')),
                if (_error != null) Text(_error!, style: AppTextStyles.bodyMuted),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _add() async {
    final profileId = _profileId;
    if (profileId == null) return;
    try {
      await ref.read(projectRepositoryProvider).addMember(
        projectMemberRow(projectId: widget.projectId, profileId: profileId, role: _role),
      );
      ref.invalidate(_members);
    } catch (error) {
      setState(() => _error = _friendly(error, "You don't have access to this project."));
    }
  }
}

class _TaskSection extends ConsumerStatefulWidget {
  const _TaskSection({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_TaskSection> createState() => _TaskSectionState();
}

class _TaskSectionState extends ConsumerState<_TaskSection> {
  final _title = TextEditingController();
  late final _tasks = FutureProvider.autoDispose((ref) => ref.watch(projectRepositoryProvider).tasks(widget.projectId));

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(_tasks);
    return Column(
      children: [
        tasks.when(
          loading: () => const AppLoader(),
          error: (error, _) => Text(_friendly(error, "We couldn't load tasks.")),
          data: (rows) => Column(
            children: [
              if (rows.isEmpty) const Text('No tasks yet'),
              for (final task in rows)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${task['title'] ?? ''}'),
                  value: task['is_done'] == true,
                  onChanged: (value) async {
                    await ref.read(projectRepositoryProvider).setTaskDone(taskId: '${task['id']}', done: value ?? false);
                    ref.invalidate(_tasks);
                  },
                ),
            ],
          ),
        ),
        AppTextField(label: 'New task', controller: _title),
        TextButton(
          onPressed: () async {
            if (_title.text.trim().isEmpty) return;
            await ref.read(projectRepositoryProvider).addTask(projectId: widget.projectId, title: _title.text);
            _title.clear();
            ref.invalidate(_tasks);
          },
          child: const Text('Add task'),
        ),
      ],
    );
  }
}

class _ReportSection extends ConsumerStatefulWidget {
  const _ReportSection({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_ReportSection> createState() => _ReportSectionState();
}

class _ReportSectionState extends ConsumerState<_ReportSection> {
  final _body = TextEditingController();
  late final _reports = FutureProvider.autoDispose((ref) => ref.watch(projectRepositoryProvider).reports(widget.projectId));

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(_reports);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        reports.when(
          loading: () => const AppLoader(),
          error: (error, _) => Text(_friendly(error, "We couldn't save this report.")),
          data: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rows.isEmpty) const Text('No reports yet'),
              for (final report in rows) Text('${report['body'] ?? ''}'),
            ],
          ),
        ),
        AppTextField(label: 'Report', controller: _body),
        TextButton(
          onPressed: () async {
            final user = ref.read(authStateProvider).asData?.value;
            if (user == null || _body.text.trim().isEmpty) return;
            await ref.read(projectRepositoryProvider).addReport(projectId: widget.projectId, userId: user.id, body: _body.text);
            _body.clear();
            ref.invalidate(_reports);
          },
          child: const Text('Add report'),
        ),
      ],
    );
  }
}

class _ExpenseSection extends ConsumerStatefulWidget {
  const _ExpenseSection({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_ExpenseSection> createState() => _ExpenseSectionState();
}

class _ExpenseSectionState extends ConsumerState<_ExpenseSection> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  late final _expenses = FutureProvider.autoDispose((ref) => ref.watch(projectRepositoryProvider).expenses(widget.projectId));
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(_expenses);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        expenses.when(
          loading: () => const AppLoader(),
          error: (error, _) => Text(_friendly(error, "We couldn't load expenses.")),
          data: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rows.isEmpty) const Text('No expenses yet'),
              for (final expense in rows) Text('${expense['description'] ?? ''} · ${expense['currency'] ?? ''} ${expense['amount'] ?? ''}'),
            ],
          ),
        ),
        AppTextField(label: 'Expense', controller: _description),
        AppTextField(label: 'Amount', controller: _amount, keyboardType: TextInputType.number),
        if (_error != null) Text(_error!, style: AppTextStyles.bodyMuted),
        TextButton(onPressed: _add, child: const Text('Add expense')),
      ],
    );
  }

  Future<void> _add() async {
    final problem = validateExpenseAmount(_amount.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    await ref.read(projectRepositoryProvider).addExpense(
      projectId: widget.projectId,
      userId: user.id,
      description: _description.text,
      amount: double.parse(_amount.text.trim()),
      currency: 'GHS',
    );
    _description.clear();
    _amount.clear();
    ref.invalidate(_expenses);
  }
}

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
    if (!canReviewCompanyAccess(type)) {
      return const Scaffold(body: Center(child: Text('Only the company owner can open the team.')));
    }
    final company = ref.watch(myCompanyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: company.when(
        loading: () => const AppLoader(message: 'Loading your company'),
        error: (error, _) => AppErrorView(message: _friendly(error, "We couldn't load your company."), onRetry: () => ref.invalidate(myCompanyProvider)),
        data: (record) {
          if (record == null) {
            return const AppEmptyState(title: 'No company yet', message: 'Finish company setup to see your team.');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(record.name, style: AppTextStyles.title),
              Text('${record.industry} · ${record.publicCode}', style: AppTextStyles.bodyMuted),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Company messages',
                outlined: true,
                onPressed: () => openContextConversation(ref, context, contextType: 'company', contextId: record.id),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Members', style: AppTextStyles.label),
              _Members(companyId: record.id),
              const SizedBox(height: AppSpacing.lg),
              const Text('Access requests', style: AppTextStyles.label),
              const _Requests(),
            ],
          );
        },
      ),
    );
  }
}

class _Members extends ConsumerWidget {
  const _Members({required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(_membersProvider(companyId));
    return members.when(
      loading: () => const AppLoader(),
      error: (error, _) => Text(_friendly(error, "We couldn't load your team.")),
      data: (rows) {
        if (rows.isEmpty) return const Text('No team members yet');
        return Column(
          children: [
            for (final member in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${member['member_role']}'),
                subtitle: Text('${member['status']}'),
              ),
          ],
        );
      },
    );
  }
}

final _membersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, companyId) {
  return ref.watch(projectRepositoryProvider).members(companyId);
});

class _Requests extends ConsumerWidget {
  const _Requests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(accessRequestsProvider);
    return requests.when(
      loading: () => const AppLoader(),
      error: (error, _) => AppErrorView(
        message: _friendly(error, "We couldn't load access requests."),
        onRetry: () => ref.invalidate(accessRequestsProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) return const Text('No access requests');
        return Column(
          children: [
            for (final request in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(request.status),
                trailing: request.status == 'pending'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(onPressed: () => _review(ref, request.id, true), child: const Text('Approve')),
                          TextButton(onPressed: () => _review(ref, request.id, false), child: const Text('Reject')),
                        ],
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }

  Future<void> _review(WidgetRef ref, String id, bool approve) async {
    await ref.read(projectRepositoryProvider).reviewRequest(requestId: id, approve: approve);
    ref.invalidate(accessRequestsProvider);
    ref.invalidate(myCompanyProvider);
  }
}

class CompanyAccessScreen extends ConsumerStatefulWidget {
  const CompanyAccessScreen({super.key});

  @override
  ConsumerState<CompanyAccessScreen> createState() => _CompanyAccessScreenState();
}

class _CompanyAccessScreenState extends ConsumerState<CompanyAccessScreen> {
  final _code = TextEditingController();
  var _saving = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
    if (!canRequestCompanyAccess(type)) {
      return const Scaffold(body: Center(child: Text('Only a project manager can request company access.')));
    }
    final requests = ref.watch(accessRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Company access')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text('Enter the company code. Knowing the code does not grant access.', style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Company code', controller: _code),
          if (_message != null) ...[const SizedBox(height: AppSpacing.md), Text(_message!)],
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Submit request', isLoading: _saving, onPressed: _submit),
          const SizedBox(height: AppSpacing.lg),
          requests.when(
            loading: () => const AppLoader(),
            error: (error, _) => Text(_friendly(error, "We couldn't submit the access request.")),
            data: (rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rows.isEmpty) const Text('No request yet'),
                for (final request in rows) Text(request.status, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref.read(projectRepositoryProvider).requestAccess(userId: user.id, publicCode: _code.text);
      ref.invalidate(accessRequestsProvider);
      setState(() => _message = 'Request sent. Access starts after the company approves it.');
    } catch (error) {
      setState(() => _message = _friendly(error, "We couldn't submit the access request."));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
