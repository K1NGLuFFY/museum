import 'dart:io';
import 'dart:typed_data';

import 'package:file/file.dart' as files;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:museum/core/storage/thumbnail_cache.dart';

class TestFileSystem implements FileSystem {
  TestFileSystem(this.directory);
  final Directory directory;
  @override
  Future<files.File> createFile(String name) async =>
      const LocalFileSystem().file('${directory.path}/$name');
}

void main() {
  test(
    'thumbnail files survive manager restart, work offline, report bytes and clear',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'museum_thumbnail_test_',
      );
      final directory = await Directory('${root.path}/images').create();
      addTearDown(() => root.delete(recursive: true));
      var requests = 0;
      CacheManager manager() => CacheManager(
        Config(
          'test-thumbnails',
          repo: JsonCacheInfoRepository(path: '${root.path}/index.json'),
          fileSystem: TestFileSystem(directory),
          fileService: HttpFileService(
            httpClient: MockClient((_) async {
              requests++;
              return http.Response.bytes(
                [1, 2, 3],
                200,
                headers: {'content-type': 'image/jpeg'},
              );
            }),
          ),
        ),
      );
      final firstManager = manager();
      final uri = Uri.https('images.metmuseum.org', '/test-thumbnail.jpg');
      await firstManager.putFile(
        uri.toString(),
        Uint8List.fromList([1, 2, 3]),
        fileExtension: 'jpg',
      );
      final first = ManagedThumbnailCache(
        manager: firstManager,
        directory: () async => directory,
      );
      expect(
        (await first.image(uri, allowNetwork: false))?.existsSync(),
        isTrue,
      );
      expect((await first.size()).bytes, 3);
      expect((await first.size()).files, 1);
      await first.dispose();
      final second = ManagedThumbnailCache(
        manager: manager(),
        directory: () async => directory,
      );
      expect(
        (await second.image(uri, allowNetwork: false))?.existsSync(),
        isTrue,
      );
      expect(requests, 0);
      expect(
        await second.image(
          Uri.https('images.metmuseum.org', '/missing.jpg'),
          allowNetwork: false,
        ),
        isNull,
      );
      await second.clear();
      expect((await second.size()).bytes, 0);
      expect(await second.image(uri, allowNetwork: false), isNull);
      await second.dispose();
    },
  );
}
