import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../Widgets/bottom_nav.dart';
import '../Widgets/models.dart';
import '../Widgets/authentication.dart'; // For AuthUtils and AuthService

/// Phone OTP Login Screen
/// Standalone file for maintainability - can be modified independently.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({Key? key}) : super(key: key);

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _auth = AuthService();
  final _phoneC = TextEditingController();
  final _otpC = TextEditingController();

  String? _completePhoneNumber;
  String? _verificationId;
  bool _loading = false;

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleSkip() async {
    setState(() => _loading = true);
    try {
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

  Future<void> _startPhoneAuth() async {
    if (_completePhoneNumber == null || _completePhoneNumber!.isEmpty) {
      _showErr('Please enter a valid phone number');
      return;
    }

    setState(() => _loading = true);

    await _auth.verifyPhoneNumber(
      _completePhoneNumber!,
      verificationCompleted: (PhoneAuthCredential cred) async {
        await _authenticateWithCredential(cred);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        _showErr(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _loading = false;
          _verificationId = verificationId;
        });
        _showOtpSheet();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _authenticateWithCredential(PhoneAuthCredential cred) async {
    try {
      final userCred = await _auth.signInWithCredential(cred);
      if (userCred.user != null) {
        final user = userCred.user!;
        final docId = AuthUtils.getDocId(user);

        final docSnap = await FirebaseFirestore.instance
            .collection('Users')
            .doc(docId)
            .get();
        if (!docSnap.exists) {
          await FirebaseFirestore.instance.collection('Users').doc(docId).set({
            'phone': user.phoneNumber,
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
      _showErr('Login failed: $e');
    }
  }

  void _verifyOtp() async {
    final smsCode = _otpC.text.trim();
    if (_verificationId == null || smsCode.length != 6) {
      _showErr('Please enter the 6-digit code');
      return;
    }

    Navigator.pop(context); // Close OTP sheet
    setState(() => _loading = true);

    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: smsCode);
      await _authenticateWithCredential(cred);
    } catch (e) {
      setState(() => _loading = false);
      _showErr('Invalid OTP: $e');
    }
  }

  void _showOtpSheet() {
    _otpC.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
              Text('Enter the 6-digit code sent to $_completePhoneNumber',
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 24),
              TextField(
                controller: _otpC,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(
                    color: Colors.black, fontSize: 24, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  counterText: "",
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryBlue)),
                ),
              ),
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
                  onPressed: _verifyOtp,
                  child: const Text('Verify',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                  onPressed: _loading ? null : _startPhoneAuth,
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
                      : const Text('Continue',
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
                  'We\'ll send you a one-time code via SMS or WhatsApp (if SMS fails) to verify your number. Message and data rates may apply. By clicking "Continue," you agree to our Terms and conditions',
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
