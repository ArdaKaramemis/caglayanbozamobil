// lib/screens/add_batch_screen.dart

import 'package:flutter/material.dart';
import 'package:caglayanbozamobil/models/batch.dart';
import 'package:caglayanbozamobil/models/product.dart';
import 'package:caglayanbozamobil/services/database_service.dart';
import 'package:caglayanbozamobil/models/market.dart';
import 'package:caglayanbozamobil/services/notification_service.dart'; // import added
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth erişimi için

class AddBatchScreen extends StatefulWidget {
  const AddBatchScreen({super.key});

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  // Form Değerleri
  Product? _selectedProduct;
  Market? _selectedMarket;
  final TextEditingController _quantityController = TextEditingController();
  DateTime _productionDate = DateTime.now();

  // Veritabanından çekilecek listeler
  List<Product> _availableProducts = [];
  List<Market> _availableMarkets = []; // Market tipinde liste
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermission(); // Yetki kontrolü
    _loadData(); // Ürün ve Marketleri aynı anda yükle
  }


  // YENİ: Yetki Kontrolü
  void _checkPermission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pop(context); // Oturum yoksa at
      return;
    }

    // DatabaseService üzerinden rolü kontrol et
    final appUser = await _dbService.getAppUser(user.uid);
    if (appUser == null || !appUser.isManager) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('HATA: Bu işlem için yetkiniz yok (Yönetici değilsiniz).'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context); // Yetkisiz giriş, geri gönder
      }
    }
  }

  // Ürünleri ve Marketleri Firestore'dan yükleme (GÜNCELLENDİ)
  void _loadData() async {
    try {
      // Load products and markets in parallel to reduce startup block time
      final results = await Future.wait([
        _dbService.getProductsList(),
        _dbService.getMarketsList(),
      ]);

      final List<Product> products = results[0] as List<Product>;
      final List<Market> markets = results[1] as List<Market>;

      setState(() {
        _isLoading = false;
        _availableProducts = products;
        _availableMarkets = markets;

        if (_availableProducts.isNotEmpty) {
          _selectedProduct = _availableProducts.first;
        }
        if (_availableMarkets.isNotEmpty) {
          _selectedMarket = _availableMarkets.first;
        }
      });
    } catch (e) {
      // Hata yönetimi
      debugPrint("Veri yükleme hatası: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // SKT Hesaplama Mantığı
  DateTime _calculateExpiryDate() {
    if (_selectedProduct == null) return DateTime.now();
    return _productionDate.add(
      Duration(days: _selectedProduct!.defaultShelfLifeDays),
    );
  }

  // (Kaldırılan) _updateExpiryDate fonksiyonu gereksizdi ve silindi.

  // Stok Girişi Yapma Fonksiyonu
  void _saveBatch() async {
    // Market ve Ürün seçimi kontrolü eklendi
    if (_formKey.currentState!.validate() &&
        _selectedProduct != null &&
        _selectedMarket != null) {
      final int quantity = int.tryParse(_quantityController.text) ?? 0;
      final expiryDate = _calculateExpiryDate();

      if (quantity <= 0) return;

      final newBatch = Batch(
        id: '', // Firestore tarafından atanacak
        productId: _selectedProduct!.id,
        marketId: _selectedMarket!.id, // marketId eklendi
        productionDate: _productionDate,
        initialQuantity: quantity,
        currentQuantity:
            quantity, // Yeni stok girişi olduğu için başlangıç ve mevcut aynı
        expiryDate: expiryDate,
      );

      await _dbService.addBatch(newBatch);

      // 1. Veritabanına Bildirim Kaydı (Diğerleri için)
      // Tarih formatlama
      final String urt = "${_productionDate.day}.${_productionDate.month}.${_productionDate.year}";
      final String skt = "${expiryDate.day}.${expiryDate.month}.${expiryDate.year}";

      await _dbService.addNotification(
        title: "Stoklar Güncellendi",
        body: "${_selectedMarket!.name}: ${_selectedProduct!.name} eklendi. ($quantity Adet)\n(ÜRT: $urt - SKT: $skt)",
        type: 'stock_added',
      );

      // 2. Yerel Bildirim (Kendi ekranım için anında geri bildirim)
      // Firestore dinleyicisi gecikebilir veya filtreleyebilir, bu yüzden garanti olsun.
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000, 
        title: "İşlem Başarılı: Yeni Stok",
        body: "${_selectedProduct!.name} başarıyla eklendi.",
      );

      if (mounted) {
        // SnackBar da gösterelim ama bildirim isteği üzerine bildirim de ekledik.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yeni stok partisi başarıyla eklendi!')),
        );
        Navigator.pop(context); // İşlem başarılı, ana ekrana dön
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Otomatik hesaplanan SKT
    final DateTime expiryDate = _calculateExpiryDate();

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Stok Girişi')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 1. Market Seçimi (Dropdown)
                    const Text(
                      '1. Market Seçimi:',
                      style: TextStyle(fontSize: 16),
                    ),
                    DropdownButtonFormField<Market>(
                      initialValue: _selectedMarket,
                      items: _availableMarkets.map((market) {
                        return DropdownMenuItem(
                          value: market,
                          child: Text(market.name),
                        );
                      }).toList(),
                      onChanged: (Market? newValue) {
                        setState(() {
                          _selectedMarket = newValue;
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null ? 'Lütfen bir market seçin.' : null,
                    ),
                    const SizedBox(height: 20),

                    // 2. Ürün Türü Seçimi (Dropdown)
                    const Text('2. Ürün Türü:', style: TextStyle(fontSize: 16)),
                    DropdownButtonFormField<Product>(
                      // Product objesi kullanılıyor
                      initialValue: _selectedProduct,
                      isExpanded: true,
                      items: _availableProducts.map((product) {
                        return DropdownMenuItem<Product>(
                          // <<< Tür belirtildi
                          value:
                              product, // Product nesnesini değer olarak kullan
                          child: Text(product.name),
                        );
                      }).toList(),
                      onChanged: (Product? newValue) {
                        setState(() {
                          _selectedProduct = newValue;
                          // Otomatik SKT hesaplamasını tetikleme: setState zaten build'i çağırır ve bu da SKT'yi hesaplar.
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null ? 'Lütfen bir ürün seçin.' : null,
                    ),
                    const SizedBox(height: 20),

                    // 3. Üretim Miktarı
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '3. Üretilen Miktar (Adet)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (int.tryParse(value ?? '') == null ||
                            int.parse(value!) <= 0) {
                          return 'Geçerli bir adet girmelisiniz.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 4. Üretim Tarihi Seçimi
                    const Text(
                      '4. Üretim Tarihi:',
                      style: TextStyle(fontSize: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        '${_productionDate.day}.${_productionDate.month}.${_productionDate.year}',
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _productionDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && picked != _productionDate) {
                          setState(() {
                            _productionDate = picked;
                          });
                        }
                      },
                    ),
                    const Divider(),

                    // 5. Son Kullanım Tarihi (SKT) Gösterimi (Otomatik Hesaplanan)
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info, color: Colors.blue),
                          const SizedBox(width: 10),
                          Text(
                            'OTOMATİK SKT: ${expiryDate.day}.${expiryDate.month}.${expiryDate.year}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 21, 101, 192),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Kaydet Butonu
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveBatch,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 15,
                          ),
                        ),
                        child: const Text(
                          'Stoğa Ekle (Parti Girişi)',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
