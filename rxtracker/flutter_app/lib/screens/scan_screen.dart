import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/medicine.dart';
import '../utils/medicine_categories.dart';
import 'add_medicine_screen.dart';
import 'package:flutter/foundation.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  Uint8List? _imageBytes;
  File? _selectedImage;

  bool get _hasImage => kIsWeb ? _imageBytes != null : _selectedImage != null;

  bool _scanning = false;
  String? _error;
  Map<String, dynamic>? _scanResult;

  // Track which card is in "edit" mode
  final Set<int> _expandedEdits = {};

  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 3000,
      maxHeight: 4000,
    );
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();

    setState(() {
      _imageBytes = bytes;
      if (!kIsWeb) {
        _selectedImage = File(xFile.path);
      }
      _scanResult = null;
      _error = null;
      _expandedEdits.clear();
    });
  }

  Future<void> _scan() async {
    if (!_hasImage) return;

    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      Map<String, dynamic> result;

      if (kIsWeb) {
        result = await api.scanPrescriptionBytes(_imageBytes!);
      } else {
        result = await api.scanPrescription(_selectedImage!);
      }

      setState(() {
        _scanResult = result;
        _scanning = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _scanning = false;
      });
    }
  }

  void _openAddScreen(Map<String, dynamic> med) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    String? endDate;
    if (med['duration_days'] != null) {
      final end = DateTime.now().add(Duration(days: med['duration_days'] as int));
      endDate = end.toIso8601String().substring(0, 10);
    }

    final medicine = Medicine(
      name: med['name'] ?? '',
      dosage: med['dosage'] ?? '',
      frequency: med['frequency'] ?? 'once_daily',
      times: (med['times'] as List?)?.cast<String>() ?? ['08:00'],
      startDate: today,
      endDate: endDate,
      instructions: med['instructions'] as String?,
      category: med['category'] as String?,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMedicineScreen(prefill: medicine)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medicines = (_scanResult?['medicines'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prescription',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_hasImage) ...[
              _StepCard(
                step: '1',
                title: 'Take a Clear Photo',
                body:
                    'Place your prescription on a flat surface with good lighting. Capture the entire page.',
                icon: Icons.tips_and_updates,
              ),
              const SizedBox(height: 12),
              _StepCard(
                step: '2',
                title: 'We Read It For You',
                body:
                    'Our AI reads the prescription and extracts all medicine names, doses, and schedules.',
                icon: Icons.auto_awesome,
              ),
              const SizedBox(height: 12),
              _StepCard(
                step: '3',
                title: 'Edit & Save',
                body:
                    'Review each detected medicine, edit any details, then tap "Add to Tracker".',
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 24),
              _LargePickButton(
                icon: Icons.camera_alt,
                label: 'Take a Photo',
                subtitle: 'Open your camera',
                color: Theme.of(context).colorScheme.primary,
                onTap: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _LargePickButton(
                icon: Icons.photo_library,
                label: 'Choose from Gallery',
                subtitle: 'Select an existing photo',
                color: Colors.teal,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ] else ...[
              // Full-height image preview
              GestureDetector(
                onTap: () => _showFullImage(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      kIsWeb
                          ? Image.memory(
                              _imageBytes!,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Tap to zoom',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Change Photo',
                          style: TextStyle(fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.document_scanner),
                      label: Text(
                        _scanning ? 'Reading...' : 'Read Prescription',
                        style: const TextStyle(fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 50)),
                    ),
                  ),
                ],
              ),
            ],

            // Error
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ],

            // Scan results
            if (_scanResult != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    medicines.isEmpty
                        ? 'No Medicines Detected'
                        : '${medicines.length} Medicine${medicines.length == 1 ? '' : 's'} Detected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                  ),
                ],
              ),
              if (_scanResult!['note'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    _scanResult!['note'] as String,
                    style: TextStyle(color: Colors.orange[700], fontSize: 13),
                  ),
                ),
              const SizedBox(height: 10),
              if (medicines.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No medicines could be detected.\nTry a clearer photo, or add medicine manually.',
                    style: TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...medicines.asMap().entries.map(
                      (entry) => _EditableMedicineCard(
                        index: entry.key,
                        medicine: Map<String, dynamic>.from(entry.value),
                        isExpanded: _expandedEdits.contains(entry.key),
                        onToggleEdit: () => setState(() {
                          if (_expandedEdits.contains(entry.key)) {
                            _expandedEdits.remove(entry.key);
                          } else {
                            _expandedEdits.add(entry.key);
                          }
                        }),
                        onSaveEdit: (updated) {
                          setState(() {
                            (_scanResult!['medicines'] as List)[entry.key] =
                                updated;
                            _expandedEdits.remove(entry.key);
                          });
                        },
                        onAdd: (med) => _openAddScreen(med),
                      ),
                    ),

              // Raw text
              if (_scanResult!['raw_text'] != null) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('View Raw Prescription Text',
                      style: TextStyle(fontSize: 14)),
                  childrenPadding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      _scanResult!['raw_text'] as String,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: kIsWeb
                    ? Image.memory(_imageBytes!)
                    : Image.file(_selectedImage!),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editable Medicine Card ───────────────────────────────────────────────────

class _EditableMedicineCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> medicine;
  final bool isExpanded;
  final VoidCallback onToggleEdit;
  final void Function(Map<String, dynamic>) onSaveEdit;
  final void Function(Map<String, dynamic>) onAdd;

  const _EditableMedicineCard({
    required this.index,
    required this.medicine,
    required this.isExpanded,
    required this.onToggleEdit,
    required this.onSaveEdit,
    required this.onAdd,
  });

  @override
  State<_EditableMedicineCard> createState() => _EditableMedicineCardState();
}

class _EditableMedicineCardState extends State<_EditableMedicineCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _dosageCtrl;
  late TextEditingController _instructionsCtrl;
  late String _frequency;
  late String? _category;

  static const _frequencyOptions = [
    ('once_daily', 'Once Daily'),
    ('twice_daily', 'Twice Daily'),
    ('three_times_daily', '3× Daily'),
    ('four_times_daily', '4× Daily'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.medicine['name'] ?? '');
    _dosageCtrl = TextEditingController(text: widget.medicine['dosage'] ?? '');
    _instructionsCtrl =
        TextEditingController(text: widget.medicine['instructions'] ?? '');
    _frequency = widget.medicine['frequency'] ?? 'once_daily';
    _category = widget.medicine['category'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildUpdated() {
    final timesMap = {
      'once_daily': ['08:00'],
      'twice_daily': ['08:00', '20:00'],
      'three_times_daily': ['08:00', '14:00', '20:00'],
      'four_times_daily': ['08:00', '12:00', '16:00', '20:00'],
    };
    return {
      ...widget.medicine,
      'name': _nameCtrl.text.trim(),
      'dosage': _dosageCtrl.text.trim(),
      'instructions': _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      'frequency': _frequency,
      'times': timesMap[_frequency] ?? ['08:00'],
      'category': _category,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final med = widget.medicine;
    final catInfo = kMedicineCategories
        .where((c) => c.key == (med['category'] ?? ''))
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: catInfo?.color ?? cs.primary,
                  child: Icon(catInfo?.icon ?? Icons.medication,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med['name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${med['dosage'] ?? '—'}  ·  ${(med['frequency'] ?? '').toString().replaceAll('_', ' ')}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Info rows (collapsed view)
          if (!widget.isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Column(
                children: [
                  if (med['times'] != null)
                    _InfoRow('Times',
                        (med['times'] as List).cast<String>().join(', ')),
                  if (med['instructions'] != null)
                    _InfoRow('Instructions', med['instructions'] as String),
                  if (med['category'] != null)
                    _InfoRow('Category',
                        med['category'].toString().replaceAll('_', ' ')),
                ],
              ),
            ),
          ],

          // Edit form (expanded)
          if (widget.isExpanded) ...[
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Details',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Medicine Name',
                      prefixIcon: Icon(Icons.medication),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 15),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _dosageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dosage',
                      prefixIcon: Icon(Icons.straighten),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _instructionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 15),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  // Frequency dropdown
                  DropdownButtonFormField<String>(
                    value: _frequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      prefixIcon: Icon(Icons.repeat),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _frequencyOptions
                        .map((o) => DropdownMenuItem(
                            value: o.$1, child: Text(o.$2)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _frequency = v ?? _frequency),
                  ),
                  const SizedBox(height: 10),
                  // Category chips
                  const Text('Category',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kMedicineCategories.map((cat) {
                      final sel = _category == cat.key;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _category = cat.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? cat.color
                                : cat.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel
                                  ? cat.color
                                  : cat.color.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat.icon,
                                  size: 14,
                                  color: sel ? Colors.white : cat.color),
                              const SizedBox(width: 4),
                              Text(
                                cat.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      sel ? Colors.white : cat.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: widget.isExpanded
                      ? () {
                          widget.onSaveEdit(_buildUpdated());
                        }
                      : widget.onToggleEdit,
                  icon: Icon(
                      widget.isExpanded ? Icons.check : Icons.edit_outlined,
                      size: 18),
                  label: Text(widget.isExpanded ? 'Done' : 'Edit',
                      style: const TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42)),
                ),
                if (widget.isExpanded) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onToggleEdit,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel',
                        style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        foregroundColor: Colors.grey),
                  ),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => widget.onAdd(
                      widget.isExpanded ? _buildUpdated() : med),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add to Tracker',
                      style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 42)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step, title, body;
  final IconData icon;
  const _StepCard(
      {required this.step,
      required this.title,
      required this.body,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primary,
            child: Text(step,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(body,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
          ),
          Icon(icon, color: cs.primary.withOpacity(0.5), size: 28),
        ],
      ),
    );
  }
}

class _LargePickButton extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _LargePickButton(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 36),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right,
                  color: Colors.white70, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}