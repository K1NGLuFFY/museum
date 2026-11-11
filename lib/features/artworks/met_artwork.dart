import 'artwork.dart';

/// Met-specific response adapter; never exposes images without an explicit
/// public-domain flag. Empty and malformed metadata remain absent.
class MetArtworkDto {
  MetArtworkDto(this.json) {
    if (json['objectID'] is! int || (json['objectID'] as int) <= 0) {
      throw const FormatException('Missing Met object ID');
    }
  }
  final Map<String, dynamic> json;
  String? _text(String key) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static Uri? httpsUrl(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  Artwork normalize() {
    final publicDomain = json['isPublicDomain'] == true;
    final full = publicDomain ? httpsUrl(json['primaryImage']) : null;
    final thumbnail = publicDomain ? httpsUrl(json['primaryImageSmall']) : null;
    final source = httpsUrl(json['objectURL']);
    final validSource =
        source != null &&
        (source.host == 'metmuseum.org' ||
            source.host.endsWith('.metmuseum.org'));
    final id = json['objectID'].toString();
    return Artwork(
      source: 'met',
      sourceId: id,
      title: _text('title') ?? 'Untitled work',
      museum: 'The Metropolitan Museum of Art',
      sourceUrl: validSource
          ? source
          : Uri.https('www.metmuseum.org', '/art/collection/search/$id'),
      artist: _text('artistDisplayName'),
      date: _text('objectDate'),
      medium: _text('medium'),
      culture: _text('culture'),
      dimensions: _text('dimensions'),
      country: _text('country') ?? _text('region'),
      department: _text('department'),
      classification: _text('classification'),
      creditLine: _text('creditLine'),
      isPublicDomain: publicDomain,
      fullImageUrl: full,
      thumbnailUrl: thumbnail,
      additionalImages: publicDomain && json['additionalImages'] is List
          ? List<Uri>.unmodifiable(
              (json['additionalImages'] as List)
                  .map(httpsUrl)
                  .whereType<Uri>()
                  .toSet(),
            )
          : const [],
      license: publicDomain
          ? 'Public domain · The Met Open Access (CC0)'
          : _text('rightsAndReproduction') ??
                'Image rights not confirmed by the museum',
    );
  }
}
