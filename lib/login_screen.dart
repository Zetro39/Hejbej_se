import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        await AuthService().saveUserName(user.email ?? '');
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(userName: user.email ?? '')));
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
      final name = account.displayName ?? account.email;
      await AuthService().saveUserName(name ?? '');
      await AuthService().saveAuthCredentials('google', {
        'accessToken': auth.accessToken,
        'idToken': auth.idToken,
        'email': account.email,
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(userName: name ?? '')));
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

      final name = ([credential.givenName, credential.familyName].where((s) => s != null).join(' ').trim()).isEmpty
          ? (credential.email ?? 'Apple User')
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
              // Email/password sign-in button moved above social
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
              const SizedBox(height: 12),
              // Social login buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                        onPressed: _signInWithGoogle,
                      icon: const Icon(Icons.login, color: Colors.black),
                      label: const Text('Přihlásit se přes Google'),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.white),
                        foregroundColor: WidgetStateProperty.all(Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (Platform.isIOS)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: SignInWithAppleButton(
                    onPressed: _signInWithApple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              if (Platform.isIOS) const SizedBox(height: 12),
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
                    'VSTOUPIT DO HRY',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _onRegisterPressed,
                  child: const Text('Registrovat se'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}