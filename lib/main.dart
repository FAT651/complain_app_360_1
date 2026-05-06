import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/routes.dart';
import 'config/firebase_options.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/account_edit_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is not supported on Linux, so skip initialization on Linux
  if (!Platform.isLinux) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'Complaint App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: Routes.splash,
        routes: {
          Routes.splash: (_) => const SplashScreen(),
          Routes.login: (_) => const LoginScreen(),
          Routes.register: (_) => const RegisterScreen(),
          Routes.accountEdit: (_) => const AccountEditScreen(),
          Routes.studentDashboard: (_) => const StudentDashboard(),
          Routes.adminDashboard: (_) => const AdminDashboard(),
        },
      ),
    );
  }
}
