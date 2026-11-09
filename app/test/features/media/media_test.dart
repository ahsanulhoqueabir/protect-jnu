import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/features/media/data/media_store.dart';
import 'package:protect_jnu/features/media/domain/media_item.dart';
import 'package:protect_jnu/features/media/media_providers.dart';
import 'package:protect_jnu/features/media/presentation/gallery_screen.dart';

import '../../helpers/pump_app.dart';

void main() {
  late Directory root;
  late Directory cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('media_store_');
    cache = Directory.systemTemp.createTempSync('media_cache_');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  LocalMediaStore store() => LocalMediaStore(baseDir: () async => root);

  String capture(String name) {
    final f = File('${cache.path}/$name')..writeAsBytesSync([1, 2, 3]);
    return f.path;
  }

  test('save moves the file into the private folder and the index survives a restart', () async {
    final saved = await store().save(
      sourcePath: capture('a.jpg'),
      type: MediaType.photo,
      capturedAt: DateTime.utc(2026, 11, 9, 10),
      alertId: 'alert-1',
    );
    expect(File(saved.path).existsSync(), isTrue);
    expect(saved.path.startsWith(root.path), isTrue);
    expect(File('${cache.path}/a.jpg').existsSync(), isFalse);

    // A new store instance (app restart) reads the same files.
    final again = await store().list();
    expect(again, hasLength(1));
    expect(again.single.alertId, 'alert-1');
    expect(again.single.type, MediaType.photo);
  });

  test('list is newest first and drops entries whose file is gone', () async {
    final s = store();
    final older = await s.save(
      sourcePath: capture('a.jpg'),
      type: MediaType.photo,
      capturedAt: DateTime.utc(2026, 11, 9, 9),
    );
    final newer = await s.save(
      sourcePath: capture('b.mp4'),
      type: MediaType.video,
      capturedAt: DateTime.utc(2026, 11, 9, 11),
    );
    expect((await s.list()).map((i) => i.id), [newer.id, older.id]);
    File(older.path).deleteSync();
    expect((await s.list()).map((i) => i.id), [newer.id]);
  });

  test('delete removes the file and the entry', () async {
    final s = store();
    final item = await s.save(
      sourcePath: capture('a.jpg'),
      type: MediaType.photo,
      capturedAt: DateTime.utc(2026, 11, 9),
    );
    await s.delete(item.id);
    expect(File(item.path).existsSync(), isFalse);
    expect(await s.list(), isEmpty);
  });

  test('two quick captures both stay in the index', () async {
    final s = store();
    await Future.wait([
      s.save(
        sourcePath: capture('a.jpg'),
        type: MediaType.photo,
        capturedAt: DateTime.utc(2026, 11, 9, 1),
      ),
      s.save(
        sourcePath: capture('b.jpg'),
        type: MediaType.photo,
        capturedAt: DateTime.utc(2026, 11, 9, 2),
      ),
    ]);
    expect(await s.list(), hasLength(2));
  });

  test('a damaged index is treated as empty, not a crash', () async {
    Directory('${root.path}/media').createSync(recursive: true);
    File('${root.path}/media/index.json').writeAsStringSync('{not json');
    expect(await store().list(), isEmpty);
  });

  test('provider add and remove update the list', () async {
    final container = ProviderContainer(overrides: [mediaStoreProvider.overrideWithValue(store())]);
    addTearDown(container.dispose);
    await container.read(mediaListProvider.future);
    final notifier = container.read(mediaListProvider.notifier);
    final item = await notifier.add(sourcePath: capture('a.jpg'), type: MediaType.photo);
    expect(container.read(mediaListProvider).value, hasLength(1));
    await notifier.remove(item.id);
    expect(container.read(mediaListProvider).value, isEmpty);
  });

  testWidgets('gallery shows the empty message', (tester) async {
    await tester.pumpApp(
      const GalleryScreen(),
      overrides: [mediaStoreProvider.overrideWithValue(_EmptyStore())],
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('stay on this phone only'), findsOneWidget);
  });
}

class _EmptyStore implements MediaStore {
  @override
  Future<List<MediaItem>> list() async => [];

  @override
  Future<MediaItem> save({
    required String sourcePath,
    required MediaType type,
    required DateTime capturedAt,
    String? alertId,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String id) async {}
}
