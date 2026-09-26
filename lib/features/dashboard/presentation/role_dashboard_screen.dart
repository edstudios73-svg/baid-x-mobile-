import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../messaging/presentation/messaging_providers.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/quick_actions.dart';
import '../../../shared/widgets/role_header.dart';
import '../../../shared/widgets/section_header.dart';
import '../../account_type/domain/account_type.dart';
import '../domain/role_dashboard.dart';
import 'dashboard_providers.dart';

class RoleDashboardScreen extends ConsumerWidget {
  const RoleDashboardScreen({required this.type, super.key});

  final AccountType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(_providerFor(type));
    return Scaffold(
      body: dashboard.when(
        loading: () => const AppLoader(message: 'Loading your dashboard'),
        error: (error, _) {
          ErrorHandler.logSafe(error);
          return AppErrorView(
            message: 'Something went wrong. Unable to load your dashboard.',
            onRetry: () => ref.invalidate(_providerFor(type)),
          );
        },
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(_providerFor(type).future),
          child: _DashboardBody(type: type, data: data),
        ),
      ),
    );
  }
}

FutureProvider<RoleDashboard> _providerFor(AccountType type) {
  return switch (type) {
    AccountType.worker => workerDashboardProvider,
    AccountType.employer => employerDashboardProvider,
    AccountType.business => businessDashboardProvider,
    AccountType.projectManager => projectManagerDashboardProvider,
    AccountType.company => companyDashboardProvider,
  };
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.type, required this.data});

  final AccountType type;
  final RoleDashboard data;

  @override
  Widget build(BuildContext context) {
    final name = data.name.isEmpty ? type.label : data.name;
    final showVerifyPrompt = !data.verified && (type == AccountType.worker || type == AccountType.business);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(
          title: name,
          subtitle: _subtitle(type, data),
          verified: data.verified,
          completionPercent: data.completionPercent,
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (type == AccountType.worker) ...[
                    Text(
                      data.reviewCount == 0
                          ? 'No reviews yet'
                          : data.reviewCount > 20
                          ? '20+ reviews'
                          : '${data.reviewCount} reviews',
                      style: AppTextStyles.caption.copyWith(color: context.palette.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  QuickActionGrid(
                    actions: [
                      for (final action in _actions(type))
                        QuickAction(label: action.$1, icon: action.$3, onTap: () => context.go(action.$2)),
                    ],
                  ),
                  if (showVerifyPrompt) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppListGroup(
                      children: [
                        AppListRow(
                          leading: const AppAvatar.icon(Icons.verified_user_outlined, size: 40),
                          title: 'Get verified',
                          subtitle: 'Show people your identity has been checked.',
                          onTap: () => context.push(AppRoutes.verification),
                        ),
                      ],
                    ),
                  ],
                  for (final section in _sections(type, data)) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(
                      title: section.title,
                      actionLabel: section.route == null || section.items.isEmpty ? null : 'See all',
                      onAction: section.route == null ? null : () => context.go(section.route!),
                    ),
                    if (section.items.isEmpty)
                      _EmptySection(title: section.emptyTitle, message: section.emptyMessage)
                    else
                      AppListGroup(
                        children: [
                          for (final item in section.items.take(5))
                            AppListRow(
                              leading: AppAvatar(name: item.title, size: 40),
                              title: item.title,
                              subtitle: item.detail,
                              onTap: section.route == null ? null : () => context.go(section.route!),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _subtitle(AccountType type, RoleDashboard data) {
    return switch (type) {
      AccountType.worker => [data.trade, data.location, data.availability].where((v) => v.isNotEmpty).join(' · '),
      AccountType.business => [data.trade, data.location].where((v) => v.isNotEmpty).join(' · '),
      AccountType.projectManager => data.headline,
      AccountType.company => data.headline,
      AccountType.employer => data.location,
    };
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.label.copyWith(color: palette.text)),
            const SizedBox(height: AppSpacing.xxs),
            Text(message, style: AppTextStyles.caption.copyWith(color: palette.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.verified,
    required this.completionPercent,
  });

  final String title;
  final String subtitle;
  final bool verified;
  final int completionPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationRealtimeProvider);
    final unread = ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;
    return RoleHeader(
      greeting: _greeting(),
      name: title,
      subtitle: subtitle,
      verified: verified,
      completionPercent: completionPercent,
      actions: [
        IconButton(
          onPressed: () => context.go(AppRoutes.messages),
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Messages',
        ),
        IconButton(
          onPressed: () => context.go(AppRoutes.notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.yellow,
            textColor: AppColors.ink,
            label: Text(unread > 9 ? '9+' : '$unread'),
            child: Icon(unread > 0 ? Icons.notifications : Icons.notifications_none),
          ),
          tooltip: 'Notifications',
        ),
        IconButton(
          onPressed: () => context.go(AppRoutes.settings),
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
        ),
      ],
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

class _Section {
  const _Section(this.title, this.items, this.emptyTitle, this.emptyMessage, [this.route]);

  final String title;
  final List<ListedItem> items;
  final String emptyTitle;
  final String emptyMessage;

  /// Where "See all" goes. Null when there is no full list screen yet.
  final String? route;
}

List<(String, String, IconData)> _actions(AccountType type) {
  return switch (type) {
    AccountType.worker => [
      ('Find jobs', AppRoutes.work, Icons.work_outline),
      ('My applications', AppRoutes.applications, Icons.assignment_outlined),
      ('Edit profile', AppRoutes.editWorker, Icons.edit_outlined),
      ('Marketplace', AppRoutes.marketplace, Icons.storefront_outlined),
    ],
    AccountType.employer => [
      ('Find a worker', AppRoutes.workers, Icons.person_search_outlined),
      ('Post a job', AppRoutes.postJob, Icons.add_circle_outline),
      ('My jobs', AppRoutes.myJobs, Icons.work_outline),
      ('Marketplace', AppRoutes.marketplace, Icons.storefront_outlined),
    ],
    AccountType.business => [
      ('Create listing', AppRoutes.createListing, Icons.add_circle_outline),
      ('Manage listings', AppRoutes.listings, Icons.inventory_2_outlined),
      ('Marketplace', AppRoutes.marketplace, Icons.storefront_outlined),
      ('Edit profile', AccountType.business.setupPath, Icons.edit_outlined),
    ],
    AccountType.projectManager => [
      ('My projects', AppRoutes.projects, Icons.account_tree_outlined),
      ('Request company access', AppRoutes.companyAccess, Icons.key_outlined),
      ('Reports', AppRoutes.reports, Icons.description_outlined),
      ('Marketplace', AppRoutes.marketplace, Icons.storefront_outlined),
    ],
    AccountType.company => [
      ('Projects', AppRoutes.projects, Icons.account_tree_outlined),
      ('Team', AppRoutes.team, Icons.groups_outlined),
      ('Jobs', AppRoutes.work, Icons.work_outline),
      ('Marketplace', AppRoutes.marketplace, Icons.storefront_outlined),
    ],
  };
}

List<_Section> _sections(AccountType type, RoleDashboard data) {
  return switch (type) {
    AccountType.worker => [
      _Section('Recommended jobs', data.jobs, 'No jobs yet', 'New opportunities will appear here when they match your skills.', AppRoutes.work),
      _Section('My applications', data.applications, 'No applications yet', 'Applications you send will appear here.', AppRoutes.applications),
    ],
    AccountType.employer => [
      _Section('Recommended professionals', data.people, 'No professionals listed yet', 'Workers who list their profiles will appear here.', AppRoutes.workers),
      _Section('My jobs', data.jobs, 'No jobs yet', 'Jobs you post will appear here.', AppRoutes.myJobs),
    ],
    AccountType.business => [
      _Section('Active listings', data.listings, 'No listings yet', 'Your products, materials and equipment will appear here.', AppRoutes.listings),
      const _Section('Listing performance', [], 'No activity yet', 'Listing performance will appear when activity is recorded.'),
    ],
    AccountType.projectManager => [
      _Section('Active projects', data.projects, 'No projects yet', 'Projects you manage will appear here.', AppRoutes.projects),
      _Section('Tasks', data.tasks, 'No tasks yet', 'Tasks on your projects will appear here.', AppRoutes.tasks),
      _Section('Recent reports', data.reports, 'No reports yet', 'Reports you write will appear here.', AppRoutes.reports),
      _Section('Expenses', data.expenses, 'No expenses yet', 'Expenses you submit will appear here.'),
    ],
    AccountType.company => [
      _Section('Active projects', data.projects, 'Your company workspace is ready.', 'Projects, team members and activity will appear here.', AppRoutes.projects),
      _Section('Team', data.team, 'No team members yet', 'People on your company will appear here.', AppRoutes.team),
      _Section('Jobs', data.jobs, 'No jobs yet', 'Jobs your company posts will appear here.', AppRoutes.work),
    ],
  };
}
