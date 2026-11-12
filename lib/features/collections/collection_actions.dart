import 'package:flutter/cupertino.dart';

import '../artworks/artwork.dart';
import '../library/library_controller.dart';
import '../library/library_scope.dart';

Future<void> editCollectionName(
  BuildContext context, {
  PersonalCollection? collection,
}) async {
  final library = LibraryScope.maybeOf(context)?.library;
  if (library == null) return;
  final name = await showCupertinoDialog<String>(
    context: context,
    builder: (context) => _CollectionNameDialog(initialName: collection?.name),
  );
  if (name == null || !context.mounted) return;
  await libraryAction(context, () async {
    if (collection == null) {
      await library.createCollection(name);
    } else {
      await library.renameCollection(collection.id, name);
    }
  });
}

class _CollectionNameDialog extends StatefulWidget {
  const _CollectionNameDialog({this.initialName});
  final String? initialName;
  @override
  State<_CollectionNameDialog> createState() => _CollectionNameDialogState();
}

class _CollectionNameDialogState extends State<_CollectionNameDialog> {
  late final controller = TextEditingController(text: widget.initialName ?? '');
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(
      widget.initialName == null ? 'New collection' : 'Rename collection',
    ),
    content: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CupertinoTextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        placeholder: 'Collection name',
        textCapitalization: TextCapitalization.sentences,
      ),
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

Future<void> chooseCollections(BuildContext context, Artwork artwork) =>
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _CollectionPicker(artwork: artwork),
      ),
    );

class _CollectionPicker extends StatelessWidget {
  const _CollectionPicker({required this.artwork});
  final Artwork artwork;
  @override
  Widget build(BuildContext context) {
    final library = LibraryScope.maybeOf(context)!.library;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Add to collections'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const LibraryStatus(),
            Text(artwork.title),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () => editCollectionName(context),
              child: const Text('New collection'),
            ),
            const SizedBox(height: 16),
            if (library.collections.isEmpty)
              const Text('Create a collection, then add this artwork to it.'),
            for (final collection in library.collections)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(collection.name)),
                    CupertinoSwitch(
                      value: collection.artworkIds.contains(artwork.id),
                      onChanged: (included) => libraryAction(
                        context,
                        () => library.setCollectionArtwork(
                          collection.id,
                          artwork,
                          included,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
