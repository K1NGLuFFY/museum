import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:museum/core/api/network_monitor.dart';
import 'package:museum/core/storage/library_store.dart';
import 'package:museum/core/storage/thumbnail_cache.dart';
import 'package:museum/features/artworks/artwork_detail_screen.dart';
import 'package:museum/features/collections/collections_screen.dart';
import 'package:museum/features/library/library_controller.dart';
import 'package:museum/features/library/library_scope.dart';
import 'package:museum/features/saved/saved_screen.dart';
import 'package:museum/features/settings/settings_controller.dart';
import 'package:museum/features/settings/settings_screen.dart';

import 'library_test.dart' show libraryWork, libraryFor;

Widget scoped(
  LibraryController library,
  Widget screen, {
  ThumbnailCache? thumbnails,
}) => LibraryScope(
  library: library,
  network: FixedNetworkMonitor(offline: true),
  thumbnails: thumbnails ?? EmptyThumbnailCache(),
  child: CupertinoApp(home: screen),
);

class CountingCache extends EmptyThumbnailCache {
  int clears = 0;
  @override
  Future<ThumbnailCacheSize> size() async => const ThumbnailCacheSize(2, 4096);
  @override
  Future<void> clear() async {
    clears++;
  }
}

void main() {
  testWidgets(
    'bookmark from detail survives restart and opens offline from Saved',
    (tester) async {
      final store = MemoryLibraryStore();
      final library = libraryFor(store);
      await library.initialize();
      await tester.pumpWidget(
        scoped(library, ArtworkDetailScreen(artwork: libraryWork())),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save artwork'));
      await tester.tap(find.text('Save artwork'));
      await tester.pumpAndSettle();
      expect(library.isSaved('met:45734'), isTrue);
      expect(library.recentViews.single.id, 'met:45734');
      await tester.pumpWidget(const SizedBox.shrink());
      final restored = libraryFor(store);
      await restored.initialize();
      await tester.pumpWidget(scoped(restored, SavedScreen(onExplore: () {})));
      await tester.pumpAndSettle();
      expect(find.text('Quail and Millet'), findsOneWidget);
      expect(find.textContaining('No network connection.'), findsOneWidget);
      await tester.tap(find.text('Quail and Millet'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Stored metadata'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Remove bookmark'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove bookmark'));
      await tester.pumpAndSettle();
      expect(restored.saved, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'create, rename, add/remove artwork and delete a personal collection',
    (tester) async {
      final library = libraryFor(MemoryLibraryStore());
      await library.initialize();
      await tester.pumpWidget(
        scoped(library, CollectionsScreen(onExplore: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), 'Ink');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final id = library.collections.single.id;
      await library.setCollectionArtwork(id, libraryWork(), true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ink'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), 'Silk');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(library.collections.single.name, 'Silk');
      await tester.ensureVisible(find.text('Remove from collection'));
      await tester.tap(find.text('Remove from collection'));
      await tester.pumpAndSettle();
      expect(library.collections.single.artworkIds, isEmpty);
      await tester.ensureVisible(find.text('Delete collection'));
      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(library.collections, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('collection picker adds artwork and cache controls preserve it', (
    tester,
  ) async {
    final library = libraryFor(MemoryLibraryStore());
    await library.initialize();
    final id = await library.createCollection('Favorites');
    await tester.pumpWidget(
      scoped(library, ArtworkDetailScreen(artwork: libraryWork())),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add to collection'));
    await tester.tap(find.text('Add to collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();
    expect(library.collectionArtworks(id), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    final cache = CountingCache();
    final settings = SettingsController(library: library);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      scoped(library, SettingsScreen(settings: settings), thumbnails: cache),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('4.0 KB'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear disposable cache'));
    await tester.tap(find.text('Clear disposable cache'));
    await tester.pumpAndSettle();
    expect(cache.clears, 1);
    expect(library.collectionArtworks(id), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'corrupt library displays recoverable read error rather than silently saving',
    (tester) async {
      final library = libraryFor(MemoryLibraryStore(snapshot: '{bad'));
      await library.initialize();
      await tester.pumpWidget(
        scoped(library, ArtworkDetailScreen(artwork: libraryWork())),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Existing files have been preserved'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Save artwork'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final button = tester.widget<CupertinoButton>(
        find.ancestor(
          of: find.text('Save artwork'),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
