import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pay/pay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import '../../main_shell.dart';

/// Modul Obchod – Podpora a Limetkový obchod se společníky.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late Pay _payClient;
  PaymentConfiguration? _applePayConfig;
  PaymentConfiguration? _googlePayConfig;
  bool _paymentReady = false;
  bool _applePayAvailable = false;
  final TextEditingController _donationController = TextEditingController(text: '50');
  String _selectedAmount = '50';

  // State for Limetky Shop
  int _limetkyBalance = 0;
  List<String> _unlockedCompanions = [];
  String? _selectedCompanion;
  bool _loadingLimetky = false;
  int _pendingLimetkyPurchaseAmount = 0;
  double _pendingLimetkyPurchasePrice = 0.0;

  // Premium State
  bool _isPremium = false;
  late AnimationController _sweepController;

  Timer? _countdownTimer;
  String _countdownText = '';

  final List<Map<String, dynamic>> _companions = [
    {
      'id': 'bear',
      'name': 'Medvěd',
      'image': 'assets/images/bear.png',
      'cost': 50,
      'description': 'Silný lesní medvídek, který tě doprovodí na každé dobrodružství.',
    },
    {
      'id': 'fox',
      'name': 'Liška',
      'image': 'assets/images/fox.png',
      'cost': 50,
      'description': 'Rychlá a mazaná liška, která ti bude krýt záda na lesních stezkách.',
    },
    {
      'id': 'wolf',
      'name': 'Vlk',
      'image': 'assets/images/wolf.png',
      'cost': 80,
      'description': 'Bystrý a silný vlk, vhodný pro vytrvalé běžce.',
    },
    {
      'id': 'deer',
      'name': 'Jelen',
      'image': 'assets/images/deer.png',
      'cost': 100,
      'description': 'Vznešený strážce lesa, doprovázející jen ty nejzkušenější.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadLimetkyAndCompanions();
    _initializePayClient();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _donationController.dispose();
    _sweepController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateRemainingTime();
      }
    });
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    
    setState(() {
      _countdownText = '${hours}h:${minutes}m:${seconds}s';
    });
  }

  int _getCompanionCost(String id) {
    if (id == 'deer') {
      return 75; // Flash Sale discount
    }
    final comp = _companions.firstWhere((c) => c['id'] == id);
    return comp['cost'] as int;
  }

  Widget _buildInstructionItem(IconData icon, String title, String desc, Color textColor, Color textSecondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFBFFF00), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadLimetkyAndCompanions() async {
    // 1. Load from local cache instantly
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      final balance = prefs.getInt('limetkyBalance') ?? 0;
      final isPrem = prefs.getBool('isPremium') ?? false;
      final unlockedLocally = prefs.getStringList('unlocked_companions') ?? [];
      final activeLocally = prefs.getString('selected_companion');

      if (mounted) {
        setState(() {
          _limetkyBalance = balance;
          _unlockedCompanions = unlockedLocally;
          _selectedCompanion = activeLocally;
          _isPremium = isPrem;
        });
      }
    } catch (e) {
      debugPrint('Local prefs load failed: $e');
    }

    // 2. Fetch from the server in the background
    try {
      final unlocked = await AuthService().getUnlockedCompanions().timeout(
        const Duration(seconds: 4),
        onTimeout: () => _unlockedCompanions,
      );
      final active = await AuthService().getSelectedCompanion().timeout(
        const Duration(seconds: 4),
        onTimeout: () => _selectedCompanion,
      );

      // Save to local cache for next instant load
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('unlocked_companions', unlocked);
        if (active != null) {
          await prefs.setString('selected_companion', active);
        } else {
          await prefs.remove('selected_companion');
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _unlockedCompanions = unlocked;
        _selectedCompanion = active;
      });
    } catch (e) {
      debugPrint('Server companions load failed: $e');
    }
  }

  Future<void> _initializePayClient() async {
    try {
      final appleConfig = await PaymentConfiguration.fromAsset('assets/apple_pay_config.json');
      final googleConfig = await PaymentConfiguration.fromAsset('assets/google_pay_config.json');
      _payClient = Pay({
        PayProvider.apple_pay: appleConfig,
        PayProvider.google_pay: googleConfig,
      });
      final appleAvailable = await _payClient.userCanPay(PayProvider.apple_pay);
      if (!mounted) return;
      setState(() {
        _applePayConfig = appleConfig;
        _googlePayConfig = googleConfig;
        _applePayAvailable = appleAvailable;
        _paymentReady = true;
      });
    } catch (e) {
      debugPrint('Payment initialization failed: $e');
      if (!mounted) return;
      setState(() {
        _paymentReady = true;
      });
    }
  }

  Future<void> _handleCompanionAction(Map<String, dynamic> companion) async {
    final id = companion['id'] as String;
    final cost = _getCompanionCost(id);
    final name = companion['name'] as String;

    try {
      if (_unlockedCompanions.contains(id)) {
        // Toggle active status
        if (_selectedCompanion == id) {
          await AuthService().selectCompanion(null);
          setState(() {
            _selectedCompanion = null;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Společník $name byl poslán domů.'),
              backgroundColor: const Color(0xFF263238),
            ),
          );
        } else {
          await AuthService().selectCompanion(id);
          setState(() {
            _selectedCompanion = id;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Společník $name tě nyní doprovází na mapě!'),
              backgroundColor: const Color(0xFF5C9E00),
            ),
          );
        }
      } else {
        // Try to unlock
        if (_limetkyBalance < cost) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF263238),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Nedostatek Limetek 🍋', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Text(
                'K odemčení společníka $name potřebuješ $cost Limetek. Nyní máš $_limetkyBalance Limetek.\n\nChyť se do pohybu, získávej kilometry a splň denní výzvy pro nasbírání dalších!',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Rozumím', style: TextStyle(color: Color(0xFFBFFF00), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          return;
        }

        // Confirm purchase
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF263238),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Odemknout společníka $name?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              'Opravdu si přeješ utratit $cost Limetek a odemknout společníka $name na mapu?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Zrušit', style: TextStyle(color: Colors.white60)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFBFFF00)),
                child: const Text('Odemknout', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          setState(() => _loadingLimetky = true);
          final success = await AuthService().unlockCompanion(id, cost);
          if (success) {
            await _loadLimetkyAndCompanions();
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF263238),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('🎉 Společník zakoupen!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: Text('Úspěšně jsi odemkl společníka $name. Nyní ho můžeš aktivovat jedním klepnutím.', style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Super!', style: TextStyle(color: Color(0xFFBFFF00), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          } else {
            setState(() => _loadingLimetky = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chyba při komunikaci s databází.')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling companion action: $e');
      if (mounted) {
        setState(() => _loadingLimetky = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e')),
        );
      }
    }
  }

  String get _donationAmount {
    final typed = _donationController.text.replaceAll(',', '.').trim();
    final parsed = double.tryParse(typed);
    if (parsed != null && parsed > 0) {
      return parsed.toStringAsFixed(2);
    }
    final selected = double.tryParse(_selectedAmount) ?? 50.0;
    return selected.toStringAsFixed(2);
  }

  List<PaymentItem> get _paymentItems => [
        PaymentItem(
          label: 'Dar pro Hejbej se',
          amount: _donationAmount,
          status: PaymentItemStatus.final_price,
        ),
      ];

  Widget _buildAmountChip(BuildContext context, String amount) {
    final bool selected = _selectedAmount == amount;
    return ChoiceChip(
      label: Text('$amount Kč'),
      selected: selected,
      selectedColor: const Color(0xFFBFFF00).withOpacity(0.35),
      onSelected: (_) {
        setState(() {
          _selectedAmount = amount;
          _donationController.text = amount;
        });
      },
    );
  }

  void _onGooglePayResult(dynamic result) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Děkujeme za vaši podporu přes Google Pay!'), backgroundColor: Colors.green),
    );
  }

  void _onApplePayResult(dynamic result) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Děkujeme za vaši podporu přes Apple Pay!'), backgroundColor: Colors.green),
    );
  }

  // Simulated checkout bottom sheet for Premium Subscription
  void _openSimulatedPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SimulatedPaymentSheet(
          amount: '25.00',
          title: 'Členství Premium (Hejbej se)',
          onSuccess: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isPremium', true);

            // Sync with Firebase if available
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'isPremium': true,
                });
              } catch (e) {
                debugPrint('Firebase isPremium sync failed: $e');
              }
            }

            setState(() {
              _isPremium = true;
            });
            await _loadLimetkyAndCompanions();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: MainShell.themeNotifier,
      builder: (context, theme, child) {
        final isWhite = theme == 'white';
        final bgColor = isWhite ? const Color(0xFFF9FBFC) : const Color(0xFF263238);
        final cardColor = isWhite ? Colors.white : const Color(0xFF1E272C);
        final textColor = isWhite ? const Color(0xFF263238) : Colors.white;
        final textSecondary = isWhite ? Colors.black54 : Colors.white70;
        final borderColor = isWhite ? Colors.grey.shade200 : Colors.white12;
        final appBarBg = isWhite ? Colors.white : const Color(0xFF1E272C);
        final appBarFg = isWhite ? const Color(0xFF263238) : Colors.white;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              'Obchod',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: appBarFg),
            ),
            backgroundColor: appBarBg,
            foregroundColor: appBarFg,
            bottom: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFBFFF00),
              unselectedLabelColor: appBarFg.withOpacity(0.6),
              indicatorColor: const Color(0xFFBFFF00),
              tabs: const [
                Tab(text: 'Limetky & Companion', icon: Icon(Icons.pets_rounded, size: 20)),
                Tab(text: 'Podpora & Premium', icon: Icon(Icons.favorite_rounded, size: 20)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildLimetkyShopTab(cardColor, textColor, textSecondary, borderColor),
              _buildSupportTab(cardColor, textColor, textSecondary, borderColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLimetkyShopTab(Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    if (_loadingLimetky) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF5C9E00)));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Balance card with gradient
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFBFFF00), Color(0xFF5C9E00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5C9E00).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TVOJE BILANCE',
                    style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Limetkový měšec',
                    style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('🍋', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 8),
                  Text(
                    '$_limetkyBalance',
                    style: const TextStyle(color: Colors.black87, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Flash Sale Banner
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFFF5722)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BLESKOVÁ NABÍDKA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Jelen jen za 75 🍋 (běžně 100)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Končí za: $_countdownText',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final deer = _companions.firstWhere((c) => c['id'] == 'deer');
                  _handleCompanionAction(deer);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade800,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'ZÍSKAT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'LESNÍ SPOLEČNÍCI NA MAPU',
          style: TextStyle(fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.8, fontSize: 12),
        ),
        const SizedBox(height: 12),

        // Grid of companions
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _companions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.68,
          ),
          itemBuilder: (context, idx) {
            final companion = _companions[idx];
            final id = companion['id'] as String;
            final isUnlocked = _unlockedCompanions.contains(id);
            final isActive = _selectedCompanion == id;

            Color borderCardColor;
            List<BoxShadow> glowShadows = [];
            double opacity = 1.0;

            if (isActive) {
              borderCardColor = const Color(0xFFBFFF00);
              glowShadows = [
                BoxShadow(
                  color: const Color(0xFFBFFF00).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ];
            } else if (isUnlocked) {
              borderCardColor = const Color(0xFF5C9E00);
              glowShadows = [
                BoxShadow(
                  color: const Color(0xFF5C9E00).withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ];
            } else {
              borderCardColor = Colors.transparent;
              opacity = 0.65;
            }

            final cost = _getCompanionCost(id);

            return Opacity(
              opacity: opacity,
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: borderCardColor != Colors.transparent ? borderCardColor : borderColor,
                    width: 2.5,
                  ),
                  boxShadow: glowShadows,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  companion['id'] == 'bear' ? '🐻' : companion['id'] == 'fox' ? '🦊' : companion['id'] == 'wolf' ? '🐺' : '🦌',
                                  style: const TextStyle(fontSize: 48),
                                ),
                              ),
                            ),
                            Text(
                              companion['name'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              companion['description'] as String,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textSecondary, fontSize: 10),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _handleCompanionAction(companion),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isActive
                                    ? const Color(0xFF263238)
                                    : isUnlocked
                                        ? const Color(0xFF5C9E00)
                                        : const Color(0xFFBFFF00),
                                foregroundColor: isActive || isUnlocked ? Colors.white : Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 0,
                              ),
                              child: Text(
                                isActive
                                    ? 'Poslat domů'
                                    : isUnlocked
                                        ? 'Doprovázet'
                                        : 'Koupit: $cost 🍋',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isUnlocked)
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Instruction Box
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🍋 Jak získat limetky?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 16),
              _buildInstructionItem(
                Icons.directions_walk_rounded,
                'Plň denní cíle kroků',
                'Za každý splněný denní cíl získáš 5 limetek.',
                textColor,
                textSecondary,
              ),
              const SizedBox(height: 12),
              _buildInstructionItem(
                Icons.map_rounded,
                'Dokonči outdoor trasy',
                'Procházení a objevování nových tras ti přinese 10 limetek.',
                textColor,
                textSecondary,
              ),
              const SizedBox(height: 12),
              _buildInstructionItem(
                Icons.casino_outlined,
                'Roztoč Kolo štěstí',
                'Každý den máš jedno roztočení zdarma s možností vyhrát limetky.',
                textColor,
                textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportTab(Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Podpoř vývoj Hejbej se',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Vývoj a provoz mapových služeb stojí nemalé finance. Podporou získáš exkluzivní výhody!',
          style: TextStyle(fontSize: 13, color: textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Premium Card with Liquid neon outline Sweep effect when active
        AnimatedBuilder(
          animation: _sweepController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(2), // border width
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: _isPremium
                    ? SweepGradient(
                        colors: const [
                          Color(0xFFBFFF00),
                          Color(0xFF1B5E20),
                          Color(0xFFBFFF00),
                        ],
                        transform: GradientRotation(_sweepController.value * math.pi * 2),
                      )
                    : null,
                color: _isPremium ? null : Colors.transparent,
              ),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade900, Colors.black87],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Členství Premium',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFFF00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🌟 VIP',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '25 Kč / měsíčně',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFFBFFF00), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Možnost vygenerovat 10 okruhů trasy od AI (běžně 5)',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFFBFFF00), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Exkluzivní AR 3D směrová navigace na mapě',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFFBFFF00), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Zlaté ikony, zobrazení VIP a podpora vývoje map',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isPremium ? null : _openSimulatedPaymentSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPremium ? Colors.transparent : const Color(0xFFBFFF00),
                      foregroundColor: _isPremium ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: _isPremium ? const BorderSide(color: Color(0xFFBFFF00), width: 1.5) : BorderSide.none,
                      ),
                    ),
                    child: Text(
                      _isPremium ? 'Předplatné aktivní 🌟' : 'Předplatit – 25 Kč / měsíc',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
        Text(
          'Rychlý jednorázový dar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 12),

        Card(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAmountChip(context, '20'),
                    _buildAmountChip(context, '50'),
                    _buildAmountChip(context, '100'),
                    _buildAmountChip(context, '250'),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _donationController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Vlastní částka (Kč)',
                    labelStyle: TextStyle(color: textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    prefixIcon: Icon(Icons.edit_rounded, color: textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                if (_paymentReady) ...[
                  if (_applePayAvailable)
                    ApplePayButton(
                      paymentConfiguration: _applePayConfig!,
                      paymentItems: _paymentItems,
                      style: ApplePayButtonStyle.black,
                      width: double.infinity,
                      height: 50,
                      type: ApplePayButtonType.donate,
                      onPaymentResult: _onApplePayResult,
                    )
                  else
                    GooglePayButton(
                      paymentConfiguration: _googlePayConfig!,
                      paymentItems: _paymentItems,
                      type: GooglePayButtonType.donate,
                      width: double.infinity,
                      height: 50,
                      onPaymentResult: _onGooglePayResult,
                    ),
                ] else
                  const Center(child: CircularProgressIndicator(color: Color(0xFF5C9E00))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Simulated Google/Apple Pay modal bottom sheet
class _SimulatedPaymentSheet extends StatefulWidget {
  final String amount;
  final String title;
  final VoidCallback onSuccess;

  const _SimulatedPaymentSheet({
    required this.amount,
    required this.title,
    required this.onSuccess,
  });

  @override
  State<_SimulatedPaymentSheet> createState() => _SimulatedPaymentSheetState();
}

class _SimulatedPaymentSheetState extends State<_SimulatedPaymentSheet> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  bool _isHolding = false;
  String _payState = 'holding'; // 'holding', 'processing', 'success'

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1500),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    setState(() {
      _isHolding = true;
    });
    _progressController.forward(from: 0.0).then((_) {
      if (_isHolding) {
        _triggerPayment();
      }
    });
  }

  void _onHoldEnd() {
    if (_payState == 'holding') {
      setState(() {
        _isHolding = false;
      });
      _progressController.reverse();
    }
  }

  void _triggerPayment() {
    HapticFeedback.mediumImpact();
    setState(() {
      _payState = 'processing';
    });

    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _payState = 'success';
      });

      Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        widget.onSuccess();
        Navigator.pop(context);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E262C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.apple_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 4),
                  Text('Pay', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '${widget.amount} Kč',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Karta', style: TextStyle(color: Colors.white54, fontSize: 13)),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(4)),
                    child: const Text('MC', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  const Text('•••• 8821', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Předmět', style: TextStyle(color: Colors.white54, fontSize: 13)),
              Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),

          if (_payState == 'holding') ...[
            const Text(
              'Podržte prst na senzoru pro ověření FaceID / Otisk prstu',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onLongPressStart: (_) => _onHoldStart(),
                onLongPressEnd: (_) => _onHoldEnd(),
                onTapDown: (_) => _onHoldStart(),
                onTapUp: (_) => _onHoldEnd(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return CircularProgressIndicator(
                            value: _progressController.value,
                            color: const Color(0xFFBFFF00),
                            backgroundColor: Colors.white12,
                            strokeWidth: 3.5,
                          );
                        },
                      ),
                    ),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: _isHolding ? const Color(0xFFBFFF00) : Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: _isHolding ? Colors.black : Colors.white70,
                        size: 38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_payState == 'processing') ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFBFFF00)),
                  SizedBox(height: 16),
                  Text('Ověřuji transakci...', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ] else if (_payState == 'success') ...[
            const Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFFBFFF00), size: 68),
                  SizedBox(height: 16),
                  Text('Platba Úspěšná! 🎉', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
