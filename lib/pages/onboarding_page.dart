import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 4;

  final List<_OnboardingSlideData> _slides = const [
    _OnboardingSlideData(
      icon: Icons.language,
      title: 'Welcome to DailyFrase!',
      description:
          'Learn a new language one phrase at a time. Each session focuses on a single verb with up to 20 unique phrases — so you see it used in real context, not just memorized in isolation.',
    ),
    _OnboardingSlideData(
      icon: Icons.menu,
      title: 'Customize Your Settings',
      description:
          'Tap the ☰ menu in the top-left corner to open settings. From there you can choose your language pair, tenses, and even focus on a specific verb.',
    ),
    _OnboardingSlideData(
      icon: Icons.touch_app,
      title: 'Three Buttons, Simple Flow',
      description:
          '"New" loads the next phrase (counts as learned). "Reveal" shows the translation without moving on. "Skip" moves to the next phrase without counting it. All 20 phrases share the same verb so you build real fluency fast.',
    ),
    _OnboardingSlideData(
      icon: Icons.bar_chart_rounded,
      title: 'Track Your Progress',
      description:
          'Every phrase you review is counted. Tap the stats icon anytime to see how far you\'ve come and keep the streak going!',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    context.read<AuthService>().clearNewUserFlag();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button row
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) => _OnboardingSlide(
                  data: _slides[index],
                  accentColor: colorScheme.primary,
                ),
              ),
            ),

            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Next / Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == _totalPages - 1 ? 'Get Started 🚀' : 'Next',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model for a slide
// ---------------------------------------------------------------------------
class _OnboardingSlideData {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingSlideData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

// ---------------------------------------------------------------------------
// Individual slide widget
// ---------------------------------------------------------------------------
class _OnboardingSlide extends StatelessWidget {
  final _OnboardingSlideData data;
  final Color accentColor;

  const _OnboardingSlide({
    required this.data,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 64, color: accentColor),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            data.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            data.description,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
