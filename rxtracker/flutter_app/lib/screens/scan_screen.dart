import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/medicine_provider.dart';
import '../models/medicine.dart';
import 'add_medicine_screen.dart';
import 'package:flutter/foundation.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  Uint8List? _imageBytes; // used on web [cite: 13]
  File? _selectedImage;   // used on mobile [cite: 12]
  
  // Logic to determine if an image is selected regardless of platform [cite: 14]
  bool get _hasImage => kIsWeb ? _imageBytes != null : _selectedImage != null;
  
  bool _scanning = false;
  String? _error;
  Map<String, dynamic>? _scanResult;

  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes(); // Read bytes for web/mobile [cite: 23]

    setState(() {
      _imageBytes = bytes; // [cite: 25]
      if (!kIsWeb) {
        _selectedImage = File(xFile.path); // Only use File if not on web [cite: 26]
      }
      _scanResult = null;
      _error = null;
    });
  }

  Future<void> _scan() async {
    if (!_hasImage) return; // [cite: 33]

    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      Map<String, dynamic> result;

      if (kIsWeb) {
        // On web, send bytes directly [cite: 41, 42]
        result = await api.scanPrescriptionBytes(_imageBytes!); // [cite: 43]
      } else {
        result = await api.scanPrescription(_selectedImage!); // [cite: 45]
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

  void _addMedicineFromScan(Map<String, dynamic> med) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    String? endDate;
    if (med['duration_days'] != null) {
      final end = DateTime.now()
          .add(Duration(days: med['duration_days'] as int));
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
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicineScreen(prefill: medicine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Prescription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image picker
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!_hasImage) ...[ // [cite: 80]
                      Icon(Icons.document_scanner,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text('Select a prescription image'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ],
                      ),
                    ] else ...[ // [cite: 83]
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.memory( // Display from bytes on web [cite: 63]
                                _imageBytes!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file( // Display from file on mobile [cite: 69]
                                _selectedImage!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('Change'),
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
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(_scanning ? 'Scanning...' : 'Scan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Scan results
            if (_scanResult != null) ...[
              const SizedBox(height: 16),
              Text(
                'Detected Medicines',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_scanResult!['note'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    _scanResult!['note'] as String,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.orange[700]),
                  ),
                ),
              const SizedBox(height: 8),
              if ((_scanResult!['medicines'] as List).isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No medicines detected. Try a clearer image or add manually.'),
                  ),
                )
              else
                ...(_scanResult!['medicines'] as List).map(
                  (med) => _ScannedMedicineCard(
                    medicine: med as Map<String, dynamic>,
                    onAdd: () => _addMedicineFromScan(med),
                  ),
                ),

              // Raw text (collapsible)
              if (_scanResult!['raw_text'] != null) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Raw Prescription Text'),
                  childrenPadding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      _scanResult!['raw_text'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
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
}

class _ScannedMedicineCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback onAdd;

  const _ScannedMedicineCard({required this.medicine, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    medicine['name'] ?? 'Unknown',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow('Dosage', medicine['dosage'] ?? '—'),
            _InfoRow('Frequency', medicine['frequency'] ?? '—'),
            if (medicine['times'] != null)
              _InfoRow(
                  'Times', (medicine['times'] as List).cast<String>().join(', ')),
            if (medicine['duration_days'] != null)
              _InfoRow('Duration', '${medicine['duration_days']} days'),
            if (medicine['instructions'] != null)
              _InfoRow('Instructions', medicine['instructions'] as String),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}