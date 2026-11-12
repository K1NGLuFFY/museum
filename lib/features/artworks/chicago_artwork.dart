import 'artwork.dart';
import 'museum_metadata.dart';

class ChicagoArtworkDto {
  ChicagoArtworkDto(this.json, this.config) {
    if (json['id'] is! int || (json['id'] as int) <= 0) {
      throw const FormatException('Missing Chicago artwork ID');
    }
  }
  final Map<String, dynamic> json, config;

  Uri? _image(Object? identifier, int width) {
    final base = metadataHttpsUrl(config['iiif_url']);
    final id = metadataText(identifier);
    if (base == null ||
        id == null ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      return null;
    }
    return base.replace(
      path:
          '${base.path.replaceFirst(RegExp(r'/+$'), '')}/$id/full/$width,/0/default.jpg',
      query: null,
      fragment: null,
    );
  }

  Artwork normalize() {
    final id = json['id'].toString();
    final publicDomain = json['is_public_domain'] == true;
    final description = metadataPlainText(json['description']);
    return Artwork(
      source: 'chicago',
      sourceId: id,
      title: metadataText(json['title']) ?? 'Untitled work',
      museum: 'Art Institute of Chicago',
      sourceUrl: Uri.https('www.artic.edu', '/artworks/$id'),
      artist: metadataText(json['artist_display']),
      date: metadataText(json['date_display']),
      medium: metadataText(json['medium_display']),
      dimensions: metadataText(json['dimensions']),
      country: metadataText(json['place_of_origin']),
      department: metadataText(json['department_title']),
      classification: metadataText(json['artwork_type_title']),
      creditLine: metadataText(json['credit_line']),
      description: description,
      descriptionAttribution: description == null
          ? null
          : 'Description: Art Institute of Chicago · CC BY 4.0. Formatting converted to plain text.',
      descriptionLicenseUrl: description == null
          ? null
          : Uri.https('creativecommons.org', '/licenses/by/4.0/'),
      isPublicDomain: publicDomain,
      license: publicDomain
          ? 'Public-domain image · CC0 collection metadata (description licensed separately)'
          : 'Image rights not confirmed by the museum',
      thumbnailUrl: publicDomain ? _image(json['image_id'], 843) : null,
      fullImageUrl: publicDomain ? _image(json['image_id'], 1686) : null,
      additionalImages: publicDomain && json['alt_image_ids'] is List
          ? List.unmodifiable(
              (json['alt_image_ids'] as List)
                  .map((id) => _image(id, 1686))
                  .whereType<Uri>()
                  .toSet(),
            )
          : const [],
    );
  }
}
