import 'package:flutter/cupertino.dart';

import '../../core/widgets/empty_gallery.dart';
import '../../core/widgets/museum_page.dart';
import '../artworks/artwork.dart';
import '../artworks/artwork_widgets.dart';
import '../explore/explore_screen.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import '../library/library_scope.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.settings,
    required this.onExplore,
    required this.repository,
  });
  final SettingsController settings;
  final VoidCallback onExplore;
  final ArtworkRepository repository;
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<Artwork> _artworks = [];
  List<MuseumDepartment> _departments = [];
  Artwork? _daily;
  bool _loading = true;
  bool _cached = false;
  String? _error, _dailyError, _departmentsError;
  CancellationToken? _cancellation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _cancellation?.cancel();
    final cancellation = _cancellation = CancellationToken();
    setState(() {
      _loading = true;
      _error = null;
      _dailyError = null;
    });
    try {
      final page = await widget.repository.search(
        const ArtworkQuery(highlights: true),
        cancellation: cancellation,
      );
      if (!mounted || cancellation.isCancelled) return;
      setState(() {
        _artworks = page.artworks;
        _cached = page.isCached;
        _loading = false;
      });
      try {
        final daily = await widget.repository.dailyArtwork(
          DateTime.now(),
          page.artworks,
        );
        if (mounted && !cancellation.isCancelled) {
          setState(() => _daily = daily);
        }
      } catch (_) {
        if (mounted && !cancellation.isCancelled) {
          setState(
            () => _dailyError =
                'Daily discovery is unavailable. Please try again later.',
          );
        }
      }
    } on RequestCancelled {
      return;
    } catch (error) {
      if (mounted && !cancellation.isCancelled) {
        setState(() {
          _loading = false;
          _error = error is MuseumException
              ? error.message
              : 'Unable to load the collection. Please try again.';
        });
      }
    }
    try {
      final departments = await widget.repository.departments();
      if (mounted && !cancellation.isCancelled) {
        setState(() {
          _departments = departments;
          _departmentsError = null;
        });
      }
    } catch (_) {
      if (mounted && !cancellation.isCancelled) {
        setState(
          () => _departmentsError =
              'Museum departments are temporarily unavailable.',
        );
      }
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  void _browse(ArtworkQuery query, String title) => Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => ExploreScreen(
        repository: widget.repository,
        initialQuery: query,
        title: title,
        nested: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => MuseumPage(
    title: 'MUSEUM',
    subtitle: 'Art, history & human imagination',
    trailing: CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SettingsScreen(settings: widget.settings),
        ),
      ),
      child: const Icon(
        CupertinoIcons.slider_horizontal_3,
        semanticLabel: 'Settings',
        size: 23,
      ),
    ),
    children: [
      const LibraryStatus(),
      if (_cached)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Showing a stored museum selection. Reconnect and refresh for current records.',
          ),
        ),
      const SectionHeading(
        'A world worth looking at.',
        eyebrow: 'Your daily museum',
      ),
      if (_loading)
        Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Semantics(
              label: 'Loading museum highlights',
              child: const CupertinoActivityIndicator(),
            ),
          ),
        )
      else if (_error != null)
        EmptyGallery(
          icon: CupertinoIcons.wifi_exclamationmark,
          title: 'The gallery is out of reach',
          message: _error!,
          actionLabel: 'Try again',
          onAction: _load,
        )
      else if (_artworks.isEmpty)
        EmptyGallery(
          icon: CupertinoIcons.photo,
          title: 'No open-access images found',
          message:
              'The museum did not return any public-domain images for this selection.',
          actionLabel: 'Refresh',
          onAction: _load,
        )
      else ...[
        const Text('A highlight from The Met', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        ArtworkCard(artwork: _artworks.first),
        const SectionHeading(
          'One work, a closer look',
          eyebrow: 'Daily discovery',
        ),
        if (_daily != null)
          ArtworkCard(artwork: _daily!)
        else
          Text(
            _dailyError ??
                (_cached
                    ? 'Daily discovery is unavailable in this stored selection.'
                    : 'Choosing today’s discovery…'),
          ),
        const SizedBox(height: 24),
      ],
      const SectionHeading('Follow your curiosity'),
      const Text(
        'Explore the museum’s records through a subject that interests you.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final subject in [
            'Portraits',
            'Landscapes',
            'Sculpture',
            'Architecture',
          ])
            CupertinoButton.tinted(
              onPressed: () => _browse(ArtworkQuery(text: subject), subject),
              child: Text(subject),
            ),
        ],
      ),
      const SizedBox(height: 32),
      const SectionHeading('Across the museum', eyebrow: 'Museum departments'),
      if (_departmentsError != null)
        Text(_departmentsError!)
      else if (_departments.isEmpty)
        const Text('Museum departments will appear here when available.')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final department in _departments)
              CupertinoButton.tinted(
                onPressed: () => _browse(
                  ArtworkQuery(departmentId: department.id),
                  department.name,
                ),
                child: Text(department.name),
              ),
          ],
        ),
      const SizedBox(height: 24),
      CupertinoButton.filled(
        onPressed: widget.onExplore,
        child: const Text('Explore the collection'),
      ),
      if (_artworks.length > 1) ...[
        const SizedBox(height: 32),
        const SectionHeading(
          'More from The Met',
          eyebrow: 'Collection highlights',
        ),
        for (final artwork in _artworks.skip(1).take(3))
          ArtworkCard(artwork: artwork, compact: true),
      ],
      if ((LibraryScope.maybeOf(context)?.library.recentViews ?? [])
          .isNotEmpty) ...[
        const SizedBox(height: 32),
        const SectionHeading('Continue exploring', eyebrow: 'Recently viewed'),
        for (final work in LibraryScope.maybeOf(
          context,
        )!.library.recentViews.take(3))
          ArtworkCard(artwork: work, compact: true),
      ],
    ],
  );
}
