import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

/// Account types stay separate. This is app vocabulary, not a database column.
enum AccountType {
  worker(
    'Worker',
    'Find work, build your professional profile and connect with opportunities.',
    'worker',
    'Mason, carpenter, electrician, plumber, technician, driver, designer, developer',
  ),
  employer(
    'Employer / Individual',
    'Find skilled professionals and manage the work you need done.',
    'employer',
    'Homeowner, individual client, person hiring a professional',
  ),
  business(
    'Business',
    'Sell or rent materials, equipment and business products.',
    'business',
    'Material supplier, hardware business, equipment rental, construction supplier',
  ),
  projectManager(
    'Project Manager',
    'Manage projects, workers, tasks, reports and project activity.',
    'project_manager',
    'Independent or company-linked project lead',
  ),
  company(
    'Company / Enterprise',
    'Manage teams, projects, workers and company operations.',
    'company',
    'Construction, engineering, logistics, or service company',
  );

  const AccountType(this.label, this.summary, this.dbValue, this.examples);

  final String label;
  final String summary;
  final String dbValue;
  final String examples;

  static AccountType? fromDatabase(String? value) {
    if (value == null) return null;
    for (final type in AccountType.values) {
      if (type.dbValue == value || type.name == value) return type;
    }
    return null;
  }

  String get setupPath => '/setup/$dbValue';
  String get homePath => '/role/$dbValue';
}

List<AppDestination> destinationsFor(AccountType? type) {
  AppDestination homeFor(AccountType? account) {
    return AppDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      path: account?.homePath ?? AppRoutes.home,
    );
  }

  const discover = AppDestination(
    label: 'Discover',
    icon: Icons.search,
    path: AppRoutes.discover,
  );
  const profile = AppDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    path: AppRoutes.profile,
  );
  const jobs = AppDestination(
    label: 'Jobs',
    icon: Icons.work_outline,
    path: AppRoutes.work,
  );
  const marketplace = AppDestination(
    label: 'Marketplace',
    icon: Icons.storefront_outlined,
    path: AppRoutes.marketplace,
  );
  const projects = AppDestination(
    label: 'Projects',
    icon: Icons.account_tree_outlined,
    path: AppRoutes.projects,
  );

  return switch (type) {
    AccountType.worker => [
      homeFor(type),
      jobs,
      discover,
      const AppDestination(
        label: 'Applications',
        icon: Icons.assignment_outlined,
        path: AppRoutes.applications,
      ),
      profile,
    ],
    AccountType.employer => [
      homeFor(type),
      const AppDestination(
        label: 'Workers',
        icon: Icons.people_outline,
        path: AppRoutes.workers,
      ),
      jobs,
      marketplace,
      profile,
    ],
    AccountType.business => [
      homeFor(type),
      const AppDestination(
        label: 'Listings',
        icon: Icons.inventory_2_outlined,
        path: AppRoutes.listings,
      ),
      marketplace,
      discover,
      profile,
    ],
    AccountType.projectManager => [
      homeFor(type),
      projects,
      const AppDestination(
        label: 'Tasks',
        icon: Icons.checklist_outlined,
        path: AppRoutes.tasks,
      ),
      const AppDestination(
        label: 'Reports',
        icon: Icons.description_outlined,
        path: AppRoutes.reports,
      ),
      profile,
    ],
    AccountType.company => [
      homeFor(type),
      projects,
      const AppDestination(
        label: 'Team',
        icon: Icons.groups_outlined,
        path: AppRoutes.team,
      ),
      jobs,
      profile,
    ],
    null => const [
      marketplace,
      discover,
      AppDestination(
        label: 'Sign in',
        icon: Icons.person_outline,
        path: AppRoutes.signIn,
      ),
    ],
  };
}
