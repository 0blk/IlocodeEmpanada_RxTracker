import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/medicine_provider.dart';
import '../models/medicine.dart';
import '../utils/medicine_categories.dart';
import 'add_medicine_screen.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, Medicine med) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 40),
        title: const Text(
          'Remove Medicine?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove "${med.name}" and all its history?\n\nThis cannot be undone.',
          style: const TextStyle(fontSize: 16),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Yes, Remove'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final ok = await context.read<MedicineProvider>().deleteMedicine(med.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '${med.name} removed.' : 'Failed to remove medicine.'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final active = provider.medicines.where((m) => m.isActive).toList();
    final inactive = provider.medicines.where((m) => !m.isActive).toList();

    // Category filter chips
    final allCategories = provider.medicines
        .map((m) => m.category)
        .where((c) => c != null)
        .toSet()
        .cast<String>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Medicines',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Active (${active.length})'),
            Tab(text: 'Inactive (${inactive.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Category filter
          if (allCategories.isNotEmpty)
            _CategoryFilterRow(
              categories: allCategories,
              selected: _filterCategory,
              onSelected: (k) => setState(
                () => _filterCategory = (_filterCategory == k) ? null : k,
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MedicineList(
                  medicines: _filterCategory == null
                      ? active
                      : active
                          .where((m) => m.category == _filterCategory)
                          .toList(),
                  onEdit: (m) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddMedicineScreen(prefill: m, isEdit: true),
                    ),
                  ).then((_) => provider.refresh()),
                  onDelete: (m) => _confirmDelete(context, m),
                  emptyMessage: 'No active medicines.\nTap + to add one.',
                ),
                _MedicineList(
                  medicines: _filterCategory == null
                      ? inactive
                      : inactive
                          .where((m) => m.category == _filterCategory)
                          .toList(),
                  onEdit: (m) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddMedicineScreen(prefill: m, isEdit: true),
                    ),
                  ).then((_) => provider.refresh()),
                  onDelete: (m) => _confirmDelete(context, m),
                  emptyMessage: 'No past medicines.',
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'medicines_fab',
        onPressed: () => Navigator.pushNamed(context, '/add-medicine')
            .then((_) => provider.refresh()),
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine', style: TextStyle(fontSize: 16)),
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
          final cat = categoryFromKey(key);
          final isSelected = selected == key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(cat.icon, size: 16,
                  color: isSelected ? Colors.white : cat.color),
              label: Text(cat.label),
              selected: isSelected,
              selectedColor: cat.color,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => onSelected(key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MedicineList extends StatelessWidget {
  final List<Medicine> medicines;
  final void Function(Medicine) onEdit;
  final void Function(Medicine) onDelete;
  final String emptyMessage;

  const _MedicineList({
    required this.medicines,
    required this.onEdit,
    required this.onDelete,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (medicines.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: medicines.length,
      itemBuilder: (_, i) => _MedicineCard(
        medicine: medicines[i],
        onEdit: () => onEdit(medicines[i]),
        onDelete: () => onDelete(medicines[i]),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicineCard({
    required this.medicine,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = categoryFromKey(medicine.category);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        cat.label,
                        style: TextStyle(
                          color: cat.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (medicine.lowStock)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber, size: 14,
                            color: Colors.orange[800]),
                        const SizedBox(width: 4),
                        Text(
                          '${medicine.stock} left',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                _InfoChip(
                    icon: Icons.straighten,
                    label: medicine.dosage),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: Icons.repeat,
                    label: medicine.frequencyLabel),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${dateFormat.format(DateTime.parse(medicine.startDate))}'
                  '${medicine.endDate != null ? ' → ${dateFormat.format(DateTime.parse(medicine.endDate!))}' : ' (ongoing)'}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (medicine.instructions != null &&
                medicine.instructions!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      medicine.instructions!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit',
                        style: TextStyle(fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove',
                        style: TextStyle(fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red[700],
                      elevation: 0,
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
