import 'package:flutter/cupertino.dart';
import '../library/library_controller.dart';

enum Appearance { system, light, dark }

class SettingsController extends ChangeNotifier {
  SettingsController({LibraryController? library}) : _library = library {
    library?.addListener(_sync);
    _sync();
  }
  final LibraryController? _library;
  void _sync() {
    final appearance =
        Appearance.values
            .where((value) => value.name == _library?.appearance)
            .firstOrNull ??
        Appearance.system;
    if (_appearance != appearance) {
      _appearance = appearance;
      notifyListeners();
    }
  }

  Appearance _appearance = Appearance.system;
  Appearance get appearance => _appearance;
  Brightness? get brightness => switch (_appearance) {
    Appearance.system => null,
    Appearance.light => Brightness.light,
    Appearance.dark => Brightness.dark,
  };

  Future<void> setAppearance(Appearance value) async {
    if (_appearance == value) return;
    await _library?.setAppearance(value.name);
    _appearance = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _library?.removeListener(_sync);
    super.dispose();
  }
}
