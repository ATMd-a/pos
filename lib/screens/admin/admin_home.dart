import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../login_screen.dart';
import 'menu_manager_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manager Dashboard"),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.restaurant_menu),
            tooltip: "Edit Menu",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MenuManagerScreen())),
          ),
          IconButton(icon: Icon(Icons.logout), onPressed: () {
            FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
          })
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSalesDashboard(),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("⚠️ Low Stock Alert (Below 5)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
              SizedBox(height: 10),
              _buildLowStockList(),
            ],
          ),
        ),
      ),
    );
  }

  // 1. SALES DASHBOARD (Same as before)
  Widget _buildSalesDashboard() {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        var docs = snapshot.data!.docs;
        double totalSales = 0.0;
        int totalTxn = docs.length;
        double cashTotal = 0.0;
        double onlineTotal = 0.0;
        double foodpandaTotal = 0.0;

        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>;
          double amount = (data['total'] ?? 0).toDouble();
          String method = data['paymentMethod'] ?? 'Cash';
          totalSales += amount;
          if (method == 'Cash') cashTotal += amount;
          else if (method == 'Online') onlineTotal += amount;
          else if (method == 'Foodpanda') foodpandaTotal += amount;
        }

        return Container(
          width: double.infinity,
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green[800]!, Colors.green[600]!]),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Sales", style: TextStyle(color: Colors.white70)),
              Text("Php ${totalSales.toStringAsFixed(2)}", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat("Cash", cashTotal, Icons.money),
                  _buildMiniStat("Online", onlineTotal, Icons.qr_code),
                  _buildMiniStat("Panda", foodpandaTotal, Icons.delivery_dining),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, double amount, IconData icon) {
    return Column(
      children: [
        Row(children: [Icon(icon, color: Colors.white70, size: 14), SizedBox(width: 4), Text(label, style: TextStyle(color: Colors.white70, fontSize: 12))]),
        Text("Php ${amount.toStringAsFixed(0)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
      ],
    );
  }

  // 2. LOW STOCK LIST (REDESIGNED to match Inventory UI)
  Widget _buildLowStockList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('inventory_items').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();

        var lowStockItems = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          int stock = data['currentStock'] ?? 0;
          return stock < 5;
        }).toList();

        if (lowStockItems.isEmpty) return Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("All stocks healthy! ✅", style: TextStyle(color: Colors.grey)));

        // Show as a list of nice cards
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: lowStockItems.length,
          itemBuilder: (context, index) {
            var data = lowStockItems[index].data() as Map<String, dynamic>;
            int stockStorage = data['stockStorage'] ?? 0;
            int stockDisplay = data['stockDisplay'] ?? 0;
            int total = data['currentStock'] ?? 0;
            String unit = data['unit'] ?? 'pcs';

            return Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // NAME & TOTAL (Red Alert)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                            child: Text("Total: $total $unit", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[800], fontSize: 12)),
                          )
                        ],
                      ),
                    ),
                    // BOX / DISPLAY
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(children: [Text("Box", style: TextStyle(fontSize: 10, color: Colors.grey)), Text("$stockStorage", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
                          Container(width: 1, height: 25, color: Colors.grey[300], margin: EdgeInsets.symmetric(horizontal: 10)),
                          Column(children: [Text("Display", style: TextStyle(fontSize: 10, color: Colors.grey)), Text("$stockDisplay", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}