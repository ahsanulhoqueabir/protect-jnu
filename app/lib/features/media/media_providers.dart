import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'data/media_store.dart';
import 'domain/media_item.dart';

final mediaStoreProvider = Provider<MediaStore>((ref) => LocalMediaStore());

/// The signed-in student's local gallery (newest first). Reloaded when the user changes so one
/// account never sees another's list on a shared phone's UI state.
final mediaListProvider = AsyncNotifierProvider<MediaListNotifier, List<MediaItem>>(
  MediaListNotifier.new,
);

class MediaListNotifier extends AsyncNotifier<List<MediaItem>> {
  @override
  Future<List<MediaItem>> build() {
    ref.watch(currentUserIdProvider);
    return ref.read(mediaStoreProvider).list();
  }

  Future<MediaItem> add({
    required String sourcePath,
    required MediaType type,
    String? alertId,
  }) async {
    final item = await ref
        .read(mediaStoreProvider)
        .save(sourcePath: sourcePath, type: type, capturedAt: DateTime.now(), alertId: alertId);
    state = AsyncData([item, ...?state.value]);
    return item;
  }

  Future<void> remove(String id) async {
    await ref.read(mediaStoreProvider).delete(id);
    state = AsyncData([
      for (final i in state.value ?? const <MediaItem>[])
        if (i.id != id) i,
    ]);
  }
}
