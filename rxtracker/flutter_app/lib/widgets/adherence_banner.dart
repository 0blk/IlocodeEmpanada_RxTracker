import 'package:flutter/material.dart';
import '../services/medicine_provider.dart';

class AdherenceBanner extends StatelessWidget {
  final MedicineProvider provider;

  const AdherenceBanner({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final pct = (provider.todayAdherence * 100).toInt();
    final total = provider.todayDoses.length;
    final taken = provider.takenToday;
    final pending = provider.pendingDoseCount;

    Color bannerColor;
    if (pct >= 80) {
      bannerColor = Colors.green;
    } else if (pct >= 50) {
      bannerColor = Colors.orange;
    } else {
      bannerColor = Colors.red;
    }

    // Low stock warnings
    final lowStock = provider.medicines.where((m) => m.lowStock).toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerColor.withOpacity(0.1),
            border: Border.all(color: bannerColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Progress ring substitute (linear)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Progress",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: provider.todayAdherence,
                      color: bannerColor,
                      backgroundColor: bannerColor.withOpacity(0.2),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$taken of $total doses taken',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Big percentage
              Column(
                children: [
                  Text(
                    '$pct%',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: bannerColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (pending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pending pending',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Low stock warnings
        if (lowStock.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              border: Border.all(color: Colors.amber),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Low stock: ${lowStock.map((m) => '${m.name} (${m.stock} left)').join(', ')}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
