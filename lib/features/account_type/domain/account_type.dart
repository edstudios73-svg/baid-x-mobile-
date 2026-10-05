import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

/// The five BAID X account types. They match the website exactly, so one account
/// works on both: [webRole] is the value in `account_roles.role`, and each type has
/// its own profile table on the shared backend.
enum AccountType {
  worker(
    'Professional',
    'Set up your personal trade profile and let clients and companies find and hire you.',
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
    'List products, equipment and materials, and quote on what projects need.',
    'business',
    'Cement, steel, timber, hardware, equipment rental',
    webRole: 'business',
    table: 'business_profiles',
    nameColumn: 'business_name',
    phoneColumn: 'contact_phone',
  ),
  projectManager(
    'Project Manager',
    'Run delivery on company projects: tasks, teams, reports and resource requests.',
    'project_manager',
    'Independent or company-linked project lead',
    webRole: 'project-manager',
    table: 'project_manager_profiles',
    nameColumn: 'full_name',
    phoneColumn: 'phone_number',
  ),
  company(
    'Company',
    'Post jobs, build projects and hire verified professionals, project managers and suppliers.',
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

  /// The order the website shows account types in.
  static const pickerOrder = [worker, company, projectManager, business, employer];

  String get setupPath => '/setup/$dbValue';
  String get homePath => '/role/$dbValue';
}

/// Bottom tabs per account type, the same tabs and order as the website
/// (js/common.js NAV): every member has Home, a discovery tab, their main work
/// tab, Chats and Profile.
List<AppDestination> destinationsFor(AccountType? type) {
  AppDestination home(AccountType? t) => AppDestination(label: 'Home', icon: Icons.home_outlined, path: t?.homePath ?? AppRoutes.discover);
  const chats = AppDestination(label: 'Chats', icon: Icons.chat_bubble_outline, path: AppRoutes.messages);
  const profile = AppDestination(label: 'Profile', icon: Icons.person_outline, path: AppRoutes.profile);
  const discover = AppDestination(label: 'Discover', icon: Icons.explore_outlined, path: AppRoutes.discover);
  const projects = AppDestination(label: 'Projects', icon: Icons.folder_outlined, path: AppRoutes.projects);

  return switch (type) {
    AccountType.worker => [
      home(type),
      const AppDestination(label: 'Jobs', icon: Icons.explore_outlined, path: AppRoutes.work),
      const AppDestination(label: 'Work', icon: Icons.work_outline, path: AppRoutes.applications),
      chats,
      profile,
    ],
    AccountType.company => [home(type), const AppDestination(label: 'Workforce', icon: Icons.explore_outlined, path: AppRoutes.discover), projects, chats, profile],
    AccountType.projectManager => [home(type), discover, projects, chats, profile],
    AccountType.business => [
      home(type),
      discover,
      const AppDestination(label: 'Catalog', icon: Icons.inventory_2_outlined, path: AppRoutes.listings),
      const AppDestination(label: 'Inquiries', icon: Icons.mail_outline, path: AppRoutes.inquiries),
      profile,
    ],
    AccountType.employer => [
      home(type),
      discover,
      const AppDestination(label: 'Hires', icon: Icons.how_to_reg_outlined, path: AppRoutes.myJobs),
      chats,
      profile,
    ],
    null => const [
      AppDestination(label: 'Home', icon: Icons.home_outlined, path: AppRoutes.discover),
      chats,
      profile,
    ],
  };
}
