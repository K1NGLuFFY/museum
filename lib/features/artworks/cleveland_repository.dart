import 'dart:math' as math;

import '../../core/api/museum_http_client.dart';
import 'artwork.dart';
import 'cleveland_artwork.dart';

class ClevelandRepository implements ArtworkSource {
  ClevelandRepository({MuseumApiClient? client})
    : _client = client ?? MuseumHttpClient();
  final MuseumApiClient _client;
  final Map<String, Artwork> _cache = {};
  static const pageSize = 12;
  static const fields =
      'id,title,creation_date,creators,culture,technique,department,type,measurements,creditline,description,url,images,alternate_images,share_license_status,accession_number';

  Artwork _normalize(Map<String, dynamic> json) {
    final work = ClevelandArtworkDto(json).normalize();
    if (_cache.length >= 120) _cache.remove(_cache.keys.first);
    _cache[work.sourceId] = work;
    return work;
  }

  @override
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  }) async {
    if (offset < 0) {
      throw const MuseumException('Invalid Cleveland search page.');
    }
    final json = await _client.get(
      Uri.https('openaccess-api.clevelandart.org', '/api/artworks/', {
        if (query.text.trim().isNotEmpty)
          query.titleOnly ? 'title' : 'q': query.text.trim(),
        'cc0': '',
        'has_image': '1',
        'skip': '$offset',
        'limit': '$pageSize',
        'fields': fields,
      }),
      cancellation: cancellation,
    );
    final info = json['info'];
    if (info is! Map || info['total'] is! int || json['data'] is! List) {
      throw const MuseumException(
        'Cleveland returned an unreadable search result.',
      );
    }
    final raw = json['data'] as List;
    final works = <Artwork>[];
    final seen = <String>{};
    for (final item in raw.take(pageSize)) {
      cancellation?.check();
      if (item is! Map<String, dynamic>) continue;
      try {
        final work = _normalize(item);
        if (work.hasImage && work.thumbnailUrl != null && seen.add(work.id)) {
          works.add(work);
        }
      } on FormatException {
        /* Skip invalid records without shifting pagination. */
      }
    }
    final total = math.max(0, info['total'] as int);
    final next = offset + raw.length;
    return ArtworkPage(
      artworks: List.unmodifiable(works),
      total: total,
      nextOffset: raw.isNotEmpty && next < total ? next : null,
      skipped: raw.length - works.length,
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
      throw const MuseumException('Invalid Cleveland artwork ID.');
    }
    final json = await _client.get(
      Uri.https('openaccess-api.clevelandart.org', '/api/artworks/$sourceId', {
        'fields': fields,
      }),
      cancellation: cancellation,
    );
    if (json['data'] is! Map<String, dynamic>) {
      throw const MuseumException('Cleveland returned an incomplete record.');
    }
    try {
      final work = _normalize(json['data'] as Map<String, dynamic>);
      if (work.sourceId != sourceId) throw const FormatException();
      return work;
    } on FormatException {
      throw const MuseumException('Cleveland returned an incomplete record.');
    }
  }

  @override
  void dispose() => _client.close();
}
