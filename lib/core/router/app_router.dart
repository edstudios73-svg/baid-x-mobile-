import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/extra_screens.dart';
import '../../features/account/presentation/profile_pages.dart';
import '../../features/account/presentation/profile_pages_b.dart';
import '../../features/tabs/presentation/chat_screens.dart';
import '../../features/tabs/presentation/tab_screens.dart';
import '../../features/account/presentation/checklist_screens.dart';
import '../../features/home/presentation/member_home_screen.dart';
import '../../features/account_type/domain/account_type.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/screens/auth_flow_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/directory/presentation/directory_screen.dart';
import '../../features/jobs/presentation/job_screens.dart';
import '../../features/workers/presentation/worker_screens.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/marketplace/presentation/listing_screens.dart';
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/projects/presentation/project_screens.dart';
import '../../features/home/presentation/main_shell.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/billing/presentation/product_screens.dart';
import '../../features/trust/presentation/trust_screens.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../shared/providers/app_providers.dart';
import '../constants/app_routes.dart';
import 'route_guards.dart';
import '../../features/workspace/presentation/invites_approvals.dart';
import '../../features/workspace/presentation/workspace_screen.dart';

SessionGate _gateFor(AsyncValue<AuthUser?> auth) {
  if (auth.isLoading) return SessionGate.unknown;
  final user = auth.asData?.value;
  return sessionGateFor(
    signedIn: user != null,
    emailConfirmed: user?.emailConfirmed ?? false,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authStateProvider, (_, _) => refresh.value++)
    ..listen(accountProfileProvider, (_, _) => refresh.value++)
    ..listen(splashReleasedProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final profile = ref.read(accountProfileProvider);
      return guardRedirect(
        authLoading: auth.isLoading,
        gate: _gateFor(auth),
        profileLoading: profile.isLoading,
        accountType: profile.asData?.value?.accountType,
        path: state.matchedLocation,
        splashHold: !ref.read(splashReleasedProvider),
        profileFailed: profile.hasError && !profile.isLoading,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => AuthFlowScreen(start: AuthStart.signIn, group: state.uri.queryParameters['group']),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => AuthFlowScreen(group: state.uri.queryParameters['group']),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const AuthFlowScreen(start: AuthStart.reset),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountType,
        builder: (context, state) => const AuthFlowScreen(start: AuthStart.onboard),
      ),
      GoRoute(
        path: '/setup/:role',
        builder: (context, state) {
          final type = AccountType.fromDatabase(state.pathParameters['role']);
          return AuthFlowScreen(start: AuthStart.onboard, presetType: type);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.verification,
        builder: (context, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.billing,
        builder: (context, state) => const PlansBillingScreen(),
      ),
      GoRoute(
        path: AppRoutes.companyBilling,
        builder: (context, state) => const PlansBillingScreen(),
      ),
      GoRoute(
        path: AppRoutes.xid,
        builder: (context, state) => const XidScreen(),
      ),
      GoRoute(
        path: AppRoutes.promotions,
        builder: (context, state) => const PromotionScreen(),
      ),
      GoRoute(
        path: AppRoutes.verificationReview,
        builder: (context, state) => const ReviewerScreen(),
      ),
      // a chat thread and Post a job open full screen, like the website
      GoRoute(
        path: '/messages/:id',
        builder: (context, state) => ChatThreadScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.postJob,
        builder: (context, state) => const PostJobTabScreen(),
      ),
      // full screen like the website's checklist (no tab bar); its steps keep the bar
      GoRoute(
        path: AppRoutes.checklist,
        builder: (context, state) => const ChecklistScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => RoleShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (context, state) => const DirectoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/role/:role',
            builder: (context, state) {
              return const MemberHomeScreen();
            },
          ),
          GoRoute(
            path: '${AppRoutes.checklist}/step/:n',
            builder: (context, state) => ChecklistStepScreen(index: int.tryParse(state.pathParameters['n'] ?? '') ?? 0),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsScreen2(),
          ),
          GoRoute(
            path: AppRoutes.work,
            builder: (context, state) => const JobsTabScreen(),
          ),
          GoRoute(
            path: AppRoutes.myJobs,
            builder: (context, state) => const HiresTabScreen(),
          ),
          GoRoute(
            path: '/jobs/:id/apply',
            builder: (context, state) => ApplyScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/jobs/:id/applications',
            builder: (context, state) => JobApplicationsScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/jobs/:id',
            builder: (context, state) => JobDetailScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.applications,
            builder: (context, state) => const WorkTabScreen(),
          ),
          GoRoute(
            path: AppRoutes.workers,
            builder: (context, state) => const WorkersScreen(),
          ),
          GoRoute(
            path: AppRoutes.editWorker,
            builder: (context, state) => const EditWorkerScreen(),
          ),
          GoRoute(
            path: '/workers/:id',
            builder: (context, state) => WorkerDetailScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.listings,
            builder: (context, state) => const CatalogTabScreen(),
          ),
          GoRoute(
            path: AppRoutes.createListing,
            builder: (context, state) => const ListingFormScreen(),
          ),
          GoRoute(
            path: '/listings/:id/edit',
            builder: (context, state) => ListingFormScreen(listingId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/listings/:id',
            builder: (context, state) => ListingDetailScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/businesses/:id',
            builder: (context, state) => BusinessProfileScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.projects,
            builder: (context, state) => const ProjectsTabScreen(),
          ),
          GoRoute(
            path: AppRoutes.createProject,
            builder: (context, state) => const NewProjectScreen(),
          ),
          GoRoute(
            path: '/projects/:id',
            builder: (context, state) => ProjectDetailScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.companyAccess,
            builder: (context, state) => const TeamLinkScreen(),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: AppRoutes.team,
            builder: (context, state) => const TeamLinkScreen(),
          ),
          GoRoute(
            path: AppRoutes.marketplace,
            builder: (context, state) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: AppRoutes.messages,
            builder: (context, state) => const ChatsTabScreen(),
          ),
          // Profile menu pages (website js/wallet.js, billing.js, orgs.js, orders.js ...)
          GoRoute(path: AppRoutes.wallet, builder: (context, state) => const WalletScreen()),
          GoRoute(path: AppRoutes.growth, builder: (context, state) => const GrowthScreen()),
          GoRoute(path: AppRoutes.certs, builder: (context, state) => const CertsScreen()),
          GoRoute(path: AppRoutes.portfolio, builder: (context, state) => const PortfolioScreen()),
          GoRoute(path: AppRoutes.teamLink, builder: (context, state) => const TeamLinkScreen()),
          GoRoute(path: AppRoutes.payments, builder: (context, state) => const PaymentsScreen()),
          GoRoute(path: AppRoutes.equipment, builder: (context, state) => const SupplierScreen(kind: 'equipment')),
          GoRoute(path: AppRoutes.materials, builder: (context, state) => const SupplierScreen(kind: 'products')),
          GoRoute(path: AppRoutes.orders, builder: (context, state) => const OrdersScreen()),
          GoRoute(path: '${AppRoutes.orders}/:id', builder: (context, state) => OrderDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(path: AppRoutes.orgs, builder: (context, state) => const OrgsScreen()),
          GoRoute(path: AppRoutes.invites, builder: (context, state) => const InvitesScreen()),
          GoRoute(path: AppRoutes.approvals, builder: (context, state) => const ApprovalsScreen()),
          GoRoute(
            path: '${AppRoutes.workspace}/:id',
            builder: (context, state) => WorkspaceScreen(projectId: state.pathParameters['id']!, tab: state.uri.queryParameters['tab']),
          ),
          GoRoute(path: '${AppRoutes.orgs}/:id', builder: (context, state) => OrgDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(
            path: AppRoutes.inquiries,
            builder: (context, state) => const InquiriesTabScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
