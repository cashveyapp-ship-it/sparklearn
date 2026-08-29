import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/splash_logo.png',
                width: 104, height: 104),
            const SizedBox(height: 18),
            const Text('SparkLearn',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Build confidence, gently.',
                style: TextStyle(color: AppColors.textMuted)),
          ],
        )
            .animate()
            .fadeIn(duration: 450.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}
