import 'package:cloud_firestore/cloud_firestore.dart';

class StatsService {
  static Future<void> recomputeNearExpiryCount(String uid) async {
    final now = DateTime.now();
    final limitDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 3));

    final stocksSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stocks')
        .where('remainingWeight', isGreaterThan: 0)
        .where('expirationDate', isLessThanOrEqualTo: Timestamp.fromDate(limitDate))
        .get();

    final summaryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stats')
        .doc('summary');

    await summaryRef.set({
      'nearExpiryCount': stocksSnap.size,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}