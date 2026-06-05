import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'main_shell.dart';
import 'services/auth_service.dart';
import 'features/profile/distance_preference_setup_screen.dart';
import 'features/auth/registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Test buildu'),
          content: const Text('🎉 Funguje to! Úspěšně jsi sestavil a nasadil novou verzi z lokálního počítače.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Super!'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Vyplňte e-mail a heslo';
      });
      return;
    }

    AuthService().signInWithEmail(email, password).then((cred) async {
      final user = cred.user;
      if (user != null) {
        String name = user.email ?? '';
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data()?['username'] != null) {
            name = doc.data()?['username'] as String;
          }
        } catch (_) {}
        await AuthService().saveUserName(name);
        await AuthService().syncFirestoreToLocal();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(userName: name)));
      }
    }).catchError((e) {
      if (!mounted) return;
      String message = 'Přihlášení selhalo.';
      try {
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'user-not-found':
              message = 'Tento e-mail u nás není registrovaný.';
              break;
            case 'wrong-password':
              message = 'Zadané heslo není správné.';
              break;
            case 'invalid-email':
              message = 'Neplatný formát e-mailu.';
              break;
            case 'user-disabled':
              message = 'Účet byl zablokován.';
              break;
            default:
              message = 'Přihlášení selhalo: ${e.message ?? e.code}';
          }
        } else {
          message = e.toString();
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _onRegisterPressed() async {
    // Open comprehensive registration form
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistrationScreen()));
  }

  Future<void> _signInWithGoogle() async {
    try {
      final google = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await google.signIn();
      if (account == null) return; // user canceled
      final auth = await account.authentication;
      
      // Sign in to Firebase Auth!
      final cred = await AuthService().signInWithGoogle(auth.accessToken ?? '', auth.idToken);
      final user = cred.user;
      final name = user?.displayName ?? user?.email ?? 'Uživatel';

      await AuthService().saveUserName(name);
      await AuthService().saveAuthCredentials('google', {
        'accessToken': auth.accessToken,
        'idToken': auth.idToken,
        'email': account.email,
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(userName: name)));
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Přihlášení přes Google selhalo')));
    }
  }

  Future<void> _signInWithApple() async {
    try {
      // Only available on iOS/macOS; guard for other platforms
      if (!Platform.isIOS && !Platform.isMacOS) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apple Sign In není dostupné na tomto zařízení')));
        return;
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      // Sign in to Firebase Auth!
      final cred = await AuthService().signInWithApple(credential.identityToken ?? '', null);
      final user = cred.user;

      final name = ([credential.givenName, credential.familyName].where((s) => s != null).join(' ').trim()).isEmpty
          ? (user?.email ?? 'Apple User')
          : '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();

      await AuthService().saveUserName(name);
      await AuthService().saveAuthCredentials('apple', {
        'identityToken': credential.identityToken,
        'authorizationCode': credential.authorizationCode,
        'email': credential.email,
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(userName: name)));
    } catch (e) {
      debugPrint('Apple sign-in failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Přihlášení přes Apple selhalo')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Text(
                'Hejbej se',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.lightBlue,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 60),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) {
                  if (_errorText != null) {
                    setState(() {
                      _errorText = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Heslo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              // Email/password sign-in button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onLoginPressed,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.lime),
                    foregroundColor: WidgetStateProperty.all(Colors.black),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  child: const Text(
                    'Přihlásit se',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Social login buttons next to each other as rounded squares
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(
                    child: const Text(
                      'G',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    onTap: _showSocialLoginNotice,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    child: const Icon(
                      Icons.apple,
                      size: 28,
                      color: Colors.black,
                    ),
                    onTap: _showSocialLoginNotice,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    child: Icon(
                      Icons.facebook,
                      size: 28,
                      color: Colors.blue.shade800,
                    ),
                    onTap: _showSocialLoginNotice,
                  ),
                ],
              ),
              const Spacer(),
              // Flat borderless register button at the bottom
              TextButton(
                onPressed: _onRegisterPressed,
                child: const Text(
                  'Registrovat se',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.lightBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showSocialLoginNotice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Přihlášení'),
        content: const Text(
          'Tato možnost přihlášení bude brzy dostupná. Nyní prosím použijte přihlášení přes E-mail a Heslo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Rozumím'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}