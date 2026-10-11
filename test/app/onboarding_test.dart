import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/app/onboarding.dart';

void main() {
  group('OnboardingController', () {
    test('défaut : non vu quand rien n’est stocké', () async {
      final controller = OnboardingController(store: MemoryOnboardingStore());
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.done, isFalse);
    });

    test('complete notifie et persiste', () async {
      final store = MemoryOnboardingStore();
      final controller = OnboardingController(store: store);
      addTearDown(controller.dispose);

      var notified = 0;
      controller.addListener(() => notified++);

      await controller.complete();

      expect(controller.done, isTrue);
      expect(store.value, isTrue);
      expect(notified, 1);
    });

    test('load relit la valeur persistée', () async {
      final controller = OnboardingController(
        store: MemoryOnboardingStore(true),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.done, isTrue);
    });
  });
}
