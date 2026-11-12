import '../artworks/artwork.dart';
import '../artworks/museum_metadata.dart';

abstract final class ArtworkCodec {
  static Map<String, dynamic> encode(Artwork work) => {
    'source': work.source,
    'sourceId': work.sourceId,
    'title': work.title,
    'museum': work.museum,
    'license': work.license,
    'sourceUrl': work.sourceUrl.toString(),
    'artist': work.artist,
    'date': work.date,
    'medium': work.medium,
    'culture': work.culture,
    'description': work.description,
    'descriptionAttribution': work.descriptionAttribution,
    'descriptionLicenseUrl': work.descriptionLicenseUrl?.toString(),
    'dimensions': work.dimensions,
    'country': work.country,
    'department': work.department,
    'classification': work.classification,
    'creditLine': work.creditLine,
    'thumbnailUrl': work.thumbnailUrl?.toString(),
    'fullImageUrl': work.fullImageUrl?.toString(),
    'additionalImages': work.additionalImages
        .map((uri) => uri.toString())
        .toList(),
    'isPublicDomain': work.isPublicDomain,
  };

  static Artwork decode(Map<String, dynamic> json, {DateTime? cachedAt}) {
    final source = metadataText(json['source']);
    final id = metadataText(json['sourceId']);
    final sourceUrl = metadataHttpsUrl(json['sourceUrl']);
    if (!MuseumSource.values.any((value) => value.name == source) ||
        id == null ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(id) ||
        sourceUrl == null) {
      throw const FormatException('Invalid stored artwork');
    }
    final publicDomain = json['isPublicDomain'] == true;
    return Artwork(
      source: source!,
      sourceId: id,
      sourceUrl: sourceUrl,
      title: metadataText(json['title']) ?? 'Untitled work',
      museum:
          metadataText(json['museum']) ??
          MuseumSource.values.firstWhere((value) => value.name == source).label,
      license: metadataText(json['license']) ?? 'Rights not recorded',
      artist: metadataText(json['artist']),
      date: metadataText(json['date']),
      medium: metadataText(json['medium']),
      culture: metadataText(json['culture']),
      description: metadataText(json['description']),
      descriptionAttribution: metadataText(json['descriptionAttribution']),
      descriptionLicenseUrl: metadataHttpsUrl(json['descriptionLicenseUrl']),
      dimensions: metadataText(json['dimensions']),
      country: metadataText(json['country']),
      department: metadataText(json['department']),
      classification: metadataText(json['classification']),
      creditLine: metadataText(json['creditLine']),
      isPublicDomain: publicDomain,
      thumbnailUrl: publicDomain
          ? metadataHttpsUrl(json['thumbnailUrl'])
          : null,
      fullImageUrl: publicDomain
          ? metadataHttpsUrl(json['fullImageUrl'])
          : null,
      additionalImages: publicDomain && json['additionalImages'] is List
          ? List.unmodifiable(
              (json['additionalImages'] as List)
                  .map(metadataHttpsUrl)
                  .whereType<Uri>(),
            )
          : const [],
      isCached: true,
      cachedAt: cachedAt,
    );
  }
}
