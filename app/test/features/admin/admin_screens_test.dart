import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/app/app.dart';
import 'package:protect_jnu/app/router/app_router.dart';
import 'package:protect_jnu/app/router/routes.dart';
import 'package:protect_jnu/core/connectivity/connectivity_provider.dart';
import 'package:protect_jnu/core/notifications/app_notifier.dart';
import 'package:protect_jnu/core/realtime/realtime_changes.dart';
import 'package:protect_jnu/core/storage/storage_providers.dart';
import 'package:protect_jnu/core/storage/token_store.dart';
import 'package:protect_jnu/features/admin/data/admin_repository.dart';
import 'package:protect_jnu/features/admin/domain/admin_alert.dart';
import 'package:protect_jnu/features/admin/domain/admin_chat.dart';
import 'package:protect_jnu/features/admin/domain/admin_user.dart';
import 'package:protect_jnu/features/admin/presentation/admin_reports_screen.dart';
import 'package:protect_jnu/features/admin/presentation/widgets/alert_live_map.dart';
import 'package:protect_jnu/features/auth/data/auth_repository.dart';
import 'package:protect_jnu/features/auth/domain/user.dart';
import 'package:protect_jnu/features/chat/data/chat_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/data/contacts_repository.dart';
import 'package:protect_jnu/features/emergency_contacts/domain/emergency_contact.dart';
import 'package:protect_jnu/features/location/data/location_queue.dart';
import 'package:protect_jnu/features/location/data/location_uploader.dart';
import 'package:protect_jnu/features/location/domain/location_point.dart';
import 'package:protect_jnu/features/location/location_providers.dart';
import 'package:protect_jnu/features/sos/data/alert_repository.dart';
import 'package:protect_jnu/features/sos/data/location_service.dart';
import 'package:protect_jnu/features/sos/domain/sos_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/admin_fakes.dart';
import '../../helpers/fakes.dart';

void main() {
  const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r', expiresAt: 4102444800);
  late FakeAdminRepository admin;
  late FakeRealtimeChanges realtime;
  late FakeAppNotifier notifier;
  late FakeAlertRepository alerts;
  late FakeContactsRepository contacts;
  final shared = <(String, String)>[];

  setUp(() {
    admin = FakeAdminRepository();
    realtime = FakeRealtimeChanges();
    notifier = FakeAppNotifier();
    alerts = FakeAlertRepository();
    contacts = FakeContactsRepository(const [
      EmergencyContact(id: 'c1', name: 'Mother', phone: '01711111111'),
      EmergencyContact(id: 'c2', name: 'Father', phone: '01722222222'),
    ]);
    shared.clear();
  });

  /// Boots the whole app with a stored session for [user] on a small phone.
  Future<ProviderContainer> boot(WidgetTester tester, User user) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'user': jsonEncode(user.toJson())});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(TokenStore(initial: tokens)),
        isOnlineProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        contactsRepositoryProvider.overrideWithValue(contacts),
        alertRepositoryProvider.overrideWithValue(alerts),
        locationServiceProvider.overrideWithValue(FakeLocationService(null)),
        adminRepositoryProvider.overrideWithValue(admin),
        realtimeChangesProvider.overrideWithValue(realtime),
        livePollIntervalProvider.overrideWithValue(null),
        appNotifierProvider.overrideWithValue(notifier),
        mapTilesEnabledProvider.overrideWithValue(false),
        csvSharerProvider.overrideWithValue((name, csv) async => shared.add((name, csv))),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        positionSourceProvider.overrideWithValue(FakePositionSource()),
        locationQueueProvider.overrideWithValue(InMemoryLocationQueue()),
        locationUploaderProvider.overrideWithValue(_NoUploader()),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> go(WidgetTester tester, ProviderContainer c, String path) async {
    c.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  group('role-based access', () {
    testWidgets('a normal user sees the same three tabs and cannot open admin screens', (
      tester,
    ) async {
      final c = await boot(tester, studentUser);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Admin'), findsNothing);

      await go(tester, c, Routes.adminReports);
      expect(c.read(routerProvider).state.uri.path, Routes.home);
      expect(admin.calls, isEmpty, reason: 'no admin API call for a normal user');
      expect(realtime.listened.where((t) => t == 'alerts'), isEmpty);
    });

    testWidgets('an admin keeps the student tabs and gets an Admin tab with live alerts', (
      tester,
    ) async {
      admin.open = [adminAlert('a1', AlertStatus.active)];
      await boot(tester, adminUser);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      // Student features still work for an admin: the SOS home screen is the first tab.
      expect(find.textContaining('SOS'), findsWidgets);

      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();
      expect(find.text('Live alerts'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    });

    testWidgets("an admin's own SOS and contacts queries are scoped to the admin's id", (
      tester,
    ) async {
      await boot(tester, adminUser);
      expect(alerts.openQueriedFor, everyElement(adminUser.id));
      expect(alerts.openQueriedFor, isNotEmpty);
      expect(contacts.listedFor, everyElement(adminUser.id));
    });
  });

  testWidgets('a new alert over Realtime refreshes the live list', (tester) async {
    final c = await boot(tester, adminUser);
    await go(tester, c, Routes.admin);
    expect(find.text('No open alerts'), findsOneWidget);

    admin.open = [adminAlert('a2', AlertStatus.active)];
    realtime.emit(
      const TableChange(table: 'alerts', event: 'INSERT', record: {'id': 'a2', 'status': 'active'}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('alert detail shows student, contacts, timeline and acknowledges after confirm', (
    tester,
  ) async {
    admin.details['a1'] = alertDetail('a1', AlertStatus.active);
    final c = await boot(tester, adminUser);
    await go(tester, c, Routes.adminAlertFor('a1'));

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.textContaining('No location received yet'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mother: 01711111111'), 200);
    expect(find.text('Mother: 01711111111'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Acknowledge'), -200);
    await tester.tap(find.widgetWithText(FilledButton, 'Acknowledge'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Acknowledge').last);
    await tester.pumpAndSettle();

    expect(admin.calls, contains('transition:a1:acknowledge'));
    expect(find.text('Mark resolved'), findsOneWidget);
    expect(find.text('Alert acknowledged.'), findsOneWidget);
  });

  testWidgets('a race lost to another admin is explained and the alert reloads', (tester) async {
    admin.details['a1'] = alertDetail('a1', AlertStatus.active);
    admin.raceOnTransition = true;
    final c = await boot(tester, adminUser);
    await go(tester, c, Routes.adminAlertFor('a1'));
    await tester.tap(find.widgetWithText(FilledButton, 'Acknowledge'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Acknowledge').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Another admin already changed this alert'), findsOneWidget);
    expect(find.text('Mark resolved'), findsOneWidget);
  });

  testWidgets('admin chat shows the thread, marks it read, sends, and is read-only once closed', (
    tester,
  ) async {
    admin.details['a1'] = alertDetail('a1', AlertStatus.acknowledged);
    admin.threads['a1'] = [
      AdminMessage(
        id: 'm1',
        senderId: 'student-1',
        body: 'Please help',
        sentAt: DateTime.utc(2026, 11, 9, 10),
        fromStudent: true,
      ),
    ];
    final c = await boot(tester, adminUser);
    await go(tester, c, Routes.adminAlertChatFor('a1'));
    expect(find.text('Please help'), findsOneWidget);
    expect(admin.calls, contains('markRead:a1'));

    await tester.enterText(find.byType(TextField), 'We are on our way');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(admin.calls, contains('send:a1:We are on our way'));
    expect(find.text('We are on our way'), findsOneWidget);

    admin.details['a1'] = alertDetail('a1', AlertStatus.resolved);
    realtime.emit(const TableChange(table: 'alerts', event: 'UPDATE', record: {'id': 'a1'}));
    await tester.pumpAndSettle();
    expect(find.textContaining('read-only'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('conversations list unread counts and opens the chat', (tester) async {
    admin.details['a1'] = alertDetail('a1', AlertStatus.active);
    admin.conversationRows = [
      Conversation(
        alertId: 'a1',
        lastBody: 'Please help',
        lastSentAt: DateTime.now().subtract(const Duration(minutes: 2)),
        lastSenderId: 'student-1',
        unreadCount: 3,
        student: ada,
        status: AlertStatus.active,
      ),
    ];
    final c = await boot(tester, adminUser);
    await go(tester, c, Routes.adminConversations);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('Please help'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.path, Routes.adminAlertChatFor('a1'));
  });

  testWidgets('history filters by status and resets to page 1', (tester) async {
    admin.open = [adminAlert('a1', AlertStatus.resolved)];
    final c = await boot(tester, adminUser);
    await go(tester, c, Routes.adminHistory);
    expect(admin.calls, contains('alerts:all:1'));
    // The filter row scrolls sideways on a small phone.
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Resolved'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Resolved'));
    await tester.pumpAndSettle();
    expect(admin.calls, contains('alerts:resolved:1'));
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('users list pages through results', (tester) async {
    admin.userRows = [
      AdminUser(
        id: 'u1',
        fullName: 'Ada Lovelace',
        studentId: 'B210305040',
        email: 'ada@cse.jnu.ac.bd',
        role: 'user',
        verified: false,
        createdAt: DateTime.utc(2026, 11, 9),
      ),
    ];
    final c = await boot(tester, adminUser);
    await go(tester, c, Routes.adminUsers);
    expect(find.textContaining('(unverified)'), findsOneWidget);
    expect(find.text('Page 1 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(admin.calls, contains('users:2'));
  });

  testWidgets('reports show totals and share the server CSV', (tester) async {
    final c = await boot(tester, adminUser);
    await go(tester, c, Routes.adminReports);
    expect(find.text('Alerts handled'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    await tester.tap(find.byTooltip('Share CSV'));
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    expect(shared.single.$1, startsWith('support-report-'));
    expect(shared.single.$2, startsWith('year,month,alerts_handled,students_supported'));
  });

  testWidgets('live map shows the newest point, trail age and Realtime points', (tester) async {
    admin.details['a1'] = alertDetail('a1', AlertStatus.acknowledged);
    admin.trail = [
      TrailPoint(
        id: '1',
        latitude: 23.708,
        longitude: 90.411,
        recordedAt: DateTime.now().subtract(const Duration(seconds: 30)),
      ),
    ];
    final c = await boot(tester, adminUser);
    await go(tester, c, Routes.adminAlertFor('a1'));
    expect(find.textContaining('23.708000, 90.411000'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

    realtime.emit(
      TableChange(
        table: 'locations',
        event: 'INSERT',
        record: {
          'id': 2,
          'latitude': 23.709,
          'longitude': 90.412,
          'recorded_at': DateTime.now().toUtc().toIso8601String(),
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('23.709000, 90.412000'), findsOneWidget);
  });

  group('notifications (D-081)', () {
    testWidgets('an admin is notified, with vibration, of a new SOS from someone else', (
      tester,
    ) async {
      admin.details['a9'] = alertDetail('a9', AlertStatus.active);
      await boot(tester, adminUser);
      expect(notifier.permissionRequests, greaterThan(0));

      realtime.emit(
        const TableChange(
          table: 'alerts',
          event: 'INSERT',
          record: {'id': 'a9', 'status': 'active', 'user_id': 'student-1'},
        ),
      );
      await tester.pumpAndSettle();
      final sos = notifier.shown.where((n) => n.kind == NoticeKind.sosAlert).toList();
      expect(sos, hasLength(1));
      expect(sos.single.body, contains('Ada Lovelace (B210305040)'));
      expect(sos.single.route, Routes.adminAlertFor('a9'));
      expect(notifier.vibrations, greaterThan(0));

      // The admin's own SOS does not notify the admin.
      realtime.emit(
        const TableChange(
          table: 'alerts',
          event: 'INSERT',
          record: {'id': 'a10', 'status': 'active', 'user_id': 'admin-1'},
        ),
      );
      await tester.pumpAndSettle();
      expect(notifier.shown.where((n) => n.kind == NoticeKind.sosAlert), hasLength(1));
    });

    testWidgets('a normal user gets no admin notifications', (tester) async {
      await boot(tester, studentUser);
      realtime.emit(
        const TableChange(
          table: 'alerts',
          event: 'INSERT',
          record: {'id': 'a9', 'status': 'active', 'user_id': 'student-2'},
        ),
      );
      await tester.pumpAndSettle();
      expect(notifier.shown, isEmpty);
    });

    testWidgets('admin message notifications are skipped for the thread on screen', (tester) async {
      admin.details['a1'] = alertDetail('a1', AlertStatus.active);
      final c = await boot(tester, adminUser);
      const msg = TableChange(
        table: 'messages',
        event: 'INSERT',
        record: {'alert_id': 'a1', 'sender_id': 'student-1', 'body': 'Are you coming?'},
      );
      realtime.emit(msg);
      await tester.pumpAndSettle();
      expect(notifier.shown.single.kind, NoticeKind.message);
      expect(notifier.shown.single.route, Routes.adminAlertChatFor('a1'));

      await go(tester, c, Routes.adminAlertChatFor('a1'));
      notifier.shown.clear();
      realtime.emit(msg);
      await tester.pumpAndSettle();
      expect(notifier.shown, isEmpty);
    });

    testWidgets('a student is notified when their alert is acknowledged and of admin messages', (
      tester,
    ) async {
      alerts.open = SosAlert(
        id: 's1',
        status: AlertStatus.active,
        startedAt: DateTime.utc(2026, 11, 9, 10),
      );
      await boot(tester, studentUser);
      expect(realtime.listened, contains('messages:s1'));

      alerts.push(AlertStatus.acknowledged);
      await tester.pumpAndSettle();
      expect(notifier.shown.single.kind, NoticeKind.alertStatus);
      expect(notifier.shown.single.title, 'Alert acknowledged');

      realtime.emit(
        const TableChange(
          table: 'messages',
          event: 'INSERT',
          record: {'alert_id': 's1', 'sender_id': 'admin-1', 'body': 'We see you'},
        ),
      );
      await tester.pumpAndSettle();
      expect(notifier.shown.last.kind, NoticeKind.message);
      expect(notifier.shown.last.route, Routes.alertChat);

      // The student's own message does not notify.
      final before = notifier.shown.length;
      realtime.emit(
        const TableChange(
          table: 'messages',
          event: 'INSERT',
          record: {'alert_id': 's1', 'sender_id': 'student-1', 'body': 'thanks'},
        ),
      );
      await tester.pumpAndSettle();
      expect(notifier.shown, hasLength(before));
    });

    testWidgets('tapping a notification opens its screen', (tester) async {
      admin.details['a1'] = alertDetail('a1', AlertStatus.active);
      final c = await boot(tester, adminUser);
      notifier.tap(Routes.adminAlertFor('a1'));
      await tester.pumpAndSettle();
      expect(c.read(routerProvider).state.uri.path, Routes.adminAlertFor('a1'));
    });
  });
}

class _NoUploader implements LocationUploader {
  @override
  Future<UploadOutcome> upload({
    required String alertId,
    required String userId,
    required List<LocationPoint> points,
  }) async => UploadOutcome.sent;
}
