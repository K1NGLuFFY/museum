import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:museum/core/api/museum_http_client.dart';
import 'package:museum/features/artworks/artwork.dart';
import 'package:museum/features/artworks/chicago_artwork.dart';
import 'package:museum/features/artworks/chicago_repository.dart';
import 'package:museum/features/artworks/cleveland_artwork.dart';
import 'package:museum/features/artworks/cleveland_repository.dart';
import 'package:museum/features/artworks/museum_repository.dart';

// Minimal fields from live public-domain museum records; malformed variants
// below are test inputs, never bundled as application content.
Map<String, dynamic> chicagoRecord() => {
  'id': 16568,
  'title': 'Water Lilies',
  'artist_display': 'Claude Monet (French, 1840–1926)',
  'date_display': '1906',
  'place_of_origin': 'France',
  'medium_display': 'Oil on canvas',
  'is_public_domain': true,
  'image_id': '3c27b499-af56-f0d5-93b5-a7f2f1ad5813',
  'alt_image_ids': [],
  'department_title': 'Painting and Sculpture of Europe',
};
const chicagoConfig = {'iiif_url': 'https://www.artic.edu/iiif/2'};
Map<String, dynamic> clevelandRecord() => {
  'id': 135382,
  'title': 'The Red Kerchief',
  'creation_date': 'c. 1868–73',
  'share_license_status': 'CC0',
  'url': 'https://clevelandart.org/art/1958.39',
  'culture': ['France'],
  'creators': [
    {'description': 'Claude Monet (French, 1840–1926)'},
  ],
  'images': {
    'web': {
      'url': 'https://openaccess-cdn.clevelandart.org/1958.39/1958.39_web.jpg',
    },
    'print': {
      'url':
          'https://openaccess-cdn.clevelandart.org/1958.39/1958.39_print.jpg',
    },
    'full': {
      'url': 'https://openaccess-cdn.clevelandart.org/1958.39/1958.39_full.tif',
    },
  },
  'alternate_images': [
    {
      'web': {
        'url':
            'https://openaccess-cdn.clevelandart.org/1958.39/1958.39_alt0_web.jpg',
      },
    },
  ],
};

class RecordingSource implements ArtworkSource {
  RecordingSource(this.respond);
  Future<ArtworkPage> Function(ArtworkQuery query, int offset) respond;
  final offsets = <int>[];
  final ids = <String>[];
  bool disposed = false;
  @override
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  }) {
    cancellation?.check();
    offsets.add(offset);
    return respond(query, offset);
  }

  @override
  Future<Artwork> getArtwork(
    String sourceId, {
    CancellationToken? cancellation,
  }) async {
    ids.add(sourceId);
    return ChicagoArtworkDto(chicagoRecord(), chicagoConfig).normalize();
  }

  @override
  void dispose() {
    disposed = true;
  }
}

ArtworkPage page(List<Artwork> works, {int total = 1, int? next}) =>
    ArtworkPage(artworks: works, total: total, nextOffset: next);

void main() {
  group('Chicago adapter', () {
    test(
      'uses response IIIF base, exact supported sizes, source and artist metadata',
      () {
        final work = ChicagoArtworkDto(chicagoRecord(), {
          'iiif_url': 'https://museum.example/iiif/custom/',
        }).normalize();
        expect(work.id, 'chicago:16568');
        expect(
          work.thumbnailUrl.toString(),
          'https://museum.example/iiif/custom/3c27b499-af56-f0d5-93b5-a7f2f1ad5813/full/843,/0/default.jpg',
        );
        expect(
          work.fullImageUrl.toString(),
          endsWith('/full/1686,/0/default.jpg'),
        );
        expect(
          work.sourceUrl.toString(),
          'https://www.artic.edu/artworks/16568',
        );
        expect(work.artist, contains('Claude Monet'));
        expect(work.culture, isNull);
      },
    );
    test(
      'non-public-domain works, missing config and unsafe identifiers expose no images',
      () {
        for (final flag in [false, null, 'true']) {
          final work = ChicagoArtworkDto({
            ...chicagoRecord(),
            'is_public_domain': flag,
            'alt_image_ids': ['image-id'],
          }, chicagoConfig).normalize();
          expect(work.fullImageUrl, isNull);
          expect(work.thumbnailUrl, isNull);
          expect(work.additionalImages, isEmpty);
        }
        for (final id in [null, '', '../bad', 'https://bad.example/a']) {
          expect(
            ChicagoArtworkDto({
              ...chicagoRecord(),
              'image_id': id,
            }, chicagoConfig).normalize().hasImage,
            isFalse,
          );
        }
        expect(
          ChicagoArtworkDto(chicagoRecord(), {}).normalize().hasImage,
          isFalse,
        );
        expect(
          ChicagoArtworkDto(chicagoRecord(), {
            'iiif_url': 'http://example.com',
          }).normalize().hasImage,
          isFalse,
        );
      },
    );
    test(
      'description is parsed as text and retains separate CC BY attribution',
      () {
        final work = ChicagoArtworkDto({
          ...chicagoRecord(),
          'description':
              '<p>Test &amp; <em>text</em>.</p><p>Second paragraph.</p><script>bad()</script>',
        }, chicagoConfig).normalize();
        expect(work.description, 'Test & text.\nSecond paragraph.');
        expect(work.descriptionAttribution, contains('CC BY 4.0'));
        expect(
          work.descriptionLicenseUrl.toString(),
          'https://creativecommons.org/licenses/by/4.0/',
        );
        expect(
          ChicagoArtworkDto(
            chicagoRecord(),
            chicagoConfig,
          ).normalize().descriptionAttribution,
          isNull,
        );
      },
    );
    test('invalid id rejected; absent optional metadata stays absent', () {
      expect(
        () => ChicagoArtworkDto({'id': '1'}, chicagoConfig),
        throwsFormatException,
      );
      final work = ChicagoArtworkDto({'id': 1}, {}).normalize();
      expect(work.title, 'Untitled work');
      expect(work.artist, isNull);
      expect(work.description, isNull);
    });
  });

  group('Cleveland adapter', () {
    test(
      'preserves CC0, creators, culture, source URL and JPEG alternate views',
      () {
        final work = ClevelandArtworkDto(clevelandRecord()).normalize();
        expect(work.id, 'cleveland:135382');
        expect(work.artist, contains('Claude Monet'));
        expect(work.culture, 'France');
        expect(work.hasImage, isTrue);
        expect(work.fullImageUrl.toString(), endsWith('_print.jpg'));
        expect(
          work.additionalImages.single.toString(),
          endsWith('_alt0_web.jpg'),
        );
        expect(
          work.sourceUrl.toString(),
          'https://clevelandart.org/art/1958.39',
        );
        expect(work.license, contains('CC0'));
      },
    );
    test('Copyrighted, Other and absent license suppress every image', () {
      for (final license in ['Copyrighted', 'Other', null, 'cc0']) {
        final work = ClevelandArtworkDto({
          ...clevelandRecord(),
          'share_license_status': license,
        }).normalize();
        expect(work.hasImage, isFalse);
        expect(work.thumbnailUrl, isNull);
        expect(work.additionalImages, isEmpty);
      }
    });
    test(
      'falls back to web JPEG and never feeds TIFF or unsafe URLs to Flutter',
      () {
        final work = ClevelandArtworkDto({
          ...clevelandRecord(),
          'images': {
            'web': {'url': 'https://example.com/image.jpg'},
            'print': {'url': 'https://example.com/image.tif'},
          },
        }).normalize();
        expect(work.fullImageUrl.toString(), 'https://example.com/image.jpg');
        final invalid = ClevelandArtworkDto({
          ...clevelandRecord(),
          'images': {
            'web': {'url': 'http://example.com/image.jpg'},
            'full': {'url': 'https://example.com/image.tif'},
          },
        }).normalize();
        expect(invalid.hasImage, isFalse);
        expect(ClevelandArtworkDto({'id': 1}).normalize().artist, isNull);
        expect(() => ClevelandArtworkDto({'id': -1}), throwsFormatException);
      },
    );
  });

  group('source repositories', () {
    test(
      'Chicago uses mandatory keyword match plus rights filter, pages correctly and caches details',
      () async {
        var calls = 0;
        final repository = ChicagoRepository(
          client: MuseumHttpClient(
            client: MockClient((request) async {
              calls++;
              expect(request.url.path, '/api/v1/artworks/search');
              final params =
                  jsonDecode(request.url.queryParameters['params']!) as Map;
              expect(params['page'], 2);
              expect(params['limit'], 10);
              expect(
                params['query']['bool']['must'][0]['multi_match']['query'],
                'monet',
              );
              expect(
                params['query']['bool']['filter'][0]['term']['is_public_domain'],
                isTrue,
              );
              return http.Response(
                jsonEncode({
                  'pagination': {'total': 25},
                  'config': chicagoConfig,
                  'data': [
                    chicagoRecord(),
                    chicagoRecord(),
                    {'id': 2, 'is_public_domain': false},
                  ],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        );
        final result = await repository.search(
          const ArtworkQuery(text: 'monet'),
          offset: 10,
        );
        expect(result.artworks, hasLength(1));
        expect(result.nextOffset, 20);
        expect(result.skipped, 2);
        await repository.getArtwork('16568');
        expect(calls, 1);
        repository.dispose();
      },
    );
    test(
      'Chicago title filter is exclusive and stops at documented 1,000 cap',
      () async {
        final repository = ChicagoRepository(
          client: MuseumHttpClient(
            client: MockClient((request) async {
              final params =
                  jsonDecode(request.url.queryParameters['params']!) as Map;
              expect(params['page'], 100);
              expect(params.containsKey('q'), isFalse);
              expect(params['query']['bool']['must'][0], {
                'match': {'title': 'water'},
              });
              return http.Response(
                jsonEncode({
                  'pagination': {'total': 2000},
                  'config': chicagoConfig,
                  'data': [chicagoRecord()],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        );
        final result = await repository.search(
          const ArtworkQuery(text: 'water', titleOnly: true),
          offset: 990,
        );
        expect(result.nextOffset, isNull);
        expect(result.limited, isTrue);
        await expectLater(
          repository.search(const ArtworkQuery(), offset: 1000),
          throwsA(isA<MuseumException>()),
        );
      },
    );
    test(
      'Cleveland requests CC0 and images, paginates raw rows before filtering, caches metadata',
      () async {
        var calls = 0;
        final repository = ClevelandRepository(
          client: MuseumHttpClient(
            client: MockClient((request) async {
              calls++;
              expect(request.url.queryParameters['q'], 'monet & water');
              expect(request.url.queryParameters.containsKey('cc0'), isTrue);
              expect(request.url.queryParameters['has_image'], '1');
              expect(request.url.queryParameters['skip'], '12');
              return http.Response(
                jsonEncode({
                  'info': {'total': 18},
                  'data': [
                    clevelandRecord(),
                    {
                      ...clevelandRecord(),
                      'id': 2,
                      'share_license_status': 'Copyrighted',
                    },
                    {'id': 'bad'},
                  ],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        );
        final result = await repository.search(
          const ArtworkQuery(text: 'monet & water'),
          offset: 12,
        );
        expect(result.artworks, hasLength(1));
        expect(result.skipped, 2);
        expect(result.nextOffset, 15);
        await repository.getArtwork('135382');
        expect(calls, 1);
        repository.dispose();
      },
    );
    test(
      'Cleveland title-only query and empty page terminate correctly',
      () async {
        final repository = ClevelandRepository(
          client: MuseumHttpClient(
            client: MockClient((request) async {
              expect(request.url.queryParameters['title'], 'water');
              expect(request.url.queryParameters.containsKey('q'), isFalse);
              return http.Response('{"info":{"total":10},"data":[]}', 200);
            }),
          ),
        );
        final result = await repository.search(
          const ArtworkQuery(text: 'water', titleOnly: true),
        );
        expect(result.artworks, isEmpty);
        expect(result.nextOffset, isNull);
      },
    );
    test(
      'invalid response shapes and detail IDs are readable failures',
      () async {
        for (final source in <ArtworkSource>[
          ChicagoRepository(
            client: MuseumHttpClient(
              client: MockClient((_) async => http.Response('{}', 200)),
            ),
          ),
          ClevelandRepository(
            client: MuseumHttpClient(
              client: MockClient((_) async => http.Response('{}', 200)),
            ),
          ),
        ]) {
          await expectLater(
            source.search(const ArtworkQuery(text: 'water')),
            throwsA(isA<MuseumException>()),
          );
          await expectLater(
            source.getArtwork('42'),
            throwsA(isA<MuseumException>()),
          );
          await expectLater(
            source.getArtwork('../invalid'),
            throwsA(isA<MuseumException>()),
          );
          source.dispose();
        }
      },
    );
  });

  group('composite repository', () {
    final chicago = ChicagoArtworkDto(
      chicagoRecord(),
      chicagoConfig,
    ).normalize();
    final cleveland = ClevelandArtworkDto(clevelandRecord()).normalize();
    test(
      'partial failure preserves successful works and independent cursors; retry skips exhausted source',
      () async {
        final met = RecordingSource(
          (_, offset) async => throw const MuseumException('Offline'),
        );
        final aic = RecordingSource(
          (_, offset) async => page(
            [chicago, chicago],
            total: 20,
            next: offset == 0 ? 10 : null,
          ),
        );
        final cma = RecordingSource((_, offset) async => page([cleveland]));
        final repo = MuseumRepository(
          sources: {
            MuseumSource.met: met,
            MuseumSource.chicago: aic,
            MuseumSource.cleveland: cma,
          },
        );
        final first = await repo.search(const ArtworkQuery(text: 'monet'));
        expect(first.artworks.map((work) => work.id), [
          chicago.id,
          cleveland.id,
        ]);
        expect(first.warnings.single.source, MuseumSource.met);
        expect(first.nextCursor!.offsets[MuseumSource.met], 0);
        expect(first.nextCursor!.offsets[MuseumSource.chicago], 10);
        expect(first.nextCursor!.offsets[MuseumSource.cleveland], isNull);
        met.respond = (_, offset) async => page([]);
        final second = await repo.search(
          ArtworkQuery(text: 'monet', cursor: first.nextCursor),
          offset: first.nextOffset!,
        );
        expect(
          second.artworks,
          isEmpty,
        ); // Same source ID is not repeated on later pages.
        expect(second.warnings, isEmpty);
        expect(second.nextOffset, isNull);
        expect(aic.offsets, [0, 10]);
        expect(met.offsets, [0, 0]);
        expect(cma.offsets, [0]);
        expect(second.total, 22);
        repo.dispose();
        expect(met.disposed && aic.disposed && cma.disposed, isTrue);
      },
    );
    test(
      'all failed sources throw but successful empty sources retain partial warnings',
      () async {
        final failed = RecordingSource(
          (_, offset) async => throw const MuseumException('Offline'),
        );
        final repo = MuseumRepository(sources: {MuseumSource.chicago: failed});
        await expectLater(
          repo.search(const ArtworkQuery(text: 'monet')),
          throwsA(isA<MuseumException>()),
        );
        final partial = MuseumRepository(
          sources: {
            MuseumSource.chicago: failed,
            MuseumSource.cleveland: RecordingSource(
              (_, offset) async => page([], total: 0),
            ),
          },
        );
        final result = await partial.search(const ArtworkQuery(text: 'monet'));
        expect(result.artworks, isEmpty);
        expect(result.warnings, hasLength(1));
        expect(result.nextCursor, isNotNull);
      },
    );
    test(
      'selection isolates museum, title filter reaches source, source-qualified IDs route correctly',
      () async {
        final aic = RecordingSource((query, offset) async {
          expect(query.titleOnly, isTrue);
          return page([chicago]);
        });
        final cma = RecordingSource((_, offset) async => page([cleveland]));
        final repo = MuseumRepository(
          sources: {MuseumSource.chicago: aic, MuseumSource.cleveland: cma},
        );
        final result = await repo.search(
          const ArtworkQuery(
            text: 'water',
            source: MuseumSource.chicago,
            titleOnly: true,
          ),
        );
        expect(result.artworks.single.id, chicago.id);
        expect(cma.offsets, isEmpty);
        await repo.getArtwork('chicago:16568');
        expect(aic.ids, ['16568']);
        expect(
          () => repo.getArtwork('invalid:1'),
          throwsA(isA<MuseumException>()),
        );
      },
    );
    test(
      'cursor cannot leak into a different query and cancellation does not become partial error',
      () async {
        final aic = RecordingSource(
          (_, offset) async => page([chicago], next: 10),
        );
        final repo = MuseumRepository(sources: {MuseumSource.chicago: aic});
        final first = await repo.search(const ArtworkQuery(text: 'water'));
        await expectLater(
          repo.search(
            ArtworkQuery(text: 'different', cursor: first.nextCursor),
          ),
          throwsA(isA<MuseumException>()),
        );
        final token = CancellationToken()..cancel();
        await expectLater(
          repo.search(const ArtworkQuery(text: 'water'), cancellation: token),
          throwsA(isA<RequestCancelled>()),
        );
        expect(aic.offsets, [0]);
      },
    );
  });
}
