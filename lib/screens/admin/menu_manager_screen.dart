import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../models/menu_models.dart';

class MenuManagerScreen extends StatefulWidget {
  @override
  _MenuManagerScreenState createState() => _MenuManagerScreenState();
}

class _MenuManagerScreenState extends State<MenuManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> categories = [
    'Regular Series', 'Cheesecake Series', 'Cream Cheese Series',
    'Oreo Series', 'Chocolate Series', 'Yakult Series', 'Nutella Series',
    'Takoyaki 2-3', 'Takoyaki Solo', 'Pizza', 'Fries'
  ];

  String selectedCategory = 'Regular Series';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Menu & Recipe Manager"),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: "Products"), Tab(text: "Add-ons")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductManager(),
          _buildAddOnManager(),
        ],
      ),
    );
  }

  // --- TAB 1: PRODUCT MANAGER ---
  Widget _buildProductManager() {
    return Column(
      children: [
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
                  selected: selectedCategory == c,
                  onSelected: (val) => setState(() => selectedCategory = c),
                  backgroundColor: Colors.white,
                  selectedColor: Colors.brown[200],
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text("Add New ${selectedCategory.split(' ').first}"),
            onPressed: () => _showProductDialog(context, null),
            style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 45)),
          ),
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
              if (docs.isEmpty) return Center(child: Text("No items in $selectedCategory yet."));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var product = Product.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ExpansionTile(
                      title: Text(product.name, style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${product.variants.length} Sizes/Variants"),
                      children: [
                        ...product.variants.map((v) => ListTile(
                          title: Text("${v.name} - Php ${v.price}"),
                          subtitle: Text(
                            "Recipe: " + (v.recipe.isEmpty ? "None" : v.recipe.map((r) => "${r.quantity} ${r.inventoryName}").join(", ")),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          dense: true,
                        )),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(child: Text("Edit"), onPressed: () => _showProductDialog(context, product)),
                            TextButton(child: Text("Delete", style: TextStyle(color: Colors.red)), onPressed: () => FirebaseFirestore.instance.collection('products').doc(product.id).delete()),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 2: ADD-ON MANAGER ---
  Widget _buildAddOnManager() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text("Add New Add-on"),
            onPressed: () => _showAddOnDialog(context, null),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('addons').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var addon = AddOn.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
                  return ListTile(
                    title: Text(addon.name),
                    trailing: Text("+ Php ${addon.price}"),
                    subtitle: Text(addon.recipe.isEmpty ? "No recipe linked" : "Deducts: ${addon.recipe.first.inventoryName}..."),
                    onTap: () => _showAddOnDialog(context, addon),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  // ==============================================================================
  // DIALOGS
  // ==============================================================================

  void _showProductDialog(BuildContext context, Product? product) {
    bool isEditing = product != null;
    TextEditingController nameCtrl = TextEditingController(text: isEditing ? product.name : '');
    String currentCategory = isEditing ? product.category : selectedCategory;
    List<ProductVariant> tempVariants = isEditing ? List.from(product.variants) : [ProductVariant(name: "", price: 0, recipe: [])];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? "Edit Product" : "New Product"),
            content: Container(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Product Name")),
                    SizedBox(height: 10),
                    DropdownButton<String>(
                      value: currentCategory,
                      isExpanded: true,
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setStateDialog(() => currentCategory = val!),
                    ),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Sizes & Prices", style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          icon: Icon(Icons.add),
                          label: Text("Add Size"),
                          onPressed: () => setStateDialog(() => tempVariants.add(ProductVariant(name: "", price: 0, recipe: []))),
                        )
                      ],
                    ),
                    Container(
                      height: 250,
                      child: ListView.builder(
                        itemCount: tempVariants.length,
                        itemBuilder: (context, index) {
                          var variant = tempVariants[index];
                          var rowNameCtrl = TextEditingController(text: variant.name);
                          var rowPriceCtrl = TextEditingController(text: variant.price == 0 ? "" : variant.price.toString());
                          rowNameCtrl.selection = TextSelection.fromPosition(TextPosition(offset: rowNameCtrl.text.length));

                          return Card(
                            color: Colors.grey[50],
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(flex: 2, child: TextField(controller: rowNameCtrl, decoration: InputDecoration(labelText: "Size", isDense: true), onChanged: (val) => variant.name = val)),
                                      SizedBox(width: 10),
                                      Expanded(flex: 1, child: TextField(controller: rowPriceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Price", isDense: true), onChanged: (val) => variant.price = double.tryParse(val) ?? 0)),
                                      IconButton(icon: Icon(Icons.close, color: Colors.red), onPressed: () => setStateDialog(() => tempVariants.removeAt(index)))
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        icon: Icon(Icons.link, size: 16),
                                        label: Text("Edit Recipe (${variant.recipe.length})"),
                                        style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                        onPressed: () async {
                                          // OPEN NEW MULTI-PICKER
                                          List<RecipeIngredient> updatedRecipe = await _showMultiIngredientPicker(context, variant.recipe);
                                          setStateDialog(() => variant.recipe = updatedRecipe);
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          variant.recipe.map((r) => "${r.quantity} ${r.inventoryName}").join(", "),
                                          style: TextStyle(fontSize: 10, color: Colors.grey),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
              ElevatedButton(
                child: Text("Save Product"),
                onPressed: () {
                  if (nameCtrl.text.isEmpty) return;
                  tempVariants.removeWhere((v) => v.name.isEmpty);
                  var newProduct = Product(id: isEditing ? product.id : '', name: nameCtrl.text, category: currentCategory, variants: tempVariants);
                  if (isEditing) FirebaseFirestore.instance.collection('products').doc(product.id).update(newProduct.toMap());
                  else FirebaseFirestore.instance.collection('products').add(newProduct.toMap());
                  Navigator.pop(context);
                },
              )
            ],
          );
        });
      },
    );
  }

  void _showAddOnDialog(BuildContext context, AddOn? addon) {
    bool isEditing = addon != null;
    TextEditingController nameCtrl = TextEditingController(text: isEditing ? addon.name : '');
    TextEditingController priceCtrl = TextEditingController(text: isEditing ? addon.price.toString() : '');
    List<RecipeIngredient> tempRecipe = isEditing ? List.from(addon.recipe) : [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateAddon) {
        return AlertDialog(
          title: Text(isEditing ? "Edit Add-on" : "New Add-on"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Name")),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Price")),
                Divider(),
                ListTile(
                  title: Text("Recipe Ingredients"),
                  subtitle: Text(tempRecipe.map((r) => "${r.quantity} ${r.inventoryName}").join(", ")),
                  trailing: Icon(Icons.edit),
                  onTap: () async {
                    // OPEN NEW MULTI-PICKER
                    List<RecipeIngredient> updated = await _showMultiIngredientPicker(context, tempRecipe);
                    setStateAddon(() => tempRecipe = updated);
                  },
                )
              ],
            ),
          ),
          actions: [
            if (isEditing) TextButton(child: Text("Delete", style: TextStyle(color: Colors.red)), onPressed: () { FirebaseFirestore.instance.collection('addons').doc(addon.id).delete(); Navigator.pop(context); }),
            ElevatedButton(child: Text("Save"), onPressed: () {
              var data = AddOn(id: '', name: nameCtrl.text, price: double.tryParse(priceCtrl.text)??0, recipe: tempRecipe).toMap();
              if (isEditing) FirebaseFirestore.instance.collection('addons').doc(addon.id).update(data);
              else FirebaseFirestore.instance.collection('addons').add(data);
              Navigator.pop(context);
            })
          ],
        );
      }),
    );
  }

  // 3. *** NEW MULTI-SELECT RECIPE PICKER ***
  // This allows selecting multiple ingredients without closing the dialog
  Future<List<RecipeIngredient>> _showMultiIngredientPicker(BuildContext context, List<RecipeIngredient> currentRecipe) async {
    // 1. Create a map of currently selected items to track counts
    Map<String, RecipeIngredient> selectionMap = {};
    for (var r in currentRecipe) {
      selectionMap[r.inventoryId] = r;
    }

    String selectedCat = "All";
    final List<String> invCats = ["All", "Milk Tea", "Takoyaki", "Pizza", "Fries", "Yakult", "Others"];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            return AlertDialog(
              title: Text("Recipe Builder"),
              content: Container(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    // Category Filter
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCat,
                          isExpanded: true,
                          items: invCats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) => setPickerState(() => selectedCat = val!),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('inventory_items').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                          var docs = snapshot.data!.docs;
                          var filtered = docs.where((doc) {
                            var d = doc.data() as Map<String, dynamic>;
                            if (selectedCat == "All") return true;
                            return (d['category'] ?? 'Others') == selectedCat;
                          }).toList();
                          filtered.sort((a,b) => (a['name'] as String).compareTo(b['name'] as String));

                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              var doc = filtered[index];
                              var data = doc.data() as Map<String, dynamic>;
                              String id = doc.id;

                              // Check if item is already in selection
                              int currentQty = selectionMap[id]?.quantity ?? 0;
                              bool isSelected = currentQty > 0;

                              return Card(
                                color: isSelected ? Colors.green[50] : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(data['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text("Stock: ${data['currentStock']}", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                      ),

                                      // INCREMENT / DECREMENT CONTROLS
                                      Container(
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.grey[300]!)
                                        ),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.remove, size: 16, color: Colors.red),
                                              constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                if (currentQty > 0) {
                                                  setPickerState(() {
                                                    if (currentQty == 1) {
                                                      selectionMap.remove(id);
                                                    } else {
                                                      selectionMap[id]!.quantity--;
                                                    }
                                                  });
                                                }
                                              },
                                            ),
                                            Text(
                                                "$currentQty",
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Colors.green : Colors.grey)
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.add, size: 16, color: Colors.green),
                                              constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                setPickerState(() {
                                                  if (currentQty == 0) {
                                                    selectionMap[id] = RecipeIngredient(inventoryId: id, inventoryName: data['name'], quantity: 1);
                                                  } else {
                                                    selectionMap[id]!.quantity++;
                                                  }
                                                });
                                              },
                                            ),
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
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  child: Text("DONE / SAVE RECIPE"),
                  onPressed: () {
                    // Convert Map values back to List
                    Navigator.pop(context, selectionMap.values.toList());
                  },
                )
              ],
            );
          },
        );
      },
    );

    // Safety check in case dialog is dismissed without saving
    return selectionMap.values.toList();
  }
}