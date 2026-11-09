import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/app/app.dart';
import 'package:protect_jnu/core/connectivity/connectivity_provider.dart';
import 'package:protect_jnu/core/storage/storage_providers.dart';
import 'package:protect_jnu/core/storage/token_store.dart';
import 'package:protect_jnu/features/auth/data/auth_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/data/contacts_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/domain/emergency_contact.dart';
import 'package:protect_jnu/features/sos/data/alert_repository.dart';
import 'package:protect_jnu/features/sos/data/location_service.dart';
import 'package:protect_jnu/features/sos/domain/sos_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

void main() {
  const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r', expiresAt: 4102444800);
  const fix = GeoFix(latitude: 23.7, longitude: 90.4, accuracy: 8);
  const cancelLabel = "I'm safe, cancel the alert";

  /// Signed-in student with 2 contacts on a 360x700 phone, landing on home.
  Future<void> boot(
    WidgetTester tester, {
    required FakeAlertRepository alerts,
    GeoFix? location = fix,
  }) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'user':
          '{"id":"1","full_name":"Ada Lovelace","student_id":"B210305040",'
          '"email":"ada@cse.jnu.ac.bd","phone":null,"role":"user"}',
    });
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        tokenStoreProvider.overrideWithValue(TokenStore(initial: tokens)),
        isOnlineProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        contactsRepositoryProvider.overrideWithValue(
          FakeContactsRepository(const [
            EmergencyContact(id: 'a', name: 'Mum', phone: '01712345678'),
            EmergencyContact(id: 'b', name: 'Dad', phone: '01812345678'),
          ]),
        ),
        alertRepositoryProvider.overrideWithValue(alerts),
        locationServiceProvider.overrideWithValue(FakeLocationService(location)),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await tester.pumpAndSettle();
  }

  Future<void> holdSos(WidgetTester tester, Duration d) async {
    final g = await tester.startGesture(tester.getCenter(find.text('SOS')));
    await tester.pump(d);
    await g.up();
    await tester.pump();
  }

  SosAlert alertWith(String id, AlertStatus status) =>
      SosAlert(id: id, status: status, startedAt: DateTime.utc(2026, 11, 9));

  testWidgets('short press does nothing: no countdown and no alert', (tester) async {
    final alerts = FakeAlertRepository();
    await boot(tester, alerts: alerts);
    await holdSos(tester, const Duration(milliseconds: 900));
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const Key('sos-countdown')), findsNothing);
    expect(find.text('SOS'), findsOneWidget);
    expect(alerts.created, isEmpty);
  });

  testWidgets('hold 2 s opens the cancel window; Cancel creates no alert', (tester) async {
    final alerts = FakeAlertRepository();
    await boot(tester, alerts: alerts);
    await holdSos(tester, const Duration(milliseconds: 2100));
    expect(find.byKey(const Key('sos-countdown')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('sos-cancel')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('SOS'), findsOneWidget);
    expect(alerts.created, isEmpty);
  });

  testWidgets('full flow: alert created after the window, status follows Realtime, SOS returns when closed', (
    tester,
  ) async {
    final alerts = FakeAlertRepository();
    await boot(tester, alerts: alerts);
    await holdSos(tester, const Duration(milliseconds: 2100));
    await tester.pump(const Duration(seconds: 4));
    expect(alerts.created, isEmpty, reason: 'nothing is sent while the window is open');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(alerts.created, hasLength(1));
    expect(alerts.created.single?.latitude, 23.7);
    expect(find.text('Alert sent'), findsWidgets);

    alerts.push(AlertStatus.acknowledged);
    await tester.pumpAndSettle();
    expect(find.text('Help is on the way'), findsOneWidget);

    alerts.push(AlertStatus.resolved);
    await tester.pumpAndSettle();
    expect(find.text('Alert resolved'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('SOS'), findsOneWidget, reason: 'SOS is offered again once the alert is closed');
  });

  testWidgets('location denied: alert still sent without coordinates and the student is told', (
    tester,
  ) async {
    final alerts = FakeAlertRepository();
    await boot(tester, alerts: alerts, location: null);
    await holdSos(tester, const Duration(milliseconds: 2100));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(alerts.created, hasLength(1));
    expect(alerts.created.single, isNull);
    expect(find.textContaining('without your location'), findsOneWidget);
  });

  testWidgets('an open alert replaces the SOS button (one open alert per student)', (tester) async {
    final alerts = FakeAlertRepository(open: alertWith('x', AlertStatus.acknowledged));
    await boot(tester, alerts: alerts);
    expect(find.text('SOS'), findsNothing);
    expect(find.text('You have an open alert.'), findsOneWidget);
    await tester.tap(find.text('View alert status'));
    await tester.pumpAndSettle();
    expect(find.text('Help is on the way'), findsOneWidget);
    expect(alerts.created, isEmpty);
  });

  testWidgets('student can end an ACTIVE alert after confirming', (tester) async {
    final alerts = FakeAlertRepository(open: alertWith('x', AlertStatus.active));
    await boot(tester, alerts: alerts);
    await tester.tap(find.text('View alert status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(cancelLabel));
    // The button shows its own spinner while the dialog is open, so pumpAndSettle would never settle.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cancel alert'));
    await tester.pumpAndSettle();
    expect(alerts.cancelCalls, 1);
    expect(find.text('Alert cancelled'), findsOneWidget);
  });

  testWidgets('a student cannot cancel an acknowledged alert (RLS allows active only)', (tester) async {
    final alerts = FakeAlertRepository(open: alertWith('y', AlertStatus.acknowledged));
    await boot(tester, alerts: alerts);
    await tester.tap(find.text('View alert status'));
    await tester.pumpAndSettle();
    expect(find.text(cancelLabel), findsNothing);
  });
}
