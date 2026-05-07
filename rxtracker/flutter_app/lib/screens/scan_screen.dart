import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/medicine_provider.dart';
import '../models/medicine.dart';
import '../utils/medicine_categories.dart';
import 'add_medicine_screen.dart';
import 'package:flutter/foundation.dart';
import '../widgets/hover_scale.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ScanScreen({super.key, this.onBack});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  Uint8List? _imageBytes;
  File? _selectedImage;
  bool _scanning = false;
  String? _error;
  Map<String, dynamic>? _scanResult;
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

    if (kIsWeb) {
      final bytes = await xFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _error = null;
        _scanResult = null;
      });
    } else {
      setState(() {
        _selectedImage = File(xFile.path);
        _error = null;
        _scanResult = null;
      });
    }
  }

  Future<void> _scan() async {
    if (_imageBytes == null && _selectedImage == null) return;

    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final result = kIsWeb 
          ? await api.scanPrescriptionBytes(_imageBytes!)
          : await api.scanPrescription(_selectedImage!);
      
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

  Future<void> _addMedicineInstantly(Map<String, dynamic> med, int index) async {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await context.read<ApiService>().createMedicine(medicine);
      if (!mounted) return;
      
      // Trigger global refresh so Medication Bag and Dashboard update immediately
      context.read<MedicineProvider>().refresh();
      
      Navigator.pop(context); 

      setState(() {
        final List<dynamic> meds = List.from(_scanResult!['medicines']);
        meds[index] = {...med, 'added': true};
        _scanResult!['medicines'] = meds;
      });

      // Check if all medicines are added
      final allAdded = (_scanResult!['medicines'] as List).every((m) => m['added'] == true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medicine.name} added!'), 
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );

      if (allAdded) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/schedule', (route) => false);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicines = (_scanResult?['medicines'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final hasImage = _imageBytes != null || _selectedImage != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Color
          Positioned.fill(child: Container(color: Colors.black)),

          // Scan Preview / Background Image
          if (hasImage)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: kIsWeb 
                      ? Image.memory(_imageBytes!, fit: BoxFit.contain) 
                      : Image.file(_selectedImage!, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          
          // Dark Overlay
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),

          // Results or Instructions
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () {
                          if (widget.onBack != null) {
                            widget.onBack!();
                          } else if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const Spacer(),
                      const Text('PRESCRIPTION SCAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: _scanResult != null 
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: medicines.length,
                        itemBuilder: (context, index) => _EditableMedicineCard(
                          index: index,
                          medicine: medicines[index],
                          isExpanded: _expandedEdits.contains(index),
                          onToggleEdit: () => setState(() {
                            if (_expandedEdits.contains(index)) _expandedEdits.remove(index);
                            else _expandedEdits.add(index);
                          }),
                          onSaveEdit: (updated) => setState(() {
                            (_scanResult!['medicines'] as List)[index] = updated;
                            _expandedEdits.remove(index);
                          }),
                          onAdd: _addMedicineInstantly,
                          onManualEdit: (med) => Navigator.push(context, MaterialPageRoute(builder: (_) => AddMedicineScreen(prefill: Medicine(name: med['name'] ?? '', dosage: med['dosage'] ?? '', frequency: med['frequency'] ?? 'once_daily', times: ['08:00'], startDate: DateTime.now().toIso8601String().substring(0,10))))),
                        ),
                      )
                    : Center(
                        child: _scanning 
                          ? _buildScanningAnimation()
                          : const Text('READY TO SCAN', style: TextStyle(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                ),

                // Bottom Buttons
                if (!_scanning && _scanResult == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ActionButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Take Photo',
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                        const SizedBox(width: 40),
                        _ActionButton(
                          icon: Icons.file_upload_rounded,
                          label: 'Upload Image',
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                        if (hasImage) ...[
                          const SizedBox(width: 40),
                          _ActionButton(
                            icon: Icons.play_arrow_rounded,
                            label: 'Start Scan',
                            color: const Color(0xFFC6FF00),
                            onTap: _scan,
                          ),
                        ]
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningAnimation() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('ANALYZING...', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFFC6FF00), letterSpacing: 4)),
        const SizedBox(height: 40),
        Container(
          width: 260,
          height: 340,
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC6FF00).withOpacity(0.3), width: 2)),
          child: Stack(
            children: [
              _buildCorner(top: 0, left: 0, isTop: true, isLeft: true),
              _buildCorner(top: 0, right: 0, isTop: true, isLeft: false),
              _buildCorner(bottom: 0, left: 0, isTop: false, isLeft: true),
              _buildCorner(bottom: 0, right: 0, isTop: false, isLeft: false),
              const Center(child: CircularProgressIndicator(color: Color(0xFFC6FF00))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorner({double? top, double? bottom, double? left, double? right, required bool isTop, required bool isLeft}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Color(0xFFC6FF00), width: 4) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: Color(0xFFC6FF00), width: 4) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Color(0xFFC6FF00), width: 4) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: Color(0xFFC6FF00), width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(color == Colors.white ? 0.2 : 1.0),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Icon(icon, color: color == Colors.white ? Colors.white : Colors.black, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EditableMedicineCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> medicine;
  final bool isExpanded;
  final VoidCallback onToggleEdit;
  final Function(Map<String, dynamic>) onSaveEdit;
  final Function(Map<String, dynamic>, int) onAdd;
  final Function(Map<String, dynamic>) onManualEdit;

  const _EditableMedicineCard({
    required this.index,
    required this.medicine,
    required this.isExpanded,
    required this.onToggleEdit,
    required this.onSaveEdit,
    required this.onAdd,
    required this.onManualEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAdded = medicine['added'] ?? false;
    return Card(
      color: Colors.white.withOpacity(0.9),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, color: Color(0xFF6366F1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medicine['name'] ?? 'Unknown Medicine', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(
                        '${medicine['dosage'] ?? ''} - ${(medicine['frequency'] ?? '').toString().replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')}', 
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                if (!isAdded)
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFFC6FF00), size: 32),
                    onPressed: () => onAdd(medicine, index),
                  )
                else
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
