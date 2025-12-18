import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class IntakeCalendarScreen extends StatefulWidget {
  const IntakeCalendarScreen({super.key});

  @override
  State<IntakeCalendarScreen> createState() => _IntakeCalendarScreenState();
}

class _IntakeCalendarScreenState extends State<IntakeCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;
  DateTime? _selectedDay;
  Map<DateTime, double> _proteinPerDay = {};
  static const double _proteinGoal = 100.0; // 目標タンパク質量 (g)

  @override
  void initState() {
    super.initState();
    _loadIntakeData();
  }

  Future<void> _loadIntakeData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('intakeLogs')
        .get();

    final Map<DateTime, double> data = {};

    for (var doc in snap.docs) {
      final d = doc.data();
      final date = (d['intakeDate'] as Timestamp).toDate();
      final protein = (d['proteinAmount'] ?? 0).toDouble();
      final key = DateTime(date.year, date.month, date.day);
      data[key] = (data[key] ?? 0) + protein;
    }

    setState(() {
      _proteinPerDay = data;
    });
  }

  double _getProteinForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _proteinPerDay[key] ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _selectedDay ?? DateTime.now();
    final todayProtein = _getProteinForDay(selectedDay);
    final progress = (todayProtein / _proteinGoal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('摂取カレンダー')),
      body: Column(
        children: [
          // 📅 カレンダー部分
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,

            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),

            calendarFormat: _calendarFormat,

            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.twoWeeks: '2 weeks',
            },

            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },

            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },

            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },

            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final protein = _getProteinForDay(day);
                if (protein == 0) return null;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.day}', style: const TextStyle(fontSize: 16)),
                      Text(
                        '${protein.toStringAsFixed(0)}g',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 📊 選択日の合計摂取量バー表示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  '${DateFormat('yyyy/MM/dd').format(selectedDay)} の摂取量',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 20,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 20,
                      width:
                          MediaQuery.of(context).size.width * 0.9 * progress,
                      decoration: BoxDecoration(
                        color: progress >= 1.0
                            ? Colors.green
                            : Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${todayProtein.toStringAsFixed(1)} g / ${_proteinGoal.toStringAsFixed(0)} g',
                  style: TextStyle(
                    fontSize: 14,
                    color: progress >= 1.0
                        ? Colors.green[700]
                        : Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 📜 選択日の詳細リスト
          Expanded(child: _buildSelectedDayList(selectedDay)),
        ],
      ),
    );
  }

  Widget _buildSelectedDayList(DateTime date) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('intakeLogs')
        .where('intakeDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart))
        .where('intakeDate', isLessThan: Timestamp.fromDate(dateEnd))
        .orderBy('intakeDate', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('この日の摂取記録はありません'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final w = d['intakeWeight'] ?? 0;
            final p = d['proteinAmount'] ?? 0;
            return ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: Text('摂取量: ${w}g'),
              subtitle: Text('タンパク質: ${p.toStringAsFixed(1)}g'),
            );
          },
        );
      },
    );
  }
}