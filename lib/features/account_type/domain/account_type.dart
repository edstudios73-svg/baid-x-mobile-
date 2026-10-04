import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

/// The five BAID X account types. They match the website exactly, so one account
/// works on both: [webRole] is the value in `account_roles.role`, and each type has
/// its own profile table on the shared backend.
enum AccountType {
  worker(
    'Professional',
    'Set up your trade profile and let clients and companies find and hire you.',
    'worker',
    'Mason, carpenter, electrician, plumber, technician, welder, painter',
    webRole: 'worker',
    table: 'worker_profiles',
    nameColumn: 'full_name',
    phoneColumn: 'phone_number',
  ),
  employer(
    'Client',
    'Hiring for your home? Find a trade, message them and keep a record of your hires.',
    'employer',
    'Homeowner, landlord, anyone hiring a professional',
    webRole: 'individual-employer',
    table: 'individual_employer_profiles',
    nameColumn: 'full_name',
    phoneColumn: 'phone_number',
  ),
  business(
    'Supplier',
    'List materials and equipment, receive orders and get paid safely.',
    'business',
    'Cement, steel, timber, hardware, equipment rental',
    webRole: 'business',
    table: 'business_profiles',
    nameColumn: 'business_name',
    phoneColumn: 'contact_phone',
  ),
  projectManager(
    'Project Manager',
    'Run sites for companies: tasks, reports, approvals and payments.',
    'project_manager',
    'Independent or company-linked project lead',
    webRole: 'project-manager',
    table: 'project_manager_profiles',
    nameColumn: 'full_name',
    phoneColumn: 'phone_number',
  ),
  company(
    'Company',
    'Post jobs, run projects, hire verified people and pay through escrow.',
    'company',
    'Construction, real estate, engineering or facilities company',
    webRole: 'company',
    table: 'company_profiles',
    nameColumn: 'company_name',
    phoneColumn: 'contact_phone',
  );

  const AccountType(
    this.label,
    this.summary,
    this.dbValue,
    this.examples, {
    required this.webRole,
    required this.table,
    required this.nameColumn,
    required this.phoneColumn,
  });

  final String label;
  final String summary;

  /// App route segment (kept stable for existing deep links).
  final String dbValue;
  final String examples;

  /// `account_roles.role` on the shared backend.
  final String webRole;
  final String table;
  final String nameColumn;
  final String phoneColumn;

  /// Accepts the app value (`project_manager`), the backend role
  /// (`project-manager`) or the enum name.
  static AccountType? fromDatabase(String? value) {
    if (value == null) return null;
    for (final type in AccountType.values) {
      if (type.dbValue == value || type.webRole == value || type.name == value) return type;
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
