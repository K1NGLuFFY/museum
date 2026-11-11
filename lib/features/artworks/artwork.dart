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
    this.dimensions,
    this.country,
    this.department,
    this.classification,
    this.creditLine,
    this.thumbnailUrl,
    this.fullImageUrl,
    this.additionalImages = const [],
    this.isPublicDomain = false,
  });

  final String source, sourceId, title, museum, license;
  final Uri sourceUrl;
  final String? artist, date, medium, culture, description, dimensions;
  final String? country, department, classification, creditLine;
  final Uri? thumbnailUrl, fullImageUrl;
  final List<Uri> additionalImages;
  final bool isPublicDomain;
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
  });
  final String text;
  final int? departmentId;
  final bool highlights;
}

class ArtworkPage {
  const ArtworkPage({
    required this.artworks,
    required this.total,
    required this.nextOffset,
    this.skipped = 0,
  });
  final List<Artwork> artworks;

  /// Source match count, before image/rights filtering.
  final int total;
  final int? nextOffset;
  final int skipped;
}

abstract interface class ArtworkRepository {
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  });
  Future<Artwork> getArtwork(
    String sourceId, {
    CancellationToken? cancellation,
  });
  Future<List<MuseumDepartment>> departments();
  Future<Artwork?> dailyArtwork(DateTime date, List<Artwork> candidates);
  void dispose();
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
