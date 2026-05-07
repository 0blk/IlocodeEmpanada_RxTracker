import 'dart:convert';

class Medicine {
  final int? id;
  final String name;
  final String dosage;
  final String frequency;
  final List<String> times;
  final String startDate;
  final String? endDate;
  final String? instructions;
  final int? stock;
  final String? createdAt;

  const Medicine({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.startDate,
    this.endDate,
    this.instructions,
    this.stock,
    this.createdAt,
  });

  factory Medicine.fromJson(Map<String, dynamic> j) {
    List<String> parseTimes(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.cast<String>();
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.cast<String>();
        } catch (_) {}
      }
      return [];
    }

    return Medicine(
      id: j['id'] as int?,
      name: j['name'] as String,
      dosage: j['dosage'] as String,
      frequency: j['frequency'] as String,
      times: parseTimes(j['times']),
      startDate: j['start_date'] as String,
      endDate: j['end_date'] as String?,
      instructions: j['instructions'] as String?,
      stock: j['stock'] as int?,
      createdAt: j['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'times': times,
        'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (instructions != null) 'instructions': instructions,
        if (stock != null) 'stock': stock,
      };

  Medicine copyWith({
    int? id,
    String? name,
    String? dosage,
    String? frequency,
    List<String>? times,
    String? startDate,
    String? endDate,
    String? instructions,
    int? stock,
  }) =>
      Medicine(
        id: id ?? this.id,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        frequency: frequency ?? this.frequency,
        times: times ?? this.times,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        instructions: instructions ?? this.instructions,
        stock: stock ?? this.stock,
        createdAt: createdAt,
      );

  String get frequencyLabel {
    switch (frequency) {
      case 'once_daily':
        return 'Once daily';
      case 'twice_daily':
        return 'Twice daily';
      case 'three_times_daily':
        return '3× daily';
      case 'four_times_daily':
        return '4× daily';
      default:
        return frequency;
    }
  }

  bool get isActive {
    final today = DateTime.now();
    final start = DateTime.parse(startDate);
    if (today.isBefore(start)) return false;
    if (endDate != null) {
      final end = DateTime.parse(endDate!);
      if (today.isAfter(end)) return false;
    }
    return true;
  }

  bool get lowStock => stock != null && stock! <= 5;
}
