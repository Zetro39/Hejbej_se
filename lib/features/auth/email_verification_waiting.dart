import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../profile/distance_preference_setup_screen.dart';

class EmailVerificationWaiting extends StatefulWidget {
  final User user;
  const EmailVerificationWaiting({super.key, required this.user});

  @override
  State<EmailVerificationWaiting> createState() => _EmailVerificationWaitingState();
}

class _EmailVerificationWaitingState extends State<EmailVerificationWaiting> {
  Timer? _timer;
  bool _canResend = true;
  int _cooldown = 0;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startListening() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        await widget.user.reload();
        final u = FirebaseAuth.instance.currentUser;
        if (u != null && u.emailVerified) {
          _timer?.cancel();
          if (!mounted) return;
          setState(() {
            _verified = true;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    try {
      await widget.user.sendEmailVerification();
      setState(() {
        _canResend = false;
        _cooldown = 30;
      });
      Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          if (_cooldown > 0) _cooldown--;
          if (_cooldown == 0) {
            _canResend = true;
            t.cancel();
          }
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Odeslán potvrzovací e-mail')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba při odesílání: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) {
      // proceed to app entrypoint; pop until root so MainShell can pick up verified state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DistancePreferenceSetupScreen()));
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mail_outline, size: 72, color: Colors.lightBlue),
              const SizedBox(height: 16),
              const Text('Potvrďte svůj e-mail', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Otevřete prosím e-mail a klikněte na ověřovací odkaz. Dokud není e-mail ověřený, nebudete moci vstoupit do aplikace.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _canResend ? _resend : null,
                child: Text(_canResend ? 'Poslat znovu' : 'Znovu za $_cooldown s'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
                },
                child: const Text('Odhlásit se'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
