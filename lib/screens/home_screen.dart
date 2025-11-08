import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  int _nearExpiryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNearExpiryCount();
  }

  // ⚠️ 賞味期限が近いパック数を取得
  Future<void> _loadNearExpiryCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final today = DateTime.now();
    final next3Days = today.add(const Duration(days: 3));

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stocks')
        .where('expirationDate', isLessThanOrEqualTo: Timestamp.fromDate(next3Days))
        .get();

    setState(() {
      _nearExpiryCount = snapshot.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('とりレコ 🐔'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.pushNamed(context, '/calendar');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadNearExpiryCount();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🔥 リアルタイム総摂取量カード
            if (uid != null) _buildChickenProgressCardStream(uid),
            const SizedBox(height: 12),
            _buildExpiryCard(),
            const SizedBox(height: 12),
            _buildStockSummaryCard(),
          ],
        ),
      ),
    );
  }

  // 🐔 鶏の成長カード（リアルタイム更新版）
  Widget _buildChickenProgressCardStream(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('intakeLogs')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        double totalProtein = 0;
        for (var doc in snapshot.data?.docs ?? []) {
          totalProtein += (doc['intakeWeight'] ?? 0).toDouble();
        }

        final stage = _getChickenStage(totalProtein);
        final nextGoal = _getNextGoal(totalProtein);

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: Image.asset(
                    'assets/images/$stage',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '総摂取量：${totalProtein.toStringAsFixed(0)}g（たんぱく質 約${(totalProtein * 0.22).toStringAsFixed(0)}g）',
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'ランク：${_getRankName(totalProtein)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '次の進化まであと：${(nextGoal - totalProtein).clamp(0, double.infinity).toStringAsFixed(0)}g',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Text(
                  _getChickenMessage(totalProtein),
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ⚠️ 賞味期限カード
  Widget _buildExpiryCard() {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/stockList');
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
                      ? '賞味期限が近いパック：$_nearExpiryCount 件'
                      : 'すべてのストックは安全です！',
                  style: TextStyle(
                    fontSize: 16,
                    color: _nearExpiryCount > 0
                        ? Colors.red[700]
                        : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📦 ストック一覧サマリー（冷蔵＋冷凍合計）
  Widget _buildStockSummaryCard() {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/stockList');
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.inventory, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '在庫一覧を見る',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // 🐣 ステージ画像の判定
  String _getChickenStage(double totalProtein) {
    if (totalProtein < 1000) return 'chicken_stage1.png';
    if (totalProtein < 5000) return 'chicken_stage2.png';
    if (totalProtein < 10000) return 'chicken_stage3.png';
    return 'chicken_stage4.png';
  }

  // 🏅 ランク名の取得
  String _getRankName(double totalProtein) {
    if (totalProtein < 1000) return 'ヒヨコ';
    if (totalProtein < 5000) return '若鶏';
    if (totalProtein < 10000) return 'ブロイラー';
    return '筋トリ様';
  }

  // 🚀 次の進化までの目標値
  double _getNextGoal(double totalProtein) {
    if (totalProtein < 1000) return 1000;
    if (totalProtein < 5000) return 5000;
    if (totalProtein < 10000) return 10000;
    return totalProtein;
  }

  // 💬 鶏のセリフ
  String _getChickenMessage(double totalProtein) {
    if (totalProtein < 1000) return 'まだまだこれからッス！🔥';
    if (totalProtein < 5000) return 'だいぶ締まってきたッス💪';
    if (totalProtein < 10000) return 'タンパク質こそ力！🍗';
    return '鶏界の頂点に立ったッス！👑';
  }
}