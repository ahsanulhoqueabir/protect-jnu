/// All route paths in one place. Navigate with `context.push(Routes.x)`,
/// never with hard-coded strings.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  static const home = '/';
  static const contacts = '/contacts';
  static const activeAlert = '/alert';
  static const alertChat = '/alert/chat';
  static const media = '/media';
  static const camera = '/media/camera';
  static const mediaView = '/media/view';
  static const profile = '/profile';
  static const settings = '/settings';

  // Admin only (D-078). Every path starts with [adminPrefix]; `resolveRedirect` sends non-admins home.
  static const adminPrefix = '/admin';
  static const admin = '/admin';
  static const adminConversations = '/admin/conversations';
  static const adminHistory = '/admin/history';
  static const adminUsers = '/admin/users';
  static const adminReports = '/admin/reports';
  static const adminAlert = '/admin/alerts/:id';
  static const adminAlertChat = '/admin/alerts/:id/chat';

  static String adminAlertFor(String id) => '/admin/alerts/${Uri.encodeComponent(id)}';
  static String adminAlertChatFor(String id) => '${adminAlertFor(id)}/chat';

  static bool isAdminOnly(String location) =>
      location == adminPrefix || location.startsWith('$adminPrefix/');

  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';
  static const offline = '/offline';
  static const maintenance = '/maintenance';

  /// `/verify-email?email=...&sent=1` (`sent` = a code was just emailed, so the 60 s cooldown runs).
  static String verifyEmailFor(String email, {bool sent = false}) =>
      Uri(path: verifyEmail, queryParameters: {'email': email, if (sent) 'sent': '1'}).toString();

  static String mediaViewFor(String id) =>
      Uri(path: mediaView, queryParameters: {'id': id}).toString();

  static String resetPasswordFor(String email) =>
      Uri(path: resetPassword, queryParameters: {'email': email}).toString();

  /// Only for signed-out users; signed-in users are redirected away.
  static const authOnly = {login, register, verifyEmail, forgotPassword, resetPassword};

  /// Reachable whether or not the user is signed in.
  static const public = {terms, privacy, offline, maintenance};
}
