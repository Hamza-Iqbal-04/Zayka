import 'package:flutter/material.dart';
import '../Widgets/models.dart';


class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryBlue,
              Color(0xFF1565C0), // Slightly darker blue for depth
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circle avatar for the logo with shadow
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.white.withOpacity(0.14),
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 68,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // App name with custom font and spacing
                Text(
                  'Zayka',
                  style: AppTextStyles.headline1.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Optional: App slogan
                Text(
                  'Taste That Feels Like Home',
                  style: AppTextStyles.bodyText1.copyWith(
                    color: AppColors.white.withOpacity(0.85),
                    fontSize: 16,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 54),
                // Loading indicator with animation curve
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                    strokeWidth: 3.6,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Loading your delicious experience...',
                  style: AppTextStyles.bodyText1.copyWith(
                    color: AppColors.white.withOpacity(0.78),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


