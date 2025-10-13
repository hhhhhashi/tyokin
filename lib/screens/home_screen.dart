import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'stock_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  double _todayProtein = 0;
  int _stockRefrigerated = 0;
  int _stockFrozen = 0;
  int _nearExpiryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (uid == null) return;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final firestore = FirebaseFirestore.instance;

    // 今日の摂取ログ
    final intakeSnap = await firestore
        .collection('users')
        .doc(uid)
        .collection('intakeLogs')
        .where('intakeDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('intakeDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    double todayProtein = 0;
    for (var doc in intakeSnap.docs) {
      todayProtein += (doc['proteinAmount'] ?? 0).toDouble();
    }

    // 在庫一覧
    final stocksSnap = await firestore
        .collection('users')
        .doc(uid)
        .collection('stocks')
        .get();

    int refrigerated = 0;
    int frozen = 0;
    int nearExpiry = 0;
    final nowDate = DateTime.now();

    for (var doc in stocksSnap.docs) {
      final data = doc.data();
      final type = data['storageType'] ?? '';
      final weight = (data['remainingWeight'] ?? 0).toDouble();
      final expDate = (data['expirationDate'] as Timestamp?)?.toDate();

      if (weight <= 0) continue;
      if (type == 'refrigerated') refrigerated++;
      if (type == 'frozen') frozen++;

      if (expDate != null && expDate.isBefore(nowDate.add(const Duration(days: 3)))) {
        nearExpiry++;
      }
    }

    setState(() {
      _todayProtein = todayProtein;
      _stockRefrigerated = refrigerated;
      _stockFrozen = frozen;
      _nearExpiryCount = nearExpiry;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDashboardData(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProteinCard(),
            const SizedBox(height: 16),
            _buildStockSummaryCard(),
            const SizedBox(height: 16),
            _buildExpiryCard(),
          ],
        ),
      ),
    );
  }

 // 🥩 今日の摂取量カード
  Widget _buildProteinCard() {
    const goal = 100.0;
    final progress = (_todayProtein / goal).clamp(0.0, 1.0);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(context, '/calendar'); // ← カレンダー画面へ遷移！
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '今日の摂取量',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                color: progress >= 1 ? Colors.green : Colors.orangeAccent,
                minHeight: 12,
              ),
              const SizedBox(height: 8),
              Text(
                '${_todayProtein.toStringAsFixed(1)} g / $goal g',
                style: TextStyle(
                  fontSize: 16,
                  color:
                      progress >= 1 ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🧊 在庫サマリーカード
  Widget _buildStockSummaryCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(context, '/stockList'); // ← ここで在庫一覧へ遷移
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ストック状況',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStockBox(Icons.kitchen, '冷蔵', _stockRefrigerated),
                  _buildStockBox(Icons.ac_unit, '冷凍', _stockFrozen),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockBox(IconData icon, String label, int count) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blueAccent),
        const SizedBox(height: 8),
        Text('$count パック', style: const TextStyle(fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  // ⏰ 賞味期限カード
  Widget _buildExpiryCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (_nearExpiryCount > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StockListScreen(showNearExpiryOnly: true),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('期限が近いパックはありません')),
          );
        }
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: _nearExpiryCount > 0 ? Colors.red[50] : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                _nearExpiryCount > 0 ? Icons.warning_amber : Icons.check_circle,
                color: _nearExpiryCount > 0 ? Colors.red : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _nearExpiryCount > 0
                      ? '⚠️ 賞味期限が近いパック：$_nearExpiryCount 件'
                      : 'すべてのストックは安全です！',
                  style: TextStyle(
                    fontSize: 16,
                    color: _nearExpiryCount > 0
                        ? Colors.red[700]
                        : Colors.green[700],
                  ),
                ),
              ),
              if (_nearExpiryCount > 0)
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}