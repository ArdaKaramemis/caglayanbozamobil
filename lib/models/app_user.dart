// lib/models/app_user.dart
class AppUser {
  final String uid;
  final String email;
  final String role; // 'manager' veya 'employee'
  final String? assignedMarketId; // Eğer null ise her yere yetkili, dolu ise sadece o markete yetkili

  AppUser({
    required this.uid, 
    required this.email, 
    this.role = 'employee',
    this.assignedMarketId,
  });

  // Helper checks
  bool get isManager => role == 'manager';
  bool get canDeduct => role == 'manager' || role == 'employee';

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    // Geriye dönük uyumluluk: Eğer 'role' yoksa ama 'isAdmin' true ise 'manager' yap.
    String parsedRole = data['role'] ?? 'employee';
    if (data['role'] == null && data['isAdmin'] == true) {
      parsedRole = 'manager';
    }

    return AppUser(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      role: parsedRole,
      assignedMarketId: (data['assignedMarketId'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid, 
      'email': email, 
      'role': role,
      'assignedMarketId': assignedMarketId,
    };
  }
}
