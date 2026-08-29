import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';

class CelebrationScreen extends StatelessWidget {
  const CelebrationScreen(
      {super.key, required this.improvements, required this.levelDelta});

  final List<String> improvements;
  final double levelDelta;

  @override
  Widget build(BuildContext context) {
    final levelText = levelDelta == 0
        ? 'Reading Level +0.0'
        : 'Reading Level +${levelDelta.toStringAsFixed(1)}';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.coral,
                ),
                child: const Icon(Icons.celebration_rounded,
                    color: Colors.white, size: 40),
              ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.elasticOut,
                  duration: 900.ms),
              const SizedBox(height: 18),
              const Text('Nice work!',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  children: [
                    for (final i in improvements.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppColors.green),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(i,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.indigo,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(levelText,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
