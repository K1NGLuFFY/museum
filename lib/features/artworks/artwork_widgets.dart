import 'package:flutter/cupertino.dart';

import '../../core/theme/museum_theme.dart';
import 'artwork.dart';
import 'artwork_detail_screen.dart';

class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    super.key,
    required this.url,
    required this.label,
    this.height = 280,
    this.fullResolution = false,
  });
  final Uri? url;
  final String label;
  final double? height;
  final bool fullResolution;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    color: MuseumColors.resolve(MuseumColors.surface, context),
    child: url == null
        ? const Center(child: Text('Image unavailable'))
        : Image.network(
            url.toString(),
            height: height,
            width: double.infinity,
            fit: BoxFit.contain,
            semanticLabel: label,
            cacheWidth: fullResolution ? null : 1000,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CupertinoActivityIndicator()),
            errorBuilder: (context, error, stack) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Image unavailable. Please try again later.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
  );
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
