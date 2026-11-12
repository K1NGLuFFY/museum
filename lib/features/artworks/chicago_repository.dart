import 'dart:convert';
import 'dart:math' as math;

import '../../core/api/museum_http_client.dart';
import 'artwork.dart';
import 'chicago_artwork.dart';

class ChicagoRepository implements ArtworkSource {
  ChicagoRepository({MuseumApiClient? client})
    : _client =
          client ??
          MuseumHttpClient(
            minimumInterval: const Duration(seconds: 1),
            headers: const {
              'AIC-User-Agent': 'MUSEUM (personal collection browser)',
            },
          );
  final MuseumApiClient _client;
  final Map<String, Artwork> _cache = {};
  static const pageSize = 10;
  static const fields = [
    'id',
    'title',
    'artist_display',
    'date_display',
    'medium_display',
    'dimensions',
    'place_of_origin',
    'department_title',
    'artwork_type_title',
    'credit_line',
    'image_id',
    'alt_image_ids',
    'is_public_domain',
    'description',
  ];

  Artwork _normalize(Map<String, dynamic> json, Map<String, dynamic> config) {
    final artwork = ChicagoArtworkDto(json, config).normalize();
    if (_cache.length >= 120) _cache.remove(_cache.keys.first);
    _cache[artwork.sourceId] = artwork;
    return artwork;
  }

  @override
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  }) async {
    if (offset < 0 || offset >= 1000 || offset % pageSize != 0) {
      throw const MuseumException(
        'Refine the Chicago search to see more specific results.',
      );
    }
    final text = query.text.trim();
    final params = {
      'limit': pageSize,
      'page': offset ~/ pageSize + 1,
      'fields': fields,
      'query': {
        'bool': {
          'filter': [
            {
              'term': {'is_public_domain': true},
            },
            {
              'exists': {'field': 'image_id'},
            },
          ],
          if (text.isNotEmpty)
            'must': [
              query.titleOnly
                  ? {
                      'match': {'title': text},
                    }
                  : {
                      'multi_match': {
                        'query': text,
                        'fields': [
                          'title',
                          'artist_title',
                          'artist_display',
                          'place_of_origin',
                          'medium_display',
                          'style_titles',
                          'subject_titles',
                          'description',
                        ],
                      },
                    },
            ],
        },
      },
    };
    final json = await _client.get(
      Uri.https('api.artic.edu', '/api/v1/artworks/search', {
        'params': jsonEncode(params),
      }),
      cancellation: cancellation,
    );
    final pagination = json['pagination'];
    if (pagination is! Map ||
        pagination['total'] is! int ||
        json['data'] is! List ||
        json['config'] is! Map<String, dynamic>) {
      throw const MuseumException(
        'Chicago returned an unreadable search result.',
      );
    }
    final raw = json['data'] as List;
    final works = <Artwork>[];
    final seen = <String>{};
    for (final item in raw.take(pageSize)) {
      cancellation?.check();
      if (item is! Map<String, dynamic>) continue;
      try {
        final work = _normalize(item, json['config'] as Map<String, dynamic>);
        if (work.hasImage && work.thumbnailUrl != null && seen.add(work.id)) {
          works.add(work);
        }
      } on FormatException {
        /* Skip a malformed record, preserving page position. */
      }
    }
    final total = math.max(0, pagination['total'] as int);
    final next = offset + pageSize;
    return ArtworkPage(
      artworks: List.unmodifiable(works),
      total: total,
      nextOffset: raw.isNotEmpty && next < math.min(total, 1000) ? next : null,
      skipped: raw.length - works.length,
      limited: total > 1000,
    );
  }

  @override
  Future<Artwork> getArtwork(
    String sourceId, {
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    if (_cache[sourceId] case final artwork?) return artwork;
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(sourceId)) {
      throw const MuseumException('Invalid Chicago artwork ID.');
    }
    final json = await _client.get(
      Uri.https('api.artic.edu', '/api/v1/artworks/$sourceId', {
        'fields': fields.join(','),
      }),
      cancellation: cancellation,
    );
    if (json['data'] is! Map<String, dynamic> ||
        json['config'] is! Map<String, dynamic>) {
      throw const MuseumException('Chicago returned an incomplete record.');
    }
    try {
      final work = _normalize(
        json['data'] as Map<String, dynamic>,
        json['config'] as Map<String, dynamic>,
      );
      if (work.sourceId != sourceId) throw const FormatException();
      return work;
    } on FormatException {
      throw const MuseumException('Chicago returned an incomplete record.');
    }
  }

  @override
  void dispose() => _client.close();
}
