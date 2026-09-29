import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'firebase_options.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {}

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check for Android and iOS.
  // Web App Check will be configured separately for the web application.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }

  runApp(
    const ProviderScope(
      child: SparkLearnApp(),
    ),
  );
}

Widget buildAppForTest({List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: const SparkLearnApp(),
  );
}

class SparkLearnApp extends ConsumerWidget {
  const SparkLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'SparkLearn',
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
