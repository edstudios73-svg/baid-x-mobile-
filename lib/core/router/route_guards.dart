import '../constants/app_routes.dart';

enum SessionGate { unknown, signedOut, unverified, verified }

const publicPaths = <String>{
  AppRoutes.splash,
  AppRoutes.marketplace,
  AppRoutes.discover,
  AppRoutes.signIn,
  AppRoutes.signUp,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
  AppRoutes.messages, // signed-out visitors see a "sign in to view chats" screen, like the website
  AppRoutes.profile, // and the guest profile with the two sign-in options
};

bool isRolePath(String path) => path.startsWith('/role/') || path.startsWith('/setup/');

/// Open jobs and listed worker profiles stay readable without an account.
bool isPublicBrowse(String path) {
  if (publicPaths.contains(path) || path == AppRoutes.work || path == AppRoutes.workers || path == AppRoutes.discover) {
    return true;
  }
  if (path.startsWith('/jobs/') &&
      path != AppRoutes.postJob &&
      !path.endsWith('/apply') &&
      !path.endsWith('/applications')) {
    return true;
  }
  if (path.startsWith('/workers/') && path != AppRoutes.editWorker) return true;
  if (path.startsWith('/businesses/')) return true;
  if (path.startsWith('/listings/') &&
      path != AppRoutes.createListing &&
      !path.endsWith('/edit')) {
    return true;
  }
  return false;
}

String roleHomeFor(String? accountType) => '/role/${accountType ?? ''}';

/// Public pages stay open. A verified user without a type is sent to selection.
String? guardRedirect({
  required bool authLoading,
  required SessionGate gate,
  required bool profileLoading,
  required String? accountType,
  required String path,
  bool splashHold = false,
}) {
  if (splashHold && path == AppRoutes.splash) return null;
  if (authLoading || gate == SessionGate.unknown) {
    return path == AppRoutes.splash ? null : AppRoutes.splash;
  }

  final isPublic = isPublicBrowse(path);
  switch (gate) {
    case SessionGate.unknown:
      return AppRoutes.splash;
    case SessionGate.signedOut:
      // the website opens on the member directory for visitors
      if (path == AppRoutes.splash) return AppRoutes.discover;
      return isPublic ? null : AppRoutes.signIn;
    case SessionGate.unverified:
      if (path == AppRoutes.splash) return AppRoutes.marketplace;
      if (path == AppRoutes.emailVerification ||
          path == AppRoutes.marketplace ||
          path == AppRoutes.discover) {
        return null;
      }
      return AppRoutes.emailVerification;
    case SessionGate.verified:
      if (profileLoading && path == AppRoutes.splash) return null;
      if (profileLoading) return null;
      final home = accountType == null ? AppRoutes.accountType : roleHomeFor(accountType);
      if (accountType == null) {
        // account setup (/setup/<type>) creates the profile, so it stays open until then
        if (path == AppRoutes.splash || path == AppRoutes.emailVerification || path.startsWith('/role/')) {
          return AppRoutes.accountType;
        }
        return null;
      }
      if (path == AppRoutes.splash ||
          path == AppRoutes.home ||
          path == AppRoutes.accountType ||
          path == AppRoutes.emailVerification) {
        return home;
      }
      if (path.startsWith('/setup/')) return home; // the profile already exists
      if (path.startsWith('/role/') && path != home) return home;
      return null;
  }
}

SessionGate sessionGateFor({required bool signedIn, required bool emailConfirmed}) {
  if (!signedIn) return SessionGate.signedOut;
  if (!emailConfirmed) return SessionGate.unverified;
  return SessionGate.verified;
}
