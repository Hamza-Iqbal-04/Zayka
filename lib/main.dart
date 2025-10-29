import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mitra_da_dhaba/Screens/splash_screen.dart';
import 'package:mitra_da_dhaba/Screens/welcome_screen.dart';
import 'Services/NotificationService.dart';
import 'Widgets/appbar.dart';
import 'Widgets/authentication.dart';
import 'Widgets/bottom_nav.dart';
import 'Screens/cartScreen.dart';
import 'Widgets/Offline_Screen.dart'; // contains OfflineScreen UI only
import 'firebase_options.dart';
import 'Widgets/models.dart';
import 'Services/AddressService.dart';
import 'Services/BranchService.dart';

const Color kChipActive = Color(0xFF1E88E5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();

  // Keep orientation and any other system UI config you use
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        // 1️⃣ Streams the user’s default/saved address
        ChangeNotifierProvider<AddressService>(create: (_) => AddressService()),
        // 2️⃣ Computes the nearest branch from that address
        ChangeNotifierProxyProvider<AddressService, BranchLocator>(
          create: (ctx) => BranchLocator(ctx.read<AddressService>()),
          update: (ctx, addrSvc, locator) => locator!..recompute(),
        ),
        // 3️⃣ Your cart logic
        ChangeNotifierProvider<CartService>(create: (_) => CartService()),
      ],
      // No ConnectivityGate here; overlay is added inside MaterialApp.builder
      child: const MyApp(),
    ),
  );
}

/// Optional shared cache you had earlier
class AppImageCache {
  static const key = 'img_cache_v1';
  static final instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 400,
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
      // Inject connectivity overlay INSIDE MaterialApp so OfflineScreen has Theme/MediaQuery
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clamped = media.textScaleFactor.clamp(0.9, 1.1);
        final content = MediaQuery(
          data: media.copyWith(textScaleFactor: clamped),
          child: child ?? const SizedBox.shrink(),
        );
        return ConnectivityOverlay(child: content);
      },
      // AppLoader decides Welcome/Login/MainApp instantly without transitions
      home: AppLoader(initializationFuture: _initializationFuture),
    );
  }
}

class AppLoader extends StatefulWidget {
  final Future<bool> initializationFuture;
  const AppLoader({Key? key, required this.initializationFuture}) : super(key: key);

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Wait for both initialization and auth state
      final isFirstLaunch = await widget.initializationFuture;

      // Get the initial auth state without waiting for stream changes
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      // Navigate instantly without any transition
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) {
            if (currentUser != null) {
              return const MainApp();
            } else {
              return isFirstLaunch ? const WelcomeScreen() : const LoginScreen();
            }
          },
          transitionDuration: Duration.zero,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Fallback to login screen on error
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => const LoginScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

/// Central Firestore service (kept as in your structure)
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _usersCollection = 'Users';

  // Save or update user data
  Future<void> saveUserData(String userId, Map<String, dynamic> userData) async {
    try {
      await _db.collection(_usersCollection).doc(userId).set(userData, SetOptions(merge: true));
      // ignore: avoid_print
      print('User data saved successfully for $userId');
    } catch (e) {
      // ignore: avoid_print
      print('Error saving user data: $e');
      throw Exception('Failed to save user data.');
    }
  }

  // Get user data by ID
  Future<AppUser?> getUserData(String userId) async {
    try {
      final doc = await _db.collection(_usersCollection).doc(userId).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      } else {
        // ignore: avoid_print
        print('User document does not exist for $userId');
        return null;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error getting user data: $e');
      throw Exception('Failed to retrieve user data.');
    }
  }

  // Stream user data for real-time updates
  Stream<AppUser?> streamUserData(String userId) {
    return _db.collection(_usersCollection).doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return AppUser.fromFirestore(snapshot);
      } else {
        return null;
      }
    });
  }
}

/// Connectivity overlay injected in MaterialApp.builder
class ConnectivityOverlay extends StatefulWidget {
  final Widget child;
  const ConnectivityOverlay({super.key, required this.child});

  @override
  State<ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<ConnectivityOverlay> {
  late final StreamSubscription<ConnectivityResult> _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _sub = Connectivity().onConnectivityChanged.listen(_onChange);
  }

  Future<void> _checkInitial() async {
    final r = await Connectivity().checkConnectivity();
    _onChange(r);
  }

  void _onChange(ConnectivityResult r) {
    final isOff = r == ConnectivityResult.none;
    if (_offline != isOff && mounted) {
      setState(() => _offline = isOff);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_offline)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: const ColoredBox(
                color: Colors.white, // prevents grey/transparent flash
                child: OfflineScreen(), // UI from Widgets/connectivity_wrapper.dart
              ),
            ),
          ),
      ],
    );
  }
}
