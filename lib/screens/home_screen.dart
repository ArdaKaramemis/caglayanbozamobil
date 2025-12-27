import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // import added
import 'package:caglayanbozamobil/services/auth_service.dart';
import 'package:caglayanbozamobil/services/database_service.dart';
import 'package:caglayanbozamobil/services/notification_service.dart';

import 'package:caglayanbozamobil/models/app_user.dart';
import 'package:caglayanbozamobil/models/market.dart';
import 'package:caglayanbozamobil/screens/add_batch_screen.dart';
import 'package:caglayanbozamobil/screens/market_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Singleton servislerimizi başlatıyoruz
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  // YENİ DURUM DEĞİŞKENLERİ
  Map<String, String> _marketNames = {}; // Market ID'si -> Market Adı
  Map<String, String> _productNames = {}; // Ürün ID'si -> Ürün Adı
  List<Market> _availableMarkets = []; // Market objelerinin listesi

  // Renk Paleti
  final Color _primaryBlue = const Color(0xFF0F4C81); // Koyu Mavi
  final Color _accentGold = const Color(0xFFBE9658);  // Altın Sarısı

  @override
  void initState() {
    super.initState();
    _loadNames(); // Hem ürün hem market adlarını yükle
    
    // Bildirim Servisini Başlat (Sadece giriş yapmış kullanıcılar için)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().init();
    });
  }

  // Ürün ve Market Adlarını Yükleme Fonksiyonu (GÜNCELLENDİ)
  void _loadNames() async {
    try {
      // 1. Market Adlarını ve Objelerini Yükle
      final List<Market> markets = await _dbService.getMarketsList();
      
      // SIRALAMA: 'Çağlayan' içerenler en üste, diğerleri harf sırasına
      markets.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final aIsCaglayan = aName.contains('çağlayan') || aName.contains('caglayan');
        final bIsCaglayan = bName.contains('çağlayan') || bName.contains('caglayan');

        if (aIsCaglayan && !bIsCaglayan) return -1; // a üstte (öne gelir)
        if (!aIsCaglayan && bIsCaglayan) return 1;  // b üstte
        return aName.compareTo(bName); // Diğerleri harf sırasına
      });

      _availableMarkets = markets; // <<< MARKET LİSTESİ KAYDEDİLDİ
      _marketNames = {for (var market in markets) market.id: market.name};

      // 2. Ürün Adlarını Yükle
      final products = await _dbService.getProductsList();
      _productNames = {for (var product in products) product.id: product.name};

      // UI güncellemesi gerektiği için setState
      setState(() {});
    } catch (e) {
      // Hata oluşursa, konsola yazdırıp boş haritalarla devam et.
      debugPrint("Adları yükleme hatası: $e");
      setState(() {
        _marketNames = {};
        _productNames = {};
        _availableMarkets = []; // Hata durumunda boş liste
      });
    }
  }

  // URL Açma Fonksiyonu
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Link açılamadı: $url")));
      }
    }
  }

  // Stok Ekleme ekranına gitme fonksiyonu
  void _navigateToAddBatchScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBatchScreen()),
    );
  }





  @override
  Widget build(BuildContext context) {
    // En dıştaki StreamBuilder: Kullanıcının yetkisini (isAdmin) kontrol eder
    return StreamBuilder<AppUser?>(
      stream: _authService.appUser, // Yeni AppUser Stream'ini dinle
      builder: (context, userSnapshot) {
        // Auth state değişirken (giriş/çıkış) veya ilk yüklenmede bekleme durumu
        if (userSnapshot.connectionState == ConnectionState.waiting ||
            _marketNames.isEmpty ||
            _productNames.isEmpty) {
          // Adlar yüklenene kadar bekle
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Yetki kontrolü yapılır, userSnapshot.data null ise rol 'employee' olur.
        final isManager = userSnapshot.data?.isManager ?? false; // Yönetici mi?

        return Scaffold(
          appBar: AppBar(
            backgroundColor: _primaryBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    backgroundImage: const AssetImage('assets/images/logo.png'),
                    onBackgroundImageError: (_, __) => const Icon(Icons.error),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Çağlayan Boza', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              // SADECE YÖNETİCİ İSE GÖSTERİLECEK BUTONLAR
              if (isManager) ...[
                // 1. Stok Ekleme Butonu
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.white),
                  onPressed: _navigateToAddBatchScreen,
                ),
              ],
              // 3. Çıkış Butonu (herkes görebilir)
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                onPressed: () async {
                  await _authService.signOut();
                },
              ),
            ],
          ),
          // İÇTEKİ: Market Listesi + Footer
          body: Column(
            children: [
              Expanded(
                child: _availableMarkets.isEmpty
                    ? const Center(child: Text('Henüz tanımlı market yok.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 10),
                        itemCount: _availableMarkets.length,
                        itemBuilder: (context, index) {
                          final market = _availableMarkets[index];
                          return Card(
                            elevation: 4, 
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15), 
                            ),
                            margin: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _primaryBlue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.store,
                                  color: _accentGold, 
                                  size: 30,
                                ),
                              ),
                              title: Text(
                                market.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: _primaryBlue, 
                                ),
                              ),
                              subtitle: const Text('Stok detayları için dokunun'),
                              trailing: Icon(Icons.arrow_forward_ios, color: _accentGold, size: 18),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            MarketDetailScreen(market: market),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
              // FOOTER ALANI
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    const Text("Bizi Takip Edin", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Web Sitesi Butonu
                        ElevatedButton.icon(
                          onPressed: () => _launchURL('https://www.caglayanboza.com'),
                          icon: const Icon(Icons.language),
                          label: const Text('Web Sitemiz'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 15),
                        // Instagram Butonu
                        ElevatedButton.icon(
                          onPressed: () => _launchURL('https://www.instagram.com/caglayanboza/'),
                          icon: const FaIcon(FontAwesomeIcons.instagram, color: Colors.white), // FaIcon kullanıldı
                          label: const Text('Instagram'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE1306C), // Instagram rengi
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Güvenli alan boşluğu (Navigasyon çubuğu için)
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        );
      },
    );
  }
}
