import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../main_shell.dart';
import '../../services/auth_service.dart';

class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({super.key});

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nickname = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nickname.dispose();
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  String _generateSuffix() {
    final rnd = Random();
    return (1000 + rnd.nextInt(9000)).toString(); // 4-digit
  }

  Future<void> _saveProfile({required bool skipOptional}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uživatel není přihlášen')));
      }
      setState(() => _isSaving = false);
      return;
    }

    final suffix = _generateSuffix();
    final nicknameWithSuffix = '${_nickname.text.trim()}#${suffix}';

    final profileData = {
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'nickname': nicknameWithSuffix,
      'nickname_suffix': suffix,
      'age': int.tryParse(_age.text) ?? null,
      'weight': skipOptional ? null : (double.tryParse(_weight.text) ?? null),
      'height': skipOptional ? null : (double.tryParse(_height.text) ?? null),
      'updated_at': FieldValue.serverTimestamp(),
    };

    try {
      await AuthService().saveProfile(user.uid, profileData);
      await AuthService().saveUserName(profileData['nickname'] as String);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(userName: profileData['nickname'] as String)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uložení profilu selhalo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vytvoření profilu')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 8),
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
                  controller: _nickname,
                  decoration: const InputDecoration(labelText: 'Přezdívka ve hře'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplňte přezdívku' : null,
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
                  controller: _weight,
                  decoration: const InputDecoration(labelText: 'Váha (volitelné)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _height,
                  decoration: const InputDecoration(labelText: 'Výška (volitelné)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                if (_isSaving) const Center(child: CircularProgressIndicator()),
                if (!_isSaving) ...[
                  ElevatedButton(
                    onPressed: () => _saveProfile(skipOptional: false),
                    child: const Text('Uložit a pokračovat'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _saveProfile(skipOptional: true),
                    child: const Text('Přeskočit / Skip'),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
