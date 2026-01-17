import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_nav_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // 1. Authenticate with Email/Password
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());

      // 2. Check "users" collection to see if role is admin or staff
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role']; // 'admin' or 'staff'

        // 3. Navigate based on role
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => MainNavScreen(role: role)
            )
        );
      } else {
        // Safety fallback: If user exists in Auth but not in Database
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User data not found in database.")));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: ${e.toString()}")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Milktea Inventory", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 40),
                  TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder())),
                  SizedBox(height: 16),
                  TextField(controller: _passwordController, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
                  SizedBox(height: 24),
                  _isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _login,
                    child: Container(width: double.infinity, alignment: Alignment.center, padding: EdgeInsets.all(16), child: Text("LOGIN")),
                  ),
                ],
              ),
            ),
        ),
    );
  }
}