import 'package:flutter/material.dart';

/// Shows app details/branding on the right side of desktop auth screens
class AuthDetailsPanel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<AuthFeature>? features;

  const AuthDetailsPanel({super.key, this.title, this.subtitle, this.features});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          title ?? 'Complaint Management System',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Subtitle
        Text(
          subtitle ??
              'Streamline your complaint process with our intuitive platform',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 48),

        // Features
        ...(features ?? _defaultFeatures()).map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(feature.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        feature.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<AuthFeature> _defaultFeatures() {
    return [
      AuthFeature(
        icon: Icons.report_problem_outlined,
        title: 'Easy Complaint Submission',
        description: 'Submit complaints quickly with our simple form',
      ),
      AuthFeature(
        icon: Icons.update_outlined,
        title: 'Real-time Status Tracking',
        description: 'Monitor your complaint status and receive updates',
      ),
      AuthFeature(
        icon: Icons.check_circle_outline,
        title: 'Transparent Resolution',
        description: 'View details and replies throughout the process',
      ),
    ];
  }
}

class AuthFeature {
  final IconData icon;
  final String title;
  final String description;

  AuthFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
}
