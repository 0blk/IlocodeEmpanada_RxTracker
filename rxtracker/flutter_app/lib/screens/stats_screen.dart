import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/medicine_provider.dart';
import '../models/medicine.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats & Medicines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.refresh,
          ),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.refresh,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Overall adherence card
                  _OverallStats(provider: provider),
                  const SizedBox(height: 16),

                  Text(
                    'Per-Medicine Adherence',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...provider.stats.map((s) => _AdherenceCard(stat: s)),

                  const SizedBox(height: 16),
                  Text(
                    'All Medicines',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (provider.medicines.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No medicines added yet'),
                      ),
                    )
                  else
                    ...provider.medicines.map(
                      (m) => _MedicineManageCard(
                        medicine: m,
                        onDelete: () => _confirmDelete(context, provider, m),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MedicineProvider provider,
    Medicine medicine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text(
            'Delete ${medicine.name}? All dose logs will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteMedicine(medicine.id!);
    }
  }
}

class _OverallStats extends StatelessWidget {
  final MedicineProvider provider;

  const _OverallStats({required this.provider});

  @override
  Widget build(BuildContext context) {
    final totalDoses =
        provider.stats.fold<int>(0, (s, e) => s + (e['total_doses_logged'] as int));
    final takenDoses =
        provider.stats.fold<int>(0, (s, e) => s + (e['doses_taken'] as int));
    final overallPct =
        totalDoses > 0 ? (takenDoses / totalDoses * 100).toInt() : 0;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              label: 'Overall\nAdherence',
              value: '$overallPct%',
              icon: Icons.bar_chart,
            ),
            _StatItem(
              label: 'Doses\nTaken',
              value: '$takenDoses',
              icon: Icons.check_circle,
            ),
            _StatItem(
              label: 'Active\nMedicines',
              value: '${provider.medicines.where((m) => m.isActive).length}',
              icon: Icons.medication,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
      ],
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  final Map<String, dynamic> stat;

  const _AdherenceCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final pct = (stat['adherence_pct'] as num).toDouble();
    final color = pct >= 80
        ? Colors.green
        : pct >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stat['medicine_name'] as String,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: pct / 100,
              color: color,
              backgroundColor: color.withOpacity(0.2),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 4),
            Text(
              '${stat['doses_taken']} of ${stat['total_doses_logged']} doses taken'
              '${stat['stock'] != null ? " · ${stat['stock']} pills remaining" : ""}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineManageCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onDelete;

  const _MedicineManageCard({required this.medicine, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: medicine.isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey[200],
          child: Icon(
            Icons.medication,
            color: medicine.isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
        title: Text(medicine.name),
        subtitle: Text(
          '${medicine.dosage} · ${medicine.frequencyLabel}'
          '${medicine.stock != null ? " · ${medicine.stock} pills" : ""}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (medicine.lowStock)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.warning_amber, color: Colors.amber, size: 20),
              ),
            if (!medicine.isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ended',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.grey[700]),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
