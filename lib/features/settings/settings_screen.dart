import 'package:flutter/cupertino.dart';

import '../../core/theme/museum_theme.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(
      middle: Text('Settings'),
      previousPageTitle: 'Discover',
    ),
    child: SafeArea(
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            CupertinoListSection.insetGrouped(
              backgroundColor: MuseumColors.resolve(
                MuseumColors.background,
                context,
              ),
              header: const Text('APPEARANCE'),
              children: [
                for (final option in Appearance.values)
                  CupertinoListTile(
                    title: Text(switch (option) {
                      Appearance.system => 'Use device setting',
                      Appearance.light => 'Light',
                      Appearance.dark => 'Dark',
                    }),
                    trailing: settings.appearance == option
                        ? const Icon(CupertinoIcons.check_mark, size: 19)
                        : null,
                    onTap: () => settings.setAppearance(option),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MUSEUM',
                    style: TextStyle(
                      letterSpacing: 3,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Art, history & human imagination.\nA personal museum, open to everyone.',
                    style: TextStyle(
                      fontSize: 14,
                      color: MuseumColors.resolve(
                        MuseumColors.secondary,
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
