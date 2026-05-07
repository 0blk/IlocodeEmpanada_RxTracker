import 'package:flutter/material.dart';

/// Defines the supported medicine categories with display names, icons, and colors.
class MedicineCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const MedicineCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<MedicineCategory> kMedicineCategories = [
  MedicineCategory(
    key: 'hypertension',
    label: 'Hypertension',
    icon: Icons.favorite,
    color: Color(0xFFE53E3E),
  ),
  MedicineCategory(
    key: 'diabetes',
    label: 'Diabetes',
    icon: Icons.water_drop,
    color: Color(0xFF3182CE),
  ),
  MedicineCategory(
    key: 'antibiotic',
    label: 'Antibiotic',
    icon: Icons.biotech,
    color: Color(0xFF38A169),
  ),
  MedicineCategory(
    key: 'cardiac',
    label: 'Cardiac',
    icon: Icons.monitor_heart,
    color: Color(0xFFDD6B20),
  ),
  MedicineCategory(
    key: 'pain_relief',
    label: 'Pain Relief',
    icon: Icons.healing,
    color: Color(0xFF805AD5),
  ),
  MedicineCategory(
    key: 'mental_health',
    label: 'Mental Health',
    icon: Icons.psychology,
    color: Color(0xFF2C7A7B),
  ),
  MedicineCategory(
    key: 'vitamins',
    label: 'Vitamins & Supplements',
    icon: Icons.local_pharmacy,
    color: Color(0xFFD69E2E),
  ),
  MedicineCategory(
    key: 'respiratory',
    label: 'Respiratory',
    icon: Icons.air,
    color: Color(0xFF4299E1),
  ),
  MedicineCategory(
    key: 'gastrointestinal',
    label: 'Gastrointestinal',
    icon: Icons.self_improvement,
    color: Color(0xFF68D391),
  ),
  MedicineCategory(
    key: 'other',
    label: 'Other',
    icon: Icons.medication,
    color: Color(0xFF718096),
  ),
];

/// Look up a category by its key string. Returns 'Other' if not found.
MedicineCategory categoryFromKey(String? key) {
  if (key == null) return kMedicineCategories.last;
  return kMedicineCategories.firstWhere(
    (c) => c.key == key,
    orElse: () => kMedicineCategories.last,
  );
}
