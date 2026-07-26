import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/employee_service.dart';
import 'app_theme.dart';
import 'home.dart';
import 'security_home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() {
    return _LoginPageState();
  }
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  final supabase = Supabase.instance.client;

  bool isLoading = false;

  Future<void> _login() async {
    setState(() {
      isLoading = true;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final myRecord = await EmployeeService().getMyEmployeeRecord();

      if (!mounted) return;

      if (myRecord != null && myRecord.department == 'Security') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SecurityHome(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Home(),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            'Login failed: ${error.toString()}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  Widget _brandMark() {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.ratpGreen.withOpacity(.25),
        ),
      ),
      child: const Icon(
        Icons.directions_transit_filled_rounded,
        color: AppColors.ratpGreenDark,
        size: 38,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -80,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  color: AppColors.ratpGreen.withOpacity(.13),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              left: -100,
              child: Container(
                width: 270,
                height: 270,
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 430,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.line,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.06),
                          blurRadius: 35,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: _brandMark(),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Visitor Management System',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.3,
                          ),
                        ),

                        const SizedBox(height: 32),

                        TextField(
                          controller: emailController,
                          keyboardType:
                          TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                            ),
                            labelText: 'Email',
                            hintText: 'Enter your email',
                          ),
                        ),

                        const SizedBox(height: 18),

                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                            ),
                            labelText: 'Password',
                            hintText: 'Enter your password',
                          ),
                          onSubmitted: (_) {
                            if (!isLoading) {
                              _login();
                            }
                          },
                        ),

                        const SizedBox(height: 28),

                        SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed:
                            isLoading ? null : _login,
                            icon: isLoading
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(
                              Icons.login_rounded,
                            ),
                            label: Text(
                              isLoading
                                  ? 'Signing in...'
                                  : 'Login',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}