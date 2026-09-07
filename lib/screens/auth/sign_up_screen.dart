import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../providers/firebase_providers.dart';
import '../../models/user_profile.dart';
import '../../core/constants/app_colors.dart';
import 'auth_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String _role = UserRole.student;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
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
      final auth = ref.read(firebaseAuthProvider);
      final db = ref.read(firestoreProvider);

      final email = _email.text.trim().toLowerCase();

      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: _pass.text,
      );

      final uid = cred.user!.uid;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Create profile doc (immutable role)
      final profile = UserProfile(
        uid: uid,
        email: email,
        role: _role,
        displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        linkedStudentIds: const [],
        createdAtMs: now,
      );

      await db.doc('users/$uid').set(profile.toMap(), SetOptions(merge: false));

      // Create student doc if role is student (studentId == uid)
      if (_role == UserRole.student) {
        await db.doc('students/$uid').set({
          'id': uid,
          'email': email,
          'name': (_name.text.trim().isEmpty
              ? _email.text.trim().split('@').first
              : _name.text.trim()),
          'readingLevel': 3.9,
          'weeklyProgress': 0.45,
          'timeSpentMinThisWeek': 0,
          'voiceUsagePct': 0,
          'engagement': 'High',
          'skillTrends': {
            'Comprehension': 'Improving',
            'Math fractions': 'Needs work',
            'Vocabulary': 'Improving',
            'Writing': 'Improving'
          },
          'parentUids': <String>[],
          'preferredMode': 'Voice',
          'updatedAtMs': now,
        }, SetOptions(merge: false));
      }

      // Router auto-navigates to /app once userProfileProvider emits the new doc.
    } catch (e) {
      setState(() =>
          _err = 'Sign up failed. Please try a different email or password.');
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
                title: 'Create your account',
                subtitle:
                    'Choose Student or Parent. Parents get a read-only dashboard.',
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass,
                        obscureText: _obscure,
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
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Account type',
                            style: Theme.of(context).textTheme.labelLarge),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleChip(
                              label: 'Student',
                              selected: _role == UserRole.student,
                              icon: Icons.school,
                              onTap: () =>
                                  setState(() => _role = UserRole.student),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _RoleChip(
                              label: 'Parent',
                              selected: _role == UserRole.parent,
                              icon: Icons.family_restroom,
                              onTap: () =>
                                  setState(() => _role = UserRole.parent),
                            ),
                          ),
                        ],
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
                                        color: AppColors.textMuted))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      AppButton(
                        label: _loading ? 'Creating...' : 'Create Account',
                        icon: Icons.person_add_alt_1,
                        onPressed: _loading ? null : _submit,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: const Text('Already have an account? Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Parents can link to a student account from inside the app using the student'
                's email.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip(
      {required this.label,
      required this.selected,
      required this.icon,
      required this.onTap});
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? AppColors.indigo.withOpacity(0.12) : Colors.white,
          border:
              Border.all(color: selected ? AppColors.indigo : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.indigo : AppColors.textMuted),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.indigo : AppColors.text)),
          ],
        ),
      ),
    );
  }
}
