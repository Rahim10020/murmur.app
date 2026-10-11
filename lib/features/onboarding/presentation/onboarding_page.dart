import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/text_styles.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/strings_scope.dart';
import '../../../shared/widgets/murmur_button.dart';

/// Une page d'onboarding : icône, grand titre + paragraphe, tout centré.
class OnboardingContent {
  const OnboardingContent({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const List<IconData> onboardingIcons = [
  LucideIcons.micVocal,
  LucideIcons.shieldCheck,
  LucideIcons.bellRing,
];

/// Contenus localisés dans l'ordre des icônes.
List<OnboardingContent> onboardingContents(AppStrings strings) => [
  OnboardingContent(
    icon: LucideIcons.micVocal,
    title: strings.onboardTitle1,
    body: strings.onboardBody1,
  ),
  OnboardingContent(
    icon: LucideIcons.shieldCheck,
    title: strings.onboardTitle2,
    body: strings.onboardBody2,
  ),
  OnboardingContent(
    icon: LucideIcons.bellRing,
    title: strings.onboardTitle3,
    body: strings.onboardBody3,
  ),
];

/// Compat historique (FR) pour les tests existants.
List<OnboardingContent> get onboardingPages =>
    onboardingContents(const FrStrings());

/// Parcours première visite : texte grand format, boutons
/// Continuer/Retour, « Passer » toujours disponible (jamais bloquant),
/// « Commencer » sur le dernier écran.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _last => _index >= onboardingIcons.length - 1;

  void _goTo(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = StringsScope.of(context);
    final pages = onboardingContents(strings);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          MurmurButton(
            variant: MurmurButtonVariant.text,
            onPressed: widget.onDone,
            label: strings.onboardSkip,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: pages.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          page.icon,
                          size: 82,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(height: 48),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Gotham',
                            fontWeight: FontWeight.w500,
                            fontSize: 32,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: MurmurTextStyles.paragraph.copyWith(
                            fontSize: 17,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: i == _index
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_index > 0)
                    Expanded(
                      child: MurmurButton(
                        variant: MurmurButtonVariant.text,
                        onPressed: () => _goTo(_index - 1),
                        label: strings.onboardBack,
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: MurmurButton(
                      onPressed: _last
                          ? widget.onDone
                          : () => _goTo(_index + 1),
                      label: _last ? strings.onboardStart : strings.onboardContinue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
