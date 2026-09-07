import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/subscription_service.dart';
import 'firebase_providers.dart';

final premiumProvider = FutureProvider<bool>((ref) async {
  final authAsync = ref.watch(authStateProvider);
  final user = authAsync.asData?.value;

  if (user == null) {
    return false;
  }

  return SubscriptionService.instance.hasPremiumAccess();
});
