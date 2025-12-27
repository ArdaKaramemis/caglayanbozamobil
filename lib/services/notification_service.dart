import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore için
import 'database_service.dart'; // DatabaseService için

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization (basic)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );
     
    // Kanalı açıkça oluştur
    final AndroidNotificationChannel channel = const AndroidNotificationChannel(
      'caglayan_boza_channel', 
      'Çağlayan Boza Bildirimleri', 
      description: 'Stok ve SKT uyarıları', 
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Servisleri Başlat
    listenToFirestoreNotifications();
    checkExpiryAndNotify();
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // BigTextStyle kullanarak uzun metinlerin (...) şeklinde kesilmesini önlüyoruz
    final BigTextStyleInformation bigTextStyleInformation =
        BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
    );

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'caglayan_boza_channel', 
      'Çağlayan Boza Bildirimleri', 
      channelDescription: 'Stok ve SKT uyarıları',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: bigTextStyleInformation, // YENİ: Geniş Metin Stili
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
  // Firestore Listener'ı Başlat
  void listenToFirestoreNotifications() {
    final DatabaseService dbService = DatabaseService();
    
    dbService.getNotificationsStream().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final Timestamp? timestamp = data['timestamp'] as Timestamp?;
          
          // YENİ: İsteğe bağlı olarak "Stok Çıkışı" bildirimlerini tamamen sessize al
          // Kullanıcı "her stok düşürüldüğünde bildirim gelmesin" dediği için
          // bu tipteki bildirimleri client tarafında da filtreliyoruz.
          if (data['type'] == 'stock_removed') {
             continue; // Bu bildirimi gösterme
          }

          // Timestamp kontrolü:
          // Local yazma işlemlerinde (bizim tetiklediğimiz), timestamp henüz oluşmamış olabilir (null).
          // Bu durumda 'şimdi' kabul edip bildirimi göstermeliyiz.
          if (timestamp == null) {
              showNotification(
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                title: data['title'] ?? 'Bildirim',
                body: data['body'] ?? '',
              );
          } else {
            // 2025-12-19: Timezone Fix
            // Firestore timestamps are UTC. DateTime.now() is Local. 
            // We convert both to UTC to ensure correct difference calculation.
            final nowUtc = DateTime.now().toUtc();
            final notificationUtc = timestamp.toDate().toUtc();
            
            // Farkı dakika cinsinden al
            final diffInMinutes = nowUtc.difference(notificationUtc).inMinutes;

            // Toleransı 5 dakikaya düşürüyoruz (Eski bildirimlerin gelmesini engellemek için)
            // Ayrıca negatif farklara (gelecek tarihli?) karşı da abs() kullanıyoruz ama
            // çok eski bildirimler (örn 1 saat önce) diff > 5 olacağı için elenecek.
            if (diffInMinutes.abs() < 5) {
              showNotification(
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                title: data['title'] ?? 'Bildirim',
                body: data['body'] ?? '',
              );
            }
          }
        }
      }
    }, onError: (error) {
      debugPrint("Bildirim stream hatası: $error");
    });
  }

  // SKT Kontrolü (Açılışta çalışır)
  Future<void> checkExpiryAndNotify() async {
    final DatabaseService dbService = DatabaseService();
    try {
        // İlk veriyi çekip kontrol et
        final stream = dbService.getBatches();
        final batches = await stream.first; 

        for (var batch in batches) {
          if (batch.currentQuantity > 0) {
            final daysLeft = batch.expiryDate.difference(DateTime.now()).inDays;
            
            if (daysLeft <= 3) {
               String msg = daysLeft < 0 
                   ? "Dikkat! SKT'si geçen partiler var."
                   : "Dikkat! SKT'si yaklaşan ($daysLeft gün) partiler var.";

               await showNotification(
                 id: 888, 
                 title: "Stok Uyarısı",
                 body: msg,
               );
               break; // Tek bir genel uyarı yeterli
            }
          }
        }
    } catch(e) {
        debugPrint("Expiry check error: $e");
    }
  }
}
