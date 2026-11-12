/// Museum-independent metadata. Null fields mean the source supplied no value.
class Artwork {
  const Artwork({
    required this.source,
    required this.sourceId,
    required this.title,
    required this.museum,
    required this.license,
    required this.sourceUrl,
    this.artist,
    this.date,
    this.medium,
    this.culture,
    this.description,
    this.descriptionAttribution,
    this.descriptionLicenseUrl,
    this.dimensions,
    this.country,
    this.department,
    this.classification,
    this.creditLine,
    this.thumbnailUrl,
    this.fullImageUrl,
    this.additionalImages = const [],
    this.isPublicDomain = false,
    this.isCached = false,
    this.cachedAt,
  });

  final String source, sourceId, title, museum, license;
  final Uri sourceUrl;
  final String? artist, date, medium, culture, description, dimensions;
  final String? descriptionAttribution;
  final Uri? descriptionLicenseUrl;
  final String? country, department, classification, creditLine;
  final Uri? thumbnailUrl, fullImageUrl;
  final List<Uri> additionalImages;
  final bool isPublicDomain;
  final bool isCached;
  final DateTime? cachedAt;
  String get id => '$source:$sourceId';
  bool get hasImage => isPublicDomain && fullImageUrl != null;
}

class MuseumDepartment {
  const MuseumDepartment(this.id, this.name);
  final int id;
  final String name;
}

class ArtworkQuery {
  const ArtworkQuery({
    this.text = '',
    this.departmentId,
    this.highlights = false,
    this.source,
    this.titleOnly = false,
    this.cursor,
  });
  final String text;
  final int? departmentId;
  final bool highlights;
  final MuseumSource? source;
  final bool titleOnly;
  final ArtworkCursor? cursor;

  String get fingerprint =>
      '${text.trim()}|${source?.name}|$departmentId|$highlights|$titleOnly';
}

enum MuseumSource {
  met('The Met'),
  chicago('Art Institute of Chicago'),
  cleveland('Cleveland Museum of Art');

  const MuseumSource(this.label);
  final String label;
}

/// Per-source next positions. A null position means that source is exhausted.
/// Failed sources retain their position so a retry never skips a page.
class ArtworkCursor {
  ArtworkCursor({
    required this.queryKey,
    required Map<MuseumSource, int?> offsets,
    required Map<MuseumSource, int> totals,
    Set<String> seenIds = const {},
  }) : offsets = Map.unmodifiable(offsets),
       totals = Map.unmodifiable(totals),
       seenIds = Set.unmodifiable(seenIds);
  final String queryKey;
  final Map<MuseumSource, int?> offsets;
  final Map<MuseumSource, int> totals;
  final Set<String> seenIds;
}

class SourceWarning {
  const SourceWarning(this.source, this.message);
  final MuseumSource source;
  final String message;
}

class ArtworkPage {
  const ArtworkPage({
    required this.artworks,
    required this.total,
    required this.nextOffset,
    this.skipped = 0,
    this.nextCursor,
    this.warnings = const [],
    this.limited = false,
    this.isCached = false,
    this.cachedAt,
  });
  final List<Artwork> artworks;

  /// Source match count, before image/rights filtering.
  final int total;
  final int? nextOffset;
  final int skipped;
  final ArtworkCursor? nextCursor;
  final List<SourceWarning> warnings;
  final bool limited;
  final bool isCached;
  final DateTime? cachedAt;
}

abstract interface class ArtworkSource {
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  });
  Future<Artwork> getArtwork(
    String sourceId, {
    CancellationToken? cancellation,
  });
  void dispose();
}

abstract interface class ArtworkRepository implements ArtworkSource {
  Future<List<MuseumDepartment>> departments();
  Future<Artwork?> dailyArtwork(DateTime date, List<Artwork> candidates);
}

class MuseumException implements Exception {
  const MuseumException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class RequestCancelled implements Exception {
  const RequestCancelled();
}

class CancellationToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];
  bool get isCancelled => _cancelled;
  void check() {
    if (_cancelled) throw const RequestCancelled();
  }

  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);
  void cancel() {
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }
}
