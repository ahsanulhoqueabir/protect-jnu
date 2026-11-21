import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chat threads (alert ids) currently on screen. No "new message" notification is raised for
/// them. A plain object, not state: nothing rebuilds when it changes, so screens may update it
/// from `initState` / `dispose`.
class VisibleChats {
  final _open = <String, int>{};

  void show(String alertId) => _open.update(alertId, (n) => n + 1, ifAbsent: () => 1);

  void hide(String alertId) {
    final n = (_open[alertId] ?? 0) - 1;
    if (n <= 0) {
      _open.remove(alertId);
    } else {
      _open[alertId] = n;
    }
  }

  bool isVisible(String alertId) => _open.containsKey(alertId);
}

final visibleChatProvider = Provider<VisibleChats>((_) => VisibleChats());
