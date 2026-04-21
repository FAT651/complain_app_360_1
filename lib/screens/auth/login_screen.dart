import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/primary_button.dart';
import '../../providers/auth_provider.dart';
import '../../config/routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Complaint App',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Student ID',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF344054),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _idController,
                        decoration: AppTheme.formInputDecoration(
                          label: 'Enter your ID',
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Password',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF344054),
                            ),
                          ),
                          Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: AppTheme.formInputDecoration(
                          label: 'Enter password',
                          icon: Icons.lock_outline,
                        ),
                      ),
                      if (authProvider.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authProvider.errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: authProvider.keepSignedIn,
                            onChanged: (value) =>
                                authProvider.toggleKeepSignedIn(value ?? false),
                            activeColor: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Keep me signed in',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF344054),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      PrimaryButton(
                        label: authProvider.isLoading
                            ? 'Please wait...'
                            : 'Sign In',
                        enabled: !authProvider.isLoading,
                        onPressed: () async {
                          // Clear any previous error when starting new attempt
                          authProvider.clearError();

                          final emailOrId = _idController.text.trim();
                          final password = _passwordController.text.trim();
                          if (emailOrId.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter both student ID and password.',
                                ),
                              ),
                            );
                            return;
                          }

                          final navigator = Navigator.of(context);
                          final success = await authProvider.signIn(
                            emailOrId,
                            password,
                          );
                          if (!mounted) return;
                          if (success) {
                            final destination = authProvider.role == 'admin'
                                ? Routes.adminDashboard
                                : Routes.studentDashboard;
                            navigator.pushReplacementNamed(destination);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Don\'t have an account?',
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, Routes.register),
                              child: const Text(
                                'Register Here',
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      _FeatureBadge(
                        icon: Icons.security,
                        label: 'Secure Access',
                      ),
                      _FeatureBadge(
                        icon: Icons.support_agent,
                        label: 'Student Support',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
        ),
      ],
    );
  }
}
