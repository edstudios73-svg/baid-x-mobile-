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
import '../../trust/presentation/trust_providers.dart';
import 'worker_providers.dart';

class WorkersScreen extends ConsumerStatefulWidget {
  const WorkersScreen({super.key});

  @override
  ConsumerState<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends ConsumerState<WorkersScreen> {
  final _search = TextEditingController();
  final _location = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (query: _search.text, location: _location.text, offset: 0);
    final workers = ref.watch(workerSearchProvider(query));
    return Scaffold(
      appBar: AppBar(title: const Text('Workers')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(label: 'Trade or description', controller: _search, onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(label: 'Location', controller: _location, onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.md),
          workers.when(
            loading: () => const AppLoader(message: 'Loading professionals'),
            error: (error, _) => AppErrorView(
              message: ErrorHandler.toAppException(error).message,
              onRetry: () => ref.invalidate(workerSearchProvider(query)),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const AppEmptyState(title: 'No professionals found.', message: 'Listed workers will appear here.');
              }
              return Column(
                children: [
                  for (final worker in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(worker.name.isEmpty ? worker.trade : worker.name),
                      subtitle: Text([
                        if (worker.verified) 'Verified',
                        worker.trade,
                        worker.location,
                      ].where((part) => part.isNotEmpty).join(' · ')),
                      onTap: () => context.push('/workers/${worker.id}'),
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

class WorkerDetailScreen extends ConsumerWidget {
  const WorkerDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(workerProfileProvider(id));
    final mine = ref.watch(authStateProvider).asData?.value?.id == id;
    return Scaffold(
      appBar: AppBar(title: const Text('Worker')),
      body: profile.when(
        loading: () => const AppLoader(message: 'Loading profile'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(workerProfileProvider(id))),
        data: (data) {
          if (data == null) {
            return const AppEmptyState(title: 'Profile not available', message: 'This worker is not listed.');
          }
          final person = data['profile'] as Map<String, dynamic>;
          final worker = data['worker'] as Map<String, dynamic>?;
          final skills = (data['skills'] as List).cast<String>();
          final experience = (data['experience'] as List).cast<Map<String, dynamic>>();
          final reviews = ref.watch(subjectReviewsProvider(id));
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('${person['display_name'] ?? 'Worker'}', style: AppTextStyles.title),
              Text('${worker?['trade'] ?? ''} · ${person['location_label'] ?? ''}', style: AppTextStyles.bodyMuted),
              if (data['verified'] == true) const Text('Verified', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.md),
              Text('${worker?['summary'] ?? person['headline'] ?? ''}', style: AppTextStyles.body),
              if ('${worker?['availability'] ?? ''}'.isNotEmpty)
                Text('Available: ${worker?['availability']}', style: AppTextStyles.bodyMuted),
              if (skills.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Skills', style: AppTextStyles.label),
                Text(skills.join(', ')),
              ],
              if (experience.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Experience', style: AppTextStyles.label),
                for (final item in experience) Text('${item['title'] ?? ''} · ${item['organization'] ?? ''}'),
              ],
              const SizedBox(height: AppSpacing.md),
              reviews.when(
                loading: () => const Text('Loading reviews'),
                error: (error, _) => Text(ErrorHandler.toAppException(error).message),
                data: (rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rows.isEmpty ? 'No reviews yet' : '${rows.length} reviews', style: AppTextStyles.bodyMuted),
                    for (final review in rows) Text('${review.rating} · ${review.body}', style: AppTextStyles.body),
                  ],
                ),
              ),
              if (mine) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: 'Edit profile', outlined: true, onPressed: () => context.push(AppRoutes.editWorker)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class EditWorkerScreen extends ConsumerStatefulWidget {
  const EditWorkerScreen({super.key});

  @override
  ConsumerState<EditWorkerScreen> createState() => _EditWorkerScreenState();
}

class _EditWorkerScreenState extends ConsumerState<EditWorkerScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _headline = TextEditingController();
  final _trade = TextEditingController();
  final _availability = TextEditingController();
  final _summary = TextEditingController();
  final _years = TextEditingController();
  final _skills = TextEditingController();
  var _listed = false;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _location, _headline, _trade, _availability, _summary, _years, _skills]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(label: 'Name', controller: _name),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Location', controller: _location),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Headline', controller: _headline),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Primary skill', controller: _trade),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Availability', controller: _availability),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Description', controller: _summary),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Years of experience', controller: _years, keyboardType: TextInputType.number),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Other skills, separated by commas', controller: _skills),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('List my profile'),
            subtitle: const Text('Listed profiles can be found by people hiring.'),
            value: _listed,
            onChanged: (value) => setState(() => _listed = value),
          ),
          if (_error != null) Text(_error!, style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    final yearsText = _years.text.trim();
    final years = int.tryParse(yearsText);
    if (yearsText.isNotEmpty && (years == null || years < 0)) {
      setState(() => _error = 'Enter years of experience as a whole number.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(workerRepositoryProvider).saveProfile(
        userId: user.id,
        name: _name.text,
        location: _location.text,
        headline: _headline.text,
        trade: _trade.text,
        availability: _availability.text,
        summary: _summary.text,
        years: years,
        listed: _listed,
        skills: _skills.text.split(','),
      );
      ref.invalidate(workerProfileProvider(user.id));
      if (mounted) context.pop();
    } catch (error) {
      setState(() => _error = ErrorHandler.toAppException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
