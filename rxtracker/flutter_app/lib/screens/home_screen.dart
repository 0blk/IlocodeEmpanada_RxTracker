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
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RxTracker', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(today, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.medication),
            onPressed: () => Navigator.pushNamed(context, '/add-medicine'),
            tooltip: 'Manage medicines',
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
                      SliverToBoxAdapter(
                        child: AdherenceBanner(provider: provider),
                      ),
                      if (provider.todayDoses.isEmpty)
                        const SliverFillRemaining(
                          child: _EmptyDoses(),
                        )
                      else ...[
                        _SectionHeader(
                          title: 'Overdue',
                          doses: provider.todayDoses
                              .where((d) => d.isOverdue)
                              .toList(),
                          color: Colors.red,
                        ),
                        _SectionHeader(
                          title: 'Due Now',
                          doses: provider.todayDoses
                              .where((d) => !d.taken && !d.isOverdue && !d.isUpcoming)
                              .toList(),
                          color: Colors.orange,
                        ),
                        _SectionHeader(
                          title: 'Upcoming',
                          doses: provider.todayDoses
                              .where((d) => d.isUpcoming)
                              .toList(),
                          color: Colors.blue,
                        ),
                        _SectionHeader(
                          title: 'Taken',
                          doses: provider.todayDoses
                              .where((d) => d.taken)
                              .toList(),
                          color: Colors.green,
                        ),
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 80),
                        ),
                      ],
                    ],
                  ),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$title (${doses.length})',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
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
  const _EmptyDoses();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No medicines scheduled today',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a medicine or scan a prescription',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[500]),
          ),
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
            const Icon(Icons.cloud_off, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Could not connect to server',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
