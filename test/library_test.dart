import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:museum/core/api/network_monitor.dart';
import 'package:museum/core/storage/library_store.dart';
import 'package:museum/features/artworks/artwork.dart';
import 'package:museum/features/library/artwork_codec.dart';
import 'package:museum/features/library/cached_artwork_repository.dart';
import 'package:museum/features/library/library_controller.dart';
import 'package:museum/features/settings/settings_controller.dart';

import 'fake_artwork_repository.dart';

// Test-only metadata for the documented Met record; varying IDs exercise storage.
Artwork libraryWork({String id = '45734', String source = 'met'}) => Artwork(
  source: source,
  sourceId: id,
  title: 'Quail and Millet',
  artist: 'Kiyohara Yukinobu',
  date: 'late 17th century',
  medium: 'Hanging scroll; ink and color on silk',
  culture: 'Japan',
  museum: 'The Metropolitan Museum of Art',
  license: 'Public domain · CC0',
  isPublicDomain: true,
  sourceUrl: Uri.https('www.metmuseum.org', '/art/collection/search/$id'),
  thumbnailUrl: Uri.parse(
    'https://images.metmuseum.org/CRDImages/as/web-large/DP251139.jpg',
  ),
  fullImageUrl: Uri.parse(
    'https://images.metmuseum.org/CRDImages/as/original/DP251139.jpg',
  ),
  additionalImages: [
    Uri.parse(
      'https://images.metmuseum.org/CRDImages/as/original/DP251138.jpg',
    ),
  ],
  descriptionAttribution: 'Test attribution',
  descriptionLicenseUrl: Uri.https('creativecommons.org', '/licenses/by/4.0/'),
);

LibraryController libraryFor(LibraryStore store) => LibraryController(
  store: store,
  now: () => DateTime.utc(2026, 11, 12),
  legacyAppearance: () async => null,
);

class OfflineRemote extends FakeArtworkRepository {
  @override
  Future<Artwork> getArtwork(
    String sourceId, {
    CancellationToken? cancellation,
  }) async {
    if (error != null) throw error!;
    return page.artworks.firstWhere((work) => work.id == sourceId);
  }
}

void main() {
  test(
    'full normalized metadata and rights round trip with stable source IDs',
    () {
      final work = libraryWork();
      final restored = ArtworkCodec.decode(
        ArtworkCodec.encode(work),
        cachedAt: DateTime.utc(2026),
      );
      expect(ArtworkCodec.encode(restored), ArtworkCodec.encode(work));
      expect(restored.id, work.id);
      expect(restored.isCached, isTrue);
      expect(restored.cachedAt, DateTime.utc(2026));
      final restricted = ArtworkCodec.decode({
        ...ArtworkCodec.encode(work),
        'isPublicDomain': false,
      });
      expect(restricted.fullImageUrl, isNull);
      expect(restricted.additionalImages, isEmpty);
    },
  );

  test(
    'bookmarks, collections, history and preferences survive a new controller',
    () async {
      final store = MemoryLibraryStore();
      final library = libraryFor(store);
      await library.initialize();
      final work = libraryWork();
      await library.toggleSaved(work);
      final id = await library.createCollection('Japanese art');
      await library.setCollectionArtwork(id, work, true);
      await library.renameCollection(id, 'Ink and silk');
      await library.recordView(work);
      await library.recordSearch('Yukinobu');
      await library.setAppearance('dark');
      await library.setCacheThumbnails(false);
      final restored = libraryFor(store);
      await restored.initialize();
      expect(restored.saved.single.id, work.id);
      expect(restored.collections.single.name, 'Ink and silk');
      expect(restored.collectionArtworks(id).single.artist, work.artist);
      expect(restored.recentViews.single.id, work.id);
      expect(restored.recentSearches, ['Yukinobu']);
      expect(restored.appearance, 'dark');
      expect(restored.cacheThumbnails, isFalse);
      expect(restored.saved.single.cachedAt, DateTime.utc(2026, 11, 12));
      await restored.setCollectionArtwork(id, work, false);
      expect(restored.collectionArtworks(id), isEmpty);
      await restored.deleteCollection(id);
      expect(restored.collections, isEmpty);
      expect(restored.saved, hasLength(1));
      await restored.toggleSaved(work);
      expect(restored.saved, isEmpty);
    },
  );

  test(
    'serialized concurrent changes do not lose records or collide collection IDs',
    () async {
      final library = libraryFor(MemoryLibraryStore());
      await Future.wait([
        library.toggleSaved(libraryWork()),
        library.toggleSaved(libraryWork(source: 'chicago')),
        library.createCollection('One'),
        library.createCollection('Two'),
      ]);
      expect(library.saved.map((work) => work.id).toSet(), {
        'met:45734',
        'chicago:45734',
      });
      expect(
        library.collections.map((collection) => collection.id).toSet(),
        hasLength(2),
      );
    },
  );

  test(
    'failed writes roll back and later queued writes still succeed',
    () async {
      final store = MemoryLibraryStore();
      final library = libraryFor(store);
      await library.initialize();
      await library.toggleSaved(libraryWork());
      final before = store.snapshot;
      store.failWrites = true;
      await expectLater(library.toggleSaved(libraryWork()), throwsStateError);
      expect(library.saved, hasLength(1));
      expect(store.snapshot, before);
      expect(library.error, isNotNull);
      store.failWrites = false;
      await library.toggleSaved(libraryWork());
      expect(library.saved, isEmpty);
    },
  );

  test(
    'collection validation is actionable and does not change durable state',
    () async {
      final library = libraryFor(MemoryLibraryStore());
      await library.createCollection('One');
      expect(() => library.createCollection('  '), throwsArgumentError);
      await expectLater(library.createCollection('one'), throwsArgumentError);
      expect(library.collections, hasLength(1));
      expect(library.error, isNull);
    },
  );

  test(
    'history deduplicates and is bounded; clearing it preserves saved works',
    () async {
      final library = libraryFor(MemoryLibraryStore());
      await library.toggleSaved(libraryWork());
      for (var i = 1; i <= 34; i++) {
        await library.recordView(libraryWork(id: '$i'));
        await library.recordSearch('query $i');
      }
      await library.recordSearch('QUERY 34');
      await library.recordView(libraryWork(id: '34'));
      expect(library.recentViews, hasLength(30));
      expect(library.recentSearches, hasLength(12));
      expect(library.recentSearches.first, 'QUERY 34');
      await library.clearHistory();
      expect(library.recentViews, isEmpty);
      expect(library.recentSearches, isEmpty);
      expect(library.saved, hasLength(1));
    },
  );

  test(
    'cache eviction and explicit clearing protect saved, collected and recent metadata',
    () async {
      final library = libraryFor(MemoryLibraryStore());
      await library.toggleSaved(libraryWork(id: '1'));
      final id = await library.createCollection('Keep');
      await library.setCollectionArtwork(id, libraryWork(id: '2'), true);
      await library.recordView(libraryWork(id: '3'));
      final works = List.generate(
        305,
        (index) => libraryWork(id: '${index + 10}'),
      );
      await library.cachePage(
        const ArtworkQuery(text: 'ink'),
        ArtworkPage(artworks: works, total: 1000, nextOffset: 12),
        firstPage: true,
      );
      expect(library.artwork('met:10'), isNull);
      expect(library.artwork('met:314'), isNotNull);
      await library.clearMetadataCache();
      expect(library.artwork('met:314'), isNull);
      for (final id in ['1', '2', '3']) {
        expect(library.artwork('met:$id'), isNotNull);
      }
    },
  );

  test(
    'corrupt records are isolated, dangling IDs removed, malformed optional fields tolerated',
    () async {
      final store = MemoryLibraryStore();
      final library = libraryFor(store);
      await library.toggleSaved(libraryWork());
      final json = jsonDecode(store.snapshot!) as Map<String, dynamic>;
      json['artworks']['met:1'] = {'source': 'met', 'sourceId': 'invalid'};
      json['artworks']['met:45734']['cachedAt'] = 7;
      json['saved'] = ['met:1', 'met:45734', 'missing', 'met:45734'];
      json['recentSearches'] = 1;
      json['preferences'] = [];
      store.snapshot = jsonEncode(json);
      final restored = libraryFor(store);
      await restored.initialize();
      expect(restored.readOnly, isFalse);
      expect(restored.saved.single.id, 'met:45734');
      expect(restored.saved.single.cachedAt, isNull);
      expect(restored.error, contains('ignored'));
      expect(restored.recentSearches, isEmpty);
      expect(restored.appearance, 'system');
    },
  );

  test(
    'corrupt or future-version snapshots are never overwritten, with safe backup recovery',
    () async {
      final valid = MemoryLibraryStore();
      await libraryFor(valid).toggleSaved(libraryWork());
      final recovered = libraryFor(
        MemoryLibraryStore(snapshot: '{broken', backup: valid.snapshot),
      );
      await recovered.initialize();
      expect(recovered.saved, hasLength(1));
      expect(recovered.error, contains('recovered'));
      for (final bad in ['{broken', '{"version":99}']) {
        final store = MemoryLibraryStore(
          snapshot: bad,
          backup: bad.contains('99') ? valid.snapshot : null,
        );
        final library = libraryFor(store);
        await library.initialize();
        expect(library.readOnly, isTrue);
        await expectLater(library.toggleSaved(libraryWork()), throwsStateError);
        expect(store.snapshot, bad);
      }
    },
  );

  test(
    'legacy appearance migrates once; settings restore without replacing new preference',
    () async {
      final store = MemoryLibraryStore();
      final library = LibraryController(
        store: store,
        legacyAppearance: () async => 'dark',
      );
      final settings = SettingsController(library: library);
      await library.initialize();
      expect(settings.appearance, Appearance.dark);
      await settings.setAppearance(Appearance.light);
      settings.dispose();
      final next = LibraryController(
        store: store,
        legacyAppearance: () async => 'dark',
      );
      await next.initialize();
      expect(next.appearance, 'light');
    },
  );

  test(
    'file snapshots replace atomically and recover after a corrupt primary',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'museum_library_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = FileLibraryStore(directory: () async => directory);
      final first = libraryFor(store);
      await first.toggleSaved(libraryWork());
      await first.recordView(libraryWork());
      final restored = libraryFor(store);
      await restored.initialize();
      expect(restored.saved, hasLength(1));
      await File(
        '${directory.path}/museum_library.json',
      ).writeAsString('corrupt');
      final recovered = libraryFor(store);
      await recovered.initialize();
      expect(recovered.saved, hasLength(1));
      await recovered.setAppearance('dark');
      final finalRead = libraryFor(store);
      await finalRead.initialize();
      expect(finalRead.saved, hasLength(1));
      expect(finalRead.appearance, 'dark');
    },
  );

  test(
    'offline saved detail and cached search survive restart without a network request',
    () async {
      final store = MemoryLibraryStore();
      final library = libraryFor(store);
      final remote = OfflineRemote()
        ..page = ArtworkPage(
          artworks: [libraryWork()],
          total: 40,
          nextOffset: 12,
        );
      final network = FixedNetworkMonitor();
      final repository = CachedArtworkRepository(
        remote: remote,
        library: library,
        network: network,
      );
      await repository.search(const ArtworkQuery(text: 'ink'));
      expect(remote.queries, hasLength(1));
      final restarted = libraryFor(store);
      network.setOffline(true);
      final offline = CachedArtworkRepository(
        remote: remote,
        library: restarted,
        network: network,
      );
      final cached = await offline.search(const ArtworkQuery(text: 'ink'));
      expect(cached.isCached, isTrue);
      expect(cached.artworks.single.isCached, isTrue);
      expect(cached.nextOffset, isNull);
      expect(
        (await offline.getArtwork('met:45734')).artist,
        'Kiyohara Yukinobu',
      );
      expect(remote.queries, hasLength(1));
      network.setOffline(false);
      remote.error = const MuseumException('Offline behind Wi-Fi');
      expect(
        (await offline.search(const ArtworkQuery(text: 'ink'))).isCached,
        isTrue,
      );
      await expectLater(
        offline.search(const ArtworkQuery(text: 'ink'), offset: 12),
        throwsA(isA<MuseumException>()),
      );
    },
  );

  test(
    'local fallback respects source/title and never invents uncached curated selections',
    () async {
      final library = libraryFor(MemoryLibraryStore());
      await library.toggleSaved(libraryWork());
      expect(
        library.cachedSearch(const ArtworkQuery(text: 'Yukinobu'))!.artworks,
        hasLength(1),
      );
      expect(
        library.cachedSearch(
          const ArtworkQuery(text: 'Yukinobu', titleOnly: true),
        ),
        isNull,
      );
      expect(
        library.cachedSearch(
          const ArtworkQuery(text: 'Quail', source: MuseumSource.chicago),
        ),
        isNull,
      );
      expect(
        library.cachedSearch(const ArtworkQuery(highlights: true)),
        isNull,
      );
    },
  );
}
