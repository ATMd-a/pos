class InventoryItem {
  final String id;
  final String name;
  final String category; // 'Milk Tea', 'Takoyaki', 'Pizza'
  final int currentStock;
  final int lowStockThreshold;
  final String unit; // 'pcs', 'kg', 'bottles'

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.lowStockThreshold,
    required this.unit,
  });

  // Convert from Firestore data to our App data
  factory InventoryItem.fromMap(Map<String, dynamic> data, String documentId) {
    return InventoryItem(
      id: documentId,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Other',
      currentStock: data['currentStock'] ?? 0,
      lowStockThreshold: data['lowStockThreshold'] ?? 5,
      unit: data['unit'] ?? 'pcs',
    );
  }

  // Convert from App data to Firestore data
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'currentStock': currentStock,
      'lowStockThreshold': lowStockThreshold,
      'unit': unit,
    };
  }
}