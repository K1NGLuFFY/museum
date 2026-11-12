import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../core/widgets/empty_gallery.dart';
import '../artworks/artwork.dart';
import '../artworks/artwork_widgets.dart';
import '../library/library_scope.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.repository,
    this.initialQuery = const ArtworkQuery(),
    this.title = 'Explore',
    this.nested = false,
  });
  final ArtworkRepository repository;
  final ArtworkQuery initialQuery;
  final String title;
  final bool nested;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final TextEditingController _query;
  final List<Artwork> _artworks = [];
  Timer? _debounce;
  CancellationToken? _cancellation;
  String? _error;
  bool _loading = false, _searched = false;
  int? _nextOffset;
  int _total = 0;
  ArtworkCursor? _nextCursor;
  MuseumSource? _source;
  bool _titleOnly = false, _limited = false;
  List<SourceWarning> _warnings = [];
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery.text);
    _source = widget.initialQuery.departmentId != null
        ? MuseumSource.met
        : widget.initialQuery.source;
    _titleOnly = widget.initialQuery.titleOnly;
    if (_query.text.isNotEmpty || widget.initialQuery.departmentId != null) {
      _search();
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    _cancellation?.cancel();
    setState(() {
      _loading = false;
      _error = null;
      _artworks.clear();
      _searched = false;
      _nextOffset = null;
      _nextCursor = null;
      _warnings = [];
    });
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search({bool more = false}) async {
    _debounce?.cancel();
    _cancellation?.cancel();
    if (_query.text.trim().isEmpty &&
        widget.initialQuery.departmentId == null) {
      setState(() {
        _loading = false;
        _searched = false;
        _artworks.clear();
        _error = null;
      });
      return;
    }
    final cancellation = _cancellation = CancellationToken();
    final offset = more ? _nextOffset ?? 0 : 0;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      if (!more) {
        _artworks.clear();
        _nextOffset = null;
        _nextCursor = null;
        _warnings = [];
        _limited = false;
      }
    });
    try {
      final page = await widget.repository.search(
        ArtworkQuery(
          text: _query.text,
          departmentId: widget.initialQuery.departmentId,
          source: _source,
          titleOnly: _titleOnly,
          cursor: more ? _nextCursor : null,
        ),
        offset: offset,
        cancellation: cancellation,
      );
      if (!mounted || cancellation.isCancelled) return;
      setState(() {
        final ids = _artworks.map((artwork) => artwork.id).toSet();
        _artworks.addAll(page.artworks.where((artwork) => ids.add(artwork.id)));
        _nextOffset = page.nextOffset;
        _nextCursor = page.nextCursor;
        _warnings = page.warnings;
        _limited = _limited || page.limited;
        _total = page.total;
        _cached = page.isCached;
        _loading = false;
      });
      if (!more) {
        final library = LibraryScope.maybeOf(context)?.library;
        if (library != null) {
          await library.recordSearch(_query.text).catchError((_) {});
        }
      }
    } on RequestCancelled {
      /* A newer query owns the state. */
    } catch (error) {
      if (!mounted || cancellation.isCancelled) return;
      setState(() {
        _loading = false;
        _error = error is MuseumException
            ? error.message
            : 'Search is unavailable. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancellation?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _chooseMuseum() async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Search a museum'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('All museums'),
          ),
          for (final source in MuseumSource.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, source.name),
              child: Text(source.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(
      () => _source = MuseumSource.values
          .where((source) => source.name == choice)
          .firstOrNull,
    );
    await _search();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: widget.nested
        ? CupertinoNavigationBar(middle: Text(widget.title))
        : null,
    child: SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _search),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LibraryStatus(),
                  if (!widget.nested) ...[
                    const Text(
                      'Explore',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Three museums. A world of discoveries.'),
                    const SizedBox(height: 28),
                  ],
                  CupertinoSearchTextField(
                    controller: _query,
                    placeholder: 'Art, artists, cultures',
                    onChanged: _changed,
                    onSubmitted: (_) {
                      FocusScope.of(context).unfocus();
                      _search();
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      CupertinoButton.tinted(
                        onPressed: widget.initialQuery.departmentId == null
                            ? _chooseMuseum
                            : null,
                        child: Text(_source?.label ?? 'All museums'),
                      ),
                      CupertinoButton.tinted(
                        onPressed: () {
                          setState(() => _titleOnly = !_titleOnly);
                          _search();
                        },
                        child: Text(_titleOnly ? 'Title only' : 'All metadata'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!_searched &&
                      (LibraryScope.maybeOf(context)?.library.recentSearches ??
                              [])
                          .isNotEmpty) ...[
                    const Text('Recent searches'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final recent in LibraryScope.maybeOf(
                          context,
                        )!.library.recentSearches)
                          CupertinoButton.tinted(
                            onPressed: () {
                              _query.text = recent;
                              _search();
                            },
                            child: Text(recent),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_searched && _cached)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Stored results only. These records may be out of date, and the complete museum search requires a connection.',
                      ),
                    ),
                  if (!_searched)
                    const EmptyGallery(
                      icon: CupertinoIcons.search,
                      title: 'Where will curiosity take you?',
                      message:
                          'Search The Met, Chicago and Cleveland for an artist, a title, a culture or a material.',
                    )
                  else if (_error != null)
                    EmptyGallery(
                      icon: CupertinoIcons.wifi_exclamationmark,
                      title: 'Unable to search the museum',
                      message: _error!,
                      actionLabel: 'Try again',
                      onAction: () => _search(more: _artworks.isNotEmpty),
                    )
                  else if (!_loading && _artworks.isEmpty)
                    const EmptyGallery(
                      icon: CupertinoIcons.search,
                      title: 'No public-domain images found',
                      message:
                          'Try another term, or load the next page when available. Some museum records have no reusable image.',
                    ),
                  if (_artworks.isNotEmpty)
                    Text(
                      '${_artworks.length} works with open-access images · $_total matches from responding museums',
                      style: const TextStyle(fontSize: 13),
                    ),
                  if (_limited && _artworks.isNotEmpty)
                    const Text(
                      'Some museums limit deep pagination. Refine your search for more specific results.',
                    ),
                  for (final warning in _warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${warning.source.label}: ${warning.message} Other available results are shown. Load more to retry.',
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.builder(
              itemCount: _artworks.length,
              itemBuilder: (_, index) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ArtworkCard(artwork: _artworks[index], compact: true),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              child: Column(
                children: [
                  if (_loading)
                    Semantics(
                      label: 'Searching the museum',
                      child: const CupertinoActivityIndicator(),
                    )
                  else if (_nextOffset != null && _error == null)
                    CupertinoButton.filled(
                      onPressed: () => _search(more: true),
                      child: const Text('Load more'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
