import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import 'firebase_providers.dart';

/// ✅ Always tracks auth changes (sign out / sign in) and switches streams safely.
/// This prevents stale UID streams and the permission-denied error you keep seeing.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final db = ref.watch(firestoreProvider);

  // Watch auth state so provider rebuilds when user changes
  final authAsync = ref.watch(authStateProvider);
  final user = authAsync.asData?.value;

  if (user == null) {
    return Stream.value(null);
  }

  return db.doc('users/${user.uid}').snapshots().map((snap) {
    if (!snap.exists) return null;
    return UserProfile.fromMap(snap.data()!);
  });
});
