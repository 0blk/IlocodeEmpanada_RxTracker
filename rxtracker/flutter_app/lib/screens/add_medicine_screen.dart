import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/medicine_provider.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? prefill;

  const AddMedicineScreen({super.key, this.prefill});

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

  bool _saving = false;

  static const _frequencies = {
    'once_daily': 'Once daily',
    'twice_daily': 'Twice daily',
    'three_times_daily': '3× daily',
    'four_times_daily': '4× daily',
  };

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

  void _onFrequencyChanged(String? value) {
    if (value == null) return;
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
      lastDate: DateTime(2030),
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
    );

    final provider = context.read<MedicineProvider>();
    final result = await provider.addMedicine(medicine);

    setState(() => _saving = false);

    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.name} added!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to add medicine'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.prefill != null ? 'Confirm Medicine' : 'Add Medicine'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info
            _SectionTitle('Medicine Information'),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Medicine Name *',
                prefixIcon: Icon(Icons.medication),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dosageCtrl,
              decoration: const InputDecoration(
                labelText: 'Dosage *',
                hintText: 'e.g. 500mg, 1 tablet',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Special Instructions',
                hintText: 'e.g. Take with food',
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stockCtrl,
              decoration: const InputDecoration(
                labelText: 'Current Stock (pills)',
                hintText: 'Optional - for low stock alerts',
                prefixIcon: Icon(Icons.inventory_2),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),
            _SectionTitle('Schedule'),

            // Frequency
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                prefixIcon: Icon(Icons.repeat),
                border: OutlineInputBorder(),
              ),
              items: _frequencies.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: _onFrequencyChanged,
            ),
            const SizedBox(height: 12),

            // Times
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Reminder Times',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  ...List.generate(
                    _times.length,
                    (i) => ListTile(
                      leading: const Icon(Icons.alarm),
                      title: Text(
                        _times[i].format(context),
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.edit, size: 18),
                      onTap: () => _pickTime(i),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

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
                    onClear:
                        _endDate != null ? () => setState(() => _endDate = null) : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Medicine'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            color: date != null ? null : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
