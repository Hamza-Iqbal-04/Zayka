import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'bottom_nav.dart';
import '../main.dart';
import 'models.dart';

String _docIdFor(User user) => user.email!.toLowerCase();

// ───────────────────────── AUTH SERVICE (logic only) ─────────────────────────
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<UserCredential> signIn(String email, String password) =>
      _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUp(
      String email, String password, String name, String phone) async {
    final cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email, password: password);

    await cred.user!.updateDisplayName(name);

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(_docIdFor(cred.user!))
        .set({'name': name, 'email': email, 'phone': phone},
        SetOptions(merge: true));

    return cred;
  }

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

  Future<UserCredential> signInWithOtp(
      String verificationId, String smsCode) =>
      _firebaseAuth.signInWithCredential(PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: smsCode));

  Future<UserCredential> signInWithCredential(
      PhoneAuthCredential credential) =>
      _firebaseAuth.signInWithCredential(credential);

  /// Google sign-in (no UI)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await GoogleSignIn().signOut(); // force account picker
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
      await _firebaseAuth.signInWithCredential(credential);
      final user = userCred.user!;
      final docId = _docIdFor(user);

      // Create blank profile first time
      if (userCred.additionalUserInfo?.isNewUser ?? false) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(docId)
            .set({
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

// ───────────────────────── LOGIN / SIGN-UP SCREEN ───────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // controllers
  final _emailC = TextEditingController();
  final _passC  = TextEditingController();
  final _nameC  = TextEditingController();
  final _phoneC = TextEditingController();

  // services
  final _auth = AuthService();
  String? _verificationId;           // stores Firebase verificationId
  bool _otpSending = false;          // controls loader in the sheet


  // state
  bool _isLogin = true;
  bool _loading = false;

  // ───────── phone dialog (with country picker)
  Future<String?> _promptForPhone() {
    String? e164;
    final _formKey = GlobalKey<FormState>();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,                 // full-height when keyboard shows
      backgroundColor: Colors.transparent,      // so we can add our own radius
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.35,
        maxChildSize: 0.8,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(                    // use ListView so it scrolls
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Add phone number',
                  style: AppTextStyles.headline1.copyWith(fontSize: 20)),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: IntlPhoneField(
                  initialCountryCode: 'QAR',
                  decoration: InputDecoration(
                    hintText: 'Phone Number',
                    filled: true,
                    fillColor: AppColors.lightGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (p) => e164 = p.completeNumber,
                  validator: (p) =>
                  (p == null || p.number.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop(e164);
                    }
                  },
                  child: Text('Save',
                      style: AppTextStyles.buttonText.copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(ctx).pop(null),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }


  // ───────── Google button handler (UI layer)
  Future<void> _handleGoogle() async {
    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithGoogle();
      if (cred == null) throw Exception('Sign-in aborted');

      final user  = cred.user!;
      final docId = _docIdFor(user);

      // Read Firestore to see if phone exists
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(docId)
          .get();
      final hasPhone =
          (snap.data()?['phone'] as String?)?.isNotEmpty ?? false;

      if (!hasPhone) {
        final phone = await _promptForPhone();
        if (phone == null || phone.isEmpty) {
          await FirebaseAuth.instance.signOut();
          _showErr('Phone number required.');
          setState(() => _loading = false);
          return;
        }
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(docId)
            .set({'phone': phone}, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainApp()));
      }
    } catch (e) {
      _showErr(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ───────── show OTP sign in
  // Add this inside _LoginScreenState — complete, drop-in replacement
  void _showMobileSignInSheet(BuildContext context) {
    final phoneC = TextEditingController();
    final otpC   = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String? e164Phone;                  // phone in +974… format
    bool    localLoading = false;       // sheet-scoped spinner

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (_, controller) => StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Mobile OTP Login',
                      style:
                      AppTextStyles.headline1.copyWith(fontSize: 20)),
                  const SizedBox(height: 20),

                  // ───────── PHONE FIELD ─────────
                  Form(
                    key: formKey,
                    child: IntlPhoneField(
                      controller: phoneC,
                      initialCountryCode: 'QA',        // default Qatar
                      decoration: _fieldDeco('Phone Number'),
                      onChanged: (p) => e164Phone = p.completeNumber,
                      validator: (p) =>
                      (p == null || p.number.isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ───────── SEND / RESEND OTP ─────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: localLoading
                          ? null
                          : () async {
                        if (!formKey.currentState!.validate() ||
                            e164Phone == null) return;

                        setSheetState(() => localLoading = true);

                        await _auth.verifyPhoneNumber(
                          e164Phone!,
                          verificationCompleted:
                              (PhoneAuthCredential cred) async {
                            await _auth.signInWithCredential(cred);
                            if (mounted) Navigator.pop(context);
                          },
                          verificationFailed: (e) {
                            _showErr(e.message ?? 'SMS failed');
                            setSheetState(
                                    () => localLoading = false);
                          },
                          codeSent: (id, _) {
                            _verificationId = id;
                            _showErr('OTP sent');
                            setSheetState(
                                    () => localLoading = false);
                          },
                          codeAutoRetrievalTimeout: (id) =>
                          _verificationId = id,
                        );
                      },
                      child: localLoading
                          ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                          : const Text('Send OTP'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ───────── OTP INPUT ─────────
                  TextField(
                    controller: otpC,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: _fieldDeco('Enter 6-digit OTP')
                        .copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 16),

                  // ───────── VERIFY BUTTON ─────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: BorderSide(color: AppColors.primaryBlue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if ((_verificationId ?? '').isEmpty ||
                            otpC.text.trim().length != 6) {
                          _showErr('Enter phone & OTP first');
                          return;
                        }
                        try {
                          final cred = await _auth.signInWithOtp(
                              _verificationId!, otpC.text.trim());

                          // prompt for e-mail + name
                          final extra = await _promptForEmailAndName();
                          if (extra == null) return;

                          final email = extra['email']!;
                          final name  = extra['name']!;
                          final docId = email.toLowerCase();

                          await FirebaseFirestore.instance
                              .collection('Users')
                              .doc(docId)
                              .set({
                            'email': email,
                            'name' : name,
                            'phone': cred.user?.phoneNumber ?? '',
                          }, SetOptions(merge: true));

                          if (mounted) {
                            Navigator.pop(context); // close sheet
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MainApp()),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          _showErr(e.message ?? 'Invalid OTP');
                        }
                      },
                      child: const Text('Verify & Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  // bottom-sheet that matches _promptForPhone() styling
  Future<Map<String, String>?> _promptForEmailAndName() {
    final emailC = TextEditingController();
    final nameC  = TextEditingController();
    final key    = GlobalKey<FormState>();

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize:   0.45,
        maxChildSize:   0.85,
        builder: (_, controller) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom), // keyboard gap
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Complete your profile',
                    style: AppTextStyles.headline1.copyWith(fontSize: 20)),
                const SizedBox(height: 20),
                Form(
                  key: key,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: emailC,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _fieldDeco('Email'),
                        validator: (v) =>
                        (v == null || !v.contains('@'))
                            ? 'Valid e-mail required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameC,
                        decoration: _fieldDeco('Full Name'),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Name required'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (key.currentState!.validate()) {
                        Navigator.of(ctx).pop({
                          'email': emailC.text.trim(),
                          'name' : nameC.text.trim(),
                        });
                      }
                    },
                    child: Text('Save',
                        style: AppTextStyles.buttonText
                            .copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// same decoration helper used by _promptForPhone()
  InputDecoration _fieldDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.lightGrey,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  // ───────── Email / password auth
  Future<void> _authenticate() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await _auth.signIn(_emailC.text.trim(), _passC.text.trim());
      } else {
        if (_nameC.text.isEmpty || _phoneC.text.isEmpty) {
          throw Exception('Name and phone required.');
        }
        await _auth.signUp(_emailC.text.trim(), _passC.text.trim(),
            _nameC.text.trim(), _phoneC.text.trim());
      }
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainApp()));
      }
    } on FirebaseAuthException catch (e) {
      _showErr(e.message ?? 'Auth error');
    } catch (e) {
      _showErr(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ───────── error dialog helper
  void _showErr(String m) => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Error'),
      content: Text(m),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('OK')),
      ],
    ),
  );

  // ───────── UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, AppColors.primaryBlue, Colors.black87],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fastfood,
                      size: 60, color: AppColors.primaryBlue),
                  const SizedBox(height: 16),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: AppTextStyles.headline1
                        .copyWith(color: Colors.black87, fontSize: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please fill in the details to continue',
                    style: AppTextStyles.bodyText2
                        .copyWith(color: AppColors.darkGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // extra sign-up fields
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          _buildField(_nameC,  'Full Name',     Icons.person_outline),
                          _buildField(_phoneC, 'Phone Number',  Icons.phone_outlined,
                              keyType: TextInputType.phone),
                        ],
                      ],
                    ),
                  ),
                  _buildField(_emailC, 'Email Address', Icons.email_outlined,
                      keyType: TextInputType.emailAddress),
                  _buildField(_passC, 'Password', Icons.lock_outline,
                      obscure: true),
                  const SizedBox(height: 24),

                  // main button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                        shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                      ),
                      child: _loading
                          ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                          : Text(_isLogin ? 'Login' : 'Sign Up',
                          style: AppTextStyles.buttonText
                              .copyWith(color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR',
                            style: AppTextStyles.bodyText2
                                .copyWith(color: Colors.grey.shade600)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // google button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Image.asset('assets/google.png', height: 22),
                      label: const Text('Continue with Google'),
                      onPressed: _loading ? null : _handleGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGrey,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // mobile sheet trigger
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.phone_iphone_rounded,
                          color: AppColors.darkGrey, size: 22),
                      label: const Text('Sign in with Mobile'),
                      onPressed:
                      _loading ? null : () => _showMobileSignInSheet(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGrey,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // switch login/signup
                  TextButton(
                    onPressed:
                    _loading ? null : () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign Up"
                          : "Already have an account? Login",
                      style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // text-field builder
  Widget _buildField(TextEditingController c, String label, IconData icon,
      {bool obscure = false, TextInputType keyType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryBlue.withOpacity(0.7)),
          filled: true,
          fillColor: AppColors.lightGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        style: AppTextStyles.bodyText1.copyWith(color: AppColors.darkGrey),
      ),
    );
  }
}
