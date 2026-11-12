import 'package:flutter/cupertino.dart';

import '../../core/api/network_monitor.dart';
import '../../core/storage/thumbnail_cache.dart';
import 'library_controller.dart';

class LibraryScope extends InheritedNotifier<LibraryController> {
  const LibraryScope({
    super.key,
    required LibraryController library,
    required this.network,
    required this.thumbnails,
    required super.child,
  }) : super(notifier: library);
  final NetworkMonitor network;
  final ThumbnailCache thumbnails;
  LibraryController get library => notifier!;
  static LibraryScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LibraryScope>();
}

Future<void> libraryAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Unable to save this change'),
        content: Text(
          error is ArgumentError
              ? error.message.toString()
              : LibraryScope.maybeOf(context)?.library.error ??
                    'Please try again.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class LibraryStatus extends StatelessWidget {
  const LibraryStatus({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = LibraryScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: scope.network,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scope.network.offline)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'No network connection. Saved metadata and available cached thumbnails can still be viewed.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          if (scope.library.loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Opening your library…'),
            ),
          if (scope.library.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scope.library.error!),
                  if (scope.library.readOnly)
                    CupertinoButton(
                      onPressed: scope.library.retryLoad,
                      child: const Text('Retry library'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
