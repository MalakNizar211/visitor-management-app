import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile_application/security_home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'loginpage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color primaryBlue = Color(0xFF003B71);
  static const Color secondaryTeal = Color(0xFF00A99D);

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final isSessionValid = session;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Visitor Management',

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: secondaryTeal,
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor: const Color(0xFFF5F7FA),

        fontFamily: 'Roboto',

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: primaryBlue,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.white,
          titleTextStyle: TextStyle(
            color: primaryBlue,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 3,
          color: Colors.white,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(14),
            ),
            borderSide: BorderSide(
              color: primaryBlue,
              width: 2,
            ),
          ),
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      home: const SecurityHome(),
    );
  }
}