import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../providers/firebase_providers.dart';
import '../../core/constants/app_colors.dart';
import 'auth_widgets.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _pass.text,
          );
    } on FirebaseAuthException catch (e) {
      // ✅ Specific, user-friendly messages instead of a single generic one
      setState(() {
        _err = switch (e.code) {
          'user-not-found' => 'No account found for that email.',
          'wrong-password' => 'Incorrect password. Please try again.',
          'invalid-email' => 'That email address is not valid.',
          'user-disabled' => 'This account has been disabled.',
          'too-many-requests' => 'Too many attempts. Please wait a moment.',
          'network-request-failed' => 'Check your internet connection.',
          _ => 'Sign in failed. Please check your email and password.',
        };
      });
    } catch (_) {
      setState(() => _err = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(
                title: 'Welcome back',
                subtitle: 'Sign in to continue learning at a comfortable pace.',
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final x = (v ?? '').trim();
                          if (x.isEmpty) return 'Enter your email';
                          if (!x.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _loading ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v ?? '').length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      if (_err != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.coral, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_err!,
                                  style: const TextStyle(
                                      color: AppColors.textMuted)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      AppButton(
                        label: _loading ? 'Signing in...' : 'Sign In',
                        icon: Icons.login,
                        onPressed: _loading ? null : _submit,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => context.go('/forgot'),
                            child: const Text('Forgot password?'),
                          ),
                          TextButton(
                            onPressed: () => context.go('/sign-up'),
                            child: const Text('Create account'),
                          ),
                        ],
                      ),
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
