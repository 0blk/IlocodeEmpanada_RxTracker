import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/medicine_provider.dart';
import '../models/medicine.dart';
import '../utils/medicine_categories.dart';
import '../widgets/hover_scale.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

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

    final activeMedicines = provider.medicines.where((m) => m.isActive).toList();

    return SafeArea(
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
                        Text(
                          provider.profile?['full_name']?.split(' ')[0] ?? 'User',
                          style: const TextStyle(
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

          // Title Bar
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1), // Purple Bar
              ),
              child: const Text(
                'Doctors Report',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Main Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Current Maintenance Medication Section
                _ReportSection(
                  title: 'Current Maintenance Medication',
                  items: activeMedicines.map((m) => _ReportItem(
                    name: m.name,
                    subtitle: '${m.dosage} - ${m.frequency.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}',
                    status: 'Active',
                    category: m.category,
                  )).toList(),
                ),

                const SizedBox(height: 24),

                // Previous Prescriptions Section
                _ReportSection(
                  title: 'Previous Prescriptions',
                  items: () {
                    final inactive = provider.medicines.where((m) => !m.isActive).toList();
                    // Group by startDate (assuming same scan date = same prescription)
                    final Map<String, List<Medicine>> grouped = {};
                    for (var m in inactive) {
                      grouped.putIfAbsent(m.startDate, () => []).add(m);
                    }
                    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
                    
                    return sortedDates.map((date) {
                      final meds = grouped[date]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text(
                              'Prescription from $date',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                          ),
                          ...meds.map((m) => _ReportItem(
                            name: m.name,
                            subtitle: m.dosage,
                            status: 'Completed',
                            category: m.category,
                          )),
                        ],
                      );
                    }).toList();
                  }(),
                ),

                const SizedBox(height: 32),

                // Share and Export Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1), // Purple
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Share and Export',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_circle_right_rounded, size: 24),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _ReportSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF), // Soft Purple background
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(2), // Thin border effect
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 24),
            ),
            ...items,
          ],
        ),
      ),
    );
  }
}

class _ReportItem extends StatelessWidget {
  final String name;
  final String subtitle;
  final String status;
  final String? category;

  const _ReportItem({
    required this.name,
    required this.subtitle,
    required this.status,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final cat = categoryFromKey(category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(cat.icon, size: 16, color: Colors.red[400]),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6FF00), // Lime Green
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.black.withOpacity(0.05)),
        ],
      ),
    );
  }
}
