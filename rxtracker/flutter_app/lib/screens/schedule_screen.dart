import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/medicine_provider.dart';
import '../models/dose.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final now = DateTime.now();
    final hour = now.hour;
    
    String greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    // Grouping doses by AM/PM
    final amDoses = provider.todayDoses.where((d) {
      final time = DateTime.parse(d.scheduledTime);
      return time.hour < 12;
    }).toList();

    final pmDoses = provider.todayDoses.where((d) {
      final time = DateTime.parse(d.scheduledTime);
      return time.hour >= 12;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting,',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                          const Text(
                            'Ilocode Empanada',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.notifications_none_rounded, size: 28),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.limeAccent[400],
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            // Date & Time Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    // Big Date Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1), // Purple
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${now.day}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            DateFormat('E').format(now).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC6FF00), // Lime
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMMM d, yyyy').format(now),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          DateFormat('h:mm a').format(now),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Today's Schedule Title
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  "Today's Schedule",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Schedule List
            if (provider.loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.todayDoses.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No medicines scheduled for today.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ...amDoses.map((d) => _ScheduleItem(dose: d, isPm: false)),
                    ...pmDoses.map((d) => _ScheduleItem(dose: d, isPm: true)),
                  ]),
                ),
              ),
            
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final TodayDose dose;
  final bool isPm;

  const _ScheduleItem({required this.dose, required this.isPm});

  @override
  Widget build(BuildContext context) {
    final timeFormatted = DateFormat('h:mm a').format(
      DateTime.parse(dose.scheduledTime),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPm ? const Color(0xFF6366F1).withOpacity(0.8) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(
                color: isPm ? Colors.white : Colors.black,
                width: 3,
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicineName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPm ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  dose.dosage,
                  style: TextStyle(
                    fontSize: 14,
                    color: isPm ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeFormatted,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isPm ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
