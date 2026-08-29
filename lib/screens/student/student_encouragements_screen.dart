import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../models/encouragement.dart';
import '../../services/encouragement_service.dart';

class StudentEncouragementsScreen extends ConsumerStatefulWidget {
  const StudentEncouragementsScreen({super.key, required this.studentId});
  final String studentId;

  @override
  ConsumerState<StudentEncouragementsScreen> createState() =>
      _StudentEncouragementsScreenState();
}

class _StudentEncouragementsScreenState
    extends ConsumerState<StudentEncouragementsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as seen 1 second after opening
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ref.read(encouragementServiceProvider).markAllSeen(widget.studentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encouragements 💙'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.swipe_left, size: 14, color: AppColors.textMuted),
                SizedBox(width: 4),
                Text('Swipe left to delete',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Encouragement>>(
        stream: ref
            .read(encouragementServiceProvider)
            .streamForStudent(widget.studentId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: AppColors.textMuted)),
            );
          }

          final items = snap.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.favorite_border,
                      size: 64, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('No encouragements yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Ask your parent to send one from their Encourage tab!',
                      style: TextStyle(color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final e = items[i];
              final isNew = e.seenAtMs == null;

              return Dismissible(
                key: Key(e.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => ref
                    .read(encouragementServiceProvider)
                    .delete(widget.studentId, e.id),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.coral.withOpacity(0.12),
                          ),
                          alignment: Alignment.center,
                          child: Text(_emoji(e.messageKey),
                              style: const TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _text(e.messageKey),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                    ),
                                  ),
                                  if (isNew)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: AppColors.coral,
                                      ),
                                      child: const Text('New',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(_timeAgo(e.createdAtMs),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _emoji(String key) {
    switch (key) {
      case 'keep_it_up':
        return '👍';
      case 'proud_of_you':
        return '⭐';
      case 'stay_consistent':
        return '💪';
      default:
        return '💙';
    }
  }

  String _text(String key) {
    switch (key) {
      case 'keep_it_up':
        return "Keep it up! You're doing great!";
      case 'proud_of_you':
        return "I'm so proud of you and all your hard work!";
      case 'stay_consistent':
        return 'Stay consistent — small steps lead to big results!';
      default:
        return "You've got this!";
    }
  }

  String _timeAgo(int ms) {
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
