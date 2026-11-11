import 'package:flutter/cupertino.dart';

import '../../core/widgets/empty_gallery.dart';
import '../../core/widgets/museum_page.dart';

enum MediaKind { watch, listen }

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});
  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  MediaKind _kind = MediaKind.watch;

  @override
  Widget build(BuildContext context) => MuseumPage(
    title: 'Media',
    subtitle: 'Another way to experience culture.',
    children: [
      CupertinoSlidingSegmentedControl<MediaKind>(
        groupValue: _kind,
        children: const {
          MediaKind.watch: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Watch'),
          ),
          MediaKind.listen: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Listen'),
          ),
        },
        onValueChanged: (value) {
          if (value != null) setState(() => _kind = value);
        },
      ),
      const SizedBox(height: 28),
      EmptyGallery(
        icon: _kind == MediaKind.watch
            ? CupertinoIcons.play_rectangle
            : CupertinoIcons.headphones,
        title: _kind == MediaKind.watch
            ? 'No films available yet'
            : 'No recordings available yet',
        message:
            'Verified cultural media will appear here with its creator, source and license.',
      ),
    ],
  );
}
