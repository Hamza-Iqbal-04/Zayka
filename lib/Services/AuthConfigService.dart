import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage configurable auth mode (phone or email).
/// Call `loadConfig()` during app initialization.
class AuthConfigService {
  static String _authMethod = 'phone'; // Default to phone

  /// Returns the current auth method ('phone' or 'email')
  static String get authMethod => _authMethod;

  /// Returns true if phone OTP auth is configured
  static bool get isPhoneAuth => _authMethod == 'phone';

  /// Returns true if email/password auth is configured
  static bool get isEmailAuth => _authMethod == 'email';

  /// Loads auth configuration from Firestore.
  /// Call this during app startup.
  static Future<void> loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Config')
          .doc('app_settings')
          .get();

      if (doc.exists && doc.data() != null) {
        _authMethod = doc.data()?['authMethod'] ?? 'phone';
      }
    } catch (e) {
      // Default to phone if config fetch fails
      _authMethod = 'phone';
    }
  }
}
