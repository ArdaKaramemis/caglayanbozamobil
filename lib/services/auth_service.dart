import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:caglayanbozamobil/models/app_user.dart';
import 'package:rxdart/rxdart.dart'; // rxdart paketi eklendi
import 'package:caglayanbozamobil/services/database_service.dart'; // DatabaseService'i kullanmak için

class AuthService {
  // 1. Statik, private bir değişken oluştur
  static final AuthService _instance = AuthService._internal();

  // 2. Factory constructor ile her çağrıda aynı örneği döndür
  factory AuthService() {
    return _instance;
  }

  // 3. Private constructor ve bağımlılıkların başlatılması
  AuthService._internal();

  // Bağımlılıkları Singleton içinde başlat
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // DatabaseService'i de Singleton olarak çağırıyoruz
  final DatabaseService _dbService = DatabaseService();

  // ------------------------------------
  // Kayıt Olma İşlemi (Admin Rol Kaydı Eklendi)
  // ------------------------------------
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // KRİTİK ADIM: Yeni kullanıcıyı Firestore'a kaydet ve isAdmin: false yap
      if (result.user != null) {
        final newUser = AppUser(
          uid: result.user!.uid,
          email: email,
          role: 'user', // Varsayılan olarak 'user' (hiçbir yetkisi yok)
        );
        await _dbService.saveUser(newUser);
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Kayıt Hatası Kodu: ${e.code}");
      debugPrint("Kayıt Hatası Mesajı: ${e.message}");
      return null;
    } catch (e) {
      debugPrint("Genel Kayıt Hatası: $e");
      return null;
    }
  }

  // ------------------------------------
  // Oturum Açma İşlemi
  // ------------------------------------
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Giriş Hatası Kodu: ${e.code}"); // Hata kodunu göster
      debugPrint("Giriş Hatası Mesajı: ${e.message}");
      return null;
    } catch (e) {
      debugPrint("Genel Giriş Hatası: $e");
      return null;
    }
  }

  // ------------------------------------
  // Oturumu Kapatma İşlemi
  // ------------------------------------
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ------------------------------------
  // Oturum Durumunu Dinleme (Firebase User)
  // ------------------------------------
  Stream<User?> get user => _auth.authStateChanges();

  // ------------------------------------
  // Oturum Durumunu Dinleme (Custom AppUser)
  // ------------------------------------
  // Firebase User objesi değil, bizim AppUser objemizi döndürür
  Stream<AppUser?> get appUser {
    // 1. Firebase Auth durumunu dinle
    return _auth.authStateChanges().switchMap((user) {
      if (user == null) {
        return Stream.value(null); // Kullanıcı yoksa null döndür
      }
      // 2. Eğer kullanıcı varsa, o kullanıcının Firestore'daki AppUser belgesini dinle
      // switchMap sayesinde, Auth state değiştiğinde yeni bir Firestore stream'ine geçeriz.
      return _dbService.getUserStream(user.uid);
    });
  }

  // ------------------------------------
  // Şifre Sıfırlama E-postası Gönderme
  // ------------------------------------
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
