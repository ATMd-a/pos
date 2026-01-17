import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin/admin_home.dart';
import 'staff/pos_screen.dart';
import 'inventory_screen.dart';
import 'login_screen.dart';
import 'sales_screen.dart';

class MainNavScreen extends StatefulWidget {
  final String role; // 'admin' or 'staff'

  MainNavScreen({required this.role});

  @override
  _MainNavScreenState createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Define the screens
    final List<Widget> _screens = [
      widget.role == 'admin' ? AdminHomeScreen() : POSScreen(),
      InventoryScreen(userRole: widget.role),
      SalesScreen(userRole: widget.role),
      Scaffold(
        appBar: AppBar(title: Text("Account")),
        body: Center(
          child: ElevatedButton.icon(
            icon: Icon(Icons.logout),
            label: Text("Log Out"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
          ),
        ),
      ),
    ];

    return Scaffold(
      // FIX: Use IndexedStack to keep the POS Cart alive when switching tabs
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.brown,
        unselectedItemColor: Colors.grey,

        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Inventory"),
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: "Sales"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Account"),
        ],
      ),
    );
  }
}