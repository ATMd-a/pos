class Product {
  String id;
  String name;      // e.g. "Wintermelon"
  String category;  // e.g. "Regular Series"
  List<ProductVariant> variants; // e.g. [16oz, 22oz, 1L]

  Product({required this.id, required this.name, required this.category, required this.variants});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'variants': variants.map((v) => v.toMap()).toList(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Others',
      variants: (data['variants'] as List? ?? []).map((x) => ProductVariant.fromMap(x)).toList(),
    );
  }
}

class ProductVariant {
  String name; // "16oz"
  double price; // 59.0
  List<RecipeIngredient> recipe; // List of inventory items to deduct

  ProductVariant({required this.name, required this.price, required this.recipe});

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'recipe': recipe.map((r) => r.toMap()).toList(),
  };

  factory ProductVariant.fromMap(Map<String, dynamic> data) {
    return ProductVariant(
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      recipe: (data['recipe'] as List? ?? []).map((x) => RecipeIngredient.fromMap(x)).toList(),
    );
  }
}

class AddOn {
  String id;
  String name; // "Tapioca Pearl"
  double price; // 10.0
  List<RecipeIngredient> recipe;

  AddOn({required this.id, required this.name, required this.price, required this.recipe});

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'recipe': recipe.map((r) => r.toMap()).toList(),
  };

  factory AddOn.fromMap(Map<String, dynamic> data, String id) {
    return AddOn(
      id: id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      recipe: (data['recipe'] as List? ?? []).map((x) => RecipeIngredient.fromMap(x)).toList(),
    );
  }
}

class RecipeIngredient {
  String inventoryId;   // "item005"
  String inventoryName; // "16oz Cup"
  int quantity;         // 1

  RecipeIngredient({required this.inventoryId, required this.inventoryName, required this.quantity});

  Map<String, dynamic> toMap() => {'inventoryId': inventoryId, 'inventoryName': inventoryName, 'quantity': quantity};

  factory RecipeIngredient.fromMap(Map<String, dynamic> data) {
    return RecipeIngredient(
      inventoryId: data['inventoryId'] ?? '',
      inventoryName: data['inventoryName'] ?? '',
      quantity: data['quantity'] ?? 0,
    );
  }
}