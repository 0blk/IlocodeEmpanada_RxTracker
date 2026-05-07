import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/medicine_provider.dart';
import '../models/dose.dart';
import '../widgets/dose_card.dart';
import '../widgets/hover_scale.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

    // Dates for the horizontal selector
    final dates = List.generate(7, (index) => now.add(Duration(days: index - 2)));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
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

            // Date Selector
            SliverToBoxAdapter(
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    final isToday = date.day == now.day && date.month == now.month;
                    
                    return GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 60,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isToday ? const Color(0xFF6366F1) : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isToday ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              DateFormat('E').format(date).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isToday ? Colors.white70 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Today's Date Text
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                child: Center(
                  child: Text(
                    DateFormat('MMMM d, yyyy').format(now),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),

            // 3D Pill Visual
            SliverToBoxAdapter(
              child: Center(
                child: HoverScale(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/medicene');
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF6366F1).withOpacity(0.4),
                                const Color(0xFF6366F1).withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Image.asset(
                          'assets/pill_3d_visual.png',
                          width: 120,
                          height: 120,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.medication_rounded, size: 100, color: Colors.indigo[400]);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Schedule Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Schedule",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),

            // Doses List
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return DoseCard(dose: provider.todayDoses[index]);
                    },
                    childCount: provider.todayDoses.length,
                  ),
                ),
              ),
            
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }
}
