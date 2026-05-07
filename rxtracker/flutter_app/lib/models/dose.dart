class TodayDose {
  final int medicineId;
  final String medicineName;
  final String dosage;
  final String? instructions;
  final String scheduledTime;
  final String timeLabel;
  final bool taken;
  final String? takenAt;
  final int? logId;
  final String? category; // medicine category for color-coding

  const TodayDose({
    required this.medicineId,
    required this.medicineName,
    required this.dosage,
    this.instructions,
    required this.scheduledTime,
    required this.timeLabel,
    required this.taken,
    this.takenAt,
    this.logId,
    this.category,
  });

  factory TodayDose.fromJson(Map<String, dynamic> j) => TodayDose(
        medicineId: j['medicine_id'] as int,
        medicineName: j['medicine_name'] as String,
        dosage: j['dosage'] as String,
        instructions: j['instructions'] as String?,
        scheduledTime: j['scheduled_time'] as String,
        timeLabel: j['time_label'] as String,
        taken: j['taken'] as bool? ?? false,
        takenAt: j['taken_at'] as String?,
        logId: j['log_id'] as int?,
        category: j['category'] as String?,
      );

  TodayDose copyWith({bool? taken, String? takenAt, int? logId}) => TodayDose(
        medicineId: medicineId,
        medicineName: medicineName,
        dosage: dosage,
        instructions: instructions,
        scheduledTime: scheduledTime,
        timeLabel: timeLabel,
        taken: taken ?? this.taken,
        takenAt: takenAt ?? this.takenAt,
        logId: logId ?? this.logId,
        category: category,
      );

  bool get isOverdue {
    if (taken) return false;
    final scheduled = DateTime.parse(scheduledTime);
    return DateTime.now().isAfter(scheduled.add(const Duration(hours: 1)));
  }

  bool get isUpcoming {
    final scheduled = DateTime.parse(scheduledTime);
    return DateTime.now().isBefore(scheduled);
  }
}
