import 'package:flutter/material.dart';

/// A responsive auth scaffold that shows:
/// - Mobile: Full-screen form only
/// - Desktop: Split layout (form on left, details on right)
class ResponsiveAuthScaffold extends StatelessWidget {
  /// The main auth form widget
  final Widget form;

  /// The details/info widget to show on the right (desktop only)
  final Widget details;

  /// The background color
  final Color? backgroundColor;

  /// Minimum width to switch to desktop layout (default: 900)
  final double desktopThreshold;

  const ResponsiveAuthScaffold({
    super.key,
    required this.form,
    required this.details,
    this.backgroundColor,
    this.desktopThreshold = 900,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= desktopThreshold;

    if (isDesktop) {
      // Desktop: Split layout
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Row(
          children: [
            // Left side: Form
            Expanded(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 48,
                    ),
                    child: form,
                  ),
                ),
              ),
            ),

            // Right side: Details/Info
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2563EB).withOpacity(0.9),
                      const Color(0xFF1D4ED8).withOpacity(0.95),
                    ],
                  ),
                ),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 48,
                    ),
                    child: details,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile: Full screen form
      return Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: form,
            ),
          ),
        ),
      );
    }
  }
}
