import 'dart:async';
import 'dart:convert'; // For JSON
import 'dart:math'; // For Random OTP
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Add this to pubspec.yaml
import 'package:intl_phone_field/intl_phone_field.dart';
import '../Widgets/bottom_nav.dart';
import '../Widgets/models.dart';
import '../Widgets/authentication.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({Key? key}) : super(key: key);

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _auth = AuthService(); // Ensure this handles anonymous sign-in
  final _phoneC = TextEditingController();
  final _otpC = TextEditingController();

  // --- ZAYKA BOT CONFIGURATION ---
  // REPLACE THIS WITH YOUR ACTUAL ORACLE IP
  final String _botApiUrl = "http://129.151.133.172:3000/send-otp";
  final String _botSecret = "zayka_secret_key_123";
  // -------------------------------

  String? _completePhoneNumber;
  String? _generatedOtp; // Store the OTP we generated locally
  bool _loading = false;

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
    ));
  }

  // --- STEP 1: GENERATE & SEND OTP VIA BOT ---
  Future<void> _startZaykaAuth() async {
    if (_completePhoneNumber == null || _completePhoneNumber!.isEmpty) {
      _showErr('Please enter a valid phone number');
      return;
    }

    // 0. Check Lockout & Rate Limit
    final lockoutMsg = await AuthUtils.getLockoutMessage(_completePhoneNumber!);
    if (lockoutMsg != null) {
      _showErr(lockoutMsg);
      return;
    }

    if (!await AuthUtils.canRequestOtp(_completePhoneNumber!)) {
      _showErr('Please wait 1 minute before requesting another OTP');
      return;
    }

    setState(() => _loading = true);

    // 1. Generate a random 6-digit OTP
    final random = Random();
    final otp = (100000 + random.nextInt(900000)).toString();

    // 2. Remove the '+' for the API
    final cleanPhone = _completePhoneNumber!.replaceAll('+', '');

    try {
      // 3. Call Your Bot API
      final response = await http.post(
        Uri.parse(_botApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': cleanPhone,
          'otp': otp,
          'secret': _botSecret,
        }),
      );

      if (response.statusCode == 200) {
        // Success!
        await AuthUtils.recordOtpRequest(_completePhoneNumber!);
        setState(() {
          _generatedOtp = otp; // Save it to verify later
          _loading = false;
        });
        _showOtpSheet();
      } else {
        // Server Error
        final errorData = jsonDecode(response.body);
        throw errorData['error'] ?? 'Server error';
      }
    } catch (e) {
      setState(() => _loading = false);
      _showErr('Failed to send OTP: $e');
      print("OTP Error: $e");
    }
  }

  // --- STEP 2: VERIFY OTP LOCALLY ---
  void _verifyOtp(StateSetter setSheetState) async {
    final userEnteredCode = _otpC.text.trim();

    if (userEnteredCode.length != 6) {
      setSheetState(() => _sheetError = 'Please enter the 6-digit code');
      return;
    }

    // Check lockout again before verification
    final lockoutMsg = await AuthUtils.getLockoutMessage(_completePhoneNumber!);
    if (lockoutMsg != null) {
      setSheetState(() => _sheetError = lockoutMsg);
      return;
    }

    // Compare input with the OTP we generated earlier
    if (userEnteredCode == _generatedOtp) {
      await AuthUtils.clearFailedAttempts(_completePhoneNumber!);
      Navigator.pop(context); // Close sheet
      await _finishLogin();
    } else {
      await AuthUtils.recordFailedAttempt(_completePhoneNumber!);
      final newLockout =
          await AuthUtils.getLockoutMessage(_completePhoneNumber!);
      setSheetState(() {
        _sheetError = newLockout ?? 'Invalid OTP. Please try again.';
      });
    }
  }

  // --- STEP 3: AUTHENTICATE & SAVE TO FIRESTORE ---
  Future<void> _finishLogin() async {
    setState(() => _loading = true);
    try {
      // 1. Sign in Anonymously (to get a secure UID)
      // We rely on FirebaseAuth to handle the session, even though we did the OTP ourselves.
      UserCredential userCred = await FirebaseAuth.instance.signInAnonymously();

      if (userCred.user != null) {
        // 2. Set the custom verified phone in AuthUtils (for persistent identity)
        await AuthUtils.setVerifiedPhone(_completePhoneNumber);

        final docId = _completePhoneNumber!; // Use the phone number as the ID

        // 3. Save/Update User Profile in Firestore
        await FirebaseFirestore.instance.collection('Users').doc(docId).set({
          'phone': _completePhoneNumber,
          'lastLogin': FieldValue.serverTimestamp(),
          'firebaseUid': userCred.user!.uid, // Store the UID reference
        }, SetOptions(merge: true));

        // Ensure 'createdAt' exists if it's new
        final docSnap = await FirebaseFirestore.instance
            .collection('Users')
            .doc(docId)
            .get();
        if (!docSnap.exists || !docSnap.data()!.containsKey('createdAt')) {
          await FirebaseFirestore.instance.collection('Users').doc(docId).set({
            'createdAt': FieldValue.serverTimestamp(),
            'name': 'New User',
          }, SetOptions(merge: true));
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainApp()));
      }
    } catch (e) {
      setState(() => _loading = false);
      _showErr('Login processing failed: $e');
    }
  }

  // --- SKIP LOGIN (Guest Mode) ---
  Future<void> _handleSkip() async {
    setState(() => _loading = true);
    try {
      await AuthUtils.setVerifiedPhone(
          null); // Clear any previous phone identity
      await _auth.signInAnonymously();
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainApp()));
      }
    } catch (e) {
      _showErr('Could not sign in as guest: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _sheetError;

  // --- UI: OTP SHEET ---
  void _showOtpSheet() {
    _otpC.clear();
    _sheetError = null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter Verification Code',
                    style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(
                    'Enter the code sent to $_completePhoneNumber via WhatsApp',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 24),
                TextField(
                  controller: _otpC,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                      color: Colors.black, fontSize: 24, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  onChanged: (v) {
                    if (_sheetError != null)
                      setSheetState(() => _sheetError = null);
                  },
                  decoration: const InputDecoration(
                    counterText: "",
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primaryBlue)),
                  ),
                ),
                if (_sheetError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _sheetError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () => _verifyOtp(setSheetState),
                    child: const Text('Verify',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0),
            child: TextButton(
              onPressed: _handleSkip,
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Skip',
                  style: TextStyle(color: AppColors.primaryBlue)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Login or create an\naccount',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: IntlPhoneField(
                  controller: _phoneC,
                  initialCountryCode: 'QA',
                  dropdownTextStyle: const TextStyle(color: Colors.black),
                  style: const TextStyle(color: Colors.black),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _startZaykaAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    disabledBackgroundColor:
                        AppColors.primaryBlue.withOpacity(0.3),
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
                      : const Text('Get OTP on WhatsApp',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: Text(
                  'We will send you a verification code via WhatsApp. \nEnsure you have WhatsApp installed on this number.',
                  style:
                      TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
