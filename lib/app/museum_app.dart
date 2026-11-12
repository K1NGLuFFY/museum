import 'package:flutter/cupertino.dart';

import '../core/theme/museum_theme.dart';
import '../core/api/network_monitor.dart';
import '../core/storage/library_store.dart';
import '../core/storage/thumbnail_cache.dart';
import '../features/artworks/artwork.dart';
import '../features/artworks/museum_repository.dart';
import '../features/library/library_controller.dart';
import '../features/library/library_scope.dart';
import '../features/library/cached_artwork_repository.dart';
import '../features/settings/settings_controller.dart';
import 'museum_shell.dart';

class MuseumApp extends StatefulWidget {
  const MuseumApp({
    super.key,
    this.repository,
    this.library,
    this.network,
    this.thumbnails,
  });
  final ArtworkRepository? repository;
  final LibraryController? library;
  final NetworkMonitor? network;
  final ThumbnailCache? thumbnails;

  @override
  State<MuseumApp> createState() => _MuseumAppState();
}

class _MuseumAppState extends State<MuseumApp> {
  late final _library =
      widget.library ?? LibraryController(store: FileLibraryStore());
  late final _network = widget.network ?? PlatformNetworkMonitor();
  late final _thumbnails = widget.thumbnails ?? ManagedThumbnailCache();
  late final _settings = SettingsController(library: _library);
  late final ArtworkRepository _repository =
      widget.repository ??
      CachedArtworkRepository(
        remote: MuseumRepository(),
        library: _library,
        network: _network,
      );

  @override
  void initState() {
    super.initState();
    _library.initialize();
    _network.start();
  }

  @override
  void dispose() {
    _settings.dispose();
    if (widget.repository == null) _repository.dispose();
    if (widget.library == null) _library.dispose();
    if (widget.network == null) _network.dispose();
    if (widget.thumbnails == null) _thumbnails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LibraryScope(
    library: _library,
    network: _network,
    thumbnails: _thumbnails,
    child: ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => CupertinoApp(
        title: 'MUSEUM',
        debugShowCheckedModeBanner: false,
        theme: museumTheme(_settings.brightness),
        home: MuseumShell(settings: _settings, repository: _repository),
      ),
    ),
  );
}
