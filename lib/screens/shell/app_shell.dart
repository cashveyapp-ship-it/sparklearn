import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/shell_tab_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/encouragement_service.dart';
import '../settings_screen.dart';
import '../student/student_home_screen.dart';
import '../student/ai_tutor_screen.dart';
import '../student/practice_screen.dart';
import '../student/student_encouragements_screen.dart';
import '../parent/parent_dashboard_screen.dart';
import '../parent/encourage_screen.dart';

final unreadCountProvider =
    StreamProvider.family<int, String>((ref, studentId) {
  return ref.watch(encouragementServiceProvider).unreadCount(studentId);
});

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Future<void> _signOut() async {
    ref.read(shellTabProvider.notifier).state = 0;
    await ref.read(firebaseAuthProvider).signOut();
    if (mounted) context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('SparkLearn'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('SparkLearn')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 12),
                Text('Could not load profile.\n\n$e',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (profile) {
        if (profile == null) return _RolePickerScreen(onSignOut: _signOut);

        final isParent = profile.role == 'parent';
        final index = ref.watch(shellTabProvider);

        final pages = isParent
            ? [
                ParentDashboardScreen(parentUid: profile.uid),
                EncourageScreen(parentUid: profile.uid),
              ]
            : [
                StudentHomeScreen(studentId: profile.uid),
                const AiTutorScreen(),
                PracticeScreen(studentId: profile.uid),
              ];

        final labels = isParent
            ? ['Dashboard', 'Encourage']
            : ['Home', 'AI Tutor', 'Practice'];
        final icons = isParent
            ? [Icons.insights, Icons.favorite]
            : [
                Icons.home_rounded,
                Icons.smart_toy_rounded,
                Icons.menu_book_rounded
              ];

        final safeIndex = index.clamp(0, pages.length - 1);

        return Scaffold(
          appBar: AppBar(
            title: Text(isParent ? 'Parent Dashboard' : 'SparkLearn'),
            actions: [
              if (!isParent) _NotificationBell(studentId: profile.uid),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout, color: AppColors.textMuted),
                onPressed: _signOut,
              ),
            ],
          ),
          body: pages[safeIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (i) =>
                ref.read(shellTabProvider.notifier).state = i,
            destinations: [
              for (int i = 0; i < pages.length; i++)
                NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider(studentId)).asData?.value ?? 0;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Encouragements',
          icon: Icon(
            count > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            color: count > 0 ? AppColors.coral : null,
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentEncouragementsScreen(studentId: studentId),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RolePickerScreen extends ConsumerStatefulWidget {
  const _RolePickerScreen({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  ConsumerState<_RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends ConsumerState<_RolePickerScreen> {
  bool _loading = false;
  String? _err;

  Future<void> _pick(String role) async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final auth = ref.read(firebaseAuthProvider);
      final db = ref.read(firestoreProvider);
      final u = auth.currentUser;
      if (u == null) throw Exception('Not signed in');
      final now = DateTime.now().millisecondsSinceEpoch;
      final name = u.displayName ?? u.email?.split('@').first ?? 'User';

      await db.doc('users/${u.uid}').set({
        'uid': u.uid,
        'email': u.email ?? '',
        'role': role,
        'displayName': name,
        'linkedStudentIds': <String>[],
        'createdAtMs': now,
      }, SetOptions(merge: true)).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception(
            'Firestore timeout.\n\nFix in Firebase Console:\n'
            'Firestore → Rules → allow read, write: if request.auth != null'),
      );

      if (role == 'student') {
        await db.doc('students/${u.uid}').set({
          'id': u.uid,
          'email': u.email ?? '',
          'name': name,
          'readingLevel': 3.9,
          'weeklyProgress': 0.45,
          'timeSpentMinThisWeek': 0,
          'voiceUsagePct': 0,
          'engagement': 'High',
          'skillTrends': {
            'Comprehension': 'Improving',
            'Vocabulary': 'Improving',
            'Writing': 'Improving'
          },
          'parentUids': <String>[],
          'preferredMode': 'Voice',
          'todayGoal': 'Reading: Understanding paragraphs',
          'updatedAtMs': now,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SparkLearn'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout), onPressed: widget.onSignOut),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('One more step!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('How are you using SparkLearn?',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              if (_loading)
                const CircularProgressIndicator()
              else ...[
                _btn('student', '🎓  I am a Student'),
                const SizedBox(height: 16),
                _btn('parent', '👨‍👩‍👧  I am a Parent'),
              ],
              if (_err != null) ...[
                const SizedBox(height: 16),
                Text(_err!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String role, String label) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => _pick(role),
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
