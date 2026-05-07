import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/medicine_provider.dart';
import '../models/medicine.dart';
import '../utils/medicine_categories.dart';
import '../widgets/hover_scale.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header (Same as Home)
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

            // Big Pill Visual (Restored to 200x200 as per dashboard)
            SliverToBoxAdapter(
              child: Center(
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

            // Title
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    'Medication Bag',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),

            // Medicine List
            if (provider.loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.medicines.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Your medication bag is empty.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _MedicineInfoCard(medicine: provider.medicines[index]);
                    },
                    childCount: provider.medicines.length,
                  ),
                ),
              ),
            
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(currentIndex: -1), // Custom nav for this page
    );
  }
}

class _MedicineInfoCard extends StatefulWidget {
  final Medicine medicine;
  const _MedicineInfoCard({required this.medicine});

  @override
  State<_MedicineInfoCard> createState() => _MedicineInfoCardState();
}

class _MedicineInfoCardState extends State<_MedicineInfoCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cat = categoryFromKey(widget.medicine.category);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF), // Soft Purple background
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (Always visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: _isExpanded ? const Color(0xFF6366F1).withOpacity(0.6) : const Color(0xFF6366F1).withOpacity(0.5),
                borderRadius: _isExpanded 
                    ? const BorderRadius.vertical(top: Radius.circular(24))
                    : BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.medicine.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(cat.icon, color: Colors.red[400], size: 20),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoSection(
                    title: 'Medicine information',
                    content: widget.medicine.instructions ?? 'No description provided.',
                  ),
                  const SizedBox(height: 16),
                  _InfoSection(
                    title: 'Medicine Dosage',
                    content: widget.medicine.dosage,
                  ),
                  const SizedBox(height: 16),
                  _InfoSection(
                    title: 'Medicine Instructions',
                    content: 'Take as prescribed by your doctor.',
                  ),
                  const SizedBox(height: 16),
                  _InfoSection(
                    title: 'Medice Duration',
                    content: '${widget.medicine.startDate} to ${widget.medicine.endDate ?? 'Ongoing'}',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC6FF00), // Lime Green
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'See Prescription',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_circle_right_rounded, size: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final String content;

  const _InfoSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.8),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const _BottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
              ),
              _NavBarItem(
                icon: Icons.calendar_month_rounded,
                label: 'Schedule',
                isSelected: currentIndex == 1,
                onTap: () => Navigator.pushReplacementNamed(context, '/schedule'),
              ),
              const SizedBox(width: 60),
              _NavBarItem(
                icon: Icons.bar_chart_rounded,
                label: 'Report',
                isSelected: currentIndex == 2,
                onTap: () => Navigator.pushReplacementNamed(context, '/report'),
              ),
              _NavBarItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isSelected: currentIndex == 3,
                onTap: () {},
              ),
            ],
          ),
          Positioned(
            top: -30,
            left: 0,
            right: 0,
            child: Center(
              child: HoverScale(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/scan'),
                  behavior: HitTestBehavior.translucent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6FF00),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC6FF00).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.document_scanner_rounded, color: Colors.black, size: 32),
                      ),
                      const SizedBox(height: 4),
                      const Text('SCAN', style: TextStyle(color: Color(0xFFC6FF00), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF6366F1) : Colors.grey[600], size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? const Color(0xFF6366F1) : Colors.grey[600], fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
