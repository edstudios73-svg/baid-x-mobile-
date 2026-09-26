import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../shared/widgets/page_body.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
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

String _amountLabel(Object? amount, String currency) {
  final value = amount is num ? amount.toDouble() : double.tryParse('$amount');
  return value == null ? '$currency $amount'.trim() : Formatters.price(value, currency);
}

/// Small muted line for an empty section inside a detail page.
class _Quiet extends StatelessWidget {
  const _Quiet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.bodyMuted.copyWith(color: context.palette.textMuted));
  }
}

/// One input with an add button beside it, used for tasks, reports and expenses.
class _Composer extends StatelessWidget {
  const _Composer({required this.field, required this.label, required this.onAdd});

  final Widget field;
  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: AppSpacing.xs),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            textStyle: AppTextStyles.label,
          ),
          onPressed: onAdd,
          child: Text(label),
        ),
      ],
    );
  }
}

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final projects = ref.watch(projectListProvider);
    final company = ref.watch(myCompanyProvider).asData?.value;
    final canCreate = type == 'company' || type == 'project_manager';
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      bottomNavigationBar: canCreate
          ? BottomActionBar(child: AppButton(label: 'Create project', onPressed: () => context.push(AppRoutes.createProject)))
          : null,
      body: PageBody(
        children: [
          if (canRequestCompanyAccess(type) || company != null) ...[
            AppListGroup(
              children: [
                if (canRequestCompanyAccess(type))
                  AppListRow(
                    leading: const AppAvatar.icon(Icons.key_outlined, size: 40),
                    title: 'Request company access',
                    subtitle: 'Work on a company\'s projects once they approve you.',
                    onTap: () => context.push(AppRoutes.companyAccess),
                  ),
                if (company != null)
                  AppListRow(
                    leading: const AppAvatar.icon(Icons.forum_outlined, size: 40),
                    title: 'Company messages',
                    subtitle: company.name,
                    onTap: () => openContextConversation(ref, context, contextType: 'company', contextId: company.id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SectionHeader(title: 'Your projects'),
          projects.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: AppLoader(message: 'Loading projects'),
            ),
            error: (error, _) => AppErrorView(
              message: _friendly(error, "We couldn't load your projects."),
              onRetry: () => ref.invalidate(projectListProvider),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.account_tree_outlined,
                  title: 'No projects yet',
                  message: 'Projects you manage will appear here.',
                );
              }
              return AppListGroup(
                children: [
                  for (final project in rows)
                    AppListRow(
                      leading: AppAvatar(name: project.title),
                      title: project.title,
                      badge: StatusBadge.forStatus(project.status),
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
      bottomNavigationBar: BottomActionBar(child: AppButton(label: 'Save', isLoading: _saving, onPressed: _save)),
      body: PageBody(
        children: [
          const SizedBox(height: AppSpacing.xs),
          AppTextField(label: 'Title', controller: _title, hint: 'e.g. East Legon villa'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Summary', controller: _summary, maxLines: 5, minLines: 3),
          if (_error != null) ...[const SizedBox(height: AppSpacing.md), FormMessage(_error!)],
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
          final palette = context.palette;
          return PageBody(
            children: [
              Align(alignment: Alignment.centerLeft, child: StatusBadge.forStatus(record.status)),
              const SizedBox(height: AppSpacing.sm),
              Text(record.title, style: AppTextStyles.headline.copyWith(color: palette.text)),
              if (record.summary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(record.summary, style: AppTextStyles.body.copyWith(color: palette.text)),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Project messages',
                outlined: true,
                onPressed: () => openContextConversation(ref, context, contextType: 'project', contextId: id),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Tasks'),
              _TaskSection(projectId: id),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Members'),
              _MemberSection(projectId: id, companyId: record.companyId),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Reports'),
              _ReportSection(projectId: id),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Expenses'),
              _ExpenseSection(projectId: id),
              const SizedBox(height: AppSpacing.lg),
              BoostPanel(targetType: 'project', targetId: id, title: 'Boost project'),
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
    final me = ref.watch(authStateProvider).asData?.value?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        members.when(
          loading: () => const AppLoader(),
          error: (error, _) => Text(_friendly(error, "You don't have access to this project.")),
          data: (rows) {
            if (rows.isEmpty) return const _Quiet('No project members yet');
            return AppListGroup(
              children: [
                for (final member in rows) ...[
                  AppListRow(
                    leading: AppAvatar(name: '${member['display_name'] ?? member['member_role']}', size: 40),
                    title: '${member['display_name'] ?? statusLabel('${member['member_role']}')}',
                    subtitle: member['display_name'] == null ? null : statusLabel('${member['member_role']}'),
                  ),
                  if (me != '${member['profile_id']}')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                      child: ReviewForm(subjectId: '${member['profile_id']}', projectId: widget.projectId),
                    ),
                ],
              ],
            );
          },
        ),
        companyMembers.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (rows) {
            if (rows.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Company member'),
                    initialValue: _profileId,
                    items: [
                      for (final member in rows)
                        DropdownMenuItem(value: '${member['profile_id']}', child: Text(statusLabel('${member['member_role']}'))),
                    ],
                    onChanged: (value) => setState(() => _profileId = value),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Role on this project'),
                    initialValue: _role,
                    items: const [
                      DropdownMenuItem(value: 'worker', child: Text('Worker')),
                      DropdownMenuItem(value: 'project_manager', child: Text('Project manager')),
                    ],
                    onChanged: (value) => setState(() => _role = value ?? 'worker'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(label: 'Add member', outlined: true, onPressed: _add),
                  if (_error != null) ...[const SizedBox(height: AppSpacing.xs), FormMessage(_error!)],
                ],
              ),
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
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tasks.when(
          loading: () => const AppLoader(),
          error: (error, _) => Text(_friendly(error, "We couldn't load tasks.")),
          data: (rows) {
            if (rows.isEmpty) return const _Quiet('No tasks yet');
            final done = rows.where((task) => task['is_done'] == true).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$done of ${rows.length} done', style: AppTextStyles.caption.copyWith(color: palette.textMuted)),
                const SizedBox(height: AppSpacing.xs),
                AppListGroup(
                  children: [
                    for (final task in rows)
                      CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '${task['title'] ?? ''}',
                          style: AppTextStyles.body.copyWith(
                            color: task['is_done'] == true ? palette.textMuted : palette.text,
                            decoration: task['is_done'] == true ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        value: task['is_done'] == true,
                        onChanged: (value) async {
                          await ref.read(projectRepositoryProvider).setTaskDone(taskId: '${task['id']}', done: value ?? false);
                          ref.invalidate(_tasks);
                        },
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _Composer(
          field: AppTextField(label: 'New task', controller: _title),
          label: 'Add task',
          onAdd: () async {
            if (_title.text.trim().isEmpty) return;
            await ref.read(projectRepositoryProvider).addTask(projectId: widget.projectId, title: _title.text);
            _title.clear();
            ref.invalidate(_tasks);
          },
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        reports.when(
          loading: () => const AppLoader(),
          error: (error, _) => Text(_friendly(error, "We couldn't save this report.")),
          data: (rows) {
            if (rows.isEmpty) return const _Quiet('No reports yet');
            return AppListGroup(
              children: [
                for (final report in rows)
                  AppListRow(
                    leading: const AppAvatar.icon(Icons.description_outlined, size: 40),
                    title: '${report['body'] ?? ''}',
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _Composer(
          field: AppTextField(label: 'Report', controller: _body, maxLines: 4),
          label: 'Add report',
          onAdd: () async {
            final user = ref.read(authStateProvider).asData?.value;
            if (user == null || _body.text.trim().isEmpty) return;
            await ref.read(projectRepositoryProvider).addReport(projectId: widget.projectId, userId: user.id, body: _body.text);
            _body.clear();
            ref.invalidate(_reports);
          },
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
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        expenses.when(
          loading: () => const AppLoader(),
          error: (error, _) => Text(_friendly(error, "We couldn't load expenses.")),
          data: (rows) {
            if (rows.isEmpty) return const _Quiet('No expenses yet');
            return AppListGroup(
              children: [
                for (final expense in rows)
                  AppListRow(
                    leading: const AppAvatar.icon(Icons.receipt_outlined, size: 40),
                    title: '${expense['description'] ?? ''}'.isEmpty ? 'Expense' : '${expense['description']}',
                    trailing: Text(
                      _amountLabel(expense['amount'], '${expense['currency'] ?? ''}'),
                      style: AppTextStyles.label.copyWith(color: palette.text, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(label: 'Expense', controller: _description),
        const SizedBox(height: AppSpacing.xs),
        _Composer(
          field: AppTextField(
            label: 'Amount (GH₵)',
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          label: 'Add expense',
          onAdd: _add,
        ),
        if (_error != null) ...[const SizedBox(height: AppSpacing.xs), FormMessage(_error!)],
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
          final palette = context.palette;
          return PageBody(
            children: [
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  AppAvatar(name: record.name, size: 56),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.name, style: AppTextStyles.title.copyWith(color: palette.text)),
                        if (record.industry.isNotEmpty) Text(record.industry, style: AppTextStyles.bodyMuted.copyWith(color: palette.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppListGroup(
                children: [
                  AppListRow(
                    leading: const AppAvatar.icon(Icons.tag, size: 40),
                    title: 'Company code: ${record.publicCode}',
                    subtitle: 'Project managers use this to request access. It does not grant access by itself.',
                    subtitleLines: 2,
                  ),
                  AppListRow(
                    leading: const AppAvatar.icon(Icons.forum_outlined, size: 40),
                    title: 'Company messages',
                    onTap: () => openContextConversation(ref, context, contextType: 'company', contextId: record.id),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Access requests'),
              const _Requests(),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Members'),
              _Members(companyId: record.id),
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
        if (rows.isEmpty) return const _Quiet('No team members yet');
        return AppListGroup(
          children: [
            for (final member in rows)
              AppListRow(
                leading: AppAvatar(name: '${member['display_name'] ?? member['member_role']}', size: 40),
                title: '${member['display_name'] ?? statusLabel('${member['member_role']}')}',
                subtitle: member['display_name'] == null ? null : statusLabel('${member['member_role']}'),
                trailing: StatusBadge.forStatus('${member['status']}'),
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
        if (rows.isEmpty) return const _Quiet('No access requests');
        return AppListGroup(
          children: [
            for (final request in rows)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.key_outlined, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: Text('Project manager access', style: AppTextStyles.label.copyWith(color: context.palette.text))),
                        StatusBadge.forStatus(request.status),
                      ],
                    ),
                    if (request.status == 'pending') ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(label: 'Reject', outlined: true, onPressed: () => _review(ref, request.id, false)),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: AppButton(label: 'Approve', onPressed: () => _review(ref, request.id, true)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
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
      body: PageBody(
        children: [
          Text(
            'Enter the company code. Knowing the code does not grant access.',
            style: AppTextStyles.bodyMuted.copyWith(color: context.palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Company code', controller: _code),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.md),
            FormMessage(_message!, success: _message!.startsWith('Request sent')),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Submit request', isLoading: _saving, onPressed: _submit),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Your requests'),
          requests.when(
            loading: () => const AppLoader(),
            error: (error, _) => Text(_friendly(error, "We couldn't submit the access request.")),
            data: (rows) {
              if (rows.isEmpty) return const _Quiet('No request yet');
              return AppListGroup(
                children: [
                  for (final request in rows)
                    AppListRow(
                      leading: const AppAvatar.icon(Icons.key_outlined, size: 40),
                      title: 'Company access',
                      trailing: StatusBadge.forStatus(request.status),
                    ),
                ],
              );
            },
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
