import 'dart:io';
import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ThumbnailCacheSize {
  const ThumbnailCacheSize(this.files, this.bytes);
  final int files, bytes;
}

abstract interface class ThumbnailCache {
  Future<File?> image(Uri uri, {required bool allowNetwork});
  Future<ThumbnailCacheSize> size();
  Future<void> clear();
  Future<void> dispose();
}

class ManagedThumbnailCache implements ThumbnailCache {
  ManagedThumbnailCache({
    CacheManager? manager,
    Future<Directory> Function()? directory,
  }) : _providedManager = manager,
       _cacheDirectory = directory;
  final CacheManager? _providedManager;
  final Future<Directory> Function()? _cacheDirectory;
  static const key = 'museum_thumbnails_v1';
  final _client = _ThumbnailHttpClient();
  late final _manager =
      _providedManager ??
      CacheManager(
        Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 160,
          fileService: HttpFileService(httpClient: _client)
            ..concurrentFetches = 2,
        ),
      );
  final Set<Future<File?>> _pending = {};
  bool _clearing = false;

  @override
  Future<File?> image(Uri uri, {required bool allowNetwork}) async {
    if (_clearing || uri.scheme != 'https') return null;
    final operation = _get(uri, allowNetwork);
    _pending.add(operation);
    try {
      return await operation;
    } finally {
      _pending.remove(operation);
    }
  }

  Future<File?> _get(Uri uri, bool allowNetwork) async {
    final cached = await _manager.getFileFromCache(uri.toString());
    final exists = cached != null && await cached.file.exists();
    if (!allowNetwork) return exists ? cached.file : null;
    try {
      return await _manager.getSingleFile(uri.toString());
    } catch (_) {
      return exists ? cached.file : null;
    }
  }

  @override
  Future<ThumbnailCacheSize> size() async {
    final directory = _cacheDirectory != null
        ? await _cacheDirectory()
        : Directory(
            '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}$key',
          );
    var count = 0, bytes = 0;
    if (await directory.exists()) {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File) {
          count++;
          bytes += await entity.length();
        }
      }
    }
    return ThumbnailCacheSize(count, bytes);
  }

  @override
  Future<void> clear() async {
    _clearing = true;
    try {
      await Future.wait(
        _pending.toList().map((future) async {
          try {
            await future;
          } catch (_) {}
        }),
      );
      await _manager.emptyCache();
    } finally {
      _clearing = false;
    }
  }

  @override
  Future<void> dispose() async {
    _client.close();
    await _manager.dispose();
  }
}

/// Bounds downloads through the whole body, not just response headers.
class _ThumbnailHttpClient extends http.BaseClient {
  final _inner = http.Client();
  final Set<Completer<void>> _requests = {};
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abort = Completer<void>();
    _requests.add(abort);
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    final timer = Timer(const Duration(seconds: 20), cancel);
    try {
      final response = await _inner.send(
        http.AbortableRequest(
          request.method,
          request.url,
          abortTrigger: abort.future,
        )..headers.addAll(request.headers),
      );
      Stream<List<int>> bytes() async* {
        var count = 0;
        try {
          await for (final chunk in response.stream) {
            count += chunk.length;
            if (count > 8 * 1024 * 1024) {
              cancel();
              throw const FormatException('Thumbnail too large');
            }
            yield chunk;
          }
        } finally {
          timer.cancel();
          _requests.remove(abort);
        }
      }

      if (response.statusCode != 200) {
        timer.cancel();
        cancel();
        _requests.remove(abort);
      }
      return http.StreamedResponse(
        bytes(),
        response.statusCode,
        contentLength: response.contentLength,
        headers: response.headers,
        request: request,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      timer.cancel();
      _requests.remove(abort);
      rethrow;
    }
  }

  @override
  void close() {
    for (final request in _requests) {
      if (!request.isCompleted) request.complete();
    }
    _inner.close();
  }
}

class EmptyThumbnailCache implements ThumbnailCache {
  @override
  Future<File?> image(Uri uri, {required bool allowNetwork}) async => null;
  @override
  Future<ThumbnailCacheSize> size() async => const ThumbnailCacheSize(0, 0);
  @override
  Future<void> clear() async {}
  @override
  Future<void> dispose() async {}
}
