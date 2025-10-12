import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  String _selectedTab = 'refrigerated'; // 'refrigerated' or 'frozen'

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('ログインエラー（UIDが取得できません）')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stocks')
        .where('storageType', isEqualTo: _selectedTab)
        .orderBy('expirationDate')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('在庫一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '在庫追加',
            onPressed: () {
              Navigator.pushNamed(context, '/add');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'refrigerated', label: Text('冷蔵')),
              ButtonSegment(value: 'frozen', label: Text('冷凍')),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (s) => setState(() => _selectedTab = s.first),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('登録された在庫がありません'));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final expiration = (data['expirationDate'] as Timestamp?)?.toDate();
                    final purchase = (data['purchaseDate'] as Timestamp?)?.toDate();
                    final weight = data['weight'] ?? 0;
                    final remaining = data['remainingWeight'] ?? 0;
                    final isExpired = expiration != null && expiration.isBefore(DateTime.now());
                    final daysLeft = expiration == null
                        ? null
                        : expiration.difference(DateTime.now()).inDays;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(
                          _selectedTab == 'refrigerated'
                              ? Icons.kitchen_outlined
                              : Icons.ac_unit,
                          color: _selectedTab == 'refrigerated'
                              ? Colors.brown
                              : Colors.blueGrey,
                        ),
                        title: Text('${weight}g（残り${remaining}g）'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (purchase != null)
                              Text('購入日: ${DateFormat('yyyy/MM/dd').format(purchase)}'),
                            if (expiration != null)
                              Text(
                                '賞味期限: ${DateFormat('yyyy/MM/dd').format(expiration)}',
                                style: TextStyle(
                                  color: isExpired
                                      ? Colors.red
                                      : (daysLeft != null && daysLeft <= 2
                                          ? Colors.orange
                                          : null),
                                ),
                              ),
                            if (daysLeft != null && daysLeft >= 0)
                              Text('残り $daysLeft 日', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('削除しますか？'),
                                content: const Text('この在庫データを削除します。'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await docs[index].reference.delete();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('削除しました')),
                                );
                              }
                            }
                          },
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
      floatingActionButton: FloatingActionButton.extended(
      onPressed: () {
        Navigator.pushNamed(context, '/intake');
      },
      icon: const Icon(Icons.restaurant),
      label: const Text('摂取追加'),
      ),
    );
  }
}