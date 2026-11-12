import 'artwork.dart';
import 'chicago_repository.dart';
import 'cleveland_repository.dart';
import 'met_repository.dart';

class MuseumRepository implements ArtworkRepository {
  MuseumRepository({Map<MuseumSource, ArtworkSource>? sources})
    : _sources =
          sources ??
          {
            MuseumSource.met: MetRepository(),
            MuseumSource.chicago: ChicagoRepository(),
            MuseumSource.cleveland: ClevelandRepository(),
          };
  final Map<MuseumSource, ArtworkSource> _sources;

  @override
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    final selected = query.departmentId != null || query.highlights
        ? [MuseumSource.met]
        : query.source != null
        ? [query.source!]
        : _sources.keys.toList();
    final cursor = query.cursor;
    if (cursor != null && cursor.queryKey != query.fingerprint) {
      throw const MuseumException(
        'Search filters changed. Please refresh the results.',
      );
    }
    if (offset != 0 && cursor == null) {
      throw const MuseumException(
        'Please refresh the search before loading more results.',
      );
    }
    final offsets = <MuseumSource, int?>{
      for (final source in selected)
        source: cursor == null ? 0 : cursor.offsets[source],
    };
    final totals = <MuseumSource, int>{...?cursor?.totals};
    final seen = <String>{...?cursor?.seenIds};
    final warnings = <SourceWarning>[];
    final results = <MuseumSource, ArtworkPage>{};
    // One page per source. Chicago and Cleveland include their detail metadata;
    // only The Met needs additional requests (bounded to three at a time).
    await Future.wait(
      selected.where((source) => offsets[source] != null).map((source) async {
        final provider = _sources[source];
        try {
          if (provider == null) {
            throw const MuseumException('This museum is unavailable.');
          }
          results[source] = await provider.search(
            query,
            offset: offsets[source]!,
            cancellation: cancellation,
          );
        } on RequestCancelled {
          rethrow;
        } on MuseumException catch (error) {
          warnings.add(SourceWarning(source, error.message));
        } catch (_) {
          warnings.add(
            SourceWarning(source, 'This museum is temporarily unavailable.'),
          );
        }
      }),
    );
    cancellation?.check();
    if (results.isEmpty && warnings.isNotEmpty) {
      throw MuseumException(
        warnings
            .map((warning) => '${warning.source.label}: ${warning.message}')
            .join('\n'),
      );
    }
    var skipped = 0;
    var limited = false;
    for (final entry in results.entries) {
      offsets[entry.key] = entry.value.nextOffset;
      totals[entry.key] = entry.value.total;
      skipped += entry.value.skipped;
      limited = limited || entry.value.limited;
    }
    final artworks = <Artwork>[];
    // Interleave results so every available museum is represented near the top.
    var index = 0;
    while (results.values.any((page) => page.artworks.length > index)) {
      for (final source in selected) {
        final works = results[source]?.artworks;
        if (works != null &&
            index < works.length &&
            seen.add(works[index].id)) {
          artworks.add(works[index]);
        }
      }
      index++;
    }
    final more = offsets.values.any((position) => position != null);
    warnings.sort(
      (a, b) =>
          selected.indexOf(a.source).compareTo(selected.indexOf(b.source)),
    );
    return ArtworkPage(
      artworks: List.unmodifiable(artworks),
      total: totals.values.fold(0, (total, count) => total + count),
      nextOffset: more ? offset + 1 : null,
      skipped: skipped,
      limited: limited,
      warnings: List.unmodifiable(warnings),
      nextCursor: more
          ? ArtworkCursor(
              queryKey: query.fingerprint,
              offsets: offsets,
              totals: totals,
              seenIds: seen,
            )
          : null,
    );
  }

  @override
  Future<Artwork> getArtwork(
    String sourceId, {
    CancellationToken? cancellation,
  }) {
    // Accept legacy Met IDs, but persisted cross-museum IDs must be source:id.
    final parts = sourceId.split(':');
    final source = parts.length == 1
        ? MuseumSource.met
        : MuseumSource.values
              .where((source) => source.name == parts.first)
              .firstOrNull;
    if (source == null || parts.length > 2 || !_sources.containsKey(source)) {
      throw const MuseumException('This museum record is unavailable.');
    }
    return _sources[source]!.getArtwork(parts.last, cancellation: cancellation);
  }

  @override
  Future<List<MuseumDepartment>> departments() =>
      _sources[MuseumSource.met] is ArtworkRepository
      ? (_sources[MuseumSource.met] as ArtworkRepository).departments()
      : Future.value([]);

  @override
  Future<Artwork?> dailyArtwork(DateTime date, List<Artwork> candidates) =>
      _sources[MuseumSource.met] is ArtworkRepository
      ? (_sources[MuseumSource.met] as ArtworkRepository).dailyArtwork(
          date,
          candidates.where((work) => work.source == 'met').toList(),
        )
      : Future.value(null);

  @override
  void dispose() {
    for (final source in _sources.values.toSet()) {
      source.dispose();
    }
  }
}
