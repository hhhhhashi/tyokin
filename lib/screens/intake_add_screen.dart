import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tyokin/services/stats_service.dart';

class IntakeAddScreen extends StatefulWidget {
  const IntakeAddScreen({super.key});

  @override
  State<IntakeAddScreen> createState() => _IntakeAddScreenState();
}

class _IntakeAddScreenState extends State<IntakeAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  String? _selectedStockId;
  int _selectedStockRemaining = 0;
  DateTime _intakeDate = DateTime.now();
  bool _saving = false;

  final _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  double _calcProtein(double g) => g * 0.22;

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addIntake() async {
    if (_uid == null) return;

    if (!_formKey.currentState!.validate() || _selectedStockId == null) {
      _showSnack('入力内容を確認してください');
      return;
    }

    final intakeWeight =
        double.tryParse(_weightController.text.trim());
    if (intakeWeight == null || intakeWeight <= 0) {
      _showSnack('摂取量を正しく入力してください');
      return;
    }

    setState(() => _saving = true);

    final intakeRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('intakeLogs');

    final stockRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('stocks')
        .doc(_selectedStockId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
      // --- refs ---
      final intakeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('intakeLogs')
          .doc(); // 自動ID

      final stockRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('stocks')
          .doc(_selectedStockId);

      final statsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('stats')
          .doc('summary');

      final stockSnap = await tx.get(stockRef);
      if (!stockSnap.exists) throw Exception('選択した在庫が存在しません');

      final stockData = stockSnap.data() as Map<String, dynamic>;
      final remaining = ((stockData['remainingWeight'] ?? stockData['weight'] ?? 0) as num).toDouble();

      if (intakeWeight > remaining) {
        throw Exception('在庫が不足しています（残り ${remaining.toInt()}g）');
      }

      final newRemaining = remaining - intakeWeight;

      // ① 摂取ログ追加
      tx.set(intakeRef, {
        'stockId': _selectedStockId,
        'intakeWeight': intakeWeight,
        'proteinAmount': _calcProtein(intakeWeight),
        'intakeDate': Timestamp.fromDate(_stripTime(_intakeDate)),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ② 在庫更新：0以下なら削除、それ以外は更新
      if (newRemaining <= 0) {
        tx.delete(stockRef);
      } else {
        tx.update(stockRef, {'remainingWeight': newRemaining});
      }

      // ③ stats 更新（増分）
      tx.set(
        statsRef,
        {
          'totalIntakeG': FieldValue.increment(intakeWeight),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
      // ✅ 近い賞味期限数も stats に入れる設計なら、ここで再計算する
      // ※失敗しても摂取登録は成功扱い
      try {
        await StatsService.recomputeNearExpiryCount(_uid!);
      } catch (e) {
        debugPrint('recomputeNearExpiryCount failed: $e');
      }

      if (!mounted) return;
      _showSnack('摂取記録を登録しました');
      Navigator.pop(context);

    } catch (e) {
      if (mounted) _showSnack('登録に失敗しました：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('ログインが無効です')),
      );
    }

    final stockStream = FirebaseFirestore.instance
    .collection('users')
    .doc(_uid)
    .collection('stocks')
    .where('remainingWeight', isGreaterThan: 0)
    .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('摂取記録を追加')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('使用した胸肉パック'),
              const SizedBox(height: 8),

              /// ストック選択
              StreamBuilder<QuerySnapshot>(
              stream: stockStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('ストックがありません');
                }

                // ✅ ① docs を List にコピー
                final docs = snapshot.data!.docs.toList();

                // ✅ ② 賞味期限で並び替え（インデックス不要）
                docs.sort((a, b) {
                  final ad = a.data() as Map<String, dynamic>;
                  final bd = b.data() as Map<String, dynamic>;

                  final aExp =
                      (ad['expirationDate'] as Timestamp?)?.toDate() ?? DateTime(2100);
                  final bExp =
                      (bd['expirationDate'] as Timestamp?)?.toDate() ?? DateTime(2100);

                  return aExp.compareTo(bExp);
                });

                final stocks = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  value: _selectedStockId,
                  isExpanded: true,
                  items: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final remain = ((data['remainingWeight'] ?? data['weight'] ?? 0) as num).toInt();

                    final exp = (data['expirationDate'] as Timestamp?)?.toDate();
                    final expText = exp != null ? DateFormat('MM/dd').format(exp) : '不明';

                    final storageType = (data['storageType'] ?? '') as String;
                    final storageLabel = storageType == 'refrigerated'
                        ? '冷蔵'
                        : storageType == 'frozen'
                            ? '冷凍'
                            : '不明';

                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text('[$storageLabel] $expText｜残り ${remain}g'),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;

                          final selectedDoc =
                              stocks.firstWhere((d) => d.id == value);
                          final data =
                              selectedDoc.data() as Map<String, dynamic>;
                          final remain =
                              ((data['remainingWeight'] ?? data['weight'] ?? 0)
                                      as num)
                                  .toInt();

                          setState(() {
                            _selectedStockId = value;
                            _selectedStockRemaining = remain;
                          });
                        },
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

              /// 摂取量
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                decoration: InputDecoration(
                  labelText: '摂取量（g）',
                  helperText: _selectedStockId == null
                      ? '先に胸肉パックを選択してください'
                      : '最大 $_selectedStockRemaining g まで',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (_selectedStockId == null) {
                    return '先に胸肉パックを選択してください';
                  }
                  if (value == null || value.isEmpty) {
                    return '摂取量を入力してください';
                  }
                  final v = int.tryParse(value);
                  if (v == null) return '数値を入力してください';
                  if (v <= 0) return '1g以上を入力してください';
                  if (v > _selectedStockRemaining) {
                    return '残り $_selectedStockRemaining g を超えています';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              if (_weightController.text.isNotEmpty)
                Text(
                  '→ タンパク質 約 ${_calcProtein(double.tryParse(_weightController.text) ?? 0).toStringAsFixed(1)} g',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),

              const SizedBox(height: 16),

              /// 摂取日
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(
                    '摂取日: ${DateFormat('yyyy/MM/dd').format(_intakeDate)}'),
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

              /// 登録
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? '登録中...' : '登録する'),
                onPressed: _saving ? null : _addIntake,
              ),
            ],
          ),
        ),
      ),
    );
  }
}