import 'package:flutter/cupertino.dart';

import '../core/theme/museum_theme.dart';
import '../features/artworks/artwork.dart';
import '../features/artworks/museum_repository.dart';
import '../features/settings/settings_controller.dart';
import 'museum_shell.dart';

class MuseumApp extends StatefulWidget {
  const MuseumApp({super.key, this.repository});
  final ArtworkRepository? repository;

  @override
  State<MuseumApp> createState() => _MuseumAppState();
}

class _MuseumAppState extends State<MuseumApp> {
  final _settings = SettingsController();
  late final ArtworkRepository _repository =
      widget.repository ?? MuseumRepository();

  @override
  void dispose() {
    _settings.dispose();
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _settings,
    builder: (context, _) => CupertinoApp(
      title: 'MUSEUM',
      debugShowCheckedModeBanner: false,
      theme: museumTheme(_settings.brightness),
      home: MuseumShell(settings: _settings, repository: _repository),
    ),
  );
}
