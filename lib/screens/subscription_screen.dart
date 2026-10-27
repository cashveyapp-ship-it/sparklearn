import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/subscription_service.dart';
import '../core/responsive/responsive_page.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final service = SubscriptionService.instance;

  bool loading = true;
  bool subscribing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await service.initialize();
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _subscribe({
    required String productId,
    ProductDetails? product,
  }) async {
    if (subscribing) return;

    setState(() {
      subscribing = true;
    });

    try {
      if (kIsWeb) {
        await service.startWebCheckout(productId);
        return;
      }

      if (product == null) {
        throw Exception(
          'This subscription is not currently available.',
        );
      }

      await service.buy(product);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to start subscription: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          subscribing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthly = service.monthly;
    final yearly = service.yearly;

    final monthlyEnabled = kIsWeb || monthly != null;

    final yearlyEnabled = kIsWeb || yearly != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SparkLearn Premium',
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ResponsivePage(
              maxWidth: 900,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  const Text(
                    'Choose your plan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SparkLearn Premium provides AI-powered tutoring and personalized reading practice to support student learning.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "What's included with Premium",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AI Tutoring: AI-generated explanations and guidance for reading and comprehension.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Personalized Practice: Reading activities tailored to student learning goals.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Linked Accounts: Eligible connected parent and student accounts can share Premium access.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Monthly and yearly plans include the same Premium features.',
                  ),
                  const SizedBox(height: 24),
                  _PlanCard(
                    title: 'Monthly',
                    price: kIsWeb ? '\$1.99' : monthly?.price ?? '\$1.99',
                    subtitle: 'Billed monthly',
                    loading: subscribing,
                    onTap: monthlyEnabled && !subscribing
                        ? () => _subscribe(
                              productId: SubscriptionService.monthlyId,
                              product: monthly,
                            )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _PlanCard(
                    title: 'Yearly',
                    price: kIsWeb ? '\$23.00' : yearly?.price ?? '\$23.00',
                    subtitle: 'Billed yearly - Save 4%',
                    loading: subscribing,
                    onTap: yearlyEnabled && !subscribing
                        ? () => _subscribe(
                              productId: SubscriptionService.yearlyId,
                              product: yearly,
                            )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  if (!kIsWeb)
                    TextButton(
                      onPressed: subscribing ? null : service.restore,
                      child: const Text(
                        'Restore Purchases',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    kIsWeb
                        ? 'Subscriptions automatically renew unless canceled at least 24 hours before the end of the current subscription period. Payment will be charged to your app store account upon confirmation of purchase.'
                        : 'Subscriptions automatically renew unless canceled at least 24 hours before the end of the current subscription period. Payment will be charged to your app store account upon confirmation of purchase.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.onTap,
    required this.loading,
  });

  final String title;
  final String price;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Subscribe',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
