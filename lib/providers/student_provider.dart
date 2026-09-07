import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student.dart';
import 'firebase_providers.dart';

final studentDocProvider =
    StreamProvider.autoDispose.family<Student?, String>((ref, studentId) {
  final db = ref.watch(firestoreProvider);

  final authAsync = ref.watch(authStateProvider);
  final user = authAsync.asData?.value;

  if (user == null) {
    return Stream.value(null);
  }

  return db.doc('students/$studentId').snapshots().map((snap) {
    if (!snap.exists) return null;
    return Student.fromMap(snap.data()!);
  });
});
