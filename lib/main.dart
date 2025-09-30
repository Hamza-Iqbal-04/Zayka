import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:mitra_da_dhaba/Screens/splash_screen.dart';
import 'package:mitra_da_dhaba/Screens/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Services/NotificationService.dart';
import 'Widgets/appbar.dart';
import 'Widgets/authentication.dart';
import 'Widgets/bottom_nav.dart';
import 'Screens/cartScreen.dart';
import 'firebase_options.dart';
import 'Widgets/models.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'Services/AddressService.dart';
import 'Services/BranchService.dart';

const Color kChipActive = Color(0xFF1E88E5);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.initialize();

  runApp(
      MultiProvider(
        providers: [
          // 1️⃣  Streams the user’s default/saved address
          ChangeNotifierProvider(create: (_) => AddressService()),

          // 2️⃣  Computes the nearest branch from that address
          ChangeNotifierProxyProvider<AddressService, BranchLocator>(
            create: (ctx) => BranchLocator(ctx.read<AddressService>()),
            update: (ctx, addrSvc, locator) => locator!..recompute(),
          ),

          // 3️⃣  Your cart logic (no constructor args needed)
          ChangeNotifierProvider(create: (_) => CartService()),
        ],
        child: const MyApp(),
      ),
  );
}

class AppImageCache {
  static const key = 'img_cache_v1';
  static final instance = CacheManager(
    Config(
      key,
      stalePeriod: Duration(days: 7), // keep files for a week
      maxNrOfCacheObjects: 400, // tune to your catalog size
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This logic checks if it's the user's first time opening the app.
  final Future<bool> _initializationFuture = _initializeDependencies();

  static Future<bool> _initializeDependencies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isFirstLaunch') ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mitra Da Dhaba',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: Colors.grey,
        ),
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clamped = media.textScaleFactor.clamp(0.9, 1.1);
        return MediaQuery(
            data: media.copyWith(textScaleFactor: clamped), child: child!);
      },
      // This builder structure ensures the correct screen is shown.
      home: FutureBuilder<bool>(
        future: _initializationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen(); // Show splash while loading
          }

          if (snapshot.hasError) {
            return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                    child: Text('Error initializing app: ${snapshot.error}')));
          }

          final bool isFirstLaunch = snapshot.data ?? true;

          // After initialization, check if the user is logged in.
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }
              if (authSnapshot.hasData) {
                return  MainApp(); // If logged in, go to MainApp
              } else {
                // If not logged in, show Welcome or Login screen
                return isFirstLaunch
                    ? const WelcomeScreen()
                    : const LoginScreen();
              }
            },
          );
        },
      ),
    );
  }
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference for users
  final String _usersCollection = 'Users';

  // Save or update user data
  Future<void> saveUserData(
      String userId, Map<String, dynamic> userData) async {
    try {
      await _db
          .collection(_usersCollection)
          .doc(userId)
          .set(userData, SetOptions(merge: true));
      print('User data saved successfully for $userId');
    } catch (e) {
      print('Error saving user data: $e');
      throw Exception('Failed to save user data.');
    }
  }

  // Get user data by ID
  Future<AppUser?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc =
          await _db.collection(_usersCollection).doc(userId).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      } else {
        print('User document does not exist for $userId');
        return null;
      }
    } catch (e) {
      print('Error getting user data: $e');
      throw Exception('Failed to retrieve user data.');
    }
  }

  // Stream user data for real-time updates
  Stream<AppUser?> streamUserData(String userId) {
    return _db
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return AppUser.fromFirestore(snapshot);
      } else {
        return null;
      }
    });
  }
}






