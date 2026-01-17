import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class InventoryScreen extends StatefulWidget {
  final String userRole; // 'admin' or 'staff'

  InventoryScreen({required this.userRole});

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> itemCategories = [
    'Milk Tea', 'Takoyaki', 'Pizza', 'Fries', 'Yakult', 'Others', 'Powders'
  ];

  final List<String> setCategories = [
    'Takoyaki', 'Pizza'
  ];

  String selectedItemCategory = 'Milk Tea';
  String selectedSetCategory = 'Takoyaki';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Inventory"),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Items"),
            Tab(text: "Sets"),
          ],
        ),
        actions: [
          // 1. REPAIR BUTTON (ADMIN ONLY) - CLICK THIS TO FIX OLD ITEMS
          if (widget.userRole == 'admin')
            IconButton(
              icon: Icon(Icons.build, color: Colors.orange), // The Wrench
              tooltip: "Fix Old Data",
              onPressed: () => _fixOldData(context),
            ),

          // 2. ADD BUTTON (ADMIN ONLY)
          if (widget.userRole == 'admin')
            IconButton(
              icon: Icon(Icons.add_circle),
              onPressed: () {
                // Determine which tab is active to set the default type
                String type = _tabController.index == 0 ? 'item' : 'set';
                String cat = _tabController.index == 0 ? selectedItemCategory : selectedSetCategory;
                _showAddEditItemDialog(context, null, type, cat);
              },
            )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: ITEMS
          _buildInventoryManager(
              categories: itemCategories,
              selectedCat: selectedItemCategory,
              type: 'item',
              onCatSelect: (val) => setState(() => selectedItemCategory = val)
          ),

          // TAB 2: SETS
          _buildInventoryManager(
              categories: setCategories,
              selectedCat: selectedSetCategory,
              type: 'set',
              onCatSelect: (val) => setState(() => selectedSetCategory = val)
          ),
        ],
      ),
    );
  }

  // --- REPAIR SCRIPT (Fixes the missing items) ---
  Future<void> _fixOldData(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator()));

    var collection = FirebaseFirestore.instance.collection('inventory_items');
    var snapshot = await collection.get();

    int count = 0;
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var doc in snapshot.docs) {
      var data = doc.data();
      // If the item doesn't have a 'type', give it one!
      if (data['type'] == null) {
        // If it's Pizza or Takoyaki, assume it might be a set, otherwise item.
        // For safety, we default everything to 'item' so you can see them in the first tab.
        batch.update(doc.reference, {'type': 'item'});
        count++;
      }
    }

    await batch.commit();
    Navigator.pop(context); // Close loading

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Fixed $count items! They should appear in 'Items' tab now."),
      backgroundColor: Colors.green,
    ));
  }

  // --- REUSABLE BUILDER ---
  Widget _buildInventoryManager({
    required List<String> categories,
    required String selectedCat,
    required String type,
    required Function(String) onCatSelect
  }) {
    return Column(
      children: [
        // Horizontal Scroll
        Container(
          height: 60,
          color: Colors.grey[100],
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.all(8),
            children: categories.map((c) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(c),
                  selected: selectedCat == c,
                  onSelected: (val) => onCatSelect(c),
                  backgroundColor: Colors.white,
                  selectedColor: Colors.brown[200],
                ),
              );
            }).toList(),
          ),
        ),

        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('inventory_items')
                .where('category', isEqualTo: selectedCat)
                .where('type', isEqualTo: type) // FILTER BY TYPE
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

              var docs = snapshot.data!.docs;
              if (docs.isEmpty) return Center(child: Text("No $type found in $selectedCat"));

              List<DocumentSnapshot> sortedDocs = List.from(docs);
              sortedDocs.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                return (dataA['name'] ?? '').toString().toLowerCase().compareTo((dataB['name'] ?? '').toString().toLowerCase());
              });

              return ListView.builder(
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  return _buildInventoryCard(sortedDocs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- CARD UI ---
  Widget _buildInventoryCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    int stockStorage = data['stockStorage'] ?? 0;
    int stockDisplay = data['stockDisplay'] ?? 0;
    String note = data['note'] ?? '';

    if (data.containsKey('currentStock') && !data.containsKey('stockStorage')) {
      stockStorage = data['currentStock'];
    }

    int total = stockStorage + stockDisplay;
    String unit = data['unit'] ?? 'pcs';

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _showAddEditItemDialog(context, doc, data['type'] ?? 'item', data['category']),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'],
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                      child: Text("Total: $total $unit", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800], fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(children: [Text("Box", style: TextStyle(fontSize: 10, color: Colors.grey)), Text("$stockStorage", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
                    Container(width: 1, height: 25, color: Colors.grey[300], margin: EdgeInsets.symmetric(horizontal: 10)),
                    Column(children: [Text("Display", style: TextStyle(fontSize: 10, color: Colors.grey)), Text("$stockDisplay", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
                    if (note.isNotEmpty) ...[
                      Container(width: 1, height: 25, color: Colors.grey[300], margin: EdgeInsets.symmetric(horizontal: 10)),
                      Flexible(
                        child: Column(
                          children: [
                            Icon(Icons.sticky_note_2, size: 14, color: Colors.amber[700]),
                            Text(note, style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.brown), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DIALOG ---
  void _showAddEditItemDialog(BuildContext context, DocumentSnapshot? doc, String type, String currentCategory) {
    bool isEditing = doc != null;
    Map<String, dynamic> data = isEditing ? (doc.data() as Map<String, dynamic>) : {};

    TextEditingController nameCtrl = TextEditingController(text: isEditing ? data['name'] : '');
    TextEditingController unitCtrl = TextEditingController(text: isEditing ? data['unit'] : 'pcs');
    TextEditingController storageCtrl = TextEditingController(text: isEditing ? (data['stockStorage'] ?? data['currentStock'] ?? 0).toString() : '0');
    TextEditingController displayCtrl = TextEditingController(text: isEditing ? (data['stockDisplay'] ?? 0).toString() : '0');
    TextEditingController noteCtrl = TextEditingController(text: isEditing ? (data['note'] ?? '') : '');

    List<String> activeCategories = type == 'set' ? setCategories : itemCategories;
    String selectedCategory = isEditing ? (data['category'] ?? currentCategory) : currentCategory;
    if (!activeCategories.contains(selectedCategory)) selectedCategory = activeCategories[0];

    String itemName = isEditing ? data['name'] : "New Item";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? "Update $type" : "New $type"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.userRole == 'admin') ...[
                      TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Item Name", border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[50], prefixIcon: Icon(Icons.label, color: Colors.brown))),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4), color: Colors.grey[50]),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            items: activeCategories.map((String c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) => setState(() => selectedCategory = val!),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(controller: unitCtrl, decoration: InputDecoration(labelText: "Unit", border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[50], prefixIcon: Icon(Icons.scale, color: Colors.brown))),
                    ] else ...[
                      Text("Item Name", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(itemName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Divider(),
                    ],
                    SizedBox(height: 15),
                    Text("Inventory Counts", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    SizedBox(height: 10),
                    if (widget.userRole == 'staff') ...[
                      TextField(controller: storageCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "📦 Box", border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[50])),
                      SizedBox(height: 10),
                      TextField(controller: displayCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "🏪 Display", border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[50])),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("📦 Box: ${storageCtrl.text}", style: TextStyle(fontSize: 16)), SizedBox(height: 5), Text("🏪 Display: ${displayCtrl.text}", style: TextStyle(fontSize: 16)), SizedBox(height: 5), Text("Total: ${(int.tryParse(storageCtrl.text)??0) + (int.tryParse(displayCtrl.text)??0)}", style: TextStyle(fontWeight: FontWeight.bold)), Text("(Only staff can update counts)", style: TextStyle(fontSize: 10, color: Colors.red))]),
                      )
                    ],
                    SizedBox(height: 15),
                    TextField(controller: noteCtrl, decoration: InputDecoration(labelText: "Note", border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[50], prefixIcon: Icon(Icons.note, color: Colors.amber))),
                  ],
                ),
              ),
              actions: [
                if (isEditing && widget.userRole == 'admin') TextButton(child: Text("DELETE", style: TextStyle(color: Colors.red)), onPressed: () { FirebaseFirestore.instance.collection('inventory_items').doc(doc.id).delete(); Navigator.pop(context); }),
                ElevatedButton(
                  child: Text("Save Update"),
                  onPressed: () {
                    int sStorage = int.tryParse(storageCtrl.text) ?? 0;
                    int sDisplay = int.tryParse(displayCtrl.text) ?? 0;
                    Map<String, dynamic> newData = {
                      'category': selectedCategory,
                      'stockStorage': sStorage,
                      'stockDisplay': sDisplay,
                      'currentStock': sStorage + sDisplay,
                      'unit': unitCtrl.text,
                      'note': noteCtrl.text,
                      'type': type
                    };
                    if (widget.userRole == 'admin') newData['name'] = nameCtrl.text;
                    else newData['name'] = itemName;

                    if (isEditing) FirebaseFirestore.instance.collection('inventory_items').doc(doc.id).update(newData);
                    else FirebaseFirestore.instance.collection('inventory_items').add(newData);
                    Navigator.pop(context);
                  },
                )
              ],
            );
          },
        );
      },
    );
  }
}