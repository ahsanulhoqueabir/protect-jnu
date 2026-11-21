import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_providers.dart';
import '../../features/admin/presentation/admin_alert_screen.dart';
import '../../features/admin/presentation/admin_chat_screen.dart';
import '../../features/admin/presentation/admin_conversations_screen.dart';
import '../../features/admin/presentation/admin_history_screen.dart';
import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/admin/presentation/admin_reports_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/emergency_contacts/contacts_providers.dart';
import '../../features/emergency_contacts/presentation/contacts_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/media/presentation/camera_screen.dart';
import '../../features/media/presentation/gallery_screen.dart';
import '../../features/media/presentation/media_viewer_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sos/presentation/active_alert_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/status/domain/legal_content.dart';
import '../../features/status/presentation/legal_screen.dart';
import '../../features/status/presentation/status_screens.dart';
import 'app_shell.dart';
import 'routes.dart';

/// Decides where a user may go. Pure, so every path can be unit tested.
///
/// [hasRequiredContacts] is `null` while the contacts load, `false` until the student has saved
/// the required emergency contacts (FR-AUTH-10). Unverified users are never signed in: they are
/// sent to the OTP screen by the login flow.
String? resolveRedirect({
  required String location,
  required String? from,
  required bool isRestoring,
  required bool isSignedIn,
  bool? hasRequiredContacts = true,
  bool isAdmin = false,
}) {
  if (Routes.public.contains(location)) return null;
  if (isRestoring) return location == Routes.splash ? null : Routes.splash;

  final inEntryFlow = Routes.authOnly.contains(location) || location == Routes.splash;

  if (!isSignedIn) {
    if (Routes.authOnly.contains(location)) return null;
    if (inEntryFlow) return Routes.login;
    // Remember the deep link so it opens after signing in.
    return Uri(path: Routes.login, queryParameters: {'from': location}).toString();
  }
  // Signed in: wait for the contacts check, then force contact setup until it is satisfied.
  if (hasRequiredContacts == null) return location == Routes.splash ? null : Routes.splash;
  if (!hasRequiredContacts) return location == Routes.contacts ? null : Routes.contacts;
  // `from` must be an in-app path: a link like ?from=//evil.com is ignored.
  if (inEntryFlow) {
    final target = from != null && _isInternal(from) ? from : Routes.home;
    // A remembered admin deep link is not honoured for a normal user.
    return !isAdmin && Routes.isAdminOnly(Uri.parse(target).path) ? Routes.home : target;
  }
  // Admin screens: role `admin` only (D-078). The server refuses non-admins as well (403).
  if (!isAdmin && Routes.isAdminOnly(location)) return Routes.home;
  return null;
}

bool _isInternal(String path) => path.startsWith('/') && !path.startsWith('//');

/// Router as a provider so guards (`redirect`) can read other providers.
final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs redirect when these change, without rebuilding the router itself.
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(hasRequiredContactsProvider, (_, _) => refresh.value++);
  ref.listen(isAdminProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    errorBuilder: (_, _) => const NotFoundScreen(),
    redirect: (_, state) {
      final auth = ref.read(authProvider);
      return resolveRedirect(
        location: state.uri.path,
        from: state.uri.queryParameters['from'],
        isRestoring: auth.isLoading && !auth.hasValue,
        isSignedIn: auth.value != null,
        hasRequiredContacts: auth.value == null ? true : ref.read(hasRequiredContactsProvider),
        isAdmin: ref.read(isAdminProvider),
      );
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (_, state) {
          final email = state.uri.queryParameters['email'];
          return email == null
              ? const LoginScreen()
              : VerifyEmailScreen(email: email, justSent: state.uri.queryParameters['sent'] == '1');
        },
      ),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, state) {
          final email = state.uri.queryParameters['email'];
          return email == null ? const ForgotPasswordScreen() : ResetPasswordScreen(email: email);
        },
      ),
      GoRoute(path: Routes.contacts, builder: (_, _) => const ContactsScreen()),
      GoRoute(path: Routes.activeAlert, builder: (_, _) => const ActiveAlertScreen()),
      GoRoute(path: Routes.alertChat, builder: (_, _) => const ChatScreen()),
      GoRoute(path: Routes.media, builder: (_, _) => const GalleryScreen()),
      GoRoute(path: Routes.camera, builder: (_, _) => const CameraScreen()),
      GoRoute(
        path: Routes.mediaView,
        builder: (_, state) => MediaViewerScreen(mediaId: state.uri.queryParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.adminAlert,
        builder: (_, state) => AdminAlertScreen(alertId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.adminAlertChat,
        builder: (_, state) => AdminChatScreen(alertId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.adminConversations, builder: (_, _) => const AdminConversationsScreen()),
      GoRoute(path: Routes.adminHistory, builder: (_, _) => const AdminHistoryScreen()),
      GoRoute(path: Routes.adminUsers, builder: (_, _) => const AdminUsersScreen()),
      GoRoute(path: Routes.adminReports, builder: (_, _) => const AdminReportsScreen()),
      GoRoute(
        path: Routes.terms,
        builder: (_, _) =>
            const LegalScreen(title: 'Terms of Service', sections: LegalContent.terms),
      ),
      GoRoute(
        path: Routes.privacy,
        builder: (_, _) =>
            const LegalScreen(title: 'Privacy Policy', sections: LegalContent.privacy),
      ),
      GoRoute(path: Routes.offline, builder: (_, _) => const OfflineScreen()),
      GoRoute(path: Routes.maintenance, builder: (_, _) => const MaintenanceScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen())],
          ),
          // Last, so the student's three tabs keep their indexes; the shell shows it to admins only.
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.admin, builder: (_, _) => const AdminHomeScreen())],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
