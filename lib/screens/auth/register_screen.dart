import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_auth_scaffold.dart';
import '../../widgets/register_form_widget.dart';
import '../../widgets/auth_details_panel.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ResponsiveAuthScaffold(
        form: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: const RegisterFormWidget(),
        ),
        details: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: AuthDetailsPanel(
            title: 'Join Our Community',
            subtitle: 'Create an account to start managing complaints',
            features: [
              AuthFeature(
                icon: Icons.security_outlined,
                title: 'Secure Account',
                description: 'Your data is protected with enterprise security',
              ),
              AuthFeature(
                icon: Icons.notifications_active_outlined,
                title: 'Stay Updated',
                description: 'Receive notifications for important updates',
              ),
              AuthFeature(
                icon: Icons.people_outline,
                title: 'Community Support',
                description: 'Get help from our active support community',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
