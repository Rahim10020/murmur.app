import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/app/appearance.dart';

void main() {
  group('AppearanceController', () {
    test('défaut : système quand rien n’est stocké', () async {
      final controller = AppearanceController(store: MemoryThemeModeStore());
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.mode, ThemeMode.system);
    });

    test('setMode notifie et persiste', () async {
      final store = MemoryThemeModeStore();
      final controller = AppearanceController(store: store);
      addTearDown(controller.dispose);

      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setMode(ThemeMode.dark);

      expect(controller.mode, ThemeMode.dark);
      expect(store.value, 'dark');
      expect(notified, 1);
    });

    test('load relit la valeur persistée', () async {
      final controller = AppearanceController(
        store: MemoryThemeModeStore('light'),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.mode, ThemeMode.light);
    });

    test('valeur illisible : repli système', () async {
      final controller = AppearanceController(
        store: MemoryThemeModeStore('arc-en-ciel'),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.mode, ThemeMode.system);
    });

    test('chaque mode a un nom persistable distinct', () {
      expect({
        ThemeMode.system.name,
        ThemeMode.light.name,
        ThemeMode.dark.name,
      }, hasLength(3));
    });
  });
}
