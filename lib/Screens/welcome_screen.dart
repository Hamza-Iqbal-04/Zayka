import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../Widgets/authentication.dart';
import '../Widgets/models.dart';
import '../Services/language_provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Local Lottie animation assets
  static const List<String> _lottieAssets = [
    'assets/lottie/Food ordering on phone animation.json',
    'assets/lottie/Fast delivery scooter animation.json',
    'assets/lottie/Home Delivery.json',
  ];

  @override
  void initState() {
    super.initState();
    _setFirstLaunchFlag();
  }

  // Set the flag so this screen doesn't show again on subsequent launches
  Future<void> _setFirstLaunchFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Changed to Light Grey
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _navigateToLogin,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.primaryBlue, // Changed to Blue
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPage(
                    lottieAsset: _lottieAssets[0],
                    titleKey: 'onboarding_title_1',
                    subtitleKey: 'onboarding_subtitle_1',
                  ),
                  _buildPage(
                    lottieAsset: _lottieAssets[1],
                    titleKey: 'onboarding_title_2',
                    subtitleKey: 'onboarding_subtitle_2',
                  ),
                  _buildPage(
                    lottieAsset: _lottieAssets[2],
                    titleKey: 'onboarding_title_3',
                    subtitleKey: 'onboarding_subtitle_3',
                    showTerms: true,
                  ),
                ],
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: 3,
                effect: ExpandingDotsEffect(
                  activeDotColor: AppColors.primaryBlue,
                  dotColor: Colors.grey.shade300,
                  dotHeight: 10,
                  dotWidth: 10,
                  expansionFactor: 3,
                  spacing: 8,
                ),
              ),
            ),

            // CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.primaryBlue.withOpacity(0.3),
                  ),
                  child: Text(
                    _currentPage == 2
                        ? AppStrings.get('get_started', context)
                        : AppStrings.get('next', context),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required String lottieAsset,
    required String titleKey,
    required String subtitleKey,
    bool showTerms = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie animation
          SizedBox(
            height: 280,
            width: 280,
            child: Lottie.asset(
              lottieAsset,
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 100,
                    color: AppColors.primaryBlue,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            AppStrings.get(titleKey, context),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue, // Changed to Blue
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            AppStrings.get(subtitleKey, context),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          if (showTerms) ...[
            const SizedBox(height: 24),
            Text(
              AppStrings.get('terms_privacy_agreement', context),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
