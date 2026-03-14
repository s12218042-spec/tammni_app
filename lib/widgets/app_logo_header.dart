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
    this.iconSize = 64,
    this.circleSize = 118,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE9EAFF),
                const Color(0xFFD8DBFF),
                const Color(0xFFC9CDFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.65),
                blurRadius: 12,
                offset: const Offset(-4, -4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: circleSize - 6,
                height: circleSize - 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 18,
                child: Transform.rotate(
                  angle: -0.5,
                  child: Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              Icon(
                Icons.child_friendly_rounded,
                size: iconSize,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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