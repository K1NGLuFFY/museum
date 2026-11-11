import 'package:flutter/cupertino.dart';

enum Appearance { system, light, dark }

class SettingsController extends ChangeNotifier {
  Appearance _appearance = Appearance.system;
  Appearance get appearance => _appearance;
  Brightness? get brightness => switch (_appearance) {
    Appearance.system => null,
    Appearance.light => Brightness.light,
    Appearance.dark => Brightness.dark,
  };

  void setAppearance(Appearance value) {
    if (_appearance == value) return;
    _appearance = value;
    notifyListeners();
  }
}
