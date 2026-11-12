import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/library_store.dart';
import '../artworks/artwork.dart';
import 'artwork_codec.dart';

class PersonalCollection {
  const PersonalCollection(this.id, this.name, this.artworkIds);
  final String id, name;
  final List<String> artworkIds;
}

class LibraryController extends ChangeNotifier {
  LibraryController({
    required this.store,
    DateTime Function()? now,
    Future<String?> Function()? legacyAppearance,
  }) : _now = now ?? DateTime.now,
       _legacyAppearance =
           legacyAppearance ??
           (() => SharedPreferencesAsync().getString('appearance'));
  final LibraryStore store;
  final DateTime Function() _now;
  final Future<String?> Function() _legacyAppearance;
  Map<String, dynamic> _data = _empty();
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  bool _disposed = false, loading = true, readOnly = false;
  String? error;
  static Map<String, dynamic> _empty() => {
    'version': 1,
    'artworks': <String, dynamic>{},
    'saved': <dynamic>[],
    'collections': <dynamic>[],
    'recentViews': <dynamic>[],
    'recentSearches': <dynamic>[],
    'queries': <String, dynamic>{},
    'preferences': <String, dynamic>{
      'appearance': 'system',
      'cacheThumbnails': true,
    },
  };
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initializing ??= _load();
  Future<void> retryLoad() async {
    await _queue;
    loading = true;
    _notify();
    _initializing = _load();
    await _initializing;
  }

  Future<void> _load() async {
    try {
      final snapshots = await store.readSnapshots();
      Map<String, dynamic>? loaded;
      var recovered = false, unsupported = false;
      for (final raw in snapshots) {
        try {
          final json = jsonDecode(raw);
          if (json is Map &&
              json['version'] is int &&
              (json['version'] as int) > 1) {
            unsupported = true;
            break;
          }
          if (json is! Map<String, dynamic> ||
              json['version'] != 1 ||
              json['artworks'] is! Map ||
              json['saved'] is! List ||
              json['collections'] is! List) {
            throw const FormatException();
          }
          loaded = {..._empty(), ...json};
          break;
        } catch (_) {
          recovered = true;
        }
      }
      if (unsupported || (loaded == null && snapshots.isNotEmpty)) {
        throw const FormatException('No readable library snapshot');
      }
      _data = loaded ?? _empty();
      var invalidRecords = 0;
      final records = <String, dynamic>{};
      for (final entry in (_data['artworks'] as Map).entries) {
        try {
          if (entry.value is! Map<String, dynamic>) {
            throw const FormatException();
          }
          final work = ArtworkCodec.decode(entry.value as Map<String, dynamic>);
          if (entry.key != work.id) throw const FormatException();
          records[work.id] = entry.value;
        } catch (_) {
          invalidRecords++;
        }
      }
      _data['artworks'] = records;
      for (final key in ['saved', 'recentViews']) {
        _data[key] = ((_data[key] is List ? _data[key] : []) as List)
            .whereType<String>()
            .where(records.containsKey)
            .toSet()
            .toList();
      }
      final collections = <Map<String, dynamic>>[];
      final ids = <String>{};
      for (final item in _data['collections'] as List) {
        if (item is! Map ||
            item['id'] is! String ||
            item['name'] is! String ||
            (item['name'] as String).trim().isEmpty ||
            !ids.add(item['id'] as String)) {
          continue;
        }
        collections.add({
          'id': item['id'],
          'name': item['name'],
          'artworkIds':
              ((item['artworkIds'] is List ? item['artworkIds'] : []) as List)
                  .whereType<String>()
                  .where(records.containsKey)
                  .toSet()
                  .toList(),
        });
      }
      _data['collections'] = collections;
      _data['recentSearches'] =
          ((_data['recentSearches'] is List ? _data['recentSearches'] : [])
                  as List)
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .take(12)
              .toList();
      if (_data['queries'] is! Map) _data['queries'] = <String, dynamic>{};
      if (_data['preferences'] is! Map) {
        _data['preferences'] = _empty()['preferences'];
      }
      if (loaded == null) {
        try {
          final legacy = await _legacyAppearance();
          if (['system', 'light', 'dark'].contains(legacy)) {
            (_data['preferences'] as Map)['appearance'] = legacy;
            await store.write(jsonEncode(_data));
          }
        } catch (_) {
          /* No previous appearance key is required. Daily Met keys stay intact. */
        }
      }
      error = recovered
          ? 'Your library was recovered from its previous copy.'
          : invalidRecords > 0
          ? '$invalidRecords unreadable artwork records were ignored. Your other saved items are available.'
          : null;
      readOnly = false;
    } catch (_) {
      readOnly = true;
      error =
          'Your library could not be read. Existing files have been preserved. Retry loading before making changes.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Map<String, dynamic> get _records =>
      _data['artworks'] as Map<String, dynamic>;
  Artwork? artwork(String id) {
    final json = _records[id];
    if (json is! Map<String, dynamic>) return null;
    return ArtworkCodec.decode(
      json,
      cachedAt: DateTime.tryParse(
        json['cachedAt'] is String ? json['cachedAt'] as String : '',
      ),
    );
  }

  List<Artwork> _works(Iterable<dynamic> ids) => List.unmodifiable(
    ids.whereType<String>().map(artwork).whereType<Artwork>(),
  );
  List<Artwork> get saved => _works(_data['saved'] as List);
  List<Artwork> get recentViews => _works(_data['recentViews'] as List);
  List<String> get recentSearches =>
      List<String>.unmodifiable(_data['recentSearches'] as List);
  List<PersonalCollection> get collections => List.unmodifiable(
    (_data['collections'] as List).map(
      (item) => PersonalCollection(
        item['id'] as String,
        item['name'] as String,
        List<String>.unmodifiable(item['artworkIds'] as List),
      ),
    ),
  );
  List<Artwork> collectionArtworks(String id) => _works(
    collections
            .where((collection) => collection.id == id)
            .firstOrNull
            ?.artworkIds ??
        [],
  );
  bool isSaved(String id) => (_data['saved'] as List).contains(id);
  String get appearance =>
      ['light', 'dark'].contains((_data['preferences'] as Map)['appearance'])
      ? (_data['preferences'] as Map)['appearance'] as String
      : 'system';
  bool get cacheThumbnails =>
      (_data['preferences'] as Map)['cacheThumbnails'] != false;
  int get metadataBytes => utf8.encode(jsonEncode(_data)).length;

  Future<T> _mutate<T>(T Function(Map<String, dynamic>) action) {
    final result = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        await initialize();
        if (readOnly) throw StateError('Library is read only');
        final next = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
        final value = action(next);
        _trim(next);
        await store.write(jsonEncode(next));
        _data = next;
        error = null;
        _notify();
        result.complete(value);
      } catch (failure) {
        if (failure is ArgumentError) {
          result.completeError(failure);
          return;
        }
        if (!readOnly) {
          error =
              'Unable to save changes on this device. Your previous library is unchanged. Please try again.';
        }
        _notify();
        result.completeError(StateError(error ?? 'Storage unavailable'));
      }
    });
    return result.future;
  }

  void _put(Map<String, dynamic> data, Artwork work) {
    final records = data['artworks'] as Map;
    final previous = records[work.id];
    records[work.id] = {
      ...ArtworkCodec.encode(work),
      'cachedAt': work.isCached
          ? (previous is Map
                ? previous['cachedAt']
                : work.cachedAt?.toIso8601String())
          : _now().toUtc().toIso8601String(),
    };
  }

  static Set<String> _protected(Map<String, dynamic> data) => {
    ...(data['saved'] as List).cast<String>(),
    ...(data['recentViews'] as List).cast<String>(),
    for (final collection in data['collections'] as List)
      ...(collection['artworkIds'] as List).cast<String>(),
  };
  static void _trim(Map<String, dynamic> data) {
    final records = data['artworks'] as Map;
    final protected = _protected(data);
    final removable = records.keys
        .where((id) => !protected.contains(id))
        .toList();
    for (final id in removable.take(
      (removable.length - 300).clamp(0, removable.length),
    )) {
      records.remove(id);
    }
    final queries = data['queries'] as Map;
    while (queries.length > 20) {
      queries.remove(queries.keys.first);
    }
  }

  Future<void> toggleSaved(Artwork work) => _mutate((data) {
    _put(data, work);
    final saved = data['saved'] as List;
    if (!saved.remove(work.id)) saved.insert(0, work.id);
  });
  Future<void> recordView(Artwork work) => _mutate((data) {
    _put(data, work);
    final recent = data['recentViews'] as List;
    recent.remove(work.id);
    recent.insert(0, work.id);
    if (recent.length > 30) recent.removeRange(30, recent.length);
  });
  Future<void> recordSearch(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;
    await _mutate<void>((data) {
      final recent = data['recentSearches'] as List;
      recent.removeWhere(
        (value) => (value as String).toLowerCase() == text.toLowerCase(),
      );
      recent.insert(0, text);
      if (recent.length > 12) recent.removeRange(12, recent.length);
    });
  }

  String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw ArgumentError('Use a collection name between 1 and 80 characters.');
    }
    return trimmed;
  }

  Future<String> createCollection(String name) {
    final valid = _validName(name);
    return _mutate((data) {
      final collections = data['collections'] as List;
      if (collections.any(
        (item) => (item['name'] as String).toLowerCase() == valid.toLowerCase(),
      )) {
        throw ArgumentError('A collection with that name already exists.');
      }
      var id = _now().microsecondsSinceEpoch.toString();
      while (collections.any((item) => item['id'] == id)) {
        id = '${id}a';
      }
      collections.add({'id': id, 'name': valid, 'artworkIds': <String>[]});
      return id;
    });
  }

  Future<void> renameCollection(String id, String name) {
    final valid = _validName(name);
    return _mutate((data) {
      final collections = data['collections'] as List;
      if (collections.any(
        (item) =>
            item['id'] != id &&
            (item['name'] as String).toLowerCase() == valid.toLowerCase(),
      )) {
        throw ArgumentError('A collection with that name already exists.');
      }
      final collection = collections
          .where((item) => item['id'] == id)
          .firstOrNull;
      if (collection == null) throw StateError('Collection no longer exists.');
      collection['name'] = valid;
    });
  }

  Future<void> deleteCollection(String id) => _mutate((data) {
    (data['collections'] as List).removeWhere((item) => item['id'] == id);
  });
  Future<void> setCollectionArtwork(String id, Artwork work, bool included) =>
      _mutate((data) {
        final collection = (data['collections'] as List)
            .where((item) => item['id'] == id)
            .firstOrNull;
        if (collection == null) {
          throw StateError('Collection no longer exists.');
        }
        _put(data, work);
        final ids = collection['artworkIds'] as List;
        ids.remove(work.id);
        if (included) ids.add(work.id);
      });
  Future<void> setAppearance(String appearance) => _mutate((data) {
    if (!['system', 'light', 'dark'].contains(appearance)) {
      throw ArgumentError('Invalid appearance');
    }
    (data['preferences'] as Map)['appearance'] = appearance;
  });
  Future<void> setCacheThumbnails(bool enabled) => _mutate(
    (data) => (data['preferences'] as Map)['cacheThumbnails'] = enabled,
  );
  Future<void> clearHistory() => _mutate((data) {
    data['recentViews'] = [];
    data['recentSearches'] = [];
  });
  Future<void> clearMetadataCache() => _mutate((data) {
    final protected = _protected(data);
    (data['artworks'] as Map).removeWhere((id, _) => !protected.contains(id));
    data['queries'] = <String, dynamic>{};
  });
  Future<void> cachePage(
    ArtworkQuery query,
    ArtworkPage page, {
    required bool firstPage,
  }) => _mutate((data) {
    for (final work in page.artworks) {
      _put(data, work);
    }
    if (firstPage && page.warnings.isEmpty) {
      final queries = data['queries'] as Map;
      queries.remove(query.fingerprint);
      queries[query.fingerprint] = {
        'ids': page.artworks.map((work) => work.id).toList(),
        'total': page.total,
        'cachedAt': _now().toUtc().toIso8601String(),
      };
    }
  });
  Future<void> cacheArtwork(Artwork work) =>
      _mutate((data) => _put(data, work));

  ArtworkPage? cachedSearch(ArtworkQuery query) {
    final cached = (_data['queries'] as Map)[query.fingerprint];
    if (cached is Map && cached['ids'] is List) {
      final works = _works(cached['ids'] as List);
      return ArtworkPage(
        artworks: works,
        total: works.length,
        nextOffset: null,
        isCached: true,
        cachedAt: DateTime.tryParse(
          cached['cachedAt'] is String ? cached['cachedAt'] as String : '',
        ),
      );
    }
    if (query.highlights || query.departmentId != null) return null;
    final term = query.text.trim().toLowerCase();
    final works = _records.keys
        .map(artwork)
        .whereType<Artwork>()
        .where((work) {
          if (query.source != null && work.source != query.source!.name) {
            return false;
          }
          final text = query.titleOnly
              ? work.title
              : [
                  work.title,
                  work.artist,
                  work.culture,
                  work.date,
                  work.medium,
                  work.museum,
                ].whereType<String>().join(' ');
          return text.toLowerCase().contains(term);
        })
        .take(60)
        .toList();
    if (works.isEmpty) return null;
    return ArtworkPage(
      artworks: works,
      total: works.length,
      nextOffset: null,
      isCached: true,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
