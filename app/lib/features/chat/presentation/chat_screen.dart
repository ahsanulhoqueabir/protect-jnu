import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../auth/auth_providers.dart';
import '../../sos/sos_providers.dart';
import '../chat_providers.dart';
import '../domain/chat_message.dart';

/// Chat with the administrators about the student's alert. Read-only once the alert is closed (D-072).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final alert = ref.watch(openAlertProvider).value;
    final me = ref.watch(currentUserIdProvider);
    if (alert == null || me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(child: Text('There is no alert to talk about.')),
      );
    }

    final chat = ref.watch(chatProvider(alert.id));
    final controller = ref.read(chatProvider(alert.id).notifier);
    ref.listen(chatProvider(alert.id), (_, next) {
      _toBottom();
      // Looking at the thread: anything new from an administrator is read at once.
      ref.read(chatProvider(alert.id).notifier).markRead();
    });
    final messages = chat.messages;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          if (chat.connectionLost)
            const MaterialBanner(
              content: Text('Connection lost. Showing the last messages.'),
              actions: [SizedBox.shrink()],
            ),
          Expanded(
            child: !chat.loaded
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? const Center(child: Text('No messages yet. Administrators can reply here.'))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      return _Bubble(
                        message: m,
                        mine: m.senderId == me,
                        failureText: chat.failureText[m.id],
                        onRetry: () => controller.retry(m.id),
                        onDiscard: () => controller.discard(m.id),
                      );
                    },
                  ),
          ),
          if (!alert.status.isOpen)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              color: context.colors.surfaceContainerHighest,
              child: const Text('This alert is closed. The conversation is read-only.'),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        maxLength: chatMaxLength,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Write a message'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send',
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        final body = _text.text;
                        if (body.trim().isEmpty) return;
                        _text.clear();
                        controller.send(body);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.failureText,
    required this.onRetry,
    required this.onDiscard,
  });

  final ChatMessage message;
  final bool mine;
  final String? failureText;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final failed = message.state == SendState.failed;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Card(
          color: mine ? colors.primaryContainer : colors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!mine) Text('Administrator', style: context.textTheme.labelSmall),
                Text(message.body),
                const SizedBox(height: AppSpacing.xs),
                if (failed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Not sent. ${failureText ?? ''}',
                          style: context.textTheme.bodySmall?.copyWith(color: colors.error),
                        ),
                      ),
                      TextButton(onPressed: onRetry, child: const Text('Retry')),
                      TextButton(onPressed: onDiscard, child: const Text('Delete')),
                    ],
                  )
                else
                  Text(
                    message.state == SendState.sending
                        ? 'Sending...'
                        : message.sentAt.toLocal().formatted,
                    style: context.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
