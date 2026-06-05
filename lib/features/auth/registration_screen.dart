import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../profile/profile_creation_screen.dart';
import '../auth/email_verification_waiting.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _username = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _age.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<bool> _isUsernameTaken(String username) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final username = _username.text.trim();
      if (await _isUsernameTaken(username)) {
        setState(() {
          _error = 'Tato přezdívka už je obsazena.';
          _isSubmitting = false;
        });
        return;
      }

      final email = _email.text.trim();
      final password = _password.text;
      final cred = await AuthService().registerWithEmail(email, password);
      final user = cred.user;
      if (user == null) throw Exception('Registrace selhala');

      // Save profile basics
      final profile = {
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'username': username,
        'age': int.tryParse(_age.text) ?? null,
        'friend_code': '#${username.toUpperCase()}${(100 + DateTime.now().millisecondsSinceEpoch % 900)}',
        'updated_at': FieldValue.serverTimestamp(),
      };
      await AuthService().saveProfile(user.uid, profile);
      await AuthService().saveUserName(username);

      // Go directly to MainShell
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(userName: username)));
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == 'weak-password'
            ? 'Heslo je příliš krátké.'
            : e.code == 'email-already-in-use'
                ? 'Tento e-mail je již registrován.'
                : (e.message ?? e.code);
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrovat se')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplňte e-mail' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Heslo'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Heslo musí mít alespoň 6 znaků' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  decoration: const InputDecoration(labelText: 'Potvrdit heslo'),
                  obscureText: true,
                  validator: (v) => v != _password.text ? 'Hesla se neshodují' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'Jméno'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplňte jméno' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Příjmení'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplňte příjmení' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _age,
                  decoration: const InputDecoration(labelText: 'Věk'),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplňte věk' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Přezdívka'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplňte přezdívku' : null,
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                if (_isSubmitting) const Center(child: CircularProgressIndicator()),
                if (!_isSubmitting)
                  ElevatedButton(onPressed: _submit, child: const Text('Registrovat se')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
