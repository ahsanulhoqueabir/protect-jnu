import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/app/router/app_router.dart';
import 'package:protect_jnu/app/router/routes.dart';

String? redirect(
  String location, {
  String? from,
  bool restoring = false,
  bool signedIn = false,
  bool? contacts = true,
}) => resolveRedirect(
  location: location,
  from: from,
  isRestoring: restoring,
  isSignedIn: signedIn,
  hasRequiredContacts: contacts,
);

void main() {
  test('waits on splash while restoring the session', () {
    expect(redirect(Routes.home, restoring: true), Routes.splash);
    expect(redirect(Routes.splash, restoring: true), isNull);
  });

  test('signed-out users go to login and keep their deep link', () {
    expect(redirect(Routes.splash), Routes.login);
    expect(redirect(Routes.login), isNull);
    expect(redirect('/settings'), '/login?from=%2Fsettings');
  });

  test('signed-in users leave the entry flow, honoring safe deep links', () {
    expect(redirect(Routes.login, signedIn: true), Routes.home);
    expect(redirect(Routes.login, signedIn: true, from: '/profile'), '/profile');
    expect(redirect(Routes.login, signedIn: true, from: '//evil.com'), Routes.home);
    expect(redirect(Routes.login, signedIn: true, from: 'https://evil.com'), Routes.home);
    expect(redirect(Routes.home, signedIn: true), isNull);
  });

  test('unverified or signed-out users can reach the OTP and reset screens', () {
    expect(redirect(Routes.verifyEmail), isNull);
    expect(redirect(Routes.resetPassword), isNull);
    expect(redirect(Routes.forgotPassword), isNull);
  });

  test('protected screens are unreachable without a session', () {
    expect(redirect(Routes.contacts), '/login?from=%2Fcontacts');
    expect(redirect(Routes.profile), '/login?from=%2Fprofile');
  });

  test('signed-in users without 2 contacts are held on the contacts screen', () {
    expect(redirect(Routes.home, signedIn: true, contacts: false), Routes.contacts);
    expect(redirect(Routes.login, signedIn: true, contacts: false), Routes.contacts);
    expect(redirect(Routes.profile, signedIn: true, contacts: false), Routes.contacts);
    expect(redirect(Routes.contacts, signedIn: true, contacts: false), isNull);
  });

  test('waits on splash while contacts load, and the contacts screen stays reachable after', () {
    expect(redirect(Routes.home, signedIn: true, contacts: null), Routes.splash);
    expect(redirect(Routes.splash, signedIn: true, contacts: null), isNull);
    expect(redirect(Routes.contacts, signedIn: true), isNull);
  });

  test('public pages are always reachable', () {
    expect(redirect(Routes.terms), isNull);
    expect(redirect(Routes.offline, restoring: true), isNull);
  });
}
