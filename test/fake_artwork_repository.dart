import 'package:museum/features/artworks/artwork.dart';

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
