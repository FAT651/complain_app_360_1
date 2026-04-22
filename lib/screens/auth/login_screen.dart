import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_auth_scaffold.dart';
import '../../widgets/login_form_widget.dart';
import '../../widgets/auth_details_panel.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ResponsiveAuthScaffold(
        form: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: const LoginFormWidget(),
        ),
        details: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: AuthDetailsPanel(
            title: 'Complaint Management',
            subtitle: 'Submit, track, and resolve complaints efficiently',
            features: [
              AuthFeature(
                icon: Icons.report_problem_outlined,
                title: 'Easy Complaint Submission',
                description: 'Submit your complaints with just a few clicks',
              ),
              AuthFeature(
                icon: Icons.update_outlined,
                title: 'Real-time Status Tracking',
                description: 'Track your complaints and get instant updates',
              ),
              AuthFeature(
                icon: Icons.check_circle_outline,
                title: 'Transparent Resolution',
                description: 'View detailed responses and resolution progress',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
