import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final service = SubscriptionService.instance;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await service.initialize();

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthly = service.monthly;
    final yearly = service.yearly;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SparkLearn Premium'),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
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
                  'Unlock SparkLearn Premium.',
                ),
                const SizedBox(height: 24),
                _PlanCard(
                  title: 'Monthly',
                  price: monthly?.price ?? '\$1.99',
                  subtitle: 'Billed monthly',
                  onTap: monthly == null ? null : () => service.buy(monthly),
                ),
                const SizedBox(height: 16),
                _PlanCard(
                  title: 'Yearly',
                  price: yearly?.price ?? '\$23.00',
                  subtitle: 'Billed yearly • Save 4%',
                  onTap: yearly == null ? null : () => service.buy(yearly),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: service.restore,
                  child: const Text('Restore Purchases'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID or Google Play account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
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
  });

  final String title;
  final String price;
  final String subtitle;
  final VoidCallback? onTap;

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
                child: const Text('Subscribe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
