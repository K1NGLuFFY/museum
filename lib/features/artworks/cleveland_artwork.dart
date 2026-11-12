import 'artwork.dart';
import 'museum_metadata.dart';

class ClevelandArtworkDto {
  ClevelandArtworkDto(this.json) {
    if (json['id'] is! int || (json['id'] as int) <= 0) {
      throw const FormatException('Missing Cleveland artwork ID');
    }
  }
  final Map<String, dynamic> json;

  Uri? _image(Object? images, String size) {
    if (images is! Map || images[size] is! Map) return null;
    final uri = metadataHttpsUrl(images[size]['url']);
    // The full asset is often TIFF. Use only Flutter-supported JPEG/PNG/WebP.
    return uri != null &&
            RegExp(
              r'\.(jpe?g|png|webp)$',
              caseSensitive: false,
            ).hasMatch(uri.path)
        ? uri
        : null;
  }

  Artwork normalize() {
    final id = json['id'].toString();
    final cc0 = json['share_license_status'] == 'CC0';
    final source = metadataHttpsUrl(json['url']);
    final validSource =
        source != null &&
        (source.host == 'clevelandart.org' ||
            source.host.endsWith('.clevelandart.org'));
    final creators = json['creators'] is List
        ? (json['creators'] as List)
              .whereType<Map>()
              .map((creator) => metadataText(creator['description']))
              .whereType<String>()
              .toSet()
              .join('; ')
        : '';
    final images = json['images'];
    return Artwork(
      source: 'cleveland',
      sourceId: id,
      title: metadataText(json['title']) ?? 'Untitled work',
      museum: 'Cleveland Museum of Art',
      sourceUrl: validSource
          ? source
          : Uri.https('openaccess-api.clevelandart.org', '/api/artworks/$id'),
      artist: metadataText(creators),
      date: metadataText(json['creation_date']),
      culture: metadataList(json['culture']),
      medium: metadataText(json['technique']),
      dimensions: metadataText(json['measurements']),
      department: metadataText(json['department']),
      classification: metadataText(json['type']),
      creditLine: metadataText(json['creditline']),
      description: metadataPlainText(json['description']),
      isPublicDomain: cc0,
      license: cc0
          ? 'CC0 · Cleveland Museum of Art Open Access images and metadata'
          : 'Image rights: ${metadataText(json['share_license_status']) ?? 'not confirmed by the museum'}',
      thumbnailUrl: cc0 ? _image(images, 'web') : null,
      fullImageUrl: cc0
          ? _image(images, 'print') ?? _image(images, 'web')
          : null,
      additionalImages: cc0 && json['alternate_images'] is List
          ? List.unmodifiable(
              (json['alternate_images'] as List)
                  .map(
                    (images) =>
                        _image(images, 'print') ?? _image(images, 'web'),
                  )
                  .whereType<Uri>()
                  .toSet(),
            )
          : const [],
    );
  }
}
