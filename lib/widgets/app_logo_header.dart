import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogoHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double iconSize;
  final double circleSize;

  const AppLogoHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.iconSize = 112,
    this.circleSize = 142,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFF4F4FF),
                Color(0xFFE5E6FF),
                Color(0xFFD4D7FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.16),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.7),
                blurRadius: 12,
                offset: const Offset(-4, -4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/icons/login_logo.png',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16.5,
            height: 1.6,
            color: AppColors.textLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}