// lib/models/market.dart

class Market {
  final String id;
  final String name; // Marketin adı (Örn: Çağlayan AVM, Merkez Şube)
  final double? latitude;
  final double? longitude;

  Market({
    required this.id, 
    required this.name,
    this.latitude,
    this.longitude,
  });

  factory Market.fromFirestore(Map<String, dynamic> data, String id) {
    return Market(
      id: id, 
      name: data['name'] ?? 'Bilinmeyen Market',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
