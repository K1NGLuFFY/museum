import 'package:flutter/cupertino.dart';

import '../../core/theme/museum_theme.dart';
import 'settings_controller.dart';
import '../library/library_scope.dart';
import '../../core/storage/thumbnail_cache.dart';

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
                    onTap: () => libraryAction(
                      context,
                      () => settings.setAppearance(option),
                    ),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: LibraryStatus(),
            ),
            const StorageControls(),
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

class StorageControls extends StatefulWidget {
  const StorageControls({super.key});
  @override
  State<StorageControls> createState() => _StorageControlsState();
}

class _StorageControlsState extends State<StorageControls> {
  ThumbnailCacheSize? _size;
  bool _started = false, _busy = false;
  String? _error;
  Future<void> _refresh() async {
    final scope = LibraryScope.maybeOf(context);
    if (scope == null) return;
    try {
      final size = await scope.thumbnails.size();
      if (mounted) {
        setState(() {
          _size = size;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Thumbnail size is unavailable.');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _refresh();
    }
  }

  String _bytes(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  @override
  Widget build(BuildContext context) {
    final scope = LibraryScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final library = scope.library;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ON THIS DEVICE',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text('Library metadata: ${_bytes(library.metadataBytes)}'),
          const SizedBox(height: 8),
          Text(
            _error ??
                (_size == null
                    ? 'Measuring thumbnails…'
                    : 'Thumbnail files: ${_bytes(_size!.bytes)} · ${_size!.files} files'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Cache viewed thumbnails')),
              const SizedBox(width: 12),
              CupertinoSwitch(
                value: library.cacheThumbnails,
                onChanged: library.loading || library.readOnly
                    ? null
                    : (enabled) => libraryAction(
                        context,
                        () => library.setCacheThumbnails(enabled),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Saved artwork metadata stays on this device. Thumbnail caching targets 160 images and removes older unused files after 30 days. The system may remove cached files sooner. Full-resolution images, video and audio are not downloaded for offline use.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await libraryAction(context, () async {
                      await scope.thumbnails.clear();
                      PaintingBinding.instance.imageCache.clear();
                      PaintingBinding.instance.imageCache.clearLiveImages();
                      await library.clearMetadataCache();
                    });
                    if (!mounted) return;
                    setState(() => _busy = false);
                    await _refresh();
                  },
            child: Text(_busy ? 'Clearing cache…' : 'Clear disposable cache'),
          ),
          const Text(
            'Bookmarks, collections and recent-view metadata are preserved.',
            style: TextStyle(fontSize: 13),
          ),
          CupertinoButton(
            onPressed: () => libraryAction(context, library.clearHistory),
            child: const Text('Clear viewing and search history'),
          ),
        ],
      ),
    );
  }
}
