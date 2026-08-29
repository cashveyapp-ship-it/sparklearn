import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/encouragement_service.dart';
import '../../models/encouragement.dart';

class EncourageScreen extends ConsumerWidget {
  const EncourageScreen({super.key, required this.parentUid});
  final String parentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final studentId = (profile?.linkedStudentIds.isNotEmpty ?? false)
        ? profile!.linkedStudentIds.first
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send Encouragement 💙',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'Choose a message to send. Your encouragement means a lot!',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 14),
          if (studentId == null)
            AppCard(
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: AppColors.coral),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Link a student first from the Dashboard tab.',
                          style: TextStyle(color: AppColors.textMuted))),
                ],
              ),
            )
          else ...[
            _msgTile(context, ref, studentId, EncouragementMessageKey.keepItUp,
                '👍  Keep it up!'),
            const SizedBox(height: 10),
            _msgTile(context, ref, studentId,
                EncouragementMessageKey.proudOfYou, '⭐  Proud of you'),
            const SizedBox(height: 10),
            _msgTile(
                context,
                ref,
                studentId,
                EncouragementMessageKey.stayConsistent,
                '💪  Stay consistent'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.indigo.withOpacity(0.08),
              ),
              child: const Text(
                'Messages are pre-defined to keep things safe & simple.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _msgTile(BuildContext context, WidgetRef ref, String studentId,
      String key, String title) {
    return AppCard(
      child: ListTile(
        leading: const Icon(Icons.favorite, color: AppColors.coral),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.send_rounded, color: AppColors.textMuted),
        onTap: () async {
          try {
            await ref
                .read(encouragementServiceProvider)
                .send(studentId: studentId, messageKey: key);
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Sent!')));
          } catch (_) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Could not send.')));
          }
        },
      ),
    );
  }
}
