import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'firebase_options.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ App Check without Play Console:
  // Debug tokens for emulator/dev; Play Integrity only when you ship via Play.
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode
        ? AndroidProvider
            .playIntegrity // will be truly verified only when installed from Play
        : AndroidProvider.debug, // verified via debug token
    appleProvider: AppleProvider.debug, // optional if you test iOS (safe)
  );

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
