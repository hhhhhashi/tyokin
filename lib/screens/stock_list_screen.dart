import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StockListScreen extends StatefulWidget {
  final bool showNearExpiryOnly;

  const StockListScreen({super.key, this.showNearExpiryOnly = false});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  String _selectedTab = 'refrigerated'; // 通常モード用
  final uid = FirebaseAuth.instance.currentUser?.uid;

  Stream<QuerySnapshot> _getStocksStream(String uid) {
    final now = DateTime.now();
    final limitDate = now.add(const Duration(days: 3));

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stocks');

    if (widget.showNearExpiryOnly) {
      // ⚠️ 賞味期限が近いパックのみ
      return ref
          .where('expirationDate',
              isLessThanOrEqualTo: Timestamp.fromDate(limitDate))
          .orderBy('expirationDate')
          .snapshots();
    } else {
      // 通常モード：冷蔵／冷凍ごと
      return ref
          .where('storageType', isEqualTo: _selectedTab)
          .orderBy('expirationDate')
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('ログイン情報が見つかりません')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showNearExpiryOnly
            ? '⚠️ 賞味期限が近い在庫一覧'
            : '在庫一覧'),
        actions: [
        if (!widget.showNearExpiryOnly) // ← 通常モードの時だけボタン表示
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.pushNamed(context, '/calendar');
            },
          ),
        if (!widget.showNearExpiryOnly)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/add');
            },
          ),
      ],
      ),
      
      body: Column(
        children: [
          // タブ切り替え（賞味期限モードでは非表示）
          if (!widget.showNearExpiryOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(8),
                isSelected: [
                  _selectedTab == 'refrigerated',
                  _selectedTab == 'frozen',
                ],
                onPressed: (index) {
                  setState(() {
                    _selectedTab = index == 0 ? 'refrigerated' : 'frozen';
                  });
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('冷蔵'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('冷凍'),
                  ),
                ],
              ),
            ),

          // Firestoreデータ一覧
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStocksStream(uid!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('在庫がありません'));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? '胸肉';
                    final exp = (data['expirationDate'] as Timestamp?)?.toDate();
                    final storageType = data['storageType'] ?? '';
                    final remain = data['remainingWeight'] ?? 0;

                    final expText = exp != null
                        ? DateFormat('yyyy/MM/dd').format(exp)
                        : '不明';
                    final typeLabel = storageType == 'refrigerated'
                        ? '冷蔵'
                        : storageType == 'frozen'
                            ? '冷凍'
                            : '不明';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: storageType == 'refrigerated'
                              ? Colors.orangeAccent.withOpacity(0.2)
                              : Colors.lightBlueAccent.withOpacity(0.2),
                          child: Icon(
                            storageType == 'refrigerated' ? Icons.kitchen : Icons.ac_unit,
                            color: storageType == 'refrigerated'
                                ? Colors.orangeAccent
                                : Colors.lightBlueAccent,
                          ),
                        ),
                        title: Text(
                          '残り ${remain}g（${storageType == 'refrigerated' ? '冷蔵' : '冷凍'}）',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '賞味期限：${DateFormat('yyyy/MM/dd').format(exp ?? DateTime.now())}',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // 🚫 賞味期限モードではボタン非表示
      floatingActionButton: widget.showNearExpiryOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, '/intake');
              },
              icon: const Icon(Icons.fitness_center),
              label: const Text('摂取記録'),
              backgroundColor: Colors.orangeAccent,
            ),
    );
  }
}