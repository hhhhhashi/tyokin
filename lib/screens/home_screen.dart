import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('ログインが無効です')),
      );
    }

    final statsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stats')
        .doc('summary')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('とりレコ 🐔'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => Navigator.pushNamed(context, '/calendar'),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: statsStream,
        builder: (context, snapshot) {
          // ✅ まだstatsが無い/読込中でもチラつかせないためのガード
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = (snapshot.data?.data() as Map<String, dynamic>?) ?? {};
          final totalIntakeG = ((data['totalIntakeG'] ?? 0) as num).toDouble();
          final nearExpiryCount = ((data['nearExpiryCount'] ?? 0) as num).toInt();

          return RefreshIndicator(
            // statsはstreamで更新されるので、リフレッシュは「再計算」用途にするならここで呼ぶ
            onRefresh: () async {
              // 必要なら：await StatsService.recomputeAll(uid);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ChickenProgressCard(totalIntakeG: totalIntakeG),
                const SizedBox(height: 12),
                _ExpiryCard(nearExpiryCount: nearExpiryCount),
                const SizedBox(height: 12),
                _StockSummaryCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 🐔 鶏の成長カード（UIは今までのまま流用）
class _ChickenProgressCard extends StatelessWidget {
  final double totalIntakeG;
  const _ChickenProgressCard({required this.totalIntakeG});

  @override
  Widget build(BuildContext context) {
    final stage = _getChickenStage(totalIntakeG);
    final nextGoal = _getNextGoal(totalIntakeG);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 160,
              child: Image.asset('assets/images/$stage', fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Text(
              '総摂取量：${totalIntakeG.toStringAsFixed(0)}g（たんぱく質 約${(totalIntakeG * 0.22).toStringAsFixed(0)}g）',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text('ランク：${_getRankName(totalIntakeG)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('次の進化まであと：${(nextGoal - totalIntakeG).clamp(0, double.infinity).toStringAsFixed(0)}g'),
            const SizedBox(height: 10),
            Text(_getChickenMessage(totalIntakeG),
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}

/// ⚠️ 賞味期限カード（state不要）
class _ExpiryCard extends StatelessWidget {
  final int nearExpiryCount;
  const _ExpiryCard({required this.nearExpiryCount});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/stockList'),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: nearExpiryCount > 0 ? Colors.red[50] : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                nearExpiryCount > 0 ? Icons.warning_amber : Icons.check_circle,
                color: nearExpiryCount > 0 ? Colors.red : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nearExpiryCount > 0
                      ? '賞味期限が近いパック：$nearExpiryCount 件'
                      : 'すべてのストックは安全です！',
                  style: TextStyle(
                    fontSize: 16,
                    color: nearExpiryCount > 0 ? Colors.red[700] : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 📦 在庫一覧カード
class _StockSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/stockList'),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.inventory, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(child: Text('在庫一覧を見る')),
              Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ----- 今までのロジック（そのまま） -----
String _getChickenStage(double total) {
  if (total < 1000) return 'chicken_stage1.png';
  if (total < 5000) return 'chicken_stage2.png';
  if (total < 10000) return 'chicken_stage3.png';
  return 'chicken_stage4.png';
}

String _getRankName(double total) {
  if (total < 1000) return 'ヒヨコ';
  if (total < 5000) return '若鶏';
  if (total < 10000) return 'ブロイラー';
  return '筋トリ様';
}

double _getNextGoal(double total) {
  if (total < 1000) return 1000;
  if (total < 5000) return 5000;
  if (total < 10000) return 10000;
  return total;
}

String _getChickenMessage(double total) {
  if (total < 1000) return 'まだまだこれからッス！🔥';
  if (total < 5000) return 'だいぶ締まってきたッス💪';
  if (total < 10000) return 'タンパク質こそ力！🍗';
  return '鶏界の頂点に立ったッス！👑';
}