import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesScreen extends StatefulWidget {
  final String userRole; // 'admin' or 'staff'
  SalesScreen({required this.userRole});

  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    String dateLabel = DateFormat('yyyy-MM-dd').format(selectedDate);
    DateTime startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    DateTime endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: Text("Transactions History"),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _pickDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // DATE HEADER
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.brown[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Date: $dateLabel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),

          // LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                  .where('timestamp', isLessThanOrEqualTo: endOfDay)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;

                if (docs.isEmpty) return Center(child: Text("No sales on this date."));

                // Calculate Daily Total
                double dayTotal = 0;
                for(var doc in docs) {
                  dayTotal += (doc['total'] ?? 0).toDouble();
                }

                return Column(
                  children: [
                    // TOTAL BANNER
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      color: Colors.green[100],
                      child: Text(
                        "Total Sales: Php ${dayTotal.toStringAsFixed(2)}",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green[800]),
                      ),
                    ),

                    // TRANSACTION LIST
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          Timestamp? ts = data['timestamp'];
                          String time = ts != null ? DateFormat('h:mm a').format(ts.toDate()) : '...';
                          double total = (data['total'] ?? 0).toDouble();
                          List<dynamic> items = data['items'] ?? [];
                          String paymentMethod = data['paymentMethod'] ?? 'Cash';

                          // Payment Color Logic
                          Color badgeColor = Colors.green;
                          if (paymentMethod == 'Online') badgeColor = Colors.blue;
                          if (paymentMethod == 'Foodpanda') badgeColor = Colors.pink;

                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ExpansionTile(
                              // HEADER ROW
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Php ${total.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  // PAYMENT BADGE
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: badgeColor)
                                    ),
                                    child: Text(paymentMethod, style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                              subtitle: Text("$time - ${items.length} Items"),
                              children: [
                                ...items.map((item) {
                                  String name = "${item['product']} (${item['variant']})";
                                  List<dynamic> addons = item['addons'] ?? [];
                                  return ListTile(
                                    dense: true,
                                    title: Text(name),
                                    subtitle: addons.isNotEmpty ? Text("+ ${addons.join(', ')}") : null,
                                    trailing: Text("x${item['quantity']}"),
                                  );
                                }).toList()
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }
}