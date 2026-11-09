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
  static const profile = '/profile';
  static const settings = '/settings';

  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';
  static const offline = '/offline';
  static const maintenance = '/maintenance';

  /// `/verify-email?email=...&sent=1` (`sent` = a code was just emailed, so the 60 s cooldown runs).
  static String verifyEmailFor(String email, {bool sent = false}) =>
      Uri(path: verifyEmail, queryParameters: {'email': email, if (sent) 'sent': '1'}).toString();

  static String resetPasswordFor(String email) =>
      Uri(path: resetPassword, queryParameters: {'email': email}).toString();

  /// Only for signed-out users; signed-in users are redirected away.
  static const authOnly = {login, register, verifyEmail, forgotPassword, resetPassword};

  /// Reachable whether or not the user is signed in.
  static const public = {terms, privacy, offline, maintenance};
}
