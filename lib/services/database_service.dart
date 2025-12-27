import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/batch.dart';
import '../models/app_user.dart';
import '../models/market.dart';
import '../models/stock_result.dart'; // <<< YENİ IMPORT

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Koleksiyon referansları
  final String productCollection = 'products';
  final String batchCollection = 'batches';
  final String userCollection = 'users';
  final String marketCollection = 'markets';
  final String notificationCollection = 'notifications'; // <<< YENİ REFERANS

  // ------------------------------------
  // USER (Kullanıcı) İşlemleri
  // ------------------------------------

  Future<void> saveUser(AppUser user) async {
    // Kullanıcının UID'sini belge ID'si olarak kullanıyoruz
    await _db.collection(userCollection).doc(user.uid).set(user.toFirestore());
  }

  Future<AppUser?> getAppUser(String uid) async {
    final doc = await _db.collection(userCollection).doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AppUser.fromFirestore(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // GÜNCELLENMİŞ FONKSİYON: Kullanıcının AppUser belgesini stream olarak dinleme
  // Bu fonksiyon, Auth Service'teki AppUser stream'i için kritik öneme sahiptir.
  Stream<AppUser?> getUserStream(String uid) {
    return _db.collection(userCollection).doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return AppUser.fromFirestore(doc.data() as Map<String, dynamic>);
    });
  }

  // ------------------------------------
  // MARKET İşlemleri
  // ------------------------------------

  // YENİ FONKSİYON: Tüm Marketleri Çekme
  Future<List<Market>> getMarketsList() async {
    try {
      QuerySnapshot snapshot = await _db.collection(marketCollection).get();
      return snapshot.docs.map((doc) {
        return Market.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint("Market listesi çekilirken hata oluştu: $e");
      return [];
    }
  }

  // ------------------------------------
  // PRODUCT (Ürün) İşlemleri
  // ------------------------------------

  Future<List<Product>> getProductsList() async {
    try {
      // Tüm ürün belgelerini çek
      QuerySnapshot snapshot = await _db.collection(productCollection).get();

      // Çekilen her bir belgeyi Product modeline dönüştür
      return snapshot.docs.map((doc) {
        return Product.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      debugPrint("Ürün listesi çekilirken hata oluştu: $e");
      return []; // Hata durumunda boş liste döndür
    }
  }

  // YENİ ÜRÜN EKLEME
  Future<void> addProduct(Product product) async {
    // ID Firestore tarafından otomatik oluşturulacak
    await _db.collection(productCollection).add(product.toFirestore());
  }

  // YENİ EKLENEN FONKSİYON: Barkod ile TÜM Product'ları bulma (Çift Barkod Çözümü)
  Future<List<Product>> getProductsByBarcode(String barcode) async {
    try {
      final snapshot = await _db
          .collection(productCollection)
          .where('barcode', isEqualTo: barcode)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint("Hata: Barkod ile ürün arama başarısız: $e");
      return [];
    }
  }

  // ESKİ FONKSİYON: Barkod ile TEK Product ID'sini bulma (FIFO için gerekli)
  Future<String?> getStockOutProductId(String barcode) async {
    try {
      // Ürünleri barkoda göre sorgula
      final snapshot = await _db
          .collection(productCollection)
          // Burada 'barcode' alanının Product modelinde var olduğunu varsayıyoruz
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Bulunan ürünün ID'sini döndür
        return snapshot.docs.first.id;
      }
      return null; // Barkoda karşılık gelen ürün yok
    } catch (e) {
      debugPrint("Barkodla Ürün ID'si çekilirken hata oluştu: $e");
      return null;
    }
  }

  // ------------------------------------
  // BATCH (Parti/Stok) İşlemleri
  // ------------------------------------

  // YENİ PARTİ EKLEME (Stok Girişi)
  Future<void> addBatch(Batch batch) async {
    await _db.collection(batchCollection).add(batch.toFirestore());
  }

  // TÜM PARTİLERİ STREAM OLARAK ALMA (Stok Takibi için canlı veri)
  Stream<List<Batch>> getBatches() {
    return _db
        .collection(batchCollection)
        .orderBy('expiryDate', descending: false) // SKT'ye göre sırala
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Batch.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  // YENİ EKLENEN FONKSİYON: İlgili ürüne ait, stoğu olan ve SKT'ye göre sıralanmış partileri döner.
  Future<List<Batch>> getBatchesForProduct(String productId) async {
    try {
      final snapshot = await _db
          .collection(batchCollection)
          .where('productId', isEqualTo: productId)
          .where('currentQuantity', isGreaterThan: 0) // Sadece stoğu olanlar
          .orderBy(
            'expiryDate',
            descending: false,
          ) // SKT'si en yakın olanı üste getir (FIFO)
          .get();

      return snapshot.docs
          .map((doc) => Batch.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint("Hata: Partileri çekme başarısız: $e");
      return [];
    }
  }

  Future<bool> updateBatchQuantity(String batchId, int newQuantity) async {
    try {
      await _db.collection(batchCollection).doc(batchId).update({
        'currentQuantity': newQuantity,
      });
      return true; // Başarılı
    } catch (e) {
      debugPrint("Parti Stok Güncelleme Hatası: $e");
      return false; // Başarısız
    }
  }

  Future<void> updateBatchStock(String batchId, int newQuantity) async {
    await _db.collection(batchCollection).doc(batchId).update({
      'currentQuantity': newQuantity,
    });
  }

  Future<StockDeductionResult> decreaseStockByProduct(
    String productId,
    String marketId, [
    int decreaseAmount = 1,
    String? productName, // Opsiyonel parametre eklendi
  ]) async {
    try {
      if (productId.isEmpty) {
        return StockDeductionResult(
          status: StockResultStatus.error,
          message: "Ürün ID'si boş.",
        );
      }

      int remaining = decreaseAmount;

      final batchSnapshot = await _db
          .collection(batchCollection)
          .where('productId', isEqualTo: productId)
          .get();

      debugPrint(
          "Bulunan parti sayısı (Tüm Marketler): ${batchSnapshot.docs.length}");

      if (batchSnapshot.docs.isEmpty) {
        return StockDeductionResult(
          status: StockResultStatus.noBatchesFound,
          message:
              "Bu ürün için veritabanında hiç stok kaydı (Parti) bulunamadı. Lütfen yeni stok ekleyin.",
        );
      }
      
      // Client-side Sorting (FIFO - Oldest Expiry First)
      // Firestore index hatasını önlemek için sıralamayı burada yapıyoruz.
      final batchDocs = batchSnapshot.docs.toList();
      batchDocs.sort((a, b) {
        final dateA = (a.data()['expiryDate'] as Timestamp).toDate();
        final dateB = (b.data()['expiryDate'] as Timestamp).toDate();
        return dateA.compareTo(dateB);
      });

      int matchedMarketCount = 0;
      int positiveStockCount = 0;
      
      // --- YENİ EKLENEN KISIM: Market Adı ve Toplam Stok Hesabı ---
      String marketName = marketId;
      try {
        final marketDoc = await _db.collection(marketCollection).doc(marketId).get();
        if (marketDoc.exists) {
          marketName = marketDoc.data()?['name'] ?? marketId;
        }
      } catch (e) {
        debugPrint("Market adı çekilemedi: $e");
      }

      int totalStockInMarket = 0;
      for (final doc in batchDocs) {
        final d = doc.data();
        if (d['marketId'] == marketId) {
           totalStockInMarket += (d['currentQuantity'] ?? 0) as int;
        }
      }

      final int estimatedRemaining = totalStockInMarket - decreaseAmount;
      bool stockBecameCritical = false;
      if (totalStockInMarket > 10 && estimatedRemaining <= 10) {
        stockBecameCritical = true;
      } else if (totalStockInMarket <= 10 && estimatedRemaining < totalStockInMarket) {
        stockBecameCritical = true;
      }
      // -----------------------------------------------------------

      // Parti parti stok düşüşü yap
      for (final doc in batchDocs) {
        if (remaining <= 0) break;
        final data = doc.data();

        // 1. Market Kontrolü (Client-side filtering)
        final batchMarketId = data['marketId'] as String?;
        
        // Eğer marketId null ise ve biz bir marketteyiz, bu eski bir kayıt olabilir.
        if (batchMarketId == null) {
           debugPrint("UYARI: Parti ${doc.id} market ID'si null (Eski veri?). Beklenen: $marketId");
        }

        if (batchMarketId != marketId) {
          debugPrint(
              "Parti ${doc.id} market ID'si uyuşmuyor. Beklenen: $marketId, Bulunan: $batchMarketId. Atlanıyor.");
          continue;
        }

        matchedMarketCount++;
        debugPrint("Parti ${doc.id} market ID'si uyuşuyor: $marketId.");

        // 2. Stok Kontrolü
        final int current = (data['currentQuantity'] ?? 0) as int;
        if (current <= 0) {
          debugPrint("Parti ${doc.id} stoğu 0 veya altında. Atlanıyor.");
          continue;
        }
        
        positiveStockCount++;

        final int take = current >= remaining ? remaining : current;
        final int newQty = current - take;

        // Firestore'a güncelleme isteği
        await _db.collection(batchCollection).doc(doc.id).update({
          'currentQuantity': newQty,
        });


        remaining -= take;
      }
      
      if (remaining <= 0) {
        // BİLDİRİM GÖNDERİMİ (Loop sonrası, işlem başarılıysa)
        if (stockBecameCritical) {
           final pName = productName ?? "Bir ürün";
           final displayQty = estimatedRemaining < 0 ? 0 : estimatedRemaining;
           
           await addNotification(
             title: "Kritik Stok Uyarısı",
             body: "$marketName: $pName stoğu kritik seviyeye ($displayQty) düştü!",
             type: 'stock_low',
           );
        }
        return StockDeductionResult(
          status: StockResultStatus.success, 
          message: "Stok başarıyla düşüldü."
        );
      } else {
        // Hata Analizi
        if (matchedMarketCount == 0) {
           return StockDeductionResult(
            status: StockResultStatus.marketMismatch,
            message: "Stok kayıtları bulundu ancak hiçbiri mevcut market ($marketId) ile eşleşmedi. (Muhtemelen başka markete aitler veya eski kayıtlar)",
          );
        } else if (positiveStockCount == 0) {
           return StockDeductionResult(
            status: StockResultStatus.insufficientStock,
            message: "Bu markette stok kaydı var ancak hepsinin stoğu tükenmiş (0).",
          );
        } else {
           return StockDeductionResult(
            status: StockResultStatus.insufficientStock,
            message: "Stok yetersiz. Mevcut stokların hepsi kullanıldı ancak istenen miktar karşılanamadı.",
          );
        }
      }

    } catch (e) {
      debugPrint('Stok düşürme genel hatası: $e');
      return StockDeductionResult(
        status: StockResultStatus.error,
        message: "Beklenmeyen hata: $e",
      );
    }
  }

  // ------------------------------------
  // BİLDİRİM (Notification) İşlemleri
  // ------------------------------------

  // Yeni bir bildirim kaydı oluştur (Firestore)
  Future<void> addNotification({
    required String title,
    required String body,
    required String type, // 'stock_low', 'stock_added', 'expiry_warning'
  }) async {
    try {
      await _db.collection(notificationCollection).add({
        'title': title,
        'body': body,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false, // Okundu bilgisi eklenebilir
      });
    } catch (e) {
      debugPrint("Bildirim ekleme hatası: $e");
    }
  }

  // Son bildirimleri stream olarak dinle
  Stream<QuerySnapshot> getNotificationsStream() {
    return _db
        .collection(notificationCollection)
        .orderBy('timestamp', descending: true)
        .limit(20) // Son 20 bildirim
        .snapshots();
  }
}
