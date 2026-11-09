import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/media_item.dart';

/// Local-only storage for captured media. Nothing here touches the network (D-013).
abstract interface class MediaStore {
  /// Newest first. Entries whose file is gone are dropped.
  Future<List<MediaItem>> list();

  /// Moves/copies the captured file at [sourcePath] into the store and indexes it.
  Future<MediaItem> save({
    required String sourcePath,
    required MediaType type,
    required DateTime capturedAt,
    String? alertId,
  });

  Future<void> delete(String id);
}

/// Files live in `<app documents>/media` (app-private; removed on uninstall) with a small JSON index.
class LocalMediaStore implements MediaStore {
  LocalMediaStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;
  Future<void> _queue = Future.value();

  Future<Directory> _folder() async {
    final dir = Directory('${(await _baseDir()).path}/media');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile(Directory folder) async => File('${folder.path}/index.json');

  Future<List<MediaItem>> _readIndex(Directory folder) async {
    final file = await _indexFile(folder);
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return [];
      return [
        for (final e in raw)
          if (e is Map<String, Object?>) ?MediaItem.fromJson(e, folder.path),
      ];
    } on FormatException {
      return [];
    }
  }

  Future<void> _writeIndex(Directory folder, List<MediaItem> items) async {
    final file = await _indexFile(folder);
    await file.writeAsString(jsonEncode([for (final i in items) i.toJson()]));
  }

  /// Serialises writers so two quick captures cannot overwrite each other's index entry.
  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<List<MediaItem>> list() => _exclusive(() async {
    final folder = await _folder();
    final items = await _readIndex(folder);
    final present = [
      for (final i in items)
        if (await File(i.path).exists()) i,
    ];
    present.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return present;
  });

  @override
  Future<MediaItem> save({
    required String sourcePath,
    required MediaType type,
    required DateTime capturedAt,
    String? alertId,
  }) => _exclusive(() async {
    final folder = await _folder();
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last.toLowerCase() : 'bin';
    final stamp = capturedAt.toUtc().microsecondsSinceEpoch;
    final id = '${type.name}_$stamp.$ext';
    final target = '${folder.path}/$id';
    final source = File(sourcePath);
    await source.copy(target);
    await source.delete().catchError((_) => source);
    final item = MediaItem(
      id: id,
      path: target,
      type: type,
      capturedAt: capturedAt,
      alertId: alertId,
    );
    final items = await _readIndex(folder);
    await _writeIndex(folder, [item, ...items]);
    return item;
  });

  @override
  Future<void> delete(String id) => _exclusive(() async {
    final folder = await _folder();
    final items = await _readIndex(folder);
    final file = File('${folder.path}/$id');
    if (await file.exists()) await file.delete();
    await _writeIndex(folder, [
      for (final i in items)
        if (i.id != id) i,
    ]);
  });
}
