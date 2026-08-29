import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared tab index so any screen can switch tabs programmatically.
/// e.g. ref.read(shellTabProvider.notifier).state = 2; // go to Practice
final shellTabProvider = StateProvider<int>((ref) => 0);
