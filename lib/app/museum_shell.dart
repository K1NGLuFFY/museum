import 'package:flutter/cupertino.dart';

import '../core/theme/museum_theme.dart';
import '../features/collections/collections_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/media/media_screen.dart';
import '../features/saved/saved_screen.dart';
import '../features/settings/settings_controller.dart';

class MuseumShell extends StatefulWidget {
  const MuseumShell({super.key, required this.settings});
  final SettingsController settings;

  @override
  State<MuseumShell> createState() => _MuseumShellState();
}

class _MuseumShellState extends State<MuseumShell> {
  final _tabs = CupertinoTabController();
  final _navigators = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final _canHandlePop = List.filled(5, false);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() => setState(() {});
  void _explore() => _tabs.index = 1;

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _tabs.index == 0 && !_canHandlePop[0],
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) return;
      final navigator = _navigators[_tabs.index].currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.pop(result);
      } else {
        _tabs.index = 0;
      }
    },
    child: CupertinoTabScaffold(
      controller: _tabs,
      tabBar: CupertinoTabBar(
        height: 58,
        backgroundColor: MuseumColors.resolve(MuseumColors.background, context),
        activeColor: MuseumColors.resolve(MuseumColors.accent, context),
        inactiveColor: MuseumColors.resolve(MuseumColors.secondary, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass),
            activeIcon: Icon(CupertinoIcons.compass_fill),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_stack),
            activeIcon: Icon(CupertinoIcons.square_stack_fill),
            label: 'Collections',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.play_rectangle),
            activeIcon: Icon(CupertinoIcons.play_rectangle_fill),
            label: 'Media',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bookmark),
            activeIcon: Icon(CupertinoIcons.bookmark_fill),
            label: 'Saved',
          ),
        ],
      ),
      tabBuilder: (context, index) =>
          NotificationListener<NavigationNotification>(
            onNotification: (notification) {
              if (_canHandlePop[index] != notification.canHandlePop) {
                setState(
                  () => _canHandlePop[index] = notification.canHandlePop,
                );
              }
              return true;
            },
            child: CupertinoTabView(
              navigatorKey: _navigators[index],
              builder: (_) => switch (index) {
                0 => DiscoverScreen(
                  settings: widget.settings,
                  onExplore: _explore,
                ),
                1 => const ExploreScreen(),
                2 => CollectionsScreen(onExplore: _explore),
                3 => const MediaScreen(),
                _ => SavedScreen(onExplore: _explore),
              },
            ),
          ),
    ),
  );
}
