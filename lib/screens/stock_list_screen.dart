import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:tyokin/services/stats_service.dart';
import 'package:tyokin/native/native_bridge.dart';
import 'package:tyokin/widgets/HalfCircleProgress.dart';

class StockListScreen extends StatefulWidget {
  final bool showNearExpiryOnly;

  const StockListScreen({super.key, this.showNearExpiryOnly = false});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  String _selectedTab = 'refrigerated';
  final uid = FirebaseAuth.instance.currentUser?.uid;

  Stream<QuerySnapshot> _getStocksStream(String uid) {
    final now = DateTime.now();
    final limitDate = now.add(const Duration(days: 3));

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stocks');

    if (widget.showNearExpiryOnly) {
      return ref
          .where('expirationDate',
              isLessThanOrEqualTo: Timestamp.fromDate(limitDate))
          .orderBy('expirationDate')
          .snapshots();
    } else {
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

  double _getTotal(Map<String, dynamic> data) {
    final v = data['weight'] ?? data['remainingWeight'] ?? 0;
    return (v as num).toDouble();
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  int? _daysLeft(DateTime? exp) {
    if (exp == null) return null;
    final today = _stripTime(DateTime.now());
    final e = _stripTime(exp);
    return e.difference(today).inDays;
  }

  Color _badgeColor(int days) {
    if (days <= 0) return Colors.red;
    if (days <= 1) return Colors.deepOrange;
    if (days <= 3) return Colors.orange;
    return Colors.green;
  }

  String _daysText(int days) {
    if (days <= 0) return '期限切れ';
    return 'あと$days日';
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
              onPressed: () => Navigator.pushNamed(context, '/add'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.showNearExpiryOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(10),
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
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text('冷蔵'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text('冷凍'),
                  ),
                ],
              ),
            ),

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

                // 0gは表示しない
                final validDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _getRemain(data) > 0;
                }).toList();

                if (validDocs.isEmpty) {
                  return const Center(child: Text('在庫がありません'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,          // ✅ 2列
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.70,     // ✅ 高さを少し確保（好みで調整OK）
                  ),
                  itemCount: validDocs.length,
                  itemBuilder: (context, index) {
                    final doc = validDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final exp = (data['expirationDate'] as Timestamp?)?.toDate();
                    final expText =
                        exp != null ? DateFormat('yyyy/MM/dd').format(exp) : '不明';

                    final storageType = (data['storageType'] ?? '') as String;
                    final isRefrig = storageType == 'refrigerated';

                    final remain = _getRemain(data);
                    final total = _getTotal(data);
                    final progress = total <= 0 ? 0.0 : (remain / total).clamp(0.0, 1.0);

                    final days = _daysLeft(exp);

                    return Slidable(
                      key: ValueKey(doc.id),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.35,
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
                                final stockId = doc.id;

                                await doc.reference.delete();

                                // 通知キャンセル（失敗しても続行）
                                try {
                                  await NativeNotification.cancelByStockId(stockId);
                                } catch (_) {}

                                // stats更新（失敗しても続行）
                                try {
                                  await StatsService.recomputeNearExpiryCount(uid!);
                                } catch (_) {}

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
                      child: _StockTile(
                        isRefrig: isRefrig,
                        remainG: remain.toInt(),
                        totalG: total.toInt(),
                        expText: expText,
                        daysLeft: days,
                        badgeColor: (days == null) ? Colors.grey : _badgeColor(days),
                        badgeText: (days == null) ? '期限不明' : _daysText(days),
                        progress: progress,
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

class _StockTile extends StatelessWidget {
  final bool isRefrig;
  final int remainG;
  final int totalG;
  final String expText;
  final int? daysLeft;
  final Color badgeColor;
  final String badgeText;
  final double progress;
  

  const _StockTile({
    required this.isRefrig,
    required this.remainG,
    required this.totalG,
    required this.expText,
    required this.daysLeft,
    required this.badgeColor,
    required this.badgeText,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isRefrig ? Icons.kitchen : Icons.ac_unit;
    final label = isRefrig ? '冷蔵' : '冷凍';
    final progress = remainG / totalG;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2EA),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // ✅ 溢れにくくする
          children: [
            // 上段：アイコン + バッジ
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isRefrig
                      ? Colors.orangeAccent.withOpacity(0.18)
                      : Colors.lightBlueAccent.withOpacity(0.18),
                  child: Icon(
                    icon,
                    color: isRefrig ? Colors.orangeAccent : Colors.lightBlueAccent,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 中段：残りg
            RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  const TextSpan(
                    text: '残り ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  TextSpan(
                    text: '$remainG',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(
                    text: 'g ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: '（$label）',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ✅ 半円を主役に（専用スペース確保）
            Center(
              child: HalfCircleProgress(
                progress: progress.clamp(0.0, 1.0),
                size: 128, // ✅ 大きめ（ここで調整）
                centerText: '${(progress * 100).round()}%',
              ),
            ),

            const SizedBox(height: 8),

            // 下段：期限 & 容量（改行しても崩れない）
            Text(
              '賞味期限：$expText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.black.withOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '容量：$totalG g',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.45),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}