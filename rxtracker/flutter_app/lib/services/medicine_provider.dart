import 'package:flutter/foundation.dart';
import '../models/medicine.dart';
import '../models/dose.dart';
import 'api_service.dart';
import 'notification_service.dart';

class MedicineProvider extends ChangeNotifier {
  final ApiService _api;

  List<Medicine> medicines = [];
  List<TodayDose> todayDoses = [];
  List<Map<String, dynamic>> stats = [];
  Map<String, dynamic>? profile;

  bool loading = false;
  String? error;

  MedicineProvider(this._api);

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getMedicines(),
        _api.getTodayDoses(),
        _api.getStats(),
        _api.getProfile(),
      ]);
      medicines = results[0] as List<Medicine>;
      todayDoses = results[1] as List<TodayDose>;
      stats = results[2] as List<Map<String, dynamic>>;
      profile = results[3] as Map<String, dynamic>;

      // Reschedule all notifications
      await _rescheduleNotifications();
    } catch (e) {
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }

  Future<void> fetchTodayDoses() async {
    try {
      todayDoses = await _api.getTodayDoses();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<Medicine?> addMedicine(Medicine medicine) async {
    try {
      final created = await _api.createMedicine(medicine);
      medicines.insert(0, created);
      notifyListeners();
      await fetchTodayDoses();
      await _scheduleNotificationsFor(created);
      return created;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Medicine?> updateMedicine(int id, Map<String, dynamic> updates) async {
    try {
      final updated = await _api.updateMedicine(id, updates);
      final idx = medicines.indexWhere((m) => m.id == id);
      if (idx != -1) {
        medicines[idx] = updated;
        notifyListeners();
      }
      await fetchTodayDoses();
      // Reschedule notifications for this medicine
      if (!kIsWeb) {
        await NotificationService.instance.cancelForMedicine(id);
        if (updated.isActive) await _scheduleNotificationsFor(updated);
      }
      return updated;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteMedicine(int id) async {
    try {
      await _api.deleteMedicine(id);
      medicines.removeWhere((m) => m.id == id);
      todayDoses.removeWhere((d) => d.medicineId == id);
      if (!kIsWeb) await NotificationService.instance.cancelForMedicine(id);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markDose({
    required int medicineId,
    required String scheduledTime,
    required bool taken,
  }) async {
    try {
      await _api.logDose(
        medicineId: medicineId,
        scheduledTime: scheduledTime,
        taken: taken,
      );
      // Optimistic update
      final idx = todayDoses.indexWhere(
        (d) => d.medicineId == medicineId && d.scheduledTime == scheduledTime,
      );
      if (idx != -1) {
        todayDoses[idx] = todayDoses[idx].copyWith(
          taken: taken,
          takenAt: taken ? DateTime.now().toIso8601String() : null,
        );
        notifyListeners();
      }
      // Update stock in medicines list
      if (taken) {
        final mIdx = medicines.indexWhere((m) => m.id == medicineId);
        if (mIdx != -1 && medicines[mIdx].stock != null) {
          medicines[mIdx] = medicines[mIdx].copyWith(
            stock: (medicines[mIdx].stock! - 1).clamp(0, 9999),
          );
          notifyListeners();
        }
      }
      // Refresh stats
      stats = await _api.getStats();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      profile = await _api.updateProfile(data);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Notifications ───────────────────────────────────────────────────────────

  Future<void> _rescheduleNotifications() async {
    if (kIsWeb) return;
    await NotificationService.instance.cancelAll();
    for (final med in medicines) {
      if (med.isActive) {
        await _scheduleNotificationsFor(med);
      }
    }
  }

  Future<void> _scheduleNotificationsFor(Medicine med) async {
    if (kIsWeb) return;
    if (med.id == null) return;
    for (int i = 0; i < med.times.length; i++) {
      final parts = med.times[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      await NotificationService.instance.scheduleDailyReminder(
        id: med.id! * 10 + i,
        title: '💊 Time for ${med.name}',
        body: '${med.dosage} — ${med.instructions ?? "Take as directed"}',
        hour: hour,
        minute: minute,
        medicineId: med.id!,
      );
    }
  }

  int get pendingDoseCount =>
      todayDoses.where((d) => !d.taken && !d.isUpcoming).length;

  int get takenToday => todayDoses.where((d) => d.taken).length;

  double get todayAdherence {
    final total = todayDoses.length;
    if (total == 0) return 0;
    return (takenToday / total).clamp(0.0, 1.0);
  }
}
