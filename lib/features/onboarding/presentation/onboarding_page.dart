import 'package:flutter/material.dart';

import '../../../app/text_styles.dart';
import '../../../shared/widgets/murmur_button.dart';

/// Une page d'onboarding : grand titre + paragraphe, sans icônes.
class OnboardingContent {
  const OnboardingContent({required this.title, required this.body});

  final String title;
  final String body;
}

const List<OnboardingContent> onboardingPages = [
  OnboardingContent(
    title: 'Une idée ? Murmurez-la.',
    body:
        'Capturez vos pensées à voix haute en un geste. '
        'Rien à écrire, rien à classer.',
  ),
  OnboardingContent(
    title: 'Vos mots restent à vous.',
    body:
        '100 % hors-ligne, sur votre téléphone. '
        'Rien n’est envoyé, rien n’est analysé.',
  ),
  OnboardingContent(
    title: 'On vous la rappelle.',
    body:
        'Programmez un rappel, ou laissez Murmur vous faire '
        'redécouvrir vos idées au bon moment.',
  ),
];

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

  bool get _last => _index >= onboardingPages.length - 1;

  void _goTo(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          MurmurButton(
            variant: MurmurButtonVariant.text,
            onPressed: widget.onDone,
            label: 'Passer',
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
                  itemCount: onboardingPages.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final page = onboardingPages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          page.title,
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
                  for (var i = 0; i < onboardingPages.length; i++)
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
                        label: 'Retour',
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: MurmurButton(
                      onPressed: _last
                          ? widget.onDone
                          : () => _goTo(_index + 1),
                      label: _last ? 'Commencer' : 'Continuer',
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
