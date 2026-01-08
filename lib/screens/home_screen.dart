import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('とりレコ 🐔'),
      ),

      // ✅ 中央＋ボタン
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/intake'),
        child: const Icon(Icons.add),
      ),

      // ✅ 下部AppBar（在庫 / カレンダー）
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                tooltip: '在庫',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => Navigator.pushNamed(context, '/stockList'),
              ),
              const SizedBox(width: 48), // FABの分のスペース
              IconButton(
                tooltip: 'カレンダー',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => Navigator.pushNamed(context, '/calendar'),
              ),
            ],
          ),
        ),
      ),

      body: uid == null
          ? const Center(child: Text('ログインが無効です'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('stats')
                  .doc('summary')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                double totalIntakeG = 0.0;
                int nearExpiryCount = 0;

                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  totalIntakeG = ((data?['totalIntakeG'] ?? 0) as num).toDouble();
                  nearExpiryCount = ((data?['nearExpiryCount'] ?? 0) as num).toInt();
                }

                final stage = _getChickenStage(totalIntakeG);
                final nextGoal = _getNextGoal(totalIntakeG);
                final remainToNext = (nextGoal - totalIntakeG).clamp(0, double.infinity);
                final progress = (totalIntakeG / nextGoal).clamp(0.0, 1.0);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // =========================
                    // A) 鶏の成長（主役）
                    // =========================
                    // =========================
                    // A) 鶏の成長（主役） + 履歴導線
                    // =========================
                    InkWell(
  borderRadius: BorderRadius.circular(20),
  onTap: () {
    Navigator.pushNamed(context, '/growthHistory');
  },
  child: Container(
    width: double.infinity, // ← 横幅いっぱい
    height: 400,            // ← ここで高さを固定
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // ✅ 背景画像（枠いっぱい）
          Positioned.fill(
            child: Image.asset(
              'assets/images/$stage',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // ✅ うっすらオーバーレイ（文字読みやすく）
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.12),
            ),
          ),

          // ✅ 履歴ボタン（画像右上に固定）
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pushNamed(context, '/growthHistory');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    '履歴',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ✅ コメント（画像下部）
          // ✅ コメント（画像の左下・枠なし）
          Positioned(
            left: 14,
            bottom: 8,
            child: Text(
              _getChickenMessage(totalIntakeG),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black.withOpacity(0.75),
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),

                    const SizedBox(height: 16),

                    // =========================
                    // B) 次の進化まで（最重要）
                    // =========================
                    Text(
                      '次の進化まで',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'あと ${remainToNext.toStringAsFixed(0)} g',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 14,
                        backgroundColor: Colors.black12,
                        color: progress >= 1.0 ? Colors.green : Colors.orangeAccent,
                      ),
                    ),

                    const SizedBox(height: 18),
                    Divider(color: Colors.black.withOpacity(0.08)),
                    const SizedBox(height: 10),

                    // =========================
                    // C) 今日の摂取量（現状は簡易表示）
                    // ※ “今日の合計”を出すなら stats に todayIntakeG を持たせるか
                    //    intakeLogs を日付で集計する必要あり
                    // =========================
                    Text(
                      '総摂取量',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${totalIntakeG.toStringAsFixed(0)} g（たんぱく質 約 ${(totalIntakeG * 0.22).toStringAsFixed(0)} g）',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 16),

                    // =========================
                    // D) 期限が近い在庫（通知バー風）
                    // =========================
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pushNamed(context, '/stockList'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: nearExpiryCount > 0 ? Colors.red.withOpacity(0.06) : Colors.green.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: nearExpiryCount > 0 ? Colors.red.withOpacity(0.25) : Colors.green.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              nearExpiryCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle,
                              color: nearExpiryCount > 0 ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                nearExpiryCount > 0
                                    ? '期限が近い在庫：$nearExpiryCount 件'
                                    : '期限が近い在庫はありません',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: nearExpiryCount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 余白（下部AppBarと被らないように）
                    const SizedBox(height: 60),
                  ],
                );
              },
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

  // 🚀 次の進化までの目標値
  double _getNextGoal(double totalProtein) {
    if (totalProtein < 1000) return 1000;
    if (totalProtein < 5000) return 5000;
    if (totalProtein < 10000) return 10000;
    return totalProtein; // カンスト
  }

  // 💬 鶏のセリフ
  String _getChickenMessage(double totalProtein) {
    if (totalProtein < 1000) return 'まだまだこれからッス！';
    if (totalProtein < 5000) return 'だいぶ締まってきたッスね！';
    if (totalProtein < 10000) return 'タンパク質こそ力！';
    return '鶏界の頂点に立ったッス！';
  }
}