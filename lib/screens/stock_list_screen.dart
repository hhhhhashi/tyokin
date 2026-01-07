import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:tyokin/services/stats_service.dart';
import 'package:tyokin/native/native_bridge.dart';

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

  double _getRemain(Map<String, dynamic> data) {
    final v = data['remainingWeight'] ?? data['weight'] ?? 0;
    return (v as num).toDouble();
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
        title: Text(widget.showNearExpiryOnly ? '⚠️ 賞味期限が近い在庫一覧' : '在庫一覧'),
        actions: [
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
                // ✅ 0gは表示しないだけ
                final validDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _getRemain(data) > 0;
                }).toList();

                if (validDocs.isEmpty) {
                  return const Center(child: Text('在庫がありません'));
                }

                return ListView.builder(
                  itemCount: validDocs.length,
                  itemBuilder: (context, index) {
                    final data = validDocs[index].data() as Map<String, dynamic>;
                    final exp = (data['expirationDate'] as Timestamp?)?.toDate();
                    final storageType = (data['storageType'] ?? '') as String;

                    final remain = _getRemain(data).toInt();

                    final typeLabel = storageType == 'refrigerated'
                        ? '冷蔵'
                        : storageType == 'frozen'
                            ? '冷凍'
                            : '不明';

                    final expText = exp != null
                        ? DateFormat('yyyy/MM/dd').format(exp)
                        : '不明';

                    return Slidable(
                      key: ValueKey(validDocs[index].id),

                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.25,
                        children: [
                          SlidableAction(
                            onPressed: (_) async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('削除確認'),
                                  content: const Text('この在庫を削除しますか？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('キャンセル'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('削除'),
                                    ),
                                  ],
                                ),
                              );

                              if (result == true) {
                                final stockId = validDocs[index].id;

                                // ① Firestoreから削除
                                await validDocs[index].reference.delete();

                                // ② 通知をキャンセル（失敗しても続行）
                                try {
                                  await NativeNotification.cancelByStockId(stockId);
                                } catch (e) {
                                  debugPrint('cancelByStockId failed: $e');
                                }

                                // ③ stats更新（今のままでOK）
                                try {
                                  await StatsService.recomputeNearExpiryCount(uid!);
                                } catch (e) {
                                  debugPrint('recomputeNearExpiryCount failed: $e');
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('在庫を削除しました')),
                                  );
                                }
                              }
                            },
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: '削除',
                          ),
                        ],
                      ),
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: storageType == 'refrigerated'
                              ? Colors.orangeAccent.withOpacity(0.2)
                              : Colors.lightBlueAccent.withOpacity(0.2),
                          child: Icon(
                            storageType == 'refrigerated'
                                ? Icons.kitchen
                                : Icons.ac_unit,
                            color: storageType == 'refrigerated'
                                ? Colors.orangeAccent
                                : Colors.lightBlueAccent,
                          ),
                        ),
                        title: Text(
                          '残り ${remain}g（$typeLabel）',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('賞味期限：$expText'),
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
    );
  }
}