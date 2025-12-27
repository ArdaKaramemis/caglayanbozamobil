import 'package:flutter/material.dart';
import '../models/market.dart';
import '../models/batch.dart';
import '../models/app_user.dart'; // import added
import '../services/auth_service.dart'; // import added
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Harita importu

import '../services/database_service.dart';
import 'barcode_scan_screen.dart';

class MarketDetailScreen extends StatefulWidget {
  final Market market;

  const MarketDetailScreen({super.key, required this.market});

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, String> _productNames = {}; // Ürün ID -> Ürün Adı
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductNames();
  }

  // Ürün adlarını çekmek için (Batch'lerde sadece productId var)
  void _loadProductNames() async {
    try {
      final products = await _dbService.getProductsList();
      if (mounted) {
        setState(() {
          _productNames = {
            for (var product in products) product.id: product.name
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Ürün adları yüklenirken hata: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Stok düşürme ekranına yönlendirme
  void _navigateToBarcodeScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BarcodeScanScreen(
          marketId: widget.market.id,
          marketName: widget.market.name, // İsim aktarılıyor
        ),
      ),
    );
  }

  // Market bazlı stokları gruplama (Adetleriyle birlikte Batch listesi döner)
  Map<String, List<Batch>> _groupBatchesByProduct(List<Batch> batches) {
    final grouped = <String, List<Batch>>{};

    for (final batch in batches) {
      // Sadece bu markete ait ve stoğu olan partileri al
      if (batch.marketId != widget.market.id || batch.currentQuantity <= 0) {
        continue;
      }

      final productName = _productNames[batch.productId] ?? 'Bilinmeyen Ürün';
      if (!grouped.containsKey(productName)) {
        grouped[productName] = [];
      }
      grouped[productName]!.add(batch);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.market.name} Stok Yönetimi')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.blueGrey.shade50,
                      child: Column(
                        children: [
                          Text(
                            widget.market.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<AppUser?>(
                            stream: AuthService().appUser,
                            builder: (context, snapshot) {
                              final user = snapshot.data;
                              if (user == null || !user.canDeduct) {
                                return const SizedBox.shrink();
                              }
                              if (user.assignedMarketId != null && user.assignedMarketId != widget.market.id) {
                                 return Container(
                                   padding: const EdgeInsets.all(10),
                                   decoration: BoxDecoration(
                                     color: Colors.red.shade100,
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: const Row(
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     children: [
                                       Icon(Icons.lock, color: Colors.red),
                                       SizedBox(width: 8),
                                       Text("Bu markette işlem yetkiniz yok.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                     ],
                                   ),
                                 );
                              }
                              return SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _navigateToBarcodeScan,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text(
                                    'BARKOD İLE STOK DÜŞÜR',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 62, 185, 66),
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          if (widget.market.latitude != null && widget.market.longitude != null) ...[
                            const Divider(),
                            const Text(
                              "Konum",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 200,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(widget.market.latitude!, widget.market.longitude!),
                                    zoom: 15,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId('marketLocation'),
                                      position: LatLng(widget.market.latitude!, widget.market.longitude!),
                                      infoWindow: InfoWindow(title: widget.market.name),
                                    ),
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Mevcut Stok Durumu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: StreamBuilder<List<Batch>>(
                stream: _dbService.getBatches(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Hata oluştu: ${snapshot.error}'));
                  }

                  final batches = snapshot.data ?? [];
                  final productStocks = _groupBatchesByProduct(batches);

                  if (productStocks.isEmpty) {
                    return const Center(
                      child: Text(
                        'Bu markette henüz stok bulunmamaktadır.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  final sortedKeys = productStocks.keys.toList();
                  sortedKeys.sort((a, b) {
                    final aName = a.toLowerCase();
                    final bName = b.toLowerCase();
                    final aIs1L = aName.contains('1l') || aName.contains('1 l') || aName.contains('1000') || aName.contains('1 litre');
                    final bIs1L = bName.contains('1l') || bName.contains('1 l') || bName.contains('1000') || bName.contains('1 litre');

                    if (aIs1L && !bIs1L) return -1;
                    if (!aIs1L && bIs1L) return 1;
                    return a.compareTo(b);
                  });

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: sortedKeys.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final productName = sortedKeys[index];
                      final batchList = productStocks[productName]!;
                      
                      final totalQty = batchList.fold<int>(0, (sum, item) => sum + item.currentQuantity);
                      batchList.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

                      return ListTile(
                        leading: _getProductImage(productName),
                        title: Text(
                          productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            ...batchList.map((b) {
                               final exp = "${b.expiryDate.day}.${b.expiryDate.month}.${b.expiryDate.year}";
                               final prod = "${b.productionDate.day}.${b.productionDate.month}.${b.productionDate.year}";
                               
                               return Padding(
                                 padding: const EdgeInsets.symmetric(vertical: 2.0),
                                 child: Text(
                                   "• ÜRT: $prod | SKT: $exp  (${b.currentQuantity} Adet)",
                                   style: const TextStyle(fontSize: 12, color: Colors.black54),
                                 ),
                               );
                            }).toList(),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$totalQty Adet',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  // YENİ: Ürün adına göre özel görsel getiren metot
  // YENİ: Ürün adına göre özel görsel getiren metot
  Widget _getProductImage(String productName) {
    // Normalizasyon (küçük harf, vs) yapılabilir
    final lowerName = productName.toLowerCase();

    // 1 Litre Kontrolü
    if (lowerName.contains('1l') || 
        lowerName.contains('1 l') || 
        lowerName.contains('1 litre') ||
        lowerName.contains('1litre') ||
        lowerName.contains('1000') ||
        lowerName.contains('1 lt') ||
        lowerName.contains('1lt')) {
      return _buildImageContainer(
        Image.asset('assets/images/boza_1l.png', fit: BoxFit.contain),
      );
    } 
    // 330ml Kontrolü
    else if (lowerName.contains('330') || 
             lowerName.contains('0.33') ||
             lowerName.contains('33cl') ||
             lowerName.contains('33 cl') ||
             lowerName.contains('küçük şişe')) {
      return _buildImageContainer(
        SizedBox(
          width: 30, 
          height: 45, 
          child: Image.asset('assets/images/boza_330ml.png', fit: BoxFit.contain),
        ),
      );
    } else {
      // Varsayılan İkon
      return _buildImageContainer(
        const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.inventory_2, color: Colors.white),
        ),
      );
    }
  }

  // Yardımcı metot: Tüm görselleri aynı boyutlu kutuya koyarak hizalamayı sağlar
  Widget _buildImageContainer(Widget child) {
    return SizedBox(
      width: 40,
      height: 60,
      child: Center(child: child),
    );
  }
}
