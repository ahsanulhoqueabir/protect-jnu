import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protect_jnu/app/app.dart';
import 'package:protect_jnu/app/router/app_router.dart';
import 'package:protect_jnu/core/connectivity/connectivity_provider.dart';
import 'package:protect_jnu/core/network/api_exception.dart';
import 'package:protect_jnu/core/storage/storage_providers.dart';
import 'package:protect_jnu/core/storage/token_store.dart';
import 'package:protect_jnu/features/auth/data/auth_repository.dart';
import 'package:protect_jnu/features/auth/domain/user.dart';
import 'package:protect_jnu/features/emergency_contacts/data/contacts_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/domain/emergency_contact.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  const user = User(
    id: '1',
    fullName: 'Ada Lovelace',
    studentId: 'B210305040',
    email: 'ada@cse.jnu.ac.bd',
  );
  const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r', expiresAt: 4102444800);
  late MockAuthRepository auth;
  late FakeContactsRepository contacts;

  setUp(() {
    auth = MockAuthRepository();
    contacts = FakeContactsRepository();
    when(() => auth.login(email: 'ada@cse.jnu.ac.bd', password: 'secret-pass'))
        .thenAnswer((_) async => (tokens: tokens, user: user));
    when(() => auth.logout()).thenAnswer((_) async {});
  });

  // Small phone, so any layout overflow fails the test.
  Future<ProviderContainer> boot(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    AuthTokens? stored,
  }) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(instance),
        tokenStoreProvider.overrideWithValue(TokenStore(initial: stored)),
        isOnlineProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        contactsRepositoryProvider.overrideWithValue(contacts),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await tester.pumpAndSettle();
    return container;
  }

  GoRouter router(ProviderContainer c) => c.read(routerProvider);

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'ada@cse.jnu.ac.bd');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret-pass');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('sign in without contacts is held on contact setup, then reaches home', (
    tester,
  ) async {
    await boot(tester);
    expect(find.text('Welcome back'), findsOneWidget);

    await signIn(tester);
    expect(find.text('Emergency contacts'), findsWidgets);
    expect(find.text('Add 2 more to continue'), findsOneWidget);

    Future<void> addContact(String name, String phone) async {
      await tester.enterText(find.byType(TextFormField).at(0), name);
      await tester.enterText(find.byType(TextFormField).at(1), phone);
      await tester.ensureVisible(find.text('Add contact'));
      await tester.tap(find.text('Add contact'));
      await tester.pumpAndSettle();
    }

    // A phone the DB would reject is refused before any request.
    await addContact('Mum', '12345');
    expect(find.text('Use 01XXXXXXXXX or +8801XXXXXXXXX'), findsOneWidget);
    expect(contacts.rows, isEmpty);

    await addContact('Mum', '01712345678');
    expect(find.text('Add 1 more to continue'), findsOneWidget);
    await addContact('Dad', '+8801812345678');
    expect(find.text('Done'), findsOneWidget);
    expect(contacts.rows, hasLength(2));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome, Ada Lovelace'), findsOneWidget);
  });

  testWidgets('unverified login goes to the OTP screen and no protected screen opens', (
    tester,
  ) async {
    when(() => auth.login(email: 'ada@cse.jnu.ac.bd', password: 'secret-pass')).thenThrow(
      const CodedApiException(
        statusCode: 403,
        code: 'email_not_verified',
        message: 'Verify your email first.',
      ),
    );
    final container = await boot(tester);
    await signIn(tester);
    expect(find.text('Verify your email'), findsOneWidget);

    router(container).go('/profile');
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget); // bounced to login
  });

  testWidgets('returning user with a stored session and 2 contacts lands on home', (tester) async {
    contacts = FakeContactsRepository(const [
      EmergencyContact(id: 'a', name: 'Mum', phone: '01712345678'),
      EmergencyContact(id: 'b', name: 'Dad', phone: '01812345678'),
    ]);
    final container = await boot(
      tester,
      stored: tokens,
      prefs: {
        'user':
            '{"id":"1","full_name":"Ada Lovelace","student_id":"B210305040",'
            '"email":"ada@cse.jnu.ac.bd","phone":null,"role":"user"}',
      },
    );
    expect(find.textContaining('Welcome, Ada Lovelace'), findsOneWidget);

    for (final (path, expected) in const [
      ('/profile', 'B210305040'),
      ('/settings', 'Appearance'),
      ('/legal/terms', 'Terms of Service'),
      ('/offline', "You're offline"),
      ('/no/such/page', 'Page not found'),
    ]) {
      router(container).go(path);
      await tester.pumpAndSettle();
      expect(find.text(expected), findsWidgets, reason: path);
    }

    router(container).go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    verify(() => auth.logout()).called(1);
  });

  testWidgets('register screen validates student ID and university email', (tester) async {
    final container = await boot(tester);
    router(container).go('/register');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'B12');
    await tester.enterText(find.byType(TextFormField).at(2), 'ada@gmail.com');
    await tester.ensureVisible(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Student ID looks like B210305040'), findsOneWidget);
    expect(find.text('Use your Jagannath University email (ending in jnu.ac.bd)'), findsOneWidget);
    verifyZeroInteractions(auth);
  });
}
