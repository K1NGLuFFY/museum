import '../../core/api/network_monitor.dart';
import '../artworks/artwork.dart';
import 'library_controller.dart';

class CachedArtworkRepository implements ArtworkRepository {
  CachedArtworkRepository({
    required this.remote,
    required this.library,
    required this.network,
  });
  final ArtworkRepository remote;
  final LibraryController library;
  final NetworkMonitor network;
  @override
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  }) async {
    await library.initialize();
    cancellation?.check();
    try {
      if (network.offline) {
        throw const MuseumException('No network connection.');
      }
      final result = await remote.search(
        query,
        offset: offset,
        cancellation: cancellation,
      );
      cancellation?.check();
      try {
        await library.cachePage(
          query,
          result,
          firstPage: offset == 0 && query.cursor == null,
        );
      } catch (_) {}
      return result;
    } on RequestCancelled {
      rethrow;
    } on MuseumException {
      cancellation?.check();
      if (offset == 0 && query.cursor == null) {
        final cached = library.cachedSearch(query);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  @override
  Future<Artwork> getArtwork(
    String sourceId, {
    CancellationToken? cancellation,
  }) async {
    await library.initialize();
    cancellation?.check();
    try {
      if (network.offline) {
        throw const MuseumException('No network connection.');
      }
      final work = await remote.getArtwork(
        sourceId,
        cancellation: cancellation,
      );
      try {
        await library.cacheArtwork(work);
      } catch (_) {}
      return work;
    } on RequestCancelled {
      rethrow;
    } on MuseumException {
      final cached = library.artwork(
        sourceId.contains(':') ? sourceId : 'met:$sourceId',
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<List<MuseumDepartment>> departments() async =>
      network.offline ? [] : remote.departments();
  @override
  Future<Artwork?> dailyArtwork(DateTime date, List<Artwork> candidates) =>
      network.offline || candidates.any((work) => work.isCached)
      ? Future.value(null)
      : remote.dailyArtwork(date, candidates);
  @override
  void dispose() => remote.dispose();
}
