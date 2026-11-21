import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../chat/domain/chat_message.dart';
import '../../notifications/visible_chat_provider.dart';
import '../admin_providers.dart';
import '../domain/admin_chat.dart';
import 'widgets/admin_widgets.dart';

/// The admin side of an alert's chat (dashboard chat panel): live thread, send, mark read,
/// read-only once the alert is resolved or cancelled (D-072).
class AdminChatScreen extends ConsumerStatefulWidget {
  const AdminChatScreen({super.key, required this.alertId});

  final String alertId;

  @override
  ConsumerState<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends ConsumerState<AdminChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final VisibleChats _visible;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    // No "new message" notification for the thread already on screen.
    _visible = ref.read(visibleChatProvider)..show(widget.alertId);
  }

  @override
  void dispose() {
    _visible.hide(widget.alertId);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _text.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await runGuarded(
      context,
      () => ref.read(adminChatProvider(widget.alertId).notifier).send(text),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(adminChatProvider(widget.alertId));
    final detail = ref.watch(alertDetailProvider(widget.alertId)).value;
    ref.listen(adminChatProvider(widget.alertId), (prev, next) {
      if (next.messages.length != prev?.messages.length) _toBottom();
      ref.read(adminChatProvider(widget.alertId).notifier).markRead();
    });
    final open = detail?.chatOpen ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(detail?.student.fullName ?? 'Messages')),
      body: Column(
        children: [
          if (chat.loadFailed)
            MaterialBanner(
              content: const Text('Could not load the messages.'),
              actions: [
                TextButton(
                  onPressed: () => ref.read(adminChatProvider(widget.alertId).notifier).load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: !chat.loaded
                ? const LoadingView()
                : chat.messages.isEmpty
                ? const Center(child: Text('No messages yet.'))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: chat.messages.length,
                    itemBuilder: (_, i) => _Bubble(message: chat.messages[i]),
                  ),
          ),
          if (detail != null && !open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              color: context.colors.surfaceContainerHighest,
              child: Text('This alert is ${detail.status.name}. The conversation is read-only.'),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        maxLength: chatMaxLength,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Reply to the student',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _sending || detail == null ? null : _send,
                      icon: const Icon(Icons.send_rounded),
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
  const _Bubble({required this.message});

  final AdminMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mine = !message.fromStudent;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine ? colors.primaryContainer : colors.surfaceContainerHighest,
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.fromStudent ? 'Student' : (message.senderName ?? 'Admin team'),
              style: context.textTheme.labelSmall,
            ),
            const Gap(AppSpacing.xxs),
            Text(message.body),
            const Gap(AppSpacing.xxs),
            Text(adminTime(message.sentAt), style: context.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
