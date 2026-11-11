import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:museum/core/api/museum_http_client.dart';
import 'package:museum/features/artworks/artwork.dart';
import 'package:museum/features/artworks/met_artwork.dart';
import 'package:museum/features/artworks/met_repository.dart';

// Fields from the official Met API documentation's Quail and Millet example.
Map<String, dynamic> metRecord({int id = 45734}) => {
  'objectID': id,
  'title': 'Quail and Millet',
  'isPublicDomain': true,
  'artistDisplayName': 'Kiyohara Yukinobu',
  'objectDate': 'late 17th century',
  'culture': 'Japan',
  'medium': 'Hanging scroll; ink and color on silk',
  'department': 'Asian Art',
  'primaryImage':
      'https://images.metmuseum.org/CRDImages/as/original/DP251139.jpg',
  'primaryImageSmall':
      'https://images.metmuseum.org/CRDImages/as/web-large/DP251139.jpg',
  'objectURL': 'https://www.metmuseum.org/art/collection/search/$id',
  'additionalImages': [
    'https://images.metmuseum.org/CRDImages/as/original/DP251138.jpg',
  ],
};

class MemoryDailyStore implements DailySelectionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

void main() {
  test('normalizes museum metadata and stable source ID without invention', () {
    final work = MetArtworkDto(metRecord()).normalize();
    expect(work.id, 'met:45734');
    expect(work.artist, 'Kiyohara Yukinobu');
    expect(work.culture, 'Japan');
    expect(work.hasImage, isTrue);
    expect(work.additionalImages, hasLength(1));
    expect(work.description, isNull);
    expect(work.license, contains('CC0'));
  });

  test('missing metadata remains absent and malformed object IDs fail', () {
    final work = MetArtworkDto({
      'objectID': 1,
      'title': '  ',
      'medium': 7,
    }).normalize();
    expect(work.title, 'Untitled work');
    expect(work.artist, isNull);
    expect(work.medium, isNull);
    expect(work.fullImageUrl, isNull);
    expect(() => MetArtworkDto({'objectID': '1'}), throwsFormatException);
  });

  test('non-public-domain and invalid URLs never expose images', () {
    for (final flag in [false, null, 'true']) {
      final work = MetArtworkDto({
        ...metRecord(),
        'isPublicDomain': flag,
      }).normalize();
      expect(work.hasImage, isFalse);
      expect(work.thumbnailUrl, isNull);
      expect(work.additionalImages, isEmpty);
    }
    for (final url in [
      '',
      'http://example.com/a.jpg',
      'file:///a',
      'https://',
      'https://user:pass@example.com/a',
    ]) {
      final work = MetArtworkDto({
        ...metRecord(),
        'primaryImage': url,
      }).normalize();
      expect(work.hasImage, isFalse, reason: url);
    }
  });

  test(
    'search uses current endpoint, encodes query, filters images and deduplicates',
    () async {
      final requests = <Uri>[];
      final client = MuseumHttpClient(
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path.endsWith('/search')) {
            expect(request.url.path, '/public/collection/v1.1/search');
            expect(request.url.queryParameters['q'], 'ink & silk');
            expect(request.url.queryParameters['offset'], '12');
            expect(request.url.queryParameters['limit'], '12');
            expect(request.url.queryParameters['departmentId'], '6');
            return http.Response(
              jsonEncode({
                'total': 50,
                'objectIDs': [1, 1, 2, 3, 4],
              }),
              200,
            );
          }
          final id = int.parse(request.url.pathSegments.last);
          if (id == 4) return http.Response('{}', 404);
          return http.Response(
            jsonEncode({
              ...metRecord(id: id),
              if (id == 2) 'isPublicDomain': false,
              if (id == 3) 'primaryImageSmall': '',
            }),
            200,
          );
        }),
      );
      final repository = MetRepository(
        client: client,
        dailyStore: MemoryDailyStore(),
      );
      final page = await repository.search(
        const ArtworkQuery(text: 'ink & silk', departmentId: 6),
        offset: 12,
      );
      expect(page.artworks.map((work) => work.sourceId), ['1']);
      expect(page.nextOffset, 17);
      expect(page.skipped, 4);
      await repository.getArtwork('1');
      expect(requests.where((uri) => uri.path.endsWith('/1')), hasLength(1));
      repository.dispose();
    },
  );

  test(
    'empty and final pages do not repeat; 10,000 result cap is enforced',
    () async {
      var calls = 0;
      final repository = MetRepository(
        client: MuseumHttpClient(
          client: MockClient((request) async {
            calls++;
            expect(request.url.queryParameters['limit'], '4');
            return http.Response('{"total":20000,"objectIDs":null}', 200);
          }),
        ),
        dailyStore: MemoryDailyStore(),
      );
      final page = await repository.search(const ArtworkQuery(), offset: 9996);
      expect(page.artworks, isEmpty);
      expect(page.nextOffset, isNull);
      await expectLater(
        repository.search(const ArtworkQuery(), offset: 10000),
        throwsA(isA<MuseumException>()),
      );
      expect(calls, 1);
    },
  );

  test('departments use official metadata and cache the response', () async {
    var calls = 0;
    final repository = MetRepository(
      client: MuseumHttpClient(
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/public/collection/v1/departments');
          return http.Response(
            '{"departments":[{"departmentId":6,"displayName":"Asian Art"}]}',
            200,
          );
        }),
      ),
      dailyStore: MemoryDailyStore(),
    );
    expect((await repository.departments()).single.name, 'Asian Art');
    await repository.departments();
    expect(calls, 1);
  });

  test(
    'daily selection survives a new repository and changed candidate ordering',
    () async {
      final store = MemoryDailyStore();
      MuseumHttpClient client() => MuseumHttpClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(metRecord(id: int.parse(request.url.pathSegments.last))),
            200,
          ),
        ),
      );
      final candidates = [
        MetArtworkDto(metRecord(id: 45734)).normalize(),
        MetArtworkDto(metRecord(id: 45735)).normalize(),
      ];
      final first = MetRepository(client: client(), dailyStore: store);
      final picked = await first.dailyArtwork(
        DateTime(2026, 11, 11),
        candidates,
      );
      final second = MetRepository(client: client(), dailyStore: store);
      final restored = await second.dailyArtwork(
        DateTime(2026, 11, 11),
        candidates.reversed.toList(),
      );
      expect(restored!.id, picked!.id);
      expect(store.value, startsWith('2026-11-11|'));
    },
  );

  test(
    'transient failure retries only twice and permanent failure is not retried',
    () async {
      for (final status in [429, 500, 404]) {
        var calls = 0;
        final client = MuseumHttpClient(
          retryDelay: Duration.zero,
          client: MockClient((_) async {
            calls++;
            return http.Response('{}', status);
          }),
        );
        await expectLater(
          client.get(Uri.https('example.com')),
          throwsA(isA<MuseumException>()),
        );
        expect(calls, status == 404 ? 1 : 3);
        client.close();
      }
    },
  );

  test('malformed JSON is a readable permanent failure', () async {
    var calls = 0;
    final client = MuseumHttpClient(
      client: MockClient((_) async {
        calls++;
        return http.Response('<html>', 200);
      }),
    );
    await expectLater(
      client.get(Uri.https('example.com')),
      throwsA(isA<MuseumException>()),
    );
    expect(calls, 1);
  });

  test('timeout is bounded and cancellation prevents requests', () async {
    var calls = 0;
    final client = MuseumHttpClient(
      timeout: const Duration(milliseconds: 1),
      retryDelay: Duration.zero,
      client: MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      client.get(Uri.https('example.com')),
      throwsA(isA<MuseumException>()),
    );
    expect(calls, 3);
    final cancelled = CancellationToken()..cancel();
    await expectLater(
      client.get(Uri.https('example.com'), cancellation: cancelled),
      throwsA(isA<RequestCancelled>()),
    );
    expect(calls, 3);
  });
}
