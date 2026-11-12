import 'package:museum/features/artworks/artwork.dart';
import 'package:museum/app/museum_app.dart';
import 'package:museum/core/api/network_monitor.dart';
import 'package:museum/core/storage/library_store.dart';
import 'package:museum/core/storage/thumbnail_cache.dart';
import 'package:museum/features/library/library_controller.dart';

MuseumApp testMuseumApp(ArtworkRepository repository) => MuseumApp(
  repository: repository,
  library: LibraryController(
    store: MemoryLibraryStore(),
    legacyAppearance: () async => null,
  ),
  network: FixedNetworkMonitor(),
  thumbnails: EmptyThumbnailCache(),
);

class FakeArtworkRepository implements ArtworkRepository {
  final List<ArtworkQuery> queries = [];
  MuseumException? error;
  ArtworkPage page = const ArtworkPage(
    artworks: [],
    total: 0,
    nextOffset: null,
  );

  @override
  Future<ArtworkPage> search(
    ArtworkQuery query, {
    int offset = 0,
    CancellationToken? cancellation,
  }) async {
    queries.add(query);
    if (error != null) throw error!;
    return page;
  }

  @override
  Future<Artwork> getArtwork(
    String sourceId, {
    CancellationToken? cancellation,
  }) async => page.artworks.firstWhere((work) => work.sourceId == sourceId);
  @override
  Future<List<MuseumDepartment>> departments() async => [];
  @override
  Future<Artwork?> dailyArtwork(
    DateTime date,
    List<Artwork> candidates,
  ) async => candidates.firstOrNull;
  @override
  void dispose() {}
}
