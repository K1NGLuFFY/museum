import 'package:flutter/cupertino.dart';

import '../../core/widgets/empty_gallery.dart';
import '../../core/widgets/museum_page.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key, required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => MuseumPage(
    title: 'Collections',
    subtitle: 'Art, connected by you.',
    children: [
      const SectionHeading(
        'Your own point of view',
        eyebrow: 'A personal museum',
      ),
      EmptyGallery(
        icon: CupertinoIcons.square_stack,
        title: 'Every collection begins with a discovery',
        message:
            'There are no collections yet. Explore the museum to find works that speak to you.',
        actionLabel: 'Find inspiration',
        onAction: onExplore,
      ),
    ],
  );
}
