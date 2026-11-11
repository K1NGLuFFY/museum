import 'package:flutter/cupertino.dart';

import '../../core/theme/museum_theme.dart';
import '../../core/widgets/empty_gallery.dart';
import '../../core/widgets/museum_page.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.settings,
    required this.onExplore,
  });
  final SettingsController settings;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => MuseumPage(
    title: 'MUSEUM',
    subtitle: 'Art, history & human imagination',
    trailing: CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SettingsScreen(settings: settings),
        ),
      ),
      child: const Icon(
        CupertinoIcons.slider_horizontal_3,
        semanticLabel: 'Settings',
        size: 23,
      ),
    ),
    children: [
      const SectionHeading(
        'A world worth looking at.',
        eyebrow: 'Your daily museum',
      ),
      const EmptyGallery(
        icon: CupertinoIcons.photo,
        title: 'The gallery is quiet for now',
        message:
            'There are no artworks to display yet. Discoveries from museum collections will appear here.',
      ),
      const SizedBox(height: 32),
      const SectionHeading('Follow your curiosity'),
      Text(
        'A familiar artist. An unfamiliar place. A detail that makes you stop.',
        style: TextStyle(
          color: MuseumColors.resolve(MuseumColors.secondary, context),
        ),
      ),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: CupertinoButton.filled(
          onPressed: onExplore,
          child: const Text('Explore the collection'),
        ),
      ),
      const SizedBox(height: 38),
      Container(
        height: 1,
        color: MuseumColors.resolve(MuseumColors.divider, context),
      ),
      const SizedBox(height: 24),
      const SectionHeading('Return to a discovery', eyebrow: 'Recently viewed'),
      Text(
        'Artworks you open will find a place here.',
        style: TextStyle(
          fontSize: 15,
          color: MuseumColors.resolve(MuseumColors.secondary, context),
        ),
      ),
    ],
  );
}
