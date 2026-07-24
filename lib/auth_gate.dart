import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'loginpage.dart';
import 'home.dart';
import 'security_home.dart';
import 'services/employee_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final EmployeeService employeeService = EmployeeService();

  @override
  void initState() {
    super.initState();
    _decideStartScreen();
  }

  Future<void> _decideStartScreen() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      _navigateTo(const LoginPage());
      return;
    }

    try {
      final myRecord = await employeeService.getMyEmployeeRecord();

      if (myRecord != null && myRecord.department == 'Security') {
        _navigateTo(const SecurityHome());
      } else {
        _navigateTo(const Home());
      }
    } catch (e) {
      _navigateTo(const LoginPage());
    }
  }

  void _navigateTo(Widget page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Shown briefly while _decideStartScreen() figures out where to go
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.ratpGreen,
        ),
      ),
    );
  }
}