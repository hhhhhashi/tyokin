// lib/screens/growth_history_screen.dart
import 'package:flutter/material.dart';

class GrowthHistoryScreen extends StatelessWidget {
  const GrowthHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('成長履歴')),
      body: const Center(
        child: Text('成長履歴（今後実装）'),
      ),
    );
  }
}