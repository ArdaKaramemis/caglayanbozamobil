// lib/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:caglayanbozamobil/services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  // Renk Paleti (Logodan esinlenerek)
  final Color _primaryBlue = const Color(0xFF0F4C81); // Koyu Mavi
  final Color _accentGold = const Color(0xFFBE9658);  // Altın Sarısı

  bool isLogin = true;
  bool isLoading = false;

  void _submitAuthForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      dynamic result;

      if (isLogin) {
        result = await _auth.signIn(email, password);
      } else {
        result = await _auth.signUp(email, password);
      }

      if (!mounted) return;
      setState(() => isLoading = false);

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLogin
                  ? 'Giriş Başarısız! E-posta veya şifre hatalı.'
                  : 'Kayıt Başarısız! Lütfen bilgilerinizi kontrol edin.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ekran boyutunu al
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Yatay modda yükseklik oranlarını ve boyutları ayarla
    final double headerHeight = isLandscape ? size.height * 0.5 : size.height * 0.35;
    final double headerContentHeight = isLandscape ? size.height * 0.45 : size.height * 0.33;
    final double logoRadius = isLandscape ? 30 : 50;
    final double fontSize = isLandscape ? 18 : 22;
    final double topPadding = isLandscape ? 10 : 30;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Üst Kısım: Dalgalı Header
            Stack(
              children: [
                ClipPath(
                  clipper: WaveClipper(),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 50),
                    color: _primaryBlue.withOpacity(0.8),
                    height: headerHeight,
                    alignment: Alignment.center,
                  ),
                ),
                ClipPath(
                  clipper: WaveClipper(),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 50),
                    color: _primaryBlue,
                    height: headerContentHeight,
                    alignment: Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(top: topPadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           // Logo Alanı
                           Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                )
                              ]
                            ),
                            child: CircleAvatar(
                              radius: logoRadius,
                              backgroundColor: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                           ),
                           const SizedBox(height: 5),
                           Text(
                             "ÇAĞLAYAN BOZA",
                             style: TextStyle(
                               fontSize: fontSize,
                               fontWeight: FontWeight.bold,
                               color: _accentGold,
                               letterSpacing: 1.5,
                             ),
                           ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 2. Form Alanı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Başlık (Giriş / Kayıt)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTabButton("Giriş Yap", true),
                        const SizedBox(width: 20),
                        _buildTabButton("Kayıt Ol", false),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // E-posta Input
                    _buildCustomTextField(
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      label: "E-posta (Gmail)",
                      inputType: TextInputType.emailAddress,
                      validator: (value) {
                         if (value == null || value.isEmpty) {
                           return 'E-posta boş olamaz';
                         }
                         if (!value.toLowerCase().endsWith('@gmail.com')) {
                           return 'Sadece @gmail.com adresleri kabul edilir.';
                         }
                         return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Şifre Input
                    _buildCustomTextField(
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      label: "Şifre",
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Şifre en az 6 karakter olmalıdır.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Şifremi Unuttum (Sadece girişte)
                    if (isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                             _showForgotPasswordDialog();
                          },
                          child: Text(
                            "Şifremi Unuttum?",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Ana Aksiyon Butonu
                    if (isLoading)
                      const CircularProgressIndicator()
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _submitAuthForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            isLogin ? "GİRİŞ YAP" : "KAYIT OL",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Özel Tab Butonu
  Widget _buildTabButton(String text, bool activeState) {
    final isActive = isLogin == activeState;
    return GestureDetector(
      onTap: () {
        setState(() {
          isLogin = activeState;
          _emailController.clear();
          _passwordController.clear();
        });
      },
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isActive ? _primaryBlue : Colors.grey,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 5),
              height: 3,
              width: 30,
              color: _accentGold, // Altın çizgi
            ),
        ],
      ),
    );
  }

  // Özel Text Field Tasarımı
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    bool isPassword = false,
    TextInputType? inputType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3), // Gölge yönü
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _accentGold), // İkon altın rengi
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  // Şifre Sıfırlama Diyaloğu
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Şifre Sıfırlama", style: TextStyle(color: _primaryBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Mail adresinize şifre sıfırlama bağlantısı gönderilecektir."),
              const SizedBox(height: 10),
              const Text(
                "(Lütfen SPAM klasörünü de kontrol ediniz)",
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Form(
                key: resetFormKey,
                child: TextFormField(
                  controller: resetEmailController,
                  decoration: const InputDecoration(
                    labelText: "Gmail Adresiniz",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'E-posta boş olamaz';
                    }
                    if (!value.toLowerCase().endsWith('@gmail.com')) {
                      return 'Sadece @gmail.com adresleri kabul edilir.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (resetFormKey.currentState!.validate()) {
                  final email = resetEmailController.text.trim();
                  try {
                    await _auth.sendPasswordResetEmail(email);
                    if (!mounted) return;
                    Navigator.pop(context); // Diyaloğu kapat
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Sıfırlama bağlantısı gönderildi!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Hata: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accentGold),
              child: const Text("GÖNDER", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

// Dalgalı Tasarım için Özel Clipper (Kesici)
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);
    
    // İlk dalga (aşağı)
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 40);
    path.quadraticBezierTo(
      firstControlPoint.dx, firstControlPoint.dy,
      firstEndPoint.dx, firstEndPoint.dy
    );

    // İkinci dalga (yukarı)
    var secondControlPoint = Offset(size.width * 3 / 4, size.height - 80);
    var secondEndPoint = Offset(size.width, size.height - 40); // Bitiş hafif aşağıda
    path.quadraticBezierTo(
      secondControlPoint.dx, secondControlPoint.dy,
      secondEndPoint.dx, secondEndPoint.dy
    );

    path.lineTo(size.width, 0); 
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false; // Sabit şekil, tekrar çizmeye gerek yok
  }
}
