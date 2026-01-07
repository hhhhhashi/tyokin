import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/intake_add_screen.dart';
import 'screens/intake_calendar_screen.dart';
import 'screens/stock_add_screen.dart';
import 'screens/stock_list_screen.dart';
import 'screens/growth_history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 匿名ログイン（ユーザーごとにデータを分離）
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    // 失敗しても起動は継続（後でUIに通知してもOK）
    debugPrint('Anonymous sign-in failed: $e');
  }

  runApp(const TorirecoApp());
}

class TorirecoApp extends StatelessWidget {
  const TorirecoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'とりレコ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFFB703),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(), //
        '/add': (context) => const StockAddScreen(),
        '/intake': (context) => const IntakeAddScreen(), // ←これを追加
        '/calendar': (context) => const IntakeCalendarScreen(), // ←追加
        '/stockList': (context) => const StockListScreen(), 
        '/growthHistory': (_) => const GrowthHistoryScreen(),
      },
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('とりレコ 🐔')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('まずは「在庫追加」からはじめましょう'),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('在庫追加へ'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StockAddScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            if (uid != null)
              Text(
                'UID: $uid',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}