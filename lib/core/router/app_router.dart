import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account_type/domain/account_type.dart';
import '../../features/account_type/presentation/account_type_screen.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/jobs/presentation/job_screens.dart';
import '../../features/workers/presentation/worker_screens.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/dashboard/presentation/role_dashboard_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/role_onboarding_screen.dart';
import '../../features/marketplace/presentation/listing_screens.dart';
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/projects/presentation/project_screens.dart';
import '../../features/home/presentation/main_shell.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/billing/presentation/billing_screen.dart';
import '../../features/billing/presentation/product_screens.dart';
import '../../features/trust/presentation/trust_screens.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../shared/providers/app_providers.dart';
import '../../features/messaging/presentation/messaging_screens.dart';
import '../constants/app_routes.dart';
import 'route_guards.dart';

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
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
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
        builder: (context, state) => const AccountTypeScreen(),
      ),
      GoRoute(
        path: '/setup/:role',
        builder: (context, state) {
          final type = AccountType.fromDatabase(state.pathParameters['role']);
          return RoleOnboardingScreen(type: type ?? AccountType.worker);
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
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: AppRoutes.companyBilling,
        builder: (context, state) => const CompanyBillingScreen(),
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
      ShellRoute(
        builder: (context, state, child) => RoleShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (context, state) => const DiscoverScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/role/:role',
            builder: (context, state) {
              final type = AccountType.fromDatabase(state.pathParameters['role']);
              return RoleDashboardScreen(type: type ?? AccountType.worker);
            },
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.work,
            builder: (context, state) => const JobsScreen(),
          ),
          GoRoute(
            path: AppRoutes.myJobs,
            builder: (context, state) => const MyJobsScreen(),
          ),
          GoRoute(
            path: AppRoutes.postJob,
            builder: (context, state) => const PostJobScreen(),
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
            builder: (context, state) => const ApplicationsScreen(),
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
            builder: (context, state) => const MyListingsScreen(),
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
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: AppRoutes.createProject,
            builder: (context, state) => const CreateProjectScreen(),
          ),
          GoRoute(
            path: '/projects/:id',
            builder: (context, state) => ProjectDetailScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.companyAccess,
            builder: (context, state) => const CompanyAccessScreen(),
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
            builder: (context, state) => const TeamScreen(),
          ),
          GoRoute(
            path: AppRoutes.marketplace,
            builder: (context, state) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: AppRoutes.messages,
            builder: (context, state) => const InboxScreen(),
          ),
          GoRoute(
            path: '/messages/:id',
            builder: (context, state) => ConversationScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
