import 'package:flutter/widgets.dart';

import 'app_strings.dart';

/// Expose les chaînes effectives au sous-arbre.
///
/// Les widgets lisent `StringsScope.of(context)` avec repli français pour
/// rester testables sans wrapper (les tests existants n'ont pas de scope).
class StringsScope extends InheritedWidget {
  const StringsScope({super.key, required this.strings, required super.child});

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StringsScope>();
    return scope?.strings ?? const FrStrings();
  }

  static AppStrings maybeOf(BuildContext context) => of(context);

  @override
  bool updateShouldNotify(StringsScope oldWidget) => oldWidget.strings != strings;
}
