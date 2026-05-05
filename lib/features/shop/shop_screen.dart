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
      final appleConfig = await PaymentConfiguration.fromAsset('apple_pay_config.json');
      final googleConfig = await PaymentConfiguration.fromAsset('google_pay_config.json');
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
      const SnackBar(content: Text('Děkujeme za podporu!')),
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
                        )
                      else if (_googlePayConfig != null)
                        GooglePayButton(
                          paymentConfiguration: _googlePayConfig!,
                          paymentItems: _paymentItems,
                          type: GooglePayButtonType.donate,
                          onPaymentResult: _onPaymentResult,
                          loadingIndicator: const Center(child: CircularProgressIndicator()),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
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
