import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/page_body.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
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
      body: PageBody(
        children: [
          AppSearchField(controller: _search, hint: 'Trade or skill, e.g. mason', onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.xs),
          AppSearchField(
            controller: _location,
            hint: 'Location',
            icon: Icons.place_outlined,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          workers.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: AppLoader(message: 'Loading professionals'),
            ),
            error: (error, _) => AppErrorView(
              message: ErrorHandler.toAppException(error).message,
              onRetry: () => ref.invalidate(workerSearchProvider(query)),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No professionals found.',
                  message: 'Listed workers will appear here.',
                );
              }
              return AppListGroup(
                children: [
                  for (final worker in rows)
                    AppListRow(
                      leading: AppAvatar(name: worker.name.isEmpty ? worker.trade : worker.name),
                      title: worker.name.isEmpty ? worker.trade : worker.name,
                      subtitle: [worker.trade, worker.location].where((part) => part.isNotEmpty).join(' · '),
                      badge: worker.verified ? const StatusBadge.verified() : null,
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
      bottomNavigationBar: mine
          ? BottomActionBar(
              child: AppButton(label: 'Edit profile', outlined: true, onPressed: () => context.push(AppRoutes.editWorker)),
            )
          : null,
      body: profile.when(
        loading: () => const AppLoader(message: 'Loading profile'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(workerProfileProvider(id))),
        data: (data) {
          if (data == null) {
            return const AppEmptyState(title: 'Profile not available', message: 'This worker is not listed.');
          }
          final palette = context.palette;
          final person = data['profile'] as Map<String, dynamic>;
          final worker = data['worker'] as Map<String, dynamic>?;
          final skills = (data['skills'] as List).cast<String>();
          final experience = (data['experience'] as List).cast<Map<String, dynamic>>();
          final reviews = ref.watch(subjectReviewsProvider(id));
          final name = '${person['display_name'] ?? 'Worker'}';
          final meta = ['${worker?['trade'] ?? ''}', '${person['location_label'] ?? ''}'].where((v) => v.isNotEmpty).join(' · ');
          final about = '${worker?['summary'] ?? person['headline'] ?? ''}';
          final availability = '${worker?['availability'] ?? ''}';
          return PageBody(
            children: [
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  AppAvatar(name: name, size: 64),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.title.copyWith(color: palette.text)),
                        if (meta.isNotEmpty) Text(meta, style: AppTextStyles.bodyMuted.copyWith(color: palette.textMuted)),
                        if (data['verified'] == true) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          const StatusBadge.verified(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (availability.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 18, color: palette.success),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text('Available: $availability', style: AppTextStyles.body.copyWith(color: palette.text))),
                  ],
                ),
              ],
              if (about.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'About'),
                Text(about, style: AppTextStyles.body.copyWith(color: palette.text)),
              ],
              if (skills.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Skills'),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [for (final skill in skills) Chip(label: Text(skill))],
                ),
              ],
              if (experience.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Experience'),
                AppListGroup(
                  children: [
                    for (final item in experience)
                      AppListRow(
                        leading: const AppAvatar.icon(Icons.work_history_outlined, size: 40),
                        title: '${item['title'] ?? ''}',
                        subtitle: '${item['organization'] ?? ''}',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              reviews.when(
                loading: () => const Text('Loading reviews'),
                error: (error, _) => Text(ErrorHandler.toAppException(error).message),
                data: (rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(title: rows.isEmpty ? 'No reviews yet' : '${rows.length} reviews'),
                    if (rows.isNotEmpty)
                      AppListGroup(
                        children: [
                          for (final review in rows)
                            AppListRow(
                              leading: _Rating(value: review.rating),
                              title: review.body.isEmpty ? 'No comment' : review.body,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.value});

  final num value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 18, color: AppColors.yellowPressed),
        const SizedBox(width: 2),
        Text('$value', style: AppTextStyles.label.copyWith(color: context.palette.text)),
      ],
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
