import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Widgets/authentication.dart';
import '../Widgets/models.dart';


class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _setFirstLaunchFlag();
  }

  // Set the flag so this screen doesn't show again on subsequent launches
  Future<void> _setFirstLaunchFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Restaurant Logo/Image
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentBlue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 100,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Welcome Text
              Text(
                'Welcome to Punjabi Bites!',
                style: AppTextStyles.headline1.copyWith(color: AppColors.primaryBlue),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your authentic taste of Punjab, delivered right to your doorstep.',
                style: AppTextStyles.bodyText1.copyWith(color: AppColors.darkGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              // Get Started Button
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                  shadowColor: AppColors.primaryBlue.withOpacity(0.5),
                ),
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}