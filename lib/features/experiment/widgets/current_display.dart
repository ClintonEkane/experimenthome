import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CurrentDisplay extends StatelessWidget {
  final double currentMa;
  final bool isActive;

  const CurrentDisplay({
    super.key,
    required this.currentMa,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              'Current',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isActive ? currentMa.toStringAsFixed(2) : '--',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8, left: 4),
                  child: Text('mA',
                      style: TextStyle(
                          fontSize: 18, color: AppColors.textSecondary)),
                ),
              ],
            ),
            if (!isActive)
              const Text(
                'Start the experiment to see live readings',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
