import 'package:flutter/cupertino.dart';

import '../../core/widgets/empty_gallery.dart';
import '../../core/widgets/museum_page.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MuseumPage(
    title: 'Explore',
    subtitle: 'Make room for something unexpected.',
    children: [
      CupertinoSearchTextField(
        controller: _query,
        placeholder: 'Art, artists, cultures',
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
      const SizedBox(height: 28),
      EmptyGallery(
        icon: CupertinoIcons.search,
        title: _query.text.trim().isEmpty
            ? 'Where will curiosity take you?'
            : 'Search is not available yet',
        message: _query.text.trim().isEmpty
            ? 'Find a painting, a maker or a moment in history. Museum search will be available here.'
            : 'Museum search is not available yet. Please return later to explore the collection.',
      ),
    ],
  );
}
