import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/medicine_provider.dart';
import '../models/dose.dart';
import '../widgets/dose_card.dart';
import '../widgets/adherence_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning! ☀️'
        : hour < 17
            ? 'Good afternoon! 🌤️'
            : 'Good evening! 🌙';

    // Unique categories from today's doses
    final doseCategories = provider.todayDoses
        .map((d) => d.category)
        .where((c) => c != null && c.isNotEmpty)
        .toSet()
        .cast<String>()
        .toList();

    // Optionally filter doses by category
    List<TodayDose> filtered = provider.todayDoses;
    if (_filterCategory != null) {
      filtered = filtered.where((d) => d.category == _filterCategory).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RxTracker',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(today,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 13)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            iconSize: 26,
            onPressed: () => provider.refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? _ErrorState(
                  message: provider.error!,
                  onRetry: provider.refresh,
                )
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: CustomScrollView(
                    slivers: [
                      // Greeting banner
                      SliverToBoxAdapter(
                        child: _GreetingBanner(greeting: greeting),
                      ),

                      // Adherence banner
                      SliverToBoxAdapter(
                        child: AdherenceBanner(provider: provider),
                      ),

                      // Category filter chips
                      if (doseCategories.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _CategoryFilterRow(
                            categories: doseCategories,
                            selected: _filterCategory,
                            onSelected: (k) => setState(
                              () => _filterCategory =
                                  (_filterCategory == k) ? null : k,
                            ),
                          ),
                        ),

                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          child: _EmptyDoses(
                              hasFilter: _filterCategory != null),
                        )
                      else ...[
                        _SectionHeader(
                          title: 'Overdue',
                          doses: filtered
                              .where((d) => d.isOverdue)
                              .toList(),
                          color: Colors.red,
                        ),
                        _SectionHeader(
                          title: 'Due Now',
                          doses: filtered
                              .where((d) =>
                                  !d.taken && !d.isOverdue && !d.isUpcoming)
                              .toList(),
                          color: Colors.orange,
                        ),
                        _SectionHeader(
                          title: 'Upcoming',
                          doses: filtered
                              .where((d) => d.isUpcoming)
                              .toList(),
                          color: Colors.blue,
                        ),
                        _SectionHeader(
                          title: 'Taken',
                          doses: filtered
                              .where((d) => d.taken)
                              .toList(),
                          color: Colors.green,
                        ),
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 100),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _GreetingBanner extends StatelessWidget {
  final String greeting;

  const _GreetingBanner({required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Remember to take your medicines on time.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.medication, color: Colors.white70, size: 36),
        ],
      ),
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final void Function(String) onSelected;

  const _CategoryFilterRow({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: categories.map((key) {
          final isSelected = selected == key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(key[0].toUpperCase() + key.substring(1).replaceAll('_', ' ')),
              selected: isSelected,
              onSelected: (_) => onSelected(key),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : null,
              ),
              selectedColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final List<TodayDose> doses;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.doses,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (doses.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$title (${doses.length})',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
        ),
        ...doses.map((dose) => DoseCard(dose: dose)),
      ]),
    );
  }
}

class _EmptyDoses extends StatelessWidget {
  final bool hasFilter;
  const _EmptyDoses({this.hasFilter = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'No medicines in this category today.'
                : 'No medicines scheduled today.',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[500], fontSize: 17),
            textAlign: TextAlign.center,
          ),
          if (!hasFilter) ...[
            const SizedBox(height: 8),
            Text(
              'Tap the + button below to add a medicine\nor scan a prescription.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text('Could not connect to server',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Make sure the backend is running.\n$message',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              width: 180,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
