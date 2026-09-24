import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/router/auth_gate.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/job_repository.dart';
import '../../messaging/presentation/messaging_screens.dart';
import '../../trust/presentation/trust_screens.dart';
import '../../billing/presentation/product_screens.dart';
import '../domain/job_rules.dart';
import 'job_providers.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _search = TextEditingController();
  final _location = TextEditingController();
  var _offset = 0;
  final _jobs = <JobRecord>[];

  JobQuery get _query => (search: _search.text, location: _location.text, offset: _offset);

  @override
  void dispose() {
    _search.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(openJobsProvider(_query));
    return Scaffold(
      appBar: AppBar(title: const Text('Jobs')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(label: 'Search title', controller: _search, onChanged: (_) => _reset()),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(label: 'Location', controller: _location, onChanged: (_) => _reset()),
          const SizedBox(height: AppSpacing.md),
          page.when(
            loading: () => const AppLoader(message: 'Loading jobs'),
            error: (error, _) => AppErrorView(
              message: ErrorHandler.toAppException(error).message,
              onRetry: () => ref.invalidate(openJobsProvider(_query)),
            ),
            data: (rows) {
              final shown = [..._jobs, ...rows];
              if (shown.isEmpty) {
                return const AppEmptyState(
                  title: 'No jobs available right now.',
                  message: 'Open jobs from BAID X will show here.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final job in shown) _JobTile(job: job),
                  if (rows.length == jobPageSize)
                    TextButton(
                      onPressed: () => setState(() {
                        _jobs.addAll(rows);
                        _offset += jobPageSize;
                      }),
                      child: const Text('Load more'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _reset() => setState(() {
    _jobs.clear();
    _offset = 0;
  });
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job});

  final JobRecord job;

  @override
  Widget build(BuildContext context) {
    final preview = job.description.length > 80 ? '${job.description.substring(0, 80)}…' : job.description;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(job.title, style: AppTextStyles.label),
      subtitle: Text([job.locationLabel, job.status, preview].where((part) => part.isNotEmpty).join(' · ')),
      onTap: () => context.push('/jobs/${job.id}'),
    );
  }
}

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobDetailProvider(id));
    final user = ref.watch(authStateProvider).asData?.value;
    final accountType = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final applied = ref.watch(hasAppliedProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Job')),
      body: job.when(
        loading: () => const AppLoader(message: 'Loading job'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(jobDetailProvider(id))),
        data: (record) {
          if (record == null) {
            return const AppEmptyState(title: 'Job not available', message: 'This job is closed or not public.');
          }
          final decision = decideApply(
            signedIn: user != null && user.emailConfirmed,
            accountType: accountType,
            jobStatus: record.status,
            isOwner: user?.id == record.ownerId,
            alreadyApplied: applied.asData?.value ?? false,
          );
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(record.title, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Text('${record.locationLabel} · ${record.status}', style: AppTextStyles.bodyMuted),
              if (record.createdAt != null)
                Text('Posted ${record.createdAt!.toLocal().toString().split(' ').first}', style: AppTextStyles.bodyMuted),
              const SizedBox(height: AppSpacing.md),
              Text(record.description.isEmpty ? 'No description yet.' : record.description, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.lg),
              _Action(decision: decision, jobId: id),
              if (user?.id == record.ownerId) ...[
                const SizedBox(height: AppSpacing.lg),
                BoostPanel(targetType: 'job', targetId: id, title: 'Boost job'),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Action extends ConsumerWidget {
  const _Action({required this.decision, required this.jobId});

  final ApplyDecision decision;
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (decision) {
      ApplyDecision.allowed => AppButton(
        label: 'Apply',
        onPressed: () => requireAuthentication(context, ref, () => context.push('/jobs/$jobId/apply')),
      ),
      ApplyDecision.needsSignIn => AppButton(
        label: 'Apply',
        onPressed: () => requireAuthentication(context, ref, () {}),
      ),
      ApplyDecision.ownJob => AppButton(label: 'Manage job', onPressed: () => context.push('/jobs/$jobId/applications')),
      ApplyDecision.alreadyApplied => const Text('You already applied to this job.'),
      ApplyDecision.closed => const Text('This job is not open for applications.'),
      ApplyDecision.notWorker => const Text('Only worker accounts can apply.'),
    };
  }
}

class ApplyScreen extends ConsumerStatefulWidget {
  const ApplyScreen({required this.jobId, super.key});

  final String jobId;

  @override
  ConsumerState<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends ConsumerState<ApplyScreen> {
  final _message = TextEditingController();
  var _review = false;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_review ? 'Review application' : 'Apply')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_review) AppTextField(label: 'Message', controller: _message) else Text(_message.text.isEmpty ? 'No message.' : _message.text),
            if (_error != null) ...[const SizedBox(height: AppSpacing.md), Text(_error!, style: AppTextStyles.bodyMuted)],
            const Spacer(),
            if (_review)
              AppButton(label: 'Back', outlined: true, onPressed: _saving ? null : () => setState(() => _review = false)),
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: _review ? 'Submit' : 'Review', isLoading: _saving, onPressed: _review ? _submit : () => setState(() => _review = true)),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(applicationRepositoryProvider).submit(jobId: widget.jobId, userId: user.id, message: _message.text);
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(hasAppliedProvider(widget.jobId));
      if (mounted) context.go(AppRoutes.applications);
    } catch (error) {
      setState(() => _error = ErrorHandler.toAppException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(label: 'Title', controller: _title),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Description', controller: _description),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Location', controller: _location),
          if (_error != null) ...[const SizedBox(height: AppSpacing.md), Text(_error!, style: AppTextStyles.bodyMuted)],
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Post job', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final problem = validateJobDraft(title: _title.text, description: _description.text, location: _location.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref.read(jobRepositoryProvider).createJob(
        userId: user.id,
        title: _title.text,
        description: _description.text,
        location: _location.text,
      );
      ref.invalidate(myJobsProvider);
      if (mounted) context.go('/jobs/$id');
    } catch (error) {
      setState(() => _error = ErrorHandler.toAppException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class MyJobsScreen extends ConsumerWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(myJobsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My jobs')),
      body: jobs.when(
        loading: () => const AppLoader(message: 'Loading your jobs'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(myJobsProvider)),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(title: 'No jobs yet', message: 'Jobs you post will appear here.');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final job in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(job.title),
                  subtitle: Text('${job.status} · ${job.applicationCount} applications'),
                  onTap: () => context.push('/jobs/${job.id}/applications'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(myApplicationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      body: applications.when(
        loading: () => const AppLoader(message: 'Loading applications'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(myApplicationsProvider)),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(title: "You haven't applied to any jobs yet.", message: 'Applications you send will appear here.');
          }
          return ListView(
            children: [
              for (final application in rows) ...[
                ListTile(
                  title: Text(application.jobTitle.isEmpty ? 'Job' : application.jobTitle),
                  subtitle: Text('${application.status} · ${application.createdAt?.toLocal().toString().split(' ').first ?? ''}'),
                  trailing: TextButton(
                    onPressed: () => openContextConversation(ref, context, contextType: 'job_application', contextId: application.id),
                    child: const Text('Message'),
                  ),
                  onTap: () => context.push('/jobs/${application.jobId}'),
                ),
                if (application.status == 'accepted' && application.ownerProfileId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ReviewForm(subjectId: application.ownerProfileId),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class JobApplicationsScreen extends ConsumerWidget {
  const JobApplicationsScreen({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(jobApplicationsProvider(jobId));
    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      body: applications.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(jobApplicationsProvider(jobId))),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(title: 'No applications yet', message: 'Applications to this job will appear here.');
          }
          return ListView(
            children: [
              for (final application in rows) ...[
                ListTile(
                  title: Text(application.status),
                  subtitle: Text(application.message.isEmpty ? 'No message' : application.message),
                  trailing: TextButton(
                    onPressed: () => openContextConversation(ref, context, contextType: 'job_application', contextId: application.id),
                    child: const Text('Message'),
                  ),
                ),
                if (application.status == 'accepted' && application.workerProfileId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ReviewForm(subjectId: application.workerProfileId),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
