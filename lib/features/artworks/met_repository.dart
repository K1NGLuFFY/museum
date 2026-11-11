import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/museum_http_client.dart';
import 'artwork.dart';
import 'met_artwork.dart';

abstract interface class DailySelectionStore {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesDailySelectionStore implements DailySelectionStore {
  final _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read() => _preferences.getString('daily_met_selection');
  @override
  Future<void> write(String value) =>
      _preferences.setString('daily_met_selection', value);
}

class MetRepository implements ArtworkRepository {
  MetRepository({MuseumApiClient? client, DailySelectionStore? dailyStore})
    : _client = client ?? MuseumHttpClient(),
      _dailyStore = dailyStore ?? PreferencesDailySelectionStore();
  final MuseumApiClient _client;
  final DailySelectionStore _dailyStore;
  final Map<String, Artwork> _cache = {};
  List<MuseumDepartment>? _departments;
  static const pageSize = 12;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.https(
    'collectionapi.metmuseum.org',
    '/public/collection/$path',
    query,
  );

  @override
  Future<Artwork> getArtwork(
    String sourceId, {
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    if (_cache[sourceId] case final artwork?) return artwork;
    if (int.tryParse(sourceId) == null) {
      throw const MuseumException('This museum record is unavailable.');
    }
    final json = await _client.get(
      _uri('v1/objects/$sourceId'),
      cancellation: cancellation,
    );
    final Artwork artwork;
    try {
      artwork = MetArtworkDto(json).normalize();
    } on FormatException {
      throw const MuseumException('The museum returned an incomplete record.');
    }
    if (artwork.sourceId != sourceId) {
      throw const MuseumException('The museum returned a different record.');
    }
    if (_cache.length >= 120) _cache.remove(_cache.keys.first);
    _cache[sourceId] = artwork;
    return artwork;
  }

  @override
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  }) async {
    if (offset < 0 || offset >= 10000) {
      throw const MuseumException(
        'Refine your search to see more specific results.',
      );
    }
    final limit = math.min(pageSize, 10000 - offset);
    final json = await _client.get(
      _uri('v1.1/search', {
        if (query.text.trim().isNotEmpty) 'q': query.text.trim(),
        'hasImages': 'true',
        'offset': '$offset',
        'limit': '$limit',
        if (query.highlights) 'isHighlight': 'true',
        if (query.departmentId != null) 'departmentId': '${query.departmentId}',
      }),
      cancellation: cancellation,
    );
    if (json['total'] is! int ||
        (json['objectIDs'] != null && json['objectIDs'] is! List)) {
      throw const MuseumException(
        'The museum returned an unreadable search result.',
      );
    }
    final rawIds = (json['objectIDs'] as List?) ?? const [];
    final ids = rawIds
        .whereType<int>()
        .where((id) => id > 0)
        .take(limit)
        .toSet()
        .toList();
    final artworks = <Artwork>[];
    var skipped = rawIds.length - ids.length;
    // At most three detail requests at once; cancellation prevents later batches.
    for (var i = 0; i < ids.length; i += 3) {
      cancellation?.check();
      final batch = await Future.wait(
        ids.skip(i).take(3).map((id) async {
          try {
            return await getArtwork('$id', cancellation: cancellation);
          } on MuseumException catch (error) {
            if (error.statusCode == 404) return null;
            rethrow;
          }
        }),
      );
      for (final artwork in batch) {
        if (artwork != null &&
            artwork.hasImage &&
            artwork.thumbnailUrl != null) {
          artworks.add(artwork);
        } else {
          skipped++;
        }
      }
    }
    cancellation?.check();
    final total = math.max(0, json['total'] as int);
    final next = offset + rawIds.length;
    return ArtworkPage(
      artworks: List.unmodifiable(artworks),
      total: total,
      nextOffset: rawIds.isNotEmpty && next < math.min(total, 10000)
          ? next
          : null,
      skipped: skipped,
    );
  }

  @override
  Future<List<MuseumDepartment>> departments() async {
    if (_departments != null) return _departments!;
    final json = await _client.get(_uri('v1/departments'));
    if (json['departments'] is! List) {
      throw const MuseumException('Museum departments are unavailable.');
    }
    _departments = List.unmodifiable(
      (json['departments'] as List)
          .whereType<Map<String, dynamic>>()
          .where(
            (item) =>
                item['departmentId'] is int && item['displayName'] is String,
          )
          .map(
            (item) => MuseumDepartment(
              item['departmentId'] as int,
              item['displayName'] as String,
            ),
          ),
    );
    return _departments!;
  }

  @override
  Future<Artwork?> dailyArtwork(DateTime date, List<Artwork> candidates) async {
    final day = '${date.year}-${date.month}-${date.day}';
    final saved = await _dailyStore.read();
    if (saved != null && saved.startsWith('$day|')) {
      final artwork = await getArtwork(saved.split('|').last);
      return artwork.hasImage ? artwork : null;
    }
    final eligible = candidates.where((artwork) => artwork.hasImage).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (eligible.isEmpty) return null;
    final index =
        DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final artwork = eligible[index % eligible.length];
    await _dailyStore.write('$day|${artwork.sourceId}');
    return artwork;
  }

  @override
  void dispose() => _client.close();
}
