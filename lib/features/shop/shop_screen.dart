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
  final TextEditingController _donationController = TextEditingController(text: '50');
  String _selectedAmount = '50';

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
    // Basic validation of the payment result so we can display clearer messages in Sandbox
    try {
      if (result.isEmpty) {
        throw Exception('Prázdná odpověď platební brány');
      }

      // Check for a token or paymentMethodData - structure differs between providers
      final hasToken = result.containsKey('token') || (result['paymentMethodData'] != null);
      if (!hasToken) {
        throw Exception('Neplatný platební token: $result');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Děkujeme za podporu! Vaší pomocí vylepšujeme aplikaci.'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Payment result validation failed: $e');
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
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Přihlédněte k prémiovému členství a podpoře vývoje',
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Členství Premium – 25 Kč (1 €) / měsíčně',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Získejte přístup k bonusovým hrám a dalším výhodám. Prémiové členství bude brzy aktivní.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Prémiové členství bude brzy aktivní.')),
                          );
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(const Color(0xFFBFFF00)),
                          foregroundColor: WidgetStatePropertyAll(Colors.black),
                          padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(vertical: 16)),
                        ),
                        child: const Text(
                          'Aktivovat Premium – 25 Kč (1 €) / měsíc',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Podpořte vývoj aplikace',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Vyberte částku nebo napište vlastní částku v Kč.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
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
                      const SizedBox(height: 14),
                      TextField(
                        controller: _donationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Vlastní částka (Kč)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                            backgroundColor: WidgetStatePropertyAll(const Color(0xFFBFFF00)),
                            foregroundColor: WidgetStatePropertyAll(Colors.black),
                            padding: WidgetStatePropertyAll(
                              const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          child: const Text(
                            'Podpořit vývoj',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Máte nápad na zlepšení nebo potřebujete pomoc? Kontaktujte nás na e-mailu: dlouhy.m7@seznam.cz',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              Text(
                'Děkujeme za vaši podporu!',
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
