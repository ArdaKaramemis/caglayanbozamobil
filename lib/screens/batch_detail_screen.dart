// lib/screens/batch_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:caglayanbozamobil/models/batch.dart';
import 'package:caglayanbozamobil/services/database_service.dart';

class BatchDetailScreen extends StatefulWidget {
  final Batch batch;

  // Constructor ile seçilen partiyi alıyoruz
  const BatchDetailScreen({super.key, required this.batch});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  final _quantityController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isProcessing = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // Stoktan Düşme (Güncelleme) Fonksiyonu
  void _decreaseStock() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int quantityToDecrease = int.tryParse(_quantityController.text) ?? 0;

    if (quantityToDecrease <= 0) {
      _showSnackbar('Lütfen geçerli bir miktar girin.', Colors.orange);
      return;
    }

    if (quantityToDecrease > widget.batch.currentQuantity) {
      _showSnackbar(
        'Düşülecek miktar, mevcut stoktan fazla olamaz!',
        Colors.red,
      );
      return;
    }

    // İşlem başlıyor
    setState(() {
      _isProcessing = true;
    });

    // Yeni stok miktarını hesapla
    final newQuantity = widget.batch.currentQuantity - quantityToDecrease;

    // DatabaseService'deki updateBatch metodunu çağıracağız
    final success = await _dbService.updateBatchQuantity(
      widget.batch.id,
      newQuantity,
    );

    // İşlem bitti
    setState(() {
      _isProcessing = false;
    });

    if (mounted) {
      if (success) {
        _showSnackbar(
          'Stok başarıyla güncellendi. Yeni miktar: $newQuantity',
          Colors.green,
        );
        // Ana ekrandaki StreamBuilder otomatik güncelleneceği için sadece geri dönüyoruz
        Navigator.pop(context);
      } else {
        // Bu hata muhtemelen yetki sorunundan (admin değil) veya DB hatasından gelir
        _showSnackbar(
          'Stok güncellenirken hata oluştu. Yetkilerinizi kontrol edin.',
          Colors.red,
        );
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;

    return Scaffold(
      appBar: AppBar(
        title: Text('${batch.id.substring(0, 8)}... Parti Detayı'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Parti Genel Bilgileri Kartı
            _buildBatchInfoCard(batch),

            const SizedBox(height: 30),
            const Text(
              'STOK ÇIKIŞI YAP (Azalt)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const Divider(),

            // Stoktan Düşme Formu
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Düşülecek Miktar (Adet)',
                      hintText:
                          'Maksimum ${batch.currentQuantity} girebilirsiniz.',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final quantity = int.tryParse(value ?? '');
                      if (quantity == null || quantity <= 0) {
                        return 'Geçerli bir miktar girin.';
                      }
                      if (quantity > batch.currentQuantity) {
                        return 'Mevcut stoktan fazla düşülemez!';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _isProcessing
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.remove_circle),
                          label: const Text('Stoktan Düş / Satış Yap'),
                          onPressed: _decreaseStock,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bilgi Kartı Widget'ı
  Widget _buildBatchInfoCard(Batch batch) {
    final daysRemaining = batch.expiryDate.difference(DateTime.now()).inDays;
    final isExpired = daysRemaining < 0;

    return Card(
      elevation: 4,
      color: isExpired ? Colors.red.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mevcut Stok Miktarı:',
              style: TextStyle(fontSize: 18, color: Colors.blue.shade900),
            ),
            Text(
              '${batch.currentQuantity} Adet',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _buildInfoRow(
              'Üretim Tarihi:',
              '${batch.productionDate.day}.${batch.productionDate.month}.${batch.productionDate.year}',
            ),
            _buildInfoRow(
              'Son Kullanma Tarihi:',
              '${batch.expiryDate.day}.${batch.expiryDate.month}.${batch.expiryDate.year}',
              isExpired ? Colors.red : Colors.green.shade700,
            ),
            _buildInfoRow(
              'Kalan Süre:',
              isExpired ? 'SÜRE DOLDU!' : '$daysRemaining Gün',
              isExpired ? Colors.red.shade700 : Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, [
    Color valueColor = Colors.black,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}
