import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../messaging/presentation/messaging_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
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
        error: (error, _) => AppErrorView(
          message: 'Something went wrong. Unable to load your dashboard.',
          onRetry: () => ref.invalidate(_providerFor(type)),
        ),
        data: (data) => _DashboardBody(type: type, data: data),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      children: [
        _Header(title: name, subtitle: _subtitle(type, data)),
        const SizedBox(height: AppSpacing.md),
        Text('Profile ${data.completionPercent}% complete', style: AppTextStyles.bodyMuted),
        if (data.verified) ...[
          const SizedBox(height: AppSpacing.xs),
          const Text('Verified', style: AppTextStyles.label),
        ],
        if (type == AccountType.worker) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.reviewCount == 0
                ? 'No reviews yet'
                : data.reviewCount > 20
                ? '20+ reviews'
                : '${data.reviewCount} reviews',
            style: AppTextStyles.bodyMuted,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _Actions(actions: _actions(type)),
        const SizedBox(height: AppSpacing.lg),
        for (final section in _sections(type, data)) ...[
          Text(section.title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          if (section.items.isEmpty)
            AppEmptyState(title: section.emptyTitle, message: section.emptyMessage)
          else
            for (final item in section.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(item.detail.isEmpty ? item.title : '${item.title} · ${item.detail}'),
              ),
          const SizedBox(height: AppSpacing.md),
        ],
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

class _Header extends ConsumerWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationRealtimeProvider);
    final unread = ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;
    return Row(
      children: [
        const CircleAvatar(radius: 22, child: Icon(Icons.person_outline)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello', style: AppTextStyles.bodyMuted),
              Text(title, style: AppTextStyles.title),
              if (subtitle.isNotEmpty) Text(subtitle, style: AppTextStyles.bodyMuted),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.go(AppRoutes.messages),
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Messages',
        ),
        IconButton(
          onPressed: () => context.go(AppRoutes.notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
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

class _Actions extends StatelessWidget {
  const _Actions({required this.actions});

  final List<(String, String)> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final action in actions)
          OutlinedButton(
            onPressed: () => context.go(action.$2),
            child: Text(action.$1),
          ),
      ],
    );
  }
}

class _Section {
  const _Section(this.title, this.items, this.emptyTitle, this.emptyMessage);

  final String title;
  final List<ListedItem> items;
  final String emptyTitle;
  final String emptyMessage;
}

List<(String, String)> _actions(AccountType type) {
  return switch (type) {
    AccountType.worker => [
      ('Find jobs', AppRoutes.work),
      ('My applications', AppRoutes.applications),
      ('Edit profile', AppRoutes.editWorker),
      ('Marketplace', AppRoutes.marketplace),
    ],
    AccountType.employer => [
      ('Find a worker', AppRoutes.workers),
      ('Post a job', AppRoutes.postJob),
      ('My jobs', AppRoutes.myJobs),
      ('Marketplace', AppRoutes.marketplace),
    ],
    AccountType.business => [
      ('Create listing', AppRoutes.createListing),
      ('Manage listings', AppRoutes.listings),
      ('Marketplace', AppRoutes.marketplace),
      ('Edit profile', AccountType.business.setupPath),
    ],
    AccountType.projectManager => [
      ('My projects', AppRoutes.projects),
      ('Request company access', AppRoutes.companyAccess),
      ('Reports', AppRoutes.reports),
      ('Marketplace', AppRoutes.marketplace),
    ],
    AccountType.company => [
      ('Projects', AppRoutes.projects),
      ('Team', AppRoutes.team),
      ('Jobs', AppRoutes.work),
      ('Marketplace', AppRoutes.marketplace),
    ],
  };
}

List<_Section> _sections(AccountType type, RoleDashboard data) {
  return switch (type) {
    AccountType.worker => [
      _Section('Recommended jobs', data.jobs, 'No jobs yet', 'New opportunities will appear here when they match your skills.'),
      _Section('My applications', data.applications, 'No applications yet', 'Applications you send will appear here.'),
    ],
    AccountType.employer => [
      _Section('Recommended professionals', data.people, 'No professionals listed yet', 'Workers who list their profiles will appear here.'),
      _Section('My jobs', data.jobs, 'No jobs yet', 'Jobs you post will appear here.'),
    ],
    AccountType.business => [
      _Section('Active listings', data.listings, 'No listings yet', 'Your products, materials and equipment will appear here.'),
      const _Section('Listing performance', [], 'No activity yet', 'Listing performance will appear when activity is recorded.'),
    ],
    AccountType.projectManager => [
      _Section('Active projects', data.projects, 'No projects yet', 'Projects you manage will appear here.'),
      _Section('Tasks', data.tasks, 'No tasks yet', 'Tasks on your projects will appear here.'),
      _Section('Recent reports', data.reports, 'No reports yet', 'Reports you write will appear here.'),
      _Section('Expenses', data.expenses, 'No expenses yet', 'Expenses you submit will appear here.'),
    ],
    AccountType.company => [
      _Section('Active projects', data.projects, 'Your company workspace is ready.', 'Projects, team members and activity will appear here.'),
      _Section('Team', data.team, 'No team members yet', 'People on your company will appear here.'),
      _Section('Jobs', data.jobs, 'No jobs yet', 'Jobs your company posts will appear here.'),
    ],
  };
}
