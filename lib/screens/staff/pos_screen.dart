import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/menu_models.dart';

// Helper Model for the Cart
class CartItem {
  final Product product;
  final ProductVariant variant;
  final List<AddOn> addons;
  int quantity;

  CartItem({
    required this.product,
    required this.variant,
    this.addons = const [],
    this.quantity = 1,
  });

  double get totalPrice => (variant.price + addons.fold(0.0, (sum, item) => sum + item.price)) * quantity;
}

class POSScreen extends StatefulWidget {
  @override
  _POSScreenState createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final List<String> categories = [
    'Regular Series', 'Cheesecake Series', 'Cream Cheese Series',
    'Oreo Series', 'Chocolate Series', 'Yakult Series', 'Nutella Series',
    'Takoyaki 2-3', 'Takoyaki Solo', 'Pizza', 'Fries', 'Others'
  ];

  String selectedCategory = 'Regular Series';
  String selectedPayment = 'Cash';
  List<CartItem> _cart = [];
  TextEditingController _cashController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // 1. CALCULATE TOTALS
    double grandTotal = _cart.fold(0.0, (sum, item) => sum + item.totalPrice);
    double amountPaid = double.tryParse(_cashController.text) ?? 0.0;
    double change = amountPaid - grandTotal;

    // 2. CHECK SCREEN WIDTH (Responsive Logic)
    bool isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(title: Text("Staff POS"), elevation: 2),
      body: Row(
        children: [
          // --- COLUMN 1: CATEGORIES ---
          Container(
            width: isWideScreen ? 100 : 85,
            color: Colors.grey[200],
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                String cat = categories[index];
                bool isSelected = selectedCategory == cat;
                return InkWell(
                  onTap: () => setState(() => selectedCategory = cat),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      border: isSelected ? Border(left: BorderSide(color: Colors.brown, width: 4)) : null,
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                          color: isSelected ? Colors.brown : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),

          // --- COLUMN 2: PRODUCT GRID ---
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.grey[50],
              padding: EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(selectedCategory, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('products')
                          .where('category', isEqualTo: selectedCategory)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                        var docs = snapshot.data!.docs;
                        if (docs.isEmpty) return Center(child: Text("No items"));

                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isWideScreen ? 4 : 3,
                              childAspectRatio: 1.3,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var product = Product.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
                            return _buildProductCard(product);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- COLUMN 3: CART PANEL (ONLY ON WIDE SCREEN) ---
          if (isWideScreen)
            Container(
              width: 300,
              decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(-2, 0))]
              ),
              child: _buildCartContent(grandTotal, change, setState),
            )
        ],
      ),

      // --- MOBILE BOTTOM BAR ---
      bottomNavigationBar: isWideScreen ? null : Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${_cart.length} Items", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text("Php ${grandTotal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
                ],
              ),
              Spacer(),
              ElevatedButton.icon(
                icon: Icon(Icons.shopping_cart, size: 18),
                label: Text("VIEW CART"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                onPressed: () => _showMobileCartSheet(context),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================================
  // UI COMPONENTS
  // ==============================================================================

  Widget _buildProductCard(Product product) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showVariantSelector(context, product),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Center(
            child: Text(
              product.name,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown[800]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartContent(double grandTotal, double change, StateSetter stateUpdater) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          color: Colors.brown[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Order", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("${_cart.length} items", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),

        Expanded(
          child: _cart.isEmpty
              ? Center(child: Text("Cart Empty", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            itemCount: _cart.length,
            itemBuilder: (context, index) {
              var item = _cart[index];
              return Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text("${item.product.name} (${item.variant.name})", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                      "${item.quantity}x" + (item.addons.isEmpty ? "" : " +${item.addons.length} adds"),
                      style: TextStyle(fontSize: 11)
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Php ${item.totalPrice}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      IconButton(
                          icon: Icon(Icons.close, color: Colors.red, size: 14),
                          onPressed: () => setState(() => _cart.removeAt(index))
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
          ),
          child: Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _buildPaymentBtn("Cash", Icons.money, Colors.green, stateUpdater),
                      SizedBox(width: 4),
                      _buildPaymentBtn("Online", Icons.qr_code, Colors.blue, stateUpdater),
                      SizedBox(width: 4),
                      _buildPaymentBtn("Foodpanda", Icons.delivery_dining, Colors.pink, stateUpdater),
                    ],
                  ),
                  SizedBox(height: 8),

                  if (selectedPayment == 'Cash') ...[
                    SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _cashController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                            labelText: "Amount Received",
                            prefixText: "Php ",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10)
                        ),
                        onChanged: (val) => stateUpdater((){}),
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Change:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(
                            "Php ${change < 0 ? '0.00' : change.toStringAsFixed(2)}",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: change < 0 ? Colors.red : Colors.green)
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                  ],

                  Divider(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Php ${grandTotal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.brown)),
                    ],
                  ),

                  SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: _cart.isEmpty || (selectedPayment == 'Cash' && change < 0)
                          ? null
                          : () => _processCheckout(context, selectedPayment),
                      child: Text("CONFIRM PAYMENT"),
                    ),
                  )
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

// --- Mobile Cart Sheet (Fixed: Keyboard pushes sheet up) ---
  void _showMobileCartSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Allows the sheet to resize freely
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setSheetState) {
                double grandTotal = _cart.fold(0.0, (sum, item) => sum + item.totalPrice);
                double amountPaid = double.tryParse(_cashController.text) ?? 0.0;
                double change = amountPaid - grandTotal;

                // WRAP IN PADDING to listen for Keyboard
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom // <--- THIS ADDS THE PADDING
                  ),
                  child: Container(
                    // Use slightly less height so there is room for the keyboard header
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildCartContent(grandTotal, change, setSheetState)
                  ),
                );
              }
          );
        }
    );
  }

  Widget _buildPaymentBtn(String label, IconData icon, Color color, StateSetter stateUpdater) {
    bool isSelected = selectedPayment == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          stateUpdater(() {
            selectedPayment = label;
            if (label != 'Cash') _cashController.clear();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.white,
              border: Border.all(color: isSelected ? color : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4)
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? color : Colors.grey))
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================================
  // MODALS & LOGIC
  // ==============================================================================

  void _showVariantSelector(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Divider(),
                  Text("Select Size", style: TextStyle(color: Colors.grey)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: product.variants.length,
                      itemBuilder: (context, index) {
                        var variant = product.variants[index];
                        return ListTile(
                          title: Text(variant.name, style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text("Php ${variant.price}", style: TextStyle(color: Colors.brown)),
                          onTap: () {
                            Navigator.pop(context);
                            _showAddOnSelector(context, product, variant);
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddOnSelector(BuildContext context, Product product, ProductVariant variant) {
    List<AddOn> selectedAddons = [];
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text("${product.name} (${variant.name})", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Php ${variant.price}", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Divider(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(icon: Icon(Icons.remove_circle, color: Colors.red), onPressed: () {
                        if(quantity > 1) setSheetState(() => quantity--);
                      }),
                      Text(" $quantity ", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      IconButton(icon: Icon(Icons.add_circle, color: Colors.green), onPressed: () {
                        setSheetState(() => quantity++);
                      }),
                    ],
                  ),

                  Divider(),
                  Text("Add-ons", style: TextStyle(fontWeight: FontWeight.bold)),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('addons').snapshots(),
                      builder: (context, snapshot) {
                        if(!snapshot.hasData) return Center(child: CircularProgressIndicator());
                        var docs = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var addon = AddOn.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
                            bool isSelected = selectedAddons.any((a) => a.id == addon.id);

                            return CheckboxListTile(
                              title: Text(addon.name),
                              secondary: Text("+Php ${addon.price}"),
                              value: isSelected,
                              activeColor: Colors.brown,
                              onChanged: (val) {
                                setSheetState(() {
                                  if(val == true) selectedAddons.add(addon);
                                  else selectedAddons.removeWhere((a) => a.id == addon.id);
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () {
                          setState(() {
                            _cart.add(CartItem(
                                product: product,
                                variant: variant,
                                addons: selectedAddons,
                                quantity: quantity
                            ));
                          });
                          Navigator.pop(context);
                        },
                        child: Text(
                            "Add to Order - Php ${((variant.price + selectedAddons.fold(0.0, (s, a) => s + a.price)) * quantity).toStringAsFixed(2)}",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                      )
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _processCheckout(BuildContext context, String paymentMethod) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator()));

    FirebaseFirestore db = FirebaseFirestore.instance;
    String todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      Map<String, int> inventoryNeeds = {};

      for (var cartItem in _cart) {
        for (var ingredient in cartItem.variant.recipe) {
          if (ingredient.inventoryId.isEmpty) continue;
          String id = ingredient.inventoryId;
          int qty = ingredient.quantity * cartItem.quantity;
          inventoryNeeds[id] = (inventoryNeeds[id] ?? 0) + qty;
        }
        for (var addon in cartItem.addons) {
          for (var ingredient in addon.recipe) {
            if (ingredient.inventoryId.isEmpty) continue;
            String id = ingredient.inventoryId;
            int qty = ingredient.quantity * cartItem.quantity;
            inventoryNeeds[id] = (inventoryNeeds[id] ?? 0) + qty;
          }
        }
      }

      await db.runTransaction((transaction) async {
        Map<String, DocumentSnapshot> inventorySnapshots = {};
        for (String invId in inventoryNeeds.keys) {
          DocumentReference ref = db.collection('inventory_items').doc(invId);
          DocumentSnapshot snap = await transaction.get(ref);
          inventorySnapshots[invId] = snap;
        }

        DocumentReference receiptRef = db.collection('transactions').doc();
        Map<String, dynamic> receiptData = {
          'timestamp': FieldValue.serverTimestamp(),
          'paymentMethod': paymentMethod,
          'total': _cart.fold(0.0, (sum, i) => sum + i.totalPrice),
          'items': _cart.map((i) => {
            'product': i.product.name,
            'variant': i.variant.name,
            'quantity': i.quantity,
            'addons': i.addons.map((a) => a.name).toList(),
            'price': i.totalPrice
          }).toList()
        };
        transaction.set(receiptRef, receiptData);

        DocumentReference dailyRef = db.collection('daily_sales').doc(todayDocId);
        transaction.set(dailyRef, {'last_updated': FieldValue.serverTimestamp()}, SetOptions(merge: true));

        inventoryNeeds.forEach((invId, qtyNeeded) {
          DocumentSnapshot snap = inventorySnapshots[invId]!;
          if (snap.exists) {
            var data = snap.data() as Map<String, dynamic>;
            int currentKitchen = data['stockDisplay'] ?? 0;
            int currentStorage = data['stockStorage'] ?? 0;

            transaction.update(snap.reference, {
              'stockDisplay': currentKitchen - qtyNeeded,
              'currentStock': (currentKitchen + currentStorage) - qtyNeeded
            });
          }
        });
      });

      // FIX: Use context safety
      Navigator.of(context).pop();
      // Safe check for screen size before second pop
      if (MediaQuery.of(context).size.width <= 600) Navigator.of(context).pop();

      double paid = double.tryParse(_cashController.text) ?? 0.0;
      double total = _cart.fold(0.0, (sum, i) => sum + i.totalPrice);
      double finalChange = paid - total;

      setState(() {
        _cart.clear();
        _cashController.clear();
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 50),
              SizedBox(height: 10),
              Text("Success!"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Transaction Complete"),
              if (paymentMethod == 'Cash') ...[
                Divider(),
                Text("Change Due:", style: TextStyle(color: Colors.grey)),
                Text("Php ${finalChange.toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown)),
              ]
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Next Order"))],
        ),
      );

    } catch (e) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Error"),
          content: Text("$e"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
        ),
      );
    }
  }
}