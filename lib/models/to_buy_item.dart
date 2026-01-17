import 'package:cloud_firestore/cloud_firestore.dart';

class ToBuyItem {
  final String id;
  final String name;
  final int targetQuantity; // What admin wants
  final String note;
  final bool isDone;
  final String inventoryId; // Link back to original item

  ToBuyItem({
    required this.id,
    required this.name,
    required this.targetQuantity,
    this.note = '',
    this.isDone = false,
    required this.inventoryId,
  });

  factory ToBuyItem.fromMap(Map<String, dynamic> data, String documentId) {
    return ToBuyItem(
      id: documentId,
      name: data['name'] ?? '',
      targetQuantity: data['targetQuantity'] ?? 0,
      note: data['note'] ?? '',
      isDone: data['isDone'] ?? false,
      inventoryId: data['inventoryId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'targetQuantity': targetQuantity,
      'note': note,
      'isDone': isDone,
      'inventoryId': inventoryId,
      'createdAt': FieldValue.serverTimestamp(), // Helps sort by date
    };
  }
}