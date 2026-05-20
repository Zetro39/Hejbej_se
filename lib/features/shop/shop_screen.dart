import 'package:flutter/material.dart';
import 'package:pay/pay.dart';

/// Modul Obchod – Podpora vývoje.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Pay _payClient;
  PaymentConfiguration? _applePayConfig;
  PaymentConfiguration? _googlePayConfig;
  bool _paymentReady = false;
  bool _applePayAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializePayClient();
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

  List<PaymentItem> get _paymentItems => [
    const PaymentItem(
      label: 'Dar pro Hejbej se',
      amount: '50.00',
      status: PaymentItemStatus.final_price,
    ),
  ];

  void _onPaymentResult(Map<String, dynamic> result) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Děkujeme za podporu! Vaší pomocí vylepšujeme aplikaci.'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obchod'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Podpora vývoje',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Pomozte nám vylepšovat aplikaci! Výchozí dar: 50 CZK',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Vaše příspěvek nám pomůže s vývojem nových funkcí, vylepšením map a přidáním více tras v celé ČR.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
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
                                content: Text('Platbou není dostupná na tomto zařízení.'),
                              ),
                            );
                          },
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(const Color(0xFFBFFF00)),
                            foregroundColor: MaterialStateProperty.all(Colors.black),
                            padding: MaterialStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          child: const Text(
                            'Poslat dar (Apple Pay / Google Pay)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Další možnosti',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.star, color: Colors.amber, size: 32),
                      SizedBox(height: 12),
                      Text(
                        'Spropitné',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pokud se vám aplikace líbí, můžete nám poslat spropitné prostřednictvím Apple Pay nebo Google Pay.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.feedback, color: Colors.blue, size: 32),
                      SizedBox(height: 12),
                      Text(
                        'Feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Máte nápřezad na vylepšení? Pošlijte nám zprávu s vašimi nápady a my se je pokusíme implementovat.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Děkujeme za vaši podporu! ❤️',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.lightBlue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
