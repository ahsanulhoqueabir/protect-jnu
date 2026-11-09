import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/features/auth/auth_providers.dart';
import 'package:protect_jnu/features/chat/chat_providers.dart';
import 'package:protect_jnu/features/chat/data/chat_repository.dart';
import 'package:protect_jnu/features/chat/domain/chat_message.dart';
import 'package:protect_jnu/features/chat/presentation/chat_screen.dart';
import 'package:protect_jnu/features/sos/data/alert_repository.dart';
import 'package:protect_jnu/features/sos/domain/sos_alert.dart';

import '../../helpers/fakes.dart';

void main() {
  const me = 'student-1';
  const alertId = 'alert-1';

  ProviderContainer containerWith(FakeChatRepository chat) => ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      currentUserIdProvider.overrideWithValue(me),
      chatRepositoryProvider.overrideWithValue(chat),
    ],
  );

  group('ChatController', () {
    test(
      'sends, shows the message once (no duplicate from Realtime), then it is confirmed',
      () async {
        final chat = FakeChatRepository();
        final c = containerWith(chat);
        final sub = c.listen(chatProvider(alertId), (_, _) {});
        await Future<void>.delayed(Duration.zero);

        await c.read(chatProvider(alertId).notifier).send('  help  ');
        await Future<void>.delayed(Duration.zero);

        final s = c.read(chatProvider(alertId));
        expect(s.pending, isEmpty);
        expect(s.messages.map((m) => m.body), ['help'], reason: 'trimmed, and only once');
        sub.close();
      },
    );

    test('empty and over-long messages are not sent', () async {
      final chat = FakeChatRepository();
      final c = containerWith(chat);
      final sub = c.listen(chatProvider(alertId), (_, _) {});
      final n = c.read(chatProvider(alertId).notifier);
      await n.send('   ');
      await n.send('x' * (chatMaxLength + 1));
      expect(chat.rows, isEmpty);
      await n.send('x' * chatMaxLength);
      expect(chat.rows, hasLength(1));
      sub.close();
    });

    test('offline: message is marked failed, retry sends it, discard removes it', () async {
      final chat = FakeChatRepository()..failSends = true;
      final c = containerWith(chat);
      final sub = c.listen(chatProvider(alertId), (_, _) {});
      final n = c.read(chatProvider(alertId).notifier);

      await n.send('are you there');
      var s = c.read(chatProvider(alertId));
      expect(s.pending.single.state, SendState.failed);
      expect(chat.rows, isEmpty, reason: 'nothing queued behind the user\'s back (D-072)');

      chat.failSends = false;
      await n.retry(s.pending.single.id);
      s = c.read(chatProvider(alertId));
      expect(s.pending, isEmpty);
      expect(chat.rows.single.body, 'are you there');

      chat.failSends = true;
      await n.send('second');
      n.discard(c.read(chatProvider(alertId)).pending.single.id);
      expect(c.read(chatProvider(alertId)).pending, isEmpty);
      sub.close();
    });

    test('unread counts only administrator messages and clears after markRead', () async {
      final chat = FakeChatRepository();
      final c = containerWith(chat);
      final sub = c.listen(chatProvider(alertId), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      chat.incoming('on our way');
      chat.incoming('stay put');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(chatProvider(alertId)).unreadFor(me), 2);

      await c.read(chatProvider(alertId).notifier).send('ok');
      expect(c.read(chatProvider(alertId)).unreadFor(me), 2, reason: 'own messages never count');

      await c.read(chatProvider(alertId).notifier).markRead();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(chatProvider(alertId)).unreadFor(me), 0);
      sub.close();
    });

    test('mergeMessages dedupes by id and orders by time', () {
      ChatMessage m(String id, int s, {DateTime? read}) => ChatMessage(
        id: id,
        senderId: 'x',
        body: id,
        sentAt: DateTime.utc(2026, 11, 9, 10, 0, s),
        readAt: read,
      );
      final out = mergeMessages(
        [m('a', 1), m('c', 3)],
        [m('b', 2), m('c', 3, read: DateTime.utc(2026))],
      );
      expect(out.map((x) => x.id), ['a', 'b', 'c']);
      expect(out.last.readAt, isNotNull);
    });
  });

  group('ChatScreen', () {
    Future<(FakeChatRepository, FakeAlertRepository)> pumpChat(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final chat = FakeChatRepository();
      final alerts = FakeAlertRepository(
        open: SosAlert(
          id: alertId,
          status: AlertStatus.active,
          startedAt: DateTime.utc(2026, 11, 9),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            currentUserIdProvider.overrideWithValue(me),
            chatRepositoryProvider.overrideWithValue(chat),
            alertRepositoryProvider.overrideWithValue(alerts),
          ],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return (chat, alerts);
    }

    testWidgets('shows an incoming admin message live and marks it read', (tester) async {
      final (chat, _) = await pumpChat(tester);
      expect(find.textContaining('No messages yet'), findsOneWidget);

      chat.incoming('We are coming');
      await tester.pumpAndSettle();
      expect(find.text('We are coming'), findsOneWidget);
      expect(chat.markReadCalls, greaterThan(0));
      expect(chat.rows.single.readAt, isNotNull);
    });

    testWidgets('sends a message from the composer', (tester) async {
      final (chat, _) = await pumpChat(tester);
      await tester.enterText(find.byType(TextField), 'I am at the library');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.text('I am at the library'), findsOneWidget);
      expect(chat.rows.single.body, 'I am at the library');
    });

    testWidgets('a failed message shows Retry', (tester) async {
      final (chat, _) = await pumpChat(tester);
      chat.failSends = true;
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not sent'), findsOneWidget);

      chat.failSends = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not sent'), findsNothing);
      expect(chat.rows.single.body, 'hello');
    });

    testWidgets('read-only once the alert is closed: no composer, banner shown', (tester) async {
      final (_, alerts) = await pumpChat(tester);
      expect(find.byType(TextField), findsOneWidget);

      alerts.push(AlertStatus.resolved); // what Realtime delivers when an admin resolves it
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('read-only'), findsOneWidget);
    });
  });
}
