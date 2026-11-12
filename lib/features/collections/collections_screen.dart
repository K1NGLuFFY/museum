import 'package:flutter/cupertino.dart';

import '../../core/widgets/empty_gallery.dart';
import '../../core/widgets/museum_page.dart';
import '../artworks/artwork_widgets.dart';
import '../library/library_scope.dart';
import 'collection_actions.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key, required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) {
    final library = LibraryScope.maybeOf(context)?.library;
    return MuseumPage(
      title: 'Collections',
      subtitle: 'Art, connected by you.',
      children: [
        const LibraryStatus(),
        const SectionHeading(
          'Your own point of view',
          eyebrow: 'A personal museum',
        ),
        if (library != null) ...[
          CupertinoButton.filled(
            onPressed: library.loading || library.readOnly
                ? null
                : () => editCollectionName(context),
            child: const Text('New collection'),
          ),
          const SizedBox(height: 24),
        ],
        if (library == null || library.collections.isEmpty)
          EmptyGallery(
            icon: CupertinoIcons.square_stack,
            title: 'Every collection begins with a discovery',
            message:
                'Create a collection, then add artworks from their detail pages.',
            actionLabel: 'Find inspiration',
            onAction: onExplore,
          )
        else
          for (final collection in library.collections)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CupertinoButton.tinted(
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => CollectionScreen(id: collection.id),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(collection.name)),
                    const SizedBox(width: 12),
                    Text('${collection.artworkIds.length}'),
                    const Icon(CupertinoIcons.chevron_right, size: 16),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final library = LibraryScope.maybeOf(context)!.library;
    final collection = library.collections
        .where((collection) => collection.id == id)
        .firstOrNull;
    final works = library.collectionArtworks(id);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Collection')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const LibraryStatus(),
            SectionHeading(collection?.name ?? 'Collection removed'),
            if (collection != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CupertinoButton.tinted(
                    onPressed: () =>
                        editCollectionName(context, collection: collection),
                    child: const Text('Rename'),
                  ),
                  CupertinoButton(
                    onPressed: () async {
                      final confirmed = await showCupertinoDialog<bool>(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: Text('Delete ${collection.name}?'),
                          content: const Text(
                            'Saved artworks will remain in your library.',
                          ),
                          actions: [
                            CupertinoDialogAction(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      await libraryAction(context, () async {
                        await library.deleteCollection(id);
                        if (context.mounted) Navigator.pop(context);
                      });
                    },
                    child: const Text('Delete collection'),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            if (works.isEmpty)
              const Text(
                'Add artworks using “Add to collection” on an artwork’s detail page.',
              ),
            for (final work in works) ...[
              ArtworkCard(artwork: work, compact: true),
              CupertinoButton(
                onPressed: () => libraryAction(
                  context,
                  () => library.setCollectionArtwork(id, work, false),
                ),
                child: const Text('Remove from collection'),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
