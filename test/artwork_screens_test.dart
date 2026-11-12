import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:museum/app/museum_app.dart';
import 'package:museum/features/artworks/artwork.dart';
import 'package:museum/features/artworks/artwork_detail_screen.dart';
import 'package:museum/features/explore/explore_screen.dart';

import 'fake_artwork_repository.dart';

class ControlledRepository extends FakeArtworkRepository {
  final pending = <String, Completer<ArtworkPage>>{};
  final tokens = <String, CancellationToken?>{};
  @override
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  }) {
    queries.add(query);
    tokens[query.text] = cancellation;
    return (pending[query.text] = Completer<ArtworkPage>()).future;
  }
}

void main() {
  testWidgets(
    'museum and title filters reach the repository; partial warning remains visible',
    (tester) async {
      final repository = FakeArtworkRepository()
        ..page = const ArtworkPage(
          artworks: [],
          total: 0,
          nextOffset: 1,
          warnings: [
            SourceWarning(MuseumSource.chicago, 'Temporarily unavailable.'),
          ],
        );
      await tester.pumpWidget(
        CupertinoApp(
          home: ExploreScreen(
            repository: repository,
            initialQuery: const ArtworkQuery(text: 'water'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Other available results are shown.'),
        findsOneWidget,
      );
      await tester.tap(find.text('All museums'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cleveland Museum of Art'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.source, MuseumSource.cleveland);
      await tester.tap(find.text('All metadata'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.titleOnly, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Discover renders network error and recovers with retry', (
    tester,
  ) async {
    final repository = FakeArtworkRepository()
      ..error = const MuseumException('Check your connection.');
    await tester.pumpWidget(MuseumApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('The gallery is out of reach'), findsOneWidget);
    repository.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No open-access images found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search debounces, cancels stale requests, and displays empty state',
    (tester) async {
      final repository = ControlledRepository();
      await tester.pumpWidget(
        CupertinoApp(home: ExploreScreen(repository: repository)),
      );
      await tester.enterText(find.byType(CupertinoSearchTextField), 'ink');
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      await tester.enterText(find.byType(CupertinoSearchTextField), 'silk');
      expect(repository.tokens['ink']!.isCancelled, isTrue);
      await tester.pump(const Duration(milliseconds: 450));
      repository.pending['silk']!.complete(
        const ArtworkPage(artworks: [], total: 0, nextOffset: null),
      );
      await tester.pumpAndSettle();
      expect(find.text('No public-domain images found'), findsOneWidget);
      repository.pending['ink']!.completeError(
        const MuseumException('Stale error'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stale error'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detail handles missing image and metadata at enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final artwork = Artwork(
      source: 'met',
      sourceId: '45734',
      title: 'Quail and Millet',
      museum: 'The Metropolitan Museum of Art',
      license: 'Image rights not confirmed by the museum',
      sourceUrl: Uri.https('www.metmuseum.org', '/art/collection/search/45734'),
    );
    await tester.pumpWidget(
      CupertinoApp(home: ArtworkDetailScreen(artwork: artwork)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(find.text('View full screen · Zoom'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The museum has not supplied an artist or maker for this work.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
