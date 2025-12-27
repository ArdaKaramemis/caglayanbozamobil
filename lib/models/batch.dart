// lib/models/batch.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Batch {
  final String id;
  final String productId; // İlişkili Product ID'si
  final String marketId; // <<< YENİ ALAN: Hangi markete gönderildiği
  final DateTime productionDate; // Üretim Tarihi
  final int initialQuantity; // İlk Üretim Miktarı
  final int currentQuantity; // Mevcut Stok Miktarı
  final DateTime expiryDate; // Son Kullanma Tarihi

  Batch({
    required this.id,
    required this.productId,
    required this.marketId, // <<< YENİ EKLEME
    required this.productionDate,
    required this.initialQuantity,
    required this.currentQuantity,
    required this.expiryDate,
  });

  factory Batch.fromFirestore(Map<String, dynamic> data, String id) {
    // Firestore'dan Timestamp (Zaman Damgası) olarak gelen tarihleri DateTime'a çeviriyoruz
    final productionTimestamp = data['productionDate'] as Timestamp?;
    final expiryTimestamp = data['expiryDate'] as Timestamp?;

    return Batch(
      id: id,
      productId: data['productId'] ?? '',
      marketId: data['marketId'] ?? '', // <<< YENİ EKLEME
      productionDate: productionTimestamp?.toDate() ?? DateTime.now(),
      initialQuantity: data['initialQuantity'] ?? 0,
      currentQuantity: data['currentQuantity'] ?? 0,
      expiryDate: expiryTimestamp?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'marketId': marketId, // <<< YENİ EKLEME
      'productionDate': productionDate,
      'initialQuantity': initialQuantity,
      'currentQuantity': currentQuantity,
      'expiryDate': expiryDate,
    };
  }
}
