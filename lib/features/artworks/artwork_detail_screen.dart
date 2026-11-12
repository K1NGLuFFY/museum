import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/museum_page.dart';
import 'artwork.dart';
import 'artwork_widgets.dart';
import '../library/library_scope.dart';
import '../collections/collection_actions.dart';

class ArtworkDetailScreen extends StatefulWidget {
  const ArtworkDetailScreen({super.key, required this.artwork});
  final Artwork artwork;
  @override
  State<ArtworkDetailScreen> createState() => _ArtworkDetailScreenState();
}

class _ArtworkDetailScreenState extends State<ArtworkDetailScreen> {
  Artwork get artwork => widget.artwork;
  bool _recorded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final library = LibraryScope.maybeOf(context)?.library;
    if (!_recorded && library != null) {
      _recorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) library.recordView(artwork).catchError((_) {});
      });
    }
  }

  Future<void> _openSource(BuildContext context, {Uri? url}) async {
    try {
      if (await launchUrl(
        url ?? artwork.sourceUrl,
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
        title: const Text('Unable to open the website'),
        content: Text(
          'You can open this address in your browser:\n${url ?? artwork.sourceUrl}',
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
    final scope = LibraryScope.maybeOf(context);
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
            const LibraryStatus(),
            if (artwork.isCached)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Stored metadata${artwork.cachedAt == null ? '' : ' · saved ${artwork.cachedAt!.toLocal().toString().split(' ').first}'}. Museum records may have changed.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ArtworkImage(
              url: artwork.hasImage ? artwork.fullImageUrl : null,
              label: artwork.title,
              height: 360,
              fullResolution: true,
              fallbackUrl: artwork.thumbnailUrl,
            ),
            if (images.isNotEmpty)
              CupertinoButton(
                onPressed: () {
                  final preview =
                      scope?.network.offline == true &&
                      artwork.thumbnailUrl != null;
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => ArtworkImageViewer(
                        title: artwork.title,
                        images: preview ? [artwork.thumbnailUrl!] : images,
                        cachedPreview: preview,
                      ),
                    ),
                  );
                },
                child: Text(
                  images.length > 1
                      ? 'View ${images.length} images · Zoom'
                      : 'View full screen · Zoom',
                ),
              ),
            const SizedBox(height: 24),
            if (scope != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CupertinoButton.filled(
                    onPressed: scope.library.loading || scope.library.readOnly
                        ? null
                        : () => libraryAction(
                            context,
                            () => scope.library.toggleSaved(artwork),
                          ),
                    child: Text(
                      scope.library.isSaved(artwork.id)
                          ? 'Remove bookmark'
                          : 'Save artwork',
                    ),
                  ),
                  CupertinoButton.tinted(
                    onPressed: scope.library.loading || scope.library.readOnly
                        ? null
                        : () => chooseCollections(context, artwork),
                    child: const Text('Add to collection'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
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
            if (artwork.descriptionAttribution != null) ...[
              const SizedBox(height: 12),
              Text(
                artwork.descriptionAttribution!,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            if (artwork.descriptionLicenseUrl != null)
              CupertinoButton(
                onPressed: () =>
                    _openSource(context, url: artwork.descriptionLicenseUrl),
                child: const Text('Read description license'),
              ),
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
    this.cachedPreview = false,
  });
  final String title;
  final List<Uri> images;
  final bool cachedPreview;
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
                  fullResolution: !widget.cachedPreview,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              widget.cachedPreview
                  ? 'Cached preview. Pinch to zoom.'
                  : 'Pinch to zoom. Drag to explore.',
            ),
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
