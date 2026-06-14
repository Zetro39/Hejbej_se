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
  String? _premiumTier;
  String? _premiumShippingAddress;
  late AnimationController _sweepController;


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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _donationController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  int _getCompanionCost(String id) {
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
      final tier = prefs.getString('premiumTier');
      final address = prefs.getString('premiumShippingAddress');
      final unlockedLocally = prefs.getStringList('unlocked_companions') ?? [];
      final activeLocally = prefs.getString('selected_companion');

      if (mounted) {
        setState(() {
          _limetkyBalance = balance;
          _unlockedCompanions = unlockedLocally;
          _selectedCompanion = activeLocally;
          _isPremium = isPrem;
          _premiumTier = tier;
          _premiumShippingAddress = address;
        });
      }
    } catch (e) {
      debugPrint('Local prefs load failed: $e');
    }

    // Load from Firestore in background
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final isPremDb = data['isPremium'] as bool? ?? false;
          final tierDb = data['premiumTier'] as String?;
          final addressDb = data['premiumShippingAddress'] as String?;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isPremium', isPremDb);
          if (tierDb != null) {
            await prefs.setString('premiumTier', tierDb);
          } else {
            await prefs.remove('premiumTier');
          }
          if (addressDb != null) {
            await prefs.setString('premiumShippingAddress', addressDb);
          } else {
            await prefs.remove('premiumShippingAddress');
          }
          if (mounted) {
            setState(() {
              _isPremium = isPremDb;
              _premiumTier = tierDb;
              _premiumShippingAddress = addressDb;
            });
          }
        }
      } catch (e) {
        debugPrint('Firebase load premium data failed: $e');
      }
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

  // Simulated checkout bottom sheet for Premium Subscription
  void _openSimulatedPaymentSheet(double price, String tierName) {
    if (price == 500.0) {
      final addressController = TextEditingController();
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E272C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Zadejte doručovací adresu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pro zasílání měsíčního dárku s logem HEJBEJ potřebujeme vaši doručovací adresu v ČR.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Doručovací adresa (ulice, č.p., město, PSČ)',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBFFF00))),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zrušit', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  final addr = addressController.text.trim();
                  if (addr.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Zadejte prosím platnou adresu.')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _launchSimulatedPayment(price, tierName, shippingAddress: addr);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFFF00), foregroundColor: Colors.black),
                child: const Text('Pokračovat k platbě'),
              ),
            ],
          );
        },
      );
    } else {
      _launchSimulatedPayment(price, tierName);
    }
  }

  void _launchSimulatedPayment(double price, String tierName, {String? shippingAddress}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SimulatedPaymentSheet(
          amount: price.toStringAsFixed(2),
          title: 'Podpora Hejbej se ($tierName)',
          onSuccess: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isPremium', true);
            await prefs.setString('premiumTier', tierName);
            await prefs.setBool('ever_owned_premium', true);
            if (prefs.getString('premium_start_time') == null) {
              await prefs.setString('premium_start_time', DateTime.now().toIso8601String());
            }
            if (shippingAddress != null) {
              await prefs.setString('premiumShippingAddress', shippingAddress);
            }

            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'isPremium': true,
                  'premiumTier': tierName,
                  'ever_owned_premium': true,
                  'premium_start_time': DateTime.now().toIso8601String(),
                  if (shippingAddress != null) 'premiumShippingAddress': shippingAddress,
                });
              } catch (e) {
                debugPrint('Firebase isPremium sync failed: $e');
              }
            }

            setState(() {
              _isPremium = true;
              _premiumTier = tierName;
              _premiumShippingAddress = shippingAddress;
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

        const SizedBox(height: 16),
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
        const SizedBox(height: 180),
      ],
    );
  }

  Widget _buildPremiumTierCard({
    required String title,
    required String priceText,
    required double price,
    required String badge,
    required IconData icon,
    required List<String> benefits,
    required Color accentColor,
    required String tierName,
  }) {
    final bool isActive = _isPremium && _premiumTier == tierName;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: isActive
            ? SweepGradient(
                colors: [
                  accentColor,
                  accentColor.withOpacity(0.3),
                  accentColor,
                ],
                transform: GradientRotation(_sweepController.value * math.pi * 2),
              )
            : null,
        color: isActive ? null : Colors.transparent,
      ),
      child: Card(
        color: const Color(0xFF1E272C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isActive ? 8 : 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                priceText,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              ...benefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: accentColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            b,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isActive ? null : () => _openSimulatedPaymentSheet(price, tierName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.transparent : accentColor,
                  foregroundColor: isActive ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isActive ? BorderSide(color: accentColor, width: 1.5) : BorderSide.none,
                  ),
                ),
                child: Text(
                  isActive ? 'Aktivní podpora 💖' : 'Podpořit – $priceText',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              if (isActive && tierName == '500' && _premiumShippingAddress != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Doručovací adresa: $_premiumShippingAddress',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
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
          'Vývoj a provoz mapových a serverových služeb stojí nemalé finance. Podporou pomáháte přežití celého projektu!',
          style: TextStyle(fontSize: 13, color: textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Info warning block
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade900.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade800, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upozornění pro dárce 💖',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Členství je zamýšleno jako dobrovolný příspěvek a podpora na provoz a další vývoj mapových služeb. Zakoupením získáte grafické zvýraznění a VIP odznaky mezi přáteli a v žebříčcích.',
                      style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4 Tiers of support
        _buildPremiumTierCard(
          title: 'Podporovatel',
          priceText: '25 Kč / měsíc',
          price: 25.0,
          badge: '🌟 VIP',
          icon: Icons.star_rounded,
          benefits: [
            'Zlatá ikona a VIP odznak v žebříčku',
            'Grafické zvýraznění jména pro všechny přátele',
            'Generování až 10 AI okruhů v okolí (standardně 5)',
          ],
          accentColor: const Color(0xFFBFFF00),
          tierName: '25',
        ),
        _buildPremiumTierCard(
          title: 'Super Podporovatel',
          priceText: '50 Kč / měsíc',
          price: 50.0,
          badge: '⭐ Super VIP',
          icon: Icons.stars_rounded,
          benefits: [
            'Výraznější VIP odznak v profilech a žebříčku',
            'Vaše jméno svítí zlatě v seznamu přátel',
            'Možnost přednostně testovat chystané novinky',
          ],
          accentColor: Colors.amberAccent,
          tierName: '50',
        ),
        _buildPremiumTierCard(
          title: 'Patron projektu',
          priceText: '100 Kč / měsíc',
          price: 100.0,
          badge: '🎖️ Patron',
          icon: Icons.workspace_premium_rounded,
          benefits: [
            'Speciální zlatý rámeček u vašeho jména',
            'Přednostní technická podpora od vývojářů',
            'Zobrazení v seznamu hlavních přátel projektu',
          ],
          accentColor: Colors.cyanAccent,
          tierName: '100',
        ),
        _buildPremiumTierCard(
          title: 'HEJBEJ Srdcař',
          priceText: '500 Kč / měsíc',
          price: 500.0,
          badge: '💎 Srdcař',
          icon: Icons.diamond_rounded,
          benefits: [
            'Unikátní diamantová ikona u vašeho profilu',
            'Každý měsíc fyzický dárek s logem HEJBEJ (tričko, lahev, nálepky atd.)',
            'Doručováno bezplatně na vaši adresu v ČR',
          ],
          accentColor: Colors.pinkAccent,
          tierName: '500',
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
                if (_paymentReady && (_applePayConfig != null || _googlePayConfig != null)) ...[
                  if (_applePayAvailable && _applePayConfig != null)
                    ApplePayButton(
                      paymentConfiguration: _applePayConfig!,
                      paymentItems: _paymentItems,
                      style: ApplePayButtonStyle.black,
                      width: double.infinity,
                      height: 50,
                      type: ApplePayButtonType.donate,
                      onPaymentResult: _onApplePayResult,
                    )
                  else if (_googlePayConfig != null)
                    GooglePayButton(
                      paymentConfiguration: _googlePayConfig!,
                      paymentItems: _paymentItems,
                      type: GooglePayButtonType.donate,
                      width: double.infinity,
                      height: 50,
                      onPaymentResult: _onGooglePayResult,
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Platební brána není momentálně k dispozici.',
                          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
                        ),
                      ),
                    ),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Platební brána se připravuje...',
                        style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 180),
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
