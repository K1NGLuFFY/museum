import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:museum/features/artworks/artwork.dart';
import 'package:museum/features/artworks/chicago_repository.dart';
import 'package:museum/features/artworks/cleveland_repository.dart';

// Opt in explicitly: flutter test --dart-define=RUN_LIVE_MUSEUM_TESTS=true
// test/official_api_smoke_test.dart. Normal test runs remain deterministic/offline.
void main() {
  const live = bool.fromEnvironment('RUN_LIVE_MUSEUM_TESTS');
  for (final museum in ['Chicago', 'Cleveland']) {
    test(
      '$museum official search, detail, pagination and JPEG decode',
      () async {
        final ArtworkSource repository = museum == 'Chicago'
            ? ChicagoRepository()
            : ClevelandRepository();
        addTearDown(repository.dispose);
        final first = await repository.search(
          const ArtworkQuery(text: 'monet'),
        );
        expect(first.artworks, isNotEmpty);
        final artwork = first.artworks.first;
        expect(artwork.isPublicDomain, isTrue);
        expect(artwork.thumbnailUrl?.scheme, 'https');
        final ArtworkSource detailRepository = museum == 'Chicago'
            ? ChicagoRepository()
            : ClevelandRepository();
        addTearDown(detailRepository.dispose);
        final detail = await detailRepository.getArtwork(artwork.sourceId);
        expect(detail.id, artwork.id);
        if (first.nextOffset != null) {
          final second = await repository.search(
            const ArtworkQuery(text: 'monet'),
            offset: first.nextOffset!,
          );
          expect(
            second.artworks
                .map((work) => work.id)
                .toSet()
                .intersection(first.artworks.map((work) => work.id).toSet()),
            isEmpty,
          );
        }
        final client = http.Client();
        addTearDown(client.close);
        final image = await client
            .get(artwork.thumbnailUrl!)
            .timeout(const Duration(seconds: 30));
        expect(image.statusCode, 200);
        expect(image.headers['content-type'], contains('image/'));
        final codec = await ui.instantiateImageCodec(
          image.bodyBytes,
          targetWidth: 80,
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      },
      skip: !live,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
