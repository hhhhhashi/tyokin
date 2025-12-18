import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tyokin/services/stats_service.dart';

/// 在庫追加（手入力）画面
/// - 賞味期限（日付）
/// - 内容量(g)
/// - 保存方法（冷蔵/冷凍）
/// - 購入日（日付）
/// 保存先: users/{uid}/stocks/{stockId}
class StockAddScreen extends StatefulWidget {
  const StockAddScreen({super.key});

  @override
  State<StockAddScreen> createState() => _StockAddScreenState();
}

class _StockAddScreenState extends State<StockAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  DateTime? _expirationDate;
  DateTime? _purchaseDate = DateTime.now();
  String _storageType = 'refrigerated'; // refrigerated | frozen
  bool _saving = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1, 1, 1);
    final last = DateTime(now.year + 3, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) onPicked(picked);
  }

  String _fmt(DateTime? d) => d == null ? '未選択' : DateFormat('yyyy/MM/dd').format(d);

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('ログイン状態が無効です（匿名ログイン失敗）');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_expirationDate == null) {
      _showSnack('賞味期限を選択してください');
      return;
    }
    if (_purchaseDate == null) {
      _showSnack('購入日を選択してください');
      return;
    }

    final total = int.tryParse(_weightController.text.trim());
    if (total == null || total <= 0) {
      _showSnack('内容量は1以上の数値で入力してください');
      return;
    }

    setState(() => _saving = true);
    try {
    // ① まず “在庫登録” だけ確実にやる
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stocks')
          .add({
        'weight': total,
        'remainingWeight': total,
        'storageType': _storageType,
        'expirationDate': Timestamp.fromDate(_stripTime(_expirationDate!)),
        'purchaseDate': Timestamp.fromDate(_stripTime(_purchaseDate!)),
        'createdAt': FieldValue.serverTimestamp(),
      });
      // ② stats再計算は “失敗しても登録成功扱い” にする
      try {
        await StatsService.recomputeNearExpiryCount(uid);
      } catch (e) {
        debugPrint('recomputeNearExpiryCount failed: $e');
        // ここで失敗Snackは出さない（登録は成功してるため）
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('在庫を登録しました')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登録に失敗しました：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return Scaffold(
      appBar: AppBar(title: const Text('在庫追加')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 賞味期限
              Text('賞味期限', style: labelStyle),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(_fmt(_expirationDate)),
                onPressed: _saving
                    ? null
                    : () => _pickDate(
                          current: _expirationDate,
                          onPicked: (d) => setState(() => _expirationDate = d),
                        ),
              ),
              const SizedBox(height: 16),

              // 内容量
              TextFormField(
                controller: _weightController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '内容量 (g)',
                  hintText: '例: 300',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '内容量を入力してください';
                  final n = int.tryParse(v.trim());
                  if (n == null) return '数値で入力してください';
                  if (n <= 0) return '1以上を入力してください';
                  if (n > 5000) return '5,000gを超える値は不可';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 保存方法
              Text('保存方法', style: labelStyle),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'refrigerated', label: Text('冷蔵'), icon: Icon(Icons.ac_unit_outlined)),
                  ButtonSegment(value: 'frozen', label: Text('冷凍'), icon: Icon(Icons.snowing)),
                ],
                selected: {_storageType},
                onSelectionChanged: _saving
                    ? null
                    : (s) => setState(() => _storageType = s.first),
              ),
              const SizedBox(height: 16),

              // 購入日
              Text('購入日', style: labelStyle),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_available),
                label: Text(_fmt(_purchaseDate)),
                onPressed: _saving
                    ? null
                    : () => _pickDate(
                          current: _purchaseDate,
                          onPicked: (d) => setState(() => _purchaseDate = d),
                        ),
              ),
              const SizedBox(height: 24),

              // 登録ボタン
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? '登録中…' : '登録する'),
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}