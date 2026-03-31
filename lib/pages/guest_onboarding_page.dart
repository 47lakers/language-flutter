import 'package:flutter/material.dart';
import 'guest_home_page.dart';

class GuestOnboardingPage extends StatefulWidget {
  const GuestOnboardingPage({super.key});

  @override
  State<GuestOnboardingPage> createState() => _GuestOnboardingPageState();
}

class _GuestOnboardingPageState extends State<GuestOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 2;

  final List<_OnboardingSlideData> _slides = const [
    _OnboardingSlideData(
      emoji: '👋',
      title: 'Welcome to DailyFrase (Demo Mode)!',
      description:
          'Try out the main features of DailyFrase without creating an account.\n\nYou can generate and practice a few phrases as a guest.\n\nWant to change the language? Just go to the settings icon in the top left and pick your language.',
    ),
    _OnboardingSlideData(
      emoji: '🔒',
      title: 'Limited Access in Demo',
          description:
            'As a guest, you can:\n• Generate up to 2 phrase sets per day, up to 40 phrases in total.\n• Listen to any phrase you don\'t know\n\nTo save your progress, track stats, and unlock more features, sign up for a free account!',
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

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GuestHomePage()),
    );
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
                        : colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _nextPage,
                    child: Text(_currentPage == _totalPages - 1 ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  final String emoji;
  final String title;
  final String description;
  const _OnboardingSlideData({
    required this.emoji,
    required this.title,
    required this.description,
  });
}

class _OnboardingSlide extends StatelessWidget {
  final _OnboardingSlideData data;
  final Color accentColor;
  const _OnboardingSlide({required this.data, required this.accentColor, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            data.emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 24),
          Text(
            data.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Text(
            data.description,
            style: const TextStyle(fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
