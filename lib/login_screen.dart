import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'main_shell.dart';
import 'services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = 'Zadejte jméno hrdiny';
      });
      return;
    }
    // Persist username securely so login persists across restarts
    AuthService().saveUserName(name).then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainShell(userName: name),
        ),
      );
    });
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
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Jméno hrdiny',
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  if (_errorText != null) {
                    setState(() {
                      _errorText = null;
                    });
                  }
                },
                onSubmitted: (_) => _onLoginPressed(),
              ),
              const SizedBox(height: 32),
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
            ],
          ),
        ),
      ),
    );
  }
}