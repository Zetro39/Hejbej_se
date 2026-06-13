import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../profile/distance_preference_setup_screen.dart';
import '../../widgets/app_logo.dart';

class EmailVerificationWaiting extends StatefulWidget {
  final User user;
  const EmailVerificationWaiting({super.key, required this.user});

  @override
  State<EmailVerificationWaiting> createState() => _EmailVerificationWaitingState();
}

class _EmailVerificationWaitingState extends State<EmailVerificationWaiting> with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _canResend = true;
  int _cooldown = 0;
  bool _verified = false;
  late AnimationController _envelopePulseController;

  @override
  void initState() {
    super.initState();
    _envelopePulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _startListening();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _envelopePulseController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Odeslán potvrzovací e-mail'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba při odesílání: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DistancePreferenceSetupScreen()));
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header logo
                    const Center(child: AppLogo(size: 80)),
                    const SizedBox(height: 32),

                    // Main card container
                    Card(
                      color: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
                        child: Column(
                          children: [
                            // Pulsing envelope icon
                            ScaleTransition(
                              scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                                CurvedAnimation(parent: _envelopePulseController, curve: Curves.easeInOut),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFBFFF00).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 64,
                                  color: Color(0xFF5C9E00),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Ověření e-mailu',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.black,
                                color: Color(0xFF263238),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Odeslali jsme potvrzovací odkaz na tvůj e-mail. Klikni na něj a my tě automaticky pustíme dál.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.black54,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5C9E00)),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Čekám na kliknutí na odkaz...',
                                  style: TextStyle(fontSize: 12.5, color: Colors.black45, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Actions
                    ElevatedButton(
                      onPressed: _canResend ? _resend : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFFF00),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _canResend ? 'POSLAT ZNOVU' : 'ZNOVU ZA $_cooldown s',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (!mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF263238),
                        side: const BorderSide(color: Color(0xFF263238), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ODHLÁSIT SE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
