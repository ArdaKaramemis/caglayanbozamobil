// lib/models/product.dart

class Product {
  final String id;
  final String name; // Ürünün adı (Örn: Klasik Boza 1 Litre)
  final String description;
  final int defaultShelfLifeDays;
  final String? barcode; // Stok düşüşü için kritik

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultShelfLifeDays,
    this.barcode,
  });

  factory Product.fromFirestore(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      defaultShelfLifeDays: data['defaultShelfLifeDays'] is int
          ? data['defaultShelfLifeDays'] as int
          : int.tryParse(data['defaultShelfLifeDays']?.toString() ?? '') ?? 0,
      barcode: data['barcode']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'defaultShelfLifeDays': defaultShelfLifeDays,
      'barcode': barcode,
    };
  }
}
