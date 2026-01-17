import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  @override
  _StaffHomeScreenState createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  // Temporary storage for what the user types
  Map<String, int> _boughtCounts = {};
  Map<String, bool> _isFullFueled = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text("Staff Dashboard"), // <--- CHANGED THIS
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column( // <--- WRAPPED IN COLUMN TO ADD HEADER
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- NEW HEADER HERE ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                  "📋 To Buy List",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
              ),
            ),

            // --- EXISTING LIST (Wrapped in Expanded) ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('to_buy_list').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                  var docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(child: Text("Nothing to buy today! Good job.", style: TextStyle(color: Colors.grey)));
                  }

                  return ListView.builder(
                    padding: EdgeInsets.only(bottom: 20), // Add padding at bottom so last item isn't cut off
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      String docId = docs[index].id;

                      // Get data safely
                      String itemName = data['name'] ?? 'Unknown Item';
                      int targetQty = data['targetQuantity'] ?? 0;
                      String note = data['note'] ?? '';
                      String inventoryId = data['inventoryId'] ?? '';

                      // Local state for inputs
                      int currentInput = _boughtCounts[docId] ?? 0;
                      bool isChecked = _isFullFueled[docId] ?? false;

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // 1. Item Info
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemName,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text("Target: $targetQty", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                        if (note.isNotEmpty)
                                          Text("Note: $note", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700])),
                                      ],
                                    ),
                                  ),

                                  // 2. Input Field
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      enabled: !isChecked, // Disable if checkbox is checked
                                      decoration: InputDecoration(
                                        labelText: "Bought",
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      ),
                                      controller: TextEditingController(text: isChecked ? "$targetQty" : (currentInput == 0 ? "" : "$currentInput")),
                                      onChanged: (val) {
                                        setState(() {
                                          _boughtCounts[docId] = int.tryParse(val) ?? 0;
                                        });
                                      },
                                    ),
                                  ),

                                  // 3. Checkbox (Full)
                                  Column(
                                    children: [
                                      Checkbox(
                                        value: isChecked,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _isFullFueled[docId] = value!;
                                            if (value) {
                                              _boughtCounts[docId] = targetQty; // Auto-fill max
                                            } else {
                                              _boughtCounts[docId] = 0; // Reset
                                            }
                                          });
                                        },
                                      ),
                                      Text("All", style: TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                ],
                              ),

                              SizedBox(height: 10),

                              // 4. Update Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  icon: Icon(Icons.check),
                                  label: Text("UPDATE / DONE"),
                                  onPressed: () => _processPurchase(docId, inventoryId, targetQty, _boughtCounts[docId] ?? 0),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // LOGIC: Updates Inventory + Updates To-Buy List
  Future<void> _processPurchase(String toBuyDocId, String inventoryId, int targetQty, int boughtQty) async {
    if (boughtQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please enter a quantity greater than 0")));
      return;
    }

    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      await db.runTransaction((transaction) async {
        // A. Update Actual Inventory Stock
        DocumentReference invRef = db.collection('inventory_items').doc(inventoryId);
        DocumentSnapshot invSnap = await transaction.get(invRef);

        if (invSnap.exists) {
          int currentStock = invSnap['currentStock'] ?? 0;
          transaction.update(invRef, {'currentStock': currentStock + boughtQty});
        }

        // B. Update "To Buy" List
        DocumentReference toBuyRef = db.collection('to_buy_list').doc(toBuyDocId);

        if (boughtQty >= targetQty) {
          // Full buy: Remove item from list
          transaction.delete(toBuyRef);
        } else {
          // Partial buy: Update remainder
          int newTarget = targetQty - boughtQty;
          transaction.update(toBuyRef, {'targetQuantity': newTarget});
        }
      });

      // Clear local state
      setState(() {
        _boughtCounts.remove(toBuyDocId);
        _isFullFueled.remove(toBuyDocId);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Stock Updated!")));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }
}