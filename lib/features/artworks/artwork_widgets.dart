import 'package:flutter/cupertino.dart';
import 'dart:io';

import '../../core/theme/museum_theme.dart';
import 'artwork.dart';
import 'artwork_detail_screen.dart';
import '../library/library_scope.dart';

class ArtworkImage extends StatefulWidget {
  const ArtworkImage({
    super.key,
    required this.url,
    required this.label,
    this.height = 280,
    this.fullResolution = false,
    this.fallbackUrl,
  });
  final Uri? url;
  final String label;
  final double? height;
  final bool fullResolution;
  final Uri? fallbackUrl;
  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends State<ArtworkImage> {
  Future<File?>? _cached;
  String? _cacheKey;
  Widget _unavailable(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
  Widget _network() => Image.network(
    widget.url.toString(),
    height: widget.height,
    width: double.infinity,
    fit: BoxFit.contain,
    semanticLabel: widget.label,
    cacheWidth: widget.fullResolution ? null : 1000,
    loadingBuilder: (_, child, progress) => progress == null
        ? child
        : const Center(child: CupertinoActivityIndicator()),
    errorBuilder: (_, error, stack) =>
        _unavailable('Image unavailable. Please try again later.'),
  );
  @override
  Widget build(BuildContext context) {
    final scope = LibraryScope.maybeOf(context);
    Widget content() {
      if (widget.url == null) return _unavailable('Image unavailable');
      if (scope == null) return _network();
      final offline = scope.network.offline;
      if (widget.fullResolution && !offline) return _network();
      final uri = widget.fullResolution ? widget.fallbackUrl : widget.url;
      if (uri == null) {
        return _unavailable('This image is not cached on this device.');
      }
      final key = '$uri|$offline|${scope.library.cacheThumbnails}';
      if (_cacheKey != key) {
        _cacheKey = key;
        _cached = scope.thumbnails.image(
          uri,
          allowNetwork: !offline && scope.library.cacheThumbnails,
        );
      }
      return FutureBuilder<File?>(
        future: _cached,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (snapshot.data != null) {
            return Image.file(
              snapshot.data!,
              height: widget.height,
              width: double.infinity,
              fit: BoxFit.contain,
              semanticLabel: widget.fullResolution
                  ? '${widget.label}, cached preview'
                  : widget.label,
              cacheWidth: 1000,
              errorBuilder: (_, error, stack) =>
                  _unavailable('Cached image unavailable.'),
            );
          }
          if (!offline && !scope.library.cacheThumbnails) return _network();
          return _unavailable(
            offline
                ? 'This image is not cached on this device.'
                : 'Image unavailable. Please try again later.',
          );
        },
      );
    }

    return Container(
      height: widget.height,
      color: MuseumColors.resolve(MuseumColors.surface, context),
      child: scope == null
          ? content()
          : ListenableBuilder(
              listenable: scope.network,
              builder: (_, _) => content(),
            ),
    );
  }
}

class ArtworkCard extends StatelessWidget {
  const ArtworkCard({super.key, required this.artwork, this.compact = false});
  final Artwork artwork;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      onPressed: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => ArtworkDetailScreen(artwork: artwork),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ArtworkImage(
              url: artwork.thumbnailUrl,
              label: artwork.title,
              height: compact ? 190 : 320,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            artwork.title,
            style: TextStyle(
              fontSize: compact ? 18 : 23,
              fontWeight: FontWeight.w600,
              color: MuseumColors.resolve(MuseumColors.ink, context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              artwork.artist ?? 'Maker not recorded',
              artwork.date,
            ].whereType<String>().join(' · '),
            style: TextStyle(
              fontSize: 14,
              color: MuseumColors.resolve(MuseumColors.secondary, context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            artwork.museum,
            style: TextStyle(
              fontSize: 12,
              color: MuseumColors.resolve(MuseumColors.secondary, context),
            ),
          ),
        ],
      ),
    ),
  );
}
