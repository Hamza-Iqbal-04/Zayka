import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'models.dart';
import '../Services/AuthConfigService.dart';
import '../Screens/phone_login_screen.dart';
import '../Screens/email_login_screen.dart';

// ───────────────────────── HELPER ─────────────────────────
class AuthUtils {
  /// Returns the Firestore Document ID for a user.
  static String getDocId(User? user) {
    if (user == null) return 'guest';
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      return user.phoneNumber!;
    }
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.toLowerCase();
    }
    return user.uid;
  }
}

// ───────────────────────── AUTH SERVICE ─────────────────────────
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<UserCredential> signIn(String email, String password) => _firebaseAuth
      .signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signInAnonymously() =>
      _firebaseAuth.signInAnonymously();

  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) =>
      _firebaseAuth.verifyPhoneNumber(
        phoneNumber:
            phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber',
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );

  Future<UserCredential> signInWithOtp(String verificationId, String smsCode) =>
      _firebaseAuth.signInWithCredential(PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: smsCode));

  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) =>
      _firebaseAuth.signInWithCredential(credential);

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await GoogleSignIn().signOut();
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _firebaseAuth.signInWithCredential(credential);
      final user = userCred.user!;
      final docId = AuthUtils.getDocId(user);

      if (userCred.additionalUserInfo?.isNewUser ?? false) {
        await FirebaseFirestore.instance.collection('Users').doc(docId).set({
          'name': user.displayName ?? 'Unknown',
          'email': user.email,
          'phone': '',
        }, SetOptions(merge: true));
      }
      return userCred;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return null;
    }
  }
}

// ───────────────────────── PHONE LOGIN SHEET (FOR CART/OVERLAYS) ─────────────────────────
class PhoneLoginSheet extends StatefulWidget {
  const PhoneLoginSheet({Key? key}) : super(key: key);

  @override
  State<PhoneLoginSheet> createState() => _PhoneLoginSheetState();
}

class _PhoneLoginSheetState extends State<PhoneLoginSheet> {
  final _auth = AuthService();
  final _phoneC = TextEditingController();
  final _otpC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _completePhoneNumber;
  String? _verificationId;
  bool _loading = false;
  bool _codeSent = false;

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate() || _completePhoneNumber == null)
      return;
    setState(() => _loading = true);

    await _auth.verifyPhoneNumber(
      _completePhoneNumber!,
      verificationCompleted: (PhoneAuthCredential cred) async {
        await _signIn(cred);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        _showErr(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _loading = false;
          _codeSent = true;
          _verificationId = verificationId;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) setState(() => _verificationId = verificationId);
      },
    );
  }

  Future<void> _verifyOtp() async {
    final smsCode = _otpC.text.trim();
    if (_verificationId == null || smsCode.length != 6) {
      _showErr('Please enter the 6-digit code');
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: smsCode);
      await _signIn(cred);
    } catch (e) {
      setState(() => _loading = false);
      _showErr('Invalid OTP: $e');
    }
  }

  Future<void> _signIn(PhoneAuthCredential cred) async {
    try {
      final userCred = await _auth.signInWithCredential(cred);
      final user = userCred.user!;
      final docId = AuthUtils.getDocId(user);

      final docSnap =
          await FirebaseFirestore.instance.collection('Users').doc(docId).get();
      if (!docSnap.exists) {
        await FirebaseFirestore.instance.collection('Users').doc(docId).set({
          'phone': user.phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'name': 'New User',
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true on success
      }
    } catch (e) {
      setState(() => _loading = false);
      _showErr('Login failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5), // Changed to Light Grey
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_codeSent ? 'Enter Verification Code' : 'Mobile Login',
                style: const TextStyle(
                    color: AppColors.primaryBlue, // Changed to Blue
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (!_codeSent) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white, // Changed to White for contrast
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Form(
                  key: _formKey,
                  child: IntlPhoneField(
                    controller: _phoneC,
                    initialCountryCode: 'QA',
                    dropdownTextStyle:
                        const TextStyle(color: Colors.black), // Black text
                    style: const TextStyle(color: Colors.black), // Black text
                    decoration: const InputDecoration(
                      hintText: 'Mobile Number',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: (phone) {
                      _completePhoneNumber = phone.completeNumber;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue, // Changed to Blue
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Send OTP',
                          style: TextStyle(
                              color: Colors.white, // Text inside white
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              Text('Enter the 6-digit code sent to $_completePhoneNumber',
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 24),
              TextField(
                controller: _otpC,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    letterSpacing: 8), // Black text
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  counterText: "",
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.primaryBlue)), // Blue accent
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue, // Changed to Blue
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: _verifyOtp,
                  child: const Text('Verify',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── LOGIN SCREEN ROUTER ─────────────────────────
// This widget routes to the appropriate login screen based on auth config.
// The actual screens are in separate files for independent maintenance.

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Route based on configured auth method
    if (AuthConfigService.isPhoneAuth) {
      return const PhoneLoginScreen();
    } else {
      return const EmailLoginScreen();
    }
  }
}

// ───────────────────────── EMAIL LOGIN SHEET (FOR CART/OVERLAYS) ─────────────────────────
class EmailLoginSheet extends StatefulWidget {
  const EmailLoginSheet({Key? key}) : super(key: key);

  @override
  State<EmailLoginSheet> createState() => _EmailLoginSheetState();
}

class _EmailLoginSheetState extends State<EmailLoginSheet> {
  final _auth = AuthService();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _isLogin = true;

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (_isLogin) {
        // Login with existing account
        await _auth.signIn(_emailC.text.trim(), _passC.text.trim());
      } else {
        // Sign up with new account
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailC.text.trim(), password: _passC.text.trim());

        final docId = AuthUtils.getDocId(cred.user!);
        await FirebaseFirestore.instance.collection('Users').doc(docId).set({
          'email': _emailC.text.trim(),
          'name': 'New User',
          'phone': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true on success
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      _showErr(e.message ?? 'Auth error');
    } catch (e) {
      setState(() => _loading = false);
      _showErr(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithGoogle();
      if (cred == null) {
        setState(() => _loading = false);
        return;
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _loading = false);
      _showErr('Google sign-in failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_isLogin ? 'Login to Continue' : 'Create Account',
                style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Valid email required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passC,
                    obscureText: true,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Password must be 6+ characters'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_isLogin ? 'Login' : 'Sign Up',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            // Google Sign In button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.g_translate, color: AppColors.darkGrey),
                label: const Text('Continue with Google'),
                onPressed: _loading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkGrey,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  _loading ? null : () => setState(() => _isLogin = !_isLogin),
              child: Text(
                _isLogin
                    ? "Don't have an account? Sign Up"
                    : "Already have an account? Login",
                style: TextStyle(
                    color: AppColors.primaryBlue, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
