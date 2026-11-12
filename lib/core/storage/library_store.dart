import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';

abstract interface class LibraryStore {
  /// Primary snapshot first, recovery snapshot second.
  Future<List<String>> readSnapshots();
  Future<void> write(String snapshot);
}

class FileLibraryStore implements LibraryStore {
  FileLibraryStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;
  Future<File> _file(String name) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$name');
  }

  @override
  Future<List<String>> readSnapshots() async {
    final result = <String>[];
    for (final name in ['museum_library.json', 'museum_library.backup.json']) {
      final file = await _file(name);
      if (await file.exists()) {
        try {
          result.add(await file.readAsString());
        } catch (_) {
          result.add('unreadable snapshot');
        }
      }
    }
    return result;
  }

  @override
  Future<void> write(String snapshot) async {
    final temporary = await _file('museum_library.pending.json');
    final primary = await _file('museum_library.json');
    final backup = await _file('museum_library.backup.json');
    await temporary.writeAsString(snapshot, flush: true);
    // A backup remains available if replacement is interrupted. Never rotate a
    // corrupt primary over a valid recovery snapshot.
    if (await primary.exists()) {
      String? previous;
      try {
        previous = await primary.readAsString();
      } catch (_) {}
      if (previous != null && _isLibrarySnapshot(previous)) {
        await backup.writeAsString(previous, flush: true);
      }
    }
    await temporary.rename(primary.path);
  }
}

bool _isLibrarySnapshot(String value) {
  try {
    final json = jsonDecode(value);
    return json is Map &&
        json['version'] == 1 &&
        json['artworks'] is Map &&
        json['saved'] is List &&
        json['collections'] is List;
  } catch (_) {
    return false;
  }
}

class MemoryLibraryStore implements LibraryStore {
  MemoryLibraryStore({this.snapshot, this.backup});
  String? snapshot, backup;
  bool failWrites = false;
  @override
  Future<List<String>> readSnapshots() async => [?snapshot, ?backup];
  @override
  Future<void> write(String value) async {
    if (failWrites) throw const FileSystemException('Storage unavailable');
    backup = snapshot;
    snapshot = value;
  }
}
