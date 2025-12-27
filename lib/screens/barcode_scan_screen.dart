import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/database_service.dart';
//import '../models/stock_result.dart';
import 'package:mobile_scanner/mobile_scanner.dart';


class BarcodeScanScreen extends StatefulWidget {
  final String marketId;
  final String marketName; // YENİ: Market adı eklendi

  const BarcodeScanScreen({
    super.key,
    required this.marketId,
    required this.marketName, // Zorunlu parametre
  });

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  String _statusMessage = 'Ürün barkodunu okutmak için hazır.';

  bool _askQuantity = false; // "Adet Sor" modu kapalı (hızlı mod)

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------
  // 1. ANA İŞLEM AKIŞI: Barkod Alındıktan Sonra (GÜNCELLENDİ)
  // ----------------------------------------------------
  void _processBarcode(String barcode) async {
    // Trim metodu, String'in başındaki ve sonundaki boşlukları siler.
    final trimmedBarcode = barcode.trim();
    _barcodeController.clear();
    FocusScope.of(context).unfocus();

    if (trimmedBarcode.isEmpty) {
      _updateStatus('Lütfen geçerli bir barkod okutun.', Colors.orange);
      return;
    }

    _updateStatus(
      'Tarama başarılı. Ürün kontrol ediliyor... ($trimmedBarcode)',
      Colors.blueGrey,
    );

    // 1. Ürünleri Barkoda Göre Ara (Firestore sorgusu ile optimize edildi)
    final products = await _dbService.getProductsByBarcode(trimmedBarcode);

    if (!mounted) return;

    if (products.isEmpty) {
      _updateStatus(
        "HATA: Barkod numarasıyla eşleşen bir ürün bulunamadı.",
        Colors.red,
      );
      return;
    }

    Product productToDeduct;

    if (products.length > 1) {
      // 1.1 Çift Barkod Tespiti: Kullanıcıya hangi üründen düşüş yapılacağını sor
      final selected = await _showProductSelectionDialog(products);
      if (!mounted) return;

      if (selected == null) {
        _updateStatus("İşlem iptal edildi.", Colors.orange);
        return;
      }
      productToDeduct = selected;
    } else {
      // 1.2 Tek ürün bulundu
      productToDeduct = products.first;
    }

    // 2. Miktar Kontrolü
    if (_askQuantity) {
      // "Adet Sor" modu açıksa diyaloğu göster
      final qty = await _showQuantityDialog(productToDeduct);
      if (qty != null && qty > 0) {
        await _deductStock(productToDeduct, qty);
      } else {
        _updateStatus(
          "İşlem iptal edildi veya geçersiz miktar.",
          Colors.orange,
        );
      }
    } else {
      // Hızlı mod: Direkt 1 adet düş
      await _deductStock(productToDeduct, 1);
    }
  }

  // ----------------------------------------------------
  // 2. YARDIMCI METOTLAR
  // ----------------------------------------------------

  // A. Stok Düşürme (FIFO Mantığı)
  Future<void> _deductStock(Product product, int amount) async {
    // Barcode check removed as we use ID now.
    final marketId = widget.marketId; // Market ID'sini buradan alıyoruz!

    // FIFO mantığı DatabaseService içindeki decreaseStockByProduct metodu tarafından halledilir
    // decreaseStockByProduct artık Market ID'sini ikinci argüman olarak alıyor

    final result = await _dbService.decreaseStockByProduct(
      product.id, // ID KULLANIYORUZ
      marketId,
      amount,
      product.name, // Ürün adı eklendi
    );

    if (!mounted) return;

    if (result.isSuccess) {
      _updateStatus(
        "✅ ${product.name} için $amount adet stok düşüldü.",
        Colors.green,
      );

      // 1. Veritabanına Bildirim Ekle (Kaldırıldı - Sadece kritik stokta gidecek)
      // await _dbService.addNotification(...)

      // 2. Yerel Bildirim (Kaldırıldı - Sadece kritik stokta gidecek)
      // await NotificationService().showNotification(...)
    } else {
      // Detaylı Hata Mesajı
      _updateStatus("HATA: ${result.message}", Colors.red);
    }
  }

  // B. Çift Barkod Seçim Diyaloğu
  Future<Product?> _showProductSelectionDialog(List<Product> products) {
    return showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Çift Barkod Tespit Edildi'),
          content: const Text('Lütfen hangi üründen düşüş yapılacağını seçin:'),
          actions: [
            ...products.map((product) {
              return TextButton(
                child: Text('${product.name} (${product.description})'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(product);
                },
              );
            }).toList(),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(null); // İptal
              },
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  // YENİ: Miktar Sorma Diyaloğu
  Future<int?> _showQuantityDialog(Product product) {
    final TextEditingController qtyController = TextEditingController(
      text: '1',
    );
    return showDialog<int>(
      context: context,
      barrierDismissible: false, // Dışarı tıklayınca kapanmasın
      builder: (context) {
        return AlertDialog(
          title: Text('${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Kaç adet düşülecek?"),
              const SizedBox(height: 10),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Adet',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(qtyController.text);
                Navigator.pop(context, val);
              },
              child: const Text("ONAYLA"),
            ),
          ],
        );
      },
    );
  }

  // C. Durum Güncelleme Metodu
  void _updateStatus(String message, Color color) {
    if (mounted) {
      setState(() {
        // Hata durumunda metin rengini ayarla
        // Bu kısım orijinal kodda yoktu, ancak durum mesajını daha belirgin hale getirir.
        // Orijinal koddaki _updateStatus metodunda renk parametresi kullanılmadığı için
        // bu renk parametresini kullanmayıp sadece mesajı güncelliyorum:
        _statusMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barkod ile Stok Çıkışı')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // YENİ: Toplu Düşüm Modu Switch
            SwitchListTile(
              title: const Text(
                'Toplu Düşüm (Adet Sor)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Barkod okunduktan sonra adet sorulur.'),
              value: _askQuantity,
              onChanged: (val) {
                setState(() {
                  _askQuantity = val;
                });
              },
            ),
            const Divider(),

            // 1. Barkod Giriş/Okuma Alanı
            TextFormField(
              controller: _barcodeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Barkod Numarası',
                hintText: 'Cihaz barkodu buraya yazar (veya manuel girin)',
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted:
                  _processBarcode, // ENTER tuşu basıldığında çalışır
            ),
            const SizedBox(height: 30),

            // 2. Durum Bilgisi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.lightBlue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_statusMessage, style: const TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 20),

            // 3. Manüel Düşüş Butonu (Opsiyonel)
            ElevatedButton.icon(
              onPressed: () => _processBarcode(_barcodeController.text),
              icon: const Icon(Icons.keyboard),
              label: const Text('Manuel Olarak Düş'),
            ),

            const SizedBox(height: 20),

            // 4. Kamera ile Tara Butonu (YENİ)
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _scanWithCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('KAMERA İLE TARA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // YENİ: Kamera ile Tarama Fonksiyonu
  void _scanWithCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Barkod Tara')),
          body: MobileScanner(
            // fit: BoxFit.contain, // Uygun sığdırma (iptal, varsayılan cover iyidir)
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  debugPrint('Barkod Bulundu: $code');
                  Navigator.of(context).pop(); // Kamerayı kapat
                  _processBarcode(code); // İşleme al
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
