import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/museum_page.dart';
import 'artwork.dart';
import 'artwork_widgets.dart';

class ArtworkDetailScreen extends StatelessWidget {
  const ArtworkDetailScreen({super.key, required this.artwork});
  final Artwork artwork;

  Future<void> _openSource(BuildContext context) async {
    try {
      if (await launchUrl(
        artwork.sourceUrl,
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Present a recoverable action below. */
    }
    if (!context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Unable to open the museum website'),
        content: const Text(
          'Copy the source link and open it in your browser.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadata = <String, String?>{
      'Artist or maker': artwork.artist,
      'Date': artwork.date,
      'Medium': artwork.medium,
      'Dimensions': artwork.dimensions,
      'Culture': artwork.culture,
      'Country or region': artwork.country,
      'Department': artwork.department,
      'Classification': artwork.classification,
      'Credit': artwork.creditLine,
    };
    final images = [
      if (artwork.hasImage) artwork.fullImageUrl!,
      ...artwork.additionalImages,
    ];
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Artwork')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ArtworkImage(
              url: artwork.hasImage ? artwork.fullImageUrl : null,
              label: artwork.title,
              height: 360,
              fullResolution: true,
            ),
            if (images.isNotEmpty)
              CupertinoButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).push(
                      CupertinoPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => ArtworkImageViewer(
                          title: artwork.title,
                          images: images,
                        ),
                      ),
                    ),
                child: Text(
                  images.length > 1
                      ? 'View ${images.length} images · Zoom'
                      : 'View full screen · Zoom',
                ),
              ),
            const SizedBox(height: 24),
            SectionHeading(artwork.title),
            for (final entry in metadata.entries)
              if (entry.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(entry.value!),
                    ],
                  ),
                ),
            if (artwork.artist == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Text(
                  'The museum has not supplied an artist or maker for this work.',
                ),
              ),
            if (artwork.description != null) Text(artwork.description!),
            const SizedBox(height: 20),
            const SectionHeading('Source & rights'),
            Text(artwork.museum),
            const SizedBox(height: 8),
            Text(artwork.license),
            const SizedBox(height: 8),
            const Text(
              'Metadata supplied by the museum. Visit the original record for further context.',
            ),
            CupertinoButton(
              onPressed: () => _openSource(context),
              child: const Text('Open museum record'),
            ),
            CupertinoButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: artwork.sourceUrl.toString()),
                );
                if (!context.mounted) return;
                await showCupertinoDialog<void>(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: const Text('Source link copied'),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Copy source link'),
            ),
          ],
        ),
      ),
    );
  }
}

class ArtworkImageViewer extends StatefulWidget {
  const ArtworkImageViewer({
    super.key,
    required this.title,
    required this.images,
  });
  final String title;
  final List<Uri> images;
  @override
  State<ArtworkImageViewer> createState() => _ArtworkImageViewerState();
}

class _ArtworkImageViewerState extends State<ArtworkImageViewer> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: Text('${_index + 1} of ${widget.images.length}'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ),
    child: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              key: ValueKey(_index),
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: ArtworkImage(
                  url: widget.images[_index],
                  label: widget.title,
                  height: null,
                  fullResolution: true,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Pinch to zoom. Drag to explore.'),
          ),
          if (widget.images.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CupertinoButton(
                  onPressed: _index > 0 ? () => setState(() => _index--) : null,
                  child: const Text('Previous'),
                ),
                CupertinoButton(
                  onPressed: _index < widget.images.length - 1
                      ? () => setState(() => _index++)
                      : null,
                  child: const Text('Next'),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
