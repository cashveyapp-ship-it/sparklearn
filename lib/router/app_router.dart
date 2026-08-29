import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/firebase_providers.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/sign_up_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/splash/splash_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: _RouterNotifier(ref),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (_, __) => const SignUpScreen()),
      GoRoute(
          path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/app', builder: (_, __) => AppShell()),
    ],
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final loc = state.uri.toString();

      if (authAsync.isLoading) return loc == '/' ? null : '/';

      final isAuthed = authAsync.asData?.value != null;
      final isAuthRoute = loc.startsWith('/sign-') || loc.startsWith('/forgot');

      if (!isAuthed) {
        if (isAuthRoute) return null;
        return '/sign-in';
      }

      if (isAuthRoute || loc == '/') return '/app';

      return null;
    },
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
