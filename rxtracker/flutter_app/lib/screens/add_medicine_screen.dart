import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../models/medicine.dart';
import '../services/medicine_provider.dart';
import '../utils/medicine_categories.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? prefill;
  final bool isEdit;

  const AddMedicineScreen({super.key, this.prefill, this.isEdit = false});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _instructionsCtrl;
  late final TextEditingController _stockCtrl;

  String _frequency = 'once_daily';
  List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _category;

  bool _saving = false;

  static const _defaultTimes = {
    'once_daily': [TimeOfDay(hour: 8, minute: 0)],
    'twice_daily': [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
    'three_times_daily': [
      TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 14, minute: 0),
      TimeOfDay(hour: 20, minute: 0)
    ],
    'four_times_daily': [
      TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 12, minute: 0),
      TimeOfDay(hour: 16, minute: 0),
      TimeOfDay(hour: 20, minute: 0)
    ],
  };

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _dosageCtrl = TextEditingController(text: p?.dosage ?? '');
    _instructionsCtrl = TextEditingController(text: p?.instructions ?? '');
    _stockCtrl = TextEditingController(
        text: p?.stock != null ? p!.stock.toString() : '');

    if (p != null) {
      _frequency = p.frequency;
      _times = p.times.map((t) {
        final parts = t.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }).toList();
      _startDate = DateTime.parse(p.startDate);
      if (p.endDate != null) _endDate = DateTime.parse(p.endDate!);
      _category = p.category;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  void _onFrequencyChanged(String value) {
    setState(() {
      _frequency = value;
      _times = List.from(_defaultTimes[value]!);
    });
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (picked != null) {
      setState(() => _times[index] = picked);
    }
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_endDate ?? DateTime.now()) : _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isEnd) {
          _endDate = picked;
        } else {
          _startDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final medicine = Medicine(
      id: widget.prefill?.id,
      name: _nameCtrl.text.trim(),
      dosage: _dosageCtrl.text.trim(),
      frequency: _frequency,
      times: _times
          .map((t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
          .toList(),
      startDate: _startDate.toIso8601String().substring(0, 10),
      endDate: _endDate?.toIso8601String().substring(0, 10),
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      stock: _stockCtrl.text.isEmpty ? null : int.tryParse(_stockCtrl.text),
      category: _category,
    );

    final provider = context.read<MedicineProvider>();
    Medicine? result;

    if (widget.isEdit && medicine.id != null) {
      result = await provider.updateMedicine(
        medicine.id!,
        medicine.toJson()..remove('id'),
      );
    } else {
      result = await provider.addMedicine(medicine);
    }

    setState(() => _saving = false);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit
              ? '${result.name} updated!'
              : '${result.name} added!'),
          backgroundColor: Colors.green,
        ),
      );
      // Offer calendar integration
      if (!widget.isEdit) {
        _offerCalendarAdd(result);
      } else {
        Navigator.pop(context, result);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save medicine'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _offerCalendarAdd(Medicine medicine) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.calendar_month, size: 40, color: Colors.blue),
        title: const Text(
          'Add to Calendar?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Would you like to add "${medicine.name}" reminders to your phone\'s calendar?\n\nThis makes it easier to remember, especially if you share your calendar with family.',
          style: const TextStyle(fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, medicine);
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
              child: const Text('No Thanks', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _addToCalendar(medicine);
                Navigator.pop(context, medicine);
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Yes, Add to Calendar',
                  style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCalendar(Medicine medicine) {
    final startTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _times.isNotEmpty ? _times[0].hour : 8,
      _times.isNotEmpty ? _times[0].minute : 0,
    );
    final endTime = startTime.add(const Duration(minutes: 30));
    final recurrenceEnd = _endDate ?? startTime.add(const Duration(days: 365));

    final event = Event(
      title: '💊 ${medicine.name} (${medicine.dosage})',
      description:
          '${medicine.frequencyLabel}\n${medicine.instructions ?? "Take as directed"}',
      location: '',
      startDate: startTime,
      endDate: endTime,
      allDay: false,
      recurrence: Recurrence(
        frequency: Frequency.daily,
        endDate: recurrenceEnd,
      ),
    );
    Add2Calendar.addEvent2Cal(event);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEdit;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? 'Edit Medicine'
              : widget.prefill != null
                  ? 'Confirm Medicine'
                  : 'Add Medicine',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Medicine Information ────────────────────────────────
            _SectionTitle('Medicine Information'),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Medicine Name *',
                prefixIcon: Icon(Icons.medication),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 16),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _dosageCtrl,
              decoration: const InputDecoration(
                labelText: 'Dosage *',
                hintText: 'e.g. 500mg, 1 tablet',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 16),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Special Instructions',
                hintText: 'e.g. Take with food, avoid alcohol',
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 16),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _stockCtrl,
              decoration: const InputDecoration(
                labelText: 'Current Stock (pills)',
                hintText: 'Optional — for low stock alerts',
                prefixIcon: Icon(Icons.inventory_2),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 16),
              keyboardType: TextInputType.number,
            ),

            // ── Category ────────────────────────────────────────────
            const SizedBox(height: 24),
            _SectionTitle('Medicine Type'),
            const Text(
              'Select the type of medicine so it can be grouped and color-coded.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _CategoryPicker(
              selected: _category,
              onSelected: (key) => setState(() => _category = key),
            ),

            // ── Schedule ────────────────────────────────────────────
            const SizedBox(height: 24),
            _SectionTitle('Schedule'),

            // Frequency — large tap cards
            _FrequencyPicker(
              selected: _frequency,
              onSelected: _onFrequencyChanged,
            ),
            const SizedBox(height: 14),

            // Times
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Reminder Times',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(
                    _times.length,
                    (i) => ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer),
                        ),
                      ),
                      title: Text(
                        _times[i].format(context),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      subtitle: Text(_timeLabel(i),
                          style: const TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _pickTime(i),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Dates
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () => _pickDate(isEnd: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () => _pickDate(isEnd: true),
                    optional: true,
                    onClear: _endDate != null
                        ? () => setState(() => _endDate = null)
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: Icon(isEdit ? Icons.save : Icons.add_circle_outline,
                    size: 22),
                label: Text(
                  isEdit ? 'Save Changes' : 'Add Medicine',
                  style: const TextStyle(fontSize: 17),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _timeLabel(int index) {
    switch (_frequency) {
      case 'twice_daily':
        return index == 0 ? 'Morning dose' : 'Evening dose';
      case 'three_times_daily':
        return ['Morning', 'Afternoon', 'Evening'][index];
      case 'four_times_daily':
        return ['Morning', 'Midday', 'Afternoon', 'Evening'][index];
      default:
        return 'Daily dose';
    }
  }
}

// ── Category Picker ─────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  final String? selected;
  final void Function(String) onSelected;

  const _CategoryPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kMedicineCategories.map((cat) {
        final isSelected = selected == cat.key;
        return GestureDetector(
          onTap: () => onSelected(cat.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? cat.color : cat.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? cat.color : cat.color.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon,
                    size: 18,
                    color: isSelected ? Colors.white : cat.color),
                const SizedBox(width: 6),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : cat.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Frequency Picker ────────────────────────────────────────────────────────

class _FrequencyPicker extends StatelessWidget {
  final String selected;
  final void Function(String) onSelected;

  static const _options = {
    'once_daily': ('Once Daily', Icons.looks_one_outlined),
    'twice_daily': ('Twice Daily', Icons.looks_two_outlined),
    'three_times_daily': ('3× Daily', Icons.looks_3_outlined),
    'four_times_daily': ('4× Daily', Icons.looks_4_outlined),
  };

  const _FrequencyPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: _options.entries.map((e) {
        final isSelected = selected == e.key;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                  right: e.key == _options.keys.last ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary
                    : cs.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? cs.primary
                      : cs.primary.withOpacity(0.2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(e.value.$2,
                      size: 22,
                      color: isSelected ? Colors.white : cs.primary),
                  const SizedBox(height: 4),
                  Text(
                    e.value.$1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool optional;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.optional = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label + (optional ? ' (optional)' : ''),
          border: const OutlineInputBorder(),
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          date != null
              ? DateFormat('MMM d, yyyy').format(date!)
              : 'Not set',
          style: TextStyle(
            fontSize: 15,
            color: date != null ? null : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
