import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class IntakeAddScreen extends StatefulWidget {
  const IntakeAddScreen({super.key});

  @override
  State<IntakeAddScreen> createState() => _IntakeAddScreenState();
}

class _IntakeAddScreenState extends State<IntakeAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  String? _selectedStockId;
  DateTime _intakeDate = DateTime.now();
  bool _saving = false;

  // Firestoreインスタンス
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  double _calcProtein(double g) => g * 0.22; // 胸肉100gあたり22gたんぱく質

  Future<void> _addIntake() async {
    if (_uid == null) return;
    if (!_formKey.currentState!.validate() || _selectedStockId == null) {
      _showSnack('入力内容を確認してください');
      return;
    }

    final intakeWeight = double.tryParse(_weightController.text.trim());
    if (intakeWeight == null || intakeWeight <= 0) {
      _showSnack('摂取量を正しく入力してください');
      return;
    }

    final protein = _calcProtein(intakeWeight);
    final intakeRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('intakeLogs');

    final stockRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('stocks')
        .doc(_selectedStockId);

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final stockSnap = await transaction.get(stockRef);
        if (!stockSnap.exists) {
          throw Exception('選択したストックが存在しません');
        }

        final remaining = (stockSnap['remainingWeight'] ?? 0).toDouble();
        final newRemaining = (remaining - intakeWeight).clamp(0, remaining);

        // 摂取ログを追加
        transaction.set(intakeRef.doc(), {
          'stockId': _selectedStockId,
          'intakeWeight': intakeWeight,
          'proteinAmount': protein,
          'intakeDate': Timestamp.fromDate(_stripTime(_intakeDate)),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // ストック残量を更新
        transaction.update(stockRef, {'remainingWeight': newRemaining});
      });

      if (!mounted) return;
      _showSnack('摂取ログを登録しました');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showSnack('登録に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('ログインが無効です')));
    }

    final stockStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stocks')
        .where('remainingWeight', isGreaterThan: 0)
        .orderBy('remainingWeight', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('摂取記録を追加')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // ストック選択
                const Text('使用した胸肉パック'),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: stockStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text('ストックがありません');
                    }
                    final stocks = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: _selectedStockId,
                      isExpanded: true,
                      items: stocks.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final weight = data['remainingWeight'] ?? 0;
                        final exp = (data['expirationDate'] as Timestamp?)?.toDate();
                        final expText = exp != null
                            ? DateFormat('MM/dd').format(exp)
                            : '不明';
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text('$expText｜残り ${weight}g'),
                        );
                      }).toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _selectedStockId = v),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '胸肉パックを選択',
                      ),
                      validator: (v) =>
                          v == null ? '胸肉パックを選択してください' : null,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 摂取量
                TextFormField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '摂取量 (g)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '摂取量を入力';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return '正の数値を入力';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // 自動換算（リアルタイム表示）
                if (_weightController.text.isNotEmpty)
                  Text(
                    '→ タンパク質量 約 ${_calcProtein(double.tryParse(_weightController.text) ?? 0).toStringAsFixed(1)} g',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 16),

                // 摂取日
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text('摂取日: ${DateFormat('yyyy/MM/dd').format(_intakeDate)}'),
                  onPressed: _saving
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _intakeDate,
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _intakeDate = picked);
                          }
                        },
                ),
                const SizedBox(height: 24),

                // 登録ボタン
                FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? '登録中...' : '登録する'),
                  onPressed: _saving ? null : _addIntake,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}