import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../providers/firebase_providers.dart';
import '../../core/constants/app_colors.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  String? _msg;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      await ref
          .read(firebaseAuthProvider)
          .sendPasswordResetEmail(email: _email.text.trim());
      setState(() => _msg = 'If that email exists, a reset link was sent.');
    } catch (_) {
      setState(() => _msg = 'If that email exists, a reset link was sent.');
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
                title: 'Reset password',
                subtitle:
                    'We’ll send a reset link if the email is registered.',
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
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) {
                          final x = (v ?? '').trim();
                          if (x.isEmpty) return 'Enter your email';
                          if (!x.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AppButton(
                        label: _loading ? 'Sending...' : 'Send reset link',
                        icon: Icons.mail_outline,
                        onPressed: _loading ? null : _send,
                      ),
                      if (_msg != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppColors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_msg!,
                                    style: const TextStyle(
                                        color: AppColors.textMuted))),
                          ],
                        )
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: () => context.go('/sign-in'),
                          child: const Text('Back to sign in')),
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
