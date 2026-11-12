import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:museum/core/theme/museum_theme.dart';
import 'package:museum/features/settings/settings_screen.dart';
import 'fake_artwork_repository.dart';

Finder tab(String label) => find.descendant(
  of: find.byType(CupertinoTabBar),
  matching: find.text(label),
);

void main() {
  testWidgets('all five tabs work and retain search and media state', (
    tester,
  ) async {
    await tester.pumpWidget(testMuseumApp(FakeArtworkRepository()));
    expect(find.text('MUSEUM'), findsOneWidget);

    await tester.tap(tab('Explore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), 'Monet');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('No public-domain images found'), findsOneWidget);

    await tester.tap(tab('Collections'));
    await tester.pumpAndSettle();
    expect(
      find.text('Every collection begins with a discovery'),
      findsOneWidget,
    );
    await tester.tap(tab('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen'));
    await tester.pumpAndSettle();
    expect(find.text('No recordings available yet'), findsOneWidget);

    await tester.tap(tab('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('A place for your favorites'), findsOneWidget);
    await tester.tap(find.text('Explore artworks'));
    await tester.pumpAndSettle();
    expect(find.text('Monet'), findsOneWidget);
    await tester.tap(tab('Media'));
    await tester.pumpAndSettle();
    expect(find.text('No recordings available yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings change theme and stay on their tab navigation stack', (
    tester,
  ) async {
    await tester.pumpWidget(testMuseumApp(FakeArtworkRepository()));
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    var context = tester.element(find.byType(SettingsScreen));
    expect(CupertinoTheme.brightnessOf(context), Brightness.dark);
    expect(
      MuseumColors.resolve(MuseumColors.background, context).toARGB32(),
      0xFF111111,
    );
    await tester.tap(tab('Media'));
    await tester.pumpAndSettle();
    await tester.tap(tab('Discover'));
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    context = tester.element(find.byType(SettingsScreen));
    expect(CupertinoTheme.brightnessOf(context), Brightness.light);
    expect(
      MuseumColors.resolve(MuseumColors.background, context).toARGB32(),
      0xFFF8F7F4,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('A world worth looking at.'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android back returns to Discover from another tab', (
    tester,
  ) async {
    await tester.pumpWidget(testMuseumApp(FakeArtworkRepository()));
    await tester.tap(tab('Saved'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('A world worth looking at.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(844, 390),
  ]) {
    testWidgets('all tabs fit $size with enlarged text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(testMuseumApp(FakeArtworkRepository()));
      expect(tester.takeException(), isNull);
      for (final label in ['Explore', 'Collections', 'Media', 'Saved']) {
        await tester.tap(tab(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label at $size');
      }
    });
  }
}
