import 'package:flutter/cupertino.dart';

import '../../core/widgets/empty_gallery.dart';
import '../../core/widgets/museum_page.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key, required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => MuseumPage(
    title: 'Saved',
    subtitle: 'Keep what stays with you.',
    children: [
      EmptyGallery(
        icon: CupertinoIcons.bookmark,
        title: 'A place for your favorites',
        message:
            'You have no saved artworks. Your discoveries will be easy to return to here.',
        actionLabel: 'Explore artworks',
        onAction: onExplore,
      ),
    ],
  );
}
