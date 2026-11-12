import 'package:flutter/cupertino.dart';

import '../../core/widgets/empty_gallery.dart';
import '../artworks/artwork_widgets.dart';
import '../library/library_scope.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key, required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) {
    final works = LibraryScope.maybeOf(context)?.library.saved ?? [];
    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Saved',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Keep what stays with you.'),
                    const SizedBox(height: 24),
                    const LibraryStatus(),
                    if (works.isEmpty)
                      EmptyGallery(
                        icon: CupertinoIcons.bookmark,
                        title: 'A place for your favorites',
                        message:
                            'You have no saved artworks. Your discoveries will be easy to return to here.',
                        actionLabel: 'Explore artworks',
                        onAction: onExplore,
                      )
                    else
                      Text(
                        '${works.length} saved artworks · Metadata available offline. Images depend on the thumbnail cache.',
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: works.length,
                itemBuilder: (_, index) =>
                    ArtworkCard(artwork: works[index], compact: true),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
