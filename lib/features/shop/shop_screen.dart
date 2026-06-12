import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pay/pay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

/// Modul Obchod – Podpora a Limetkový obchod se společníky.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
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
  bool _loadingLimetky = true;
  int _pendingLimetkyPurchaseAmount = 0;
  double _pendingLimetkyPurchasePrice = 0.0;

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
      'cost': 100,
      'description': 'Mystický a věrný vlk, který tě bude následovat kamkoliv.',
    },
    {
      'id': 'deer',
      'name': 'Jelen',
      'image': 'assets/images/deer.png',
      'cost': 100,
      'description': 'Ušlechtilý jelen, symbol našich lesů, ideální pro dlouhé pochody.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializePayClient();
    _loadLimetkyAndCompanions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _donationController.dispose();
    super.dispose();
  }

  Future<void> _loadLimetkyAndCompanions() async {
    setState(() => _loadingLimetky = true);
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getInt('limetkyBalance') ?? 0;

    final unlocked = await AuthService().getUnlockedCompanions();
    final active = await AuthService().getSelectedCompanion();

    if (!mounted) return;
    setState(() {
      _limetkyBalance = balance;
      _unlockedCompanions = unlocked;
      _selectedCompanion = active;
      _loadingLimetky = false;
    });
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
    final cost = companion['cost'] as int;
    final name = companion['name'] as String;

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
            backgroundColor: Colors.lightBlue,
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
            backgroundColor: Colors.lime.shade900,
          ),
        );
      }
    } else {
      // Try to unlock
      if (_limetkyBalance < cost) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nedostatek Limetek 🍋'),
            content: Text('K odemčení společníka $name potřebuješ $cost Limetek. Nyní máš $_limetkyBalance Limetek.\n\nChyť se do pohybu, získávej kilometry a splň denní výzvy pro nasbírání dalších!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Rozumím'),
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
          title: Text('Odemknout společníka $name?'),
          content: Text('Opravdu si přeješ utratit $cost Limetek a odemknout společníka $name na mapu?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušit'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.lime.shade900),
              child: const Text('Odemknout'),
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
              title: const Text('🎉 Společník zakoupen!'),
              content: Text('Úspěšně jsi odemkl společníka $name. Nyní ho můžeš aktivovat jedním klepnutím.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Super!'),
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
      selectedColor: Colors.lightBlue.shade100,
      onSelected: (_) {
        setState(() {
          _selectedAmount = amount;
          _donationController.text = amount;
        });
      },
    );
  }

  void _onPaymentResult(Map<String, dynamic> result) {
    try {
      if (result.isEmpty) {
        throw Exception('Prázdná odpověď platební brány');
      }
      final hasToken = result.containsKey('token') || (result['paymentMethodData'] != null);
      if (!hasToken) {
        throw Exception('Neplatný platební token');
      }

      if (_pendingLimetkyPurchaseAmount > 0) {
        final amount = _pendingLimetkyPurchaseAmount;
        _pendingLimetkyPurchaseAmount = 0; // reset
        
        AuthService().addLimetky(amount).then((_) {
          _loadLimetkyAndCompanions();
        });

        Navigator.of(context).pop(); // Close the purchase dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nákup úspěšný! Bylo připsáno $amount Limetek 🍋'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Děkujeme za podporu! Vaší pomocí vylepšujeme aplikaci.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _pendingLimetkyPurchaseAmount = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Platba se nepodařila: $e'),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obchod'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.pets), text: 'Společníci'),
            Tab(icon: Icon(Icons.favorite), text: 'Podpora vývoje'),
          ],
        ),
      ),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: Companions (Limetkový Obchod)
            _buildLimetkyShop(),

            // TAB 2: Donation and Subscriptions
            _buildDonationShop(),
          ],
        ),
      ),
    );
  }

  Widget _buildLimetkyShop() {
    return _loadingLimetky
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadLimetkyAndCompanions,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Balance Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.lime.shade500, Colors.lightBlue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.lightBlue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tvoje peněženka',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Herní obchod',
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text(
                              '🍋',
                              style: TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_limetkyBalance',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Kup si doprovod na mapu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Zvířecí společník bude běhat po mapě hned vedle tvého hrdiny a doprovázet tě.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  // Companions Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.70,
                    ),
                    itemCount: _companions.length,
                    itemBuilder: (context, index) {
                      final comp = _companions[index];
                      final id = comp['id'] as String;
                      final isUnlocked = _unlockedCompanions.contains(id);
                      final isActive = _selectedCompanion == id;

                      return Card(
                        elevation: isActive ? 6 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isActive
                                ? Colors.lime.shade500
                                : (isUnlocked ? Colors.lightBlue.shade200 : Colors.transparent),
                            width: isActive ? 3 : 1,
                          ),
                        ),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Thumbnail with platform
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.lime.shade50.withOpacity(0.5)
                                      : Colors.grey.shade50,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 3D platform graphics shadow
                                    Positioned(
                                      bottom: 12,
                                      child: Container(
                                        width: 70,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.08),
                                          borderRadius: const BorderRadius.all(Radius.elliptical(70, 12)),
                                        ),
                                      ),
                                    ),
                                    // 3D image
                                    Image.asset(
                                      comp['image'] as String,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.contain,
                                    ),
                                    if (isActive)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.lime.shade500,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check, color: Colors.black, size: 16),
                                        ),
                                      )
                                    else if (!isUnlocked)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.4),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.lock, color: Colors.white, size: 14),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            // Details
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comp['name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comp['description'] as String,
                                    style: const TextStyle(color: Colors.black54, fontSize: 10),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  // Button/Cost
                                  SizedBox(
                                    width: double.infinity,
                                    height: 36,
                                    child: ElevatedButton(
                                      onPressed: () => _handleCompanionAction(comp),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isActive
                                            ? Colors.grey.shade200
                                            : (isUnlocked ? Colors.lightBlue : Colors.lime.shade400),
                                        foregroundColor: isActive ? Colors.black87 : Colors.black,
                                        elevation: 1,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: isActive
                                          ? const Text('Poslat domů', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                                          : (isUnlocked
                                              ? const Text('Aktivovat', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Text('Koupit ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    Text('${comp['cost']} 🍋', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                                                  ],
                                                )),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 40),
                  const Text(
                    'Koupit Limetky 🍋',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nemáš dostatek Limetek z výletů? Kup si je pohodlně a podpoř tím vývoj aplikace.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _buildLimetkyPackageCard(10, 100.0),
                      _buildLimetkyPackageCard(25, 250.0),
                      _buildLimetkyPackageCard(50, 500.0),
                      _buildLimetkyPackageCard(100, 1000.0),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
  }

  Widget _buildLimetkyPackageCard(int amount, double price) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.lime.shade50.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPurchaseDialog(amount, price),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🍋 $amount',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.lime),
              ),
              const SizedBox(height: 4),
              Text(
                '${price.toInt()} Kč',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              const Text(
                '1 ks = 10 Kč',
                style: TextStyle(fontSize: 10, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPurchaseDialog(int amount, double price) {
    setState(() {
      _pendingLimetkyPurchaseAmount = amount;
      _pendingLimetkyPurchasePrice = price;
    });

    final priceStr = price.toStringAsFixed(2);
    final pItems = [
      PaymentItem(
        label: 'Nákup $amount Limetek 🍋',
        amount: priceStr,
        status: PaymentItemStatus.final_price,
      )
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Koupit $amount Limetek?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cena: ${price.toInt()} Kč',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.lime),
              ),
              const SizedBox(height: 8),
              const Text(
                'Limetky ti budou připsány na tvůj účet hned po dokončení platby.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              if (!_paymentReady)
                const CircularProgressIndicator()
              else if (_applePayAvailable && _applePayConfig != null)
                ApplePayButton(
                  paymentConfiguration: _applePayConfig!,
                  paymentItems: pItems,
                  style: ApplePayButtonStyle.black,
                  type: ApplePayButtonType.buy,
                  onPaymentResult: _onPaymentResult,
                  loadingIndicator: const Center(child: CircularProgressIndicator()),
                  width: double.infinity,
                  height: 48,
                )
              else if (_googlePayConfig != null)
                GooglePayButton(
                  paymentConfiguration: _googlePayConfig!,
                  paymentItems: pItems,
                  type: GooglePayButtonType.buy,
                  onPaymentResult: _onPaymentResult,
                  loadingIndicator: const Center(child: CircularProgressIndicator()),
                  width: double.infinity,
                  height: 48,
                )
              else
                const Text('Platby přes Google/Apple Pay nejsou na tomto zařízení dostupné.'),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _onPaymentResult({'token': 'debug_simulated_token'});
                  },
                  child: const Text('Simulovat úspěšnou platbu (Debug)', style: TextStyle(color: Colors.grey)),
                ),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _pendingLimetkyPurchaseAmount = 0;
                  _pendingLimetkyPurchasePrice = 0.0;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Zrušit'),
            )
          ],
        );
      },
    );
  }

  Widget _buildDonationShop() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Podpoř vývoj Hejbej se',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.lightBlue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vývoj a provoz mapových služeb stojí nemalé finance. Podporou získáš exkluzivní výhody!',
            style: TextStyle(fontSize: 13, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Premium Card
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade900, Colors.black87],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
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
                    '25 Kč (1 €) / měsíčně',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFFBFFF00), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Exkluzivní VIP hry na controlech',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFFBFFF00), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Možnost zapnout denní a noční styling mapy',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFFBFFF00), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bezplatný vstup do všech placených kontrolních bodů',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Prémiové členství bude brzy aktivní na TestFlight!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFFF00),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Předplatit – 25 Kč / měsíc',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Support Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Jednorázový dar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Zadej nebo zvol částku, kterou chceš přispět.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAmountChip(context, '20'),
                      _buildAmountChip(context, '50'),
                      _buildAmountChip(context, '100'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _donationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Vlastní částka (Kč)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!_paymentReady)
                    const Center(child: CircularProgressIndicator())
                  else if (_applePayAvailable && _applePayConfig != null)
                    ApplePayButton(
                      paymentConfiguration: _applePayConfig!,
                      paymentItems: _paymentItems,
                      style: ApplePayButtonStyle.black,
                      type: ApplePayButtonType.buy,
                      onPaymentResult: _onPaymentResult,
                      loadingIndicator: const Center(child: CircularProgressIndicator()),
                      width: double.infinity,
                      height: 48,
                    )
                  else if (_googlePayConfig != null)
                    GooglePayButton(
                      paymentConfiguration: _googlePayConfig!,
                      paymentItems: _paymentItems,
                      type: GooglePayButtonType.donate,
                      onPaymentResult: _onPaymentResult,
                      loadingIndicator: const Center(child: CircularProgressIndicator()),
                      width: double.infinity,
                      height: 48,
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Platby nejsou na tomto zařízení dostupné.'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Darovat',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Dotazy a nápady posílej na: dlouhy.m7@seznam.cz\nDěkujeme za vaši podporu! ❤️',
              style: TextStyle(fontSize: 12, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
