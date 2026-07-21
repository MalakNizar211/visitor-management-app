import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'loginpage.dart';
class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupPageState();
}

class _SignupPageState extends State<Signup> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.lightBlue
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Create Account",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold

                ),
                hintText: 'Please enter your email',
                hintStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50)
                )
              ),
            ),
            SizedBox(
              height: 40
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold

                  ),
                  hintText: 'Please enter your password',
                  hintStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50)
                  )
              ),
            ),
            ElevatedButton( onPressed:  () async{
              await supabase.auth.signUp(
                email: emailController.text,
                password: passwordController.text,
              );
            },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text('Register'),
            ),
            ElevatedButton( onPressed:  () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginPage(),
                ),
              );
            },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text('Already Have an Account? Go to Login'),
            )
          ],

        ),
      ),
    );
  }
}