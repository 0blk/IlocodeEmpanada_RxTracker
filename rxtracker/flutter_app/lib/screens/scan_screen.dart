import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/medicine.dart';
import '../utils/medicine_categories.dart';
import 'add_medicine_screen.dart';
import 'package:flutter/foundation.dart';
import '../widgets/hover_scale.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  Uint8List? _imageBytes;
  bool _scanning = false;
  String? _error;
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
      _scanning = true; // Show scanning overlay immediately
      _error = null;
    });

    // Automatically trigger AI scan
    _scan();
  }

  Future<void> _scan() async {
    if (_imageBytes == null) return;

    try {
      final api = context.read<ApiService>();
      final result = await api.scanPrescriptionBytes(_imageBytes!);
      
      // On success, navigate to Add Medicine screen or show results
      // For now, let's just go back to home or show a success message
      setState(() {
        _scanning = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription Scanned Successfully!')),
        );
        Navigator.pop(context); // Go back after success
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background - Image Preview or Placeholder
          if (_imageBytes != null)
            Positioned.fill(
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            )
          else
            const Positioned.fill(
              child: Center(
                child: Text(
                  'No Image Selected',
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                ),
              ),
            ),

          // Semi-transparent overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),

          // Scanning Frame & Text
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Scanning...',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFC6FF00), // Lime Green
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 40),
                // The Frame
                Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: Stack(
                    children: [
                      // Corners
                      _buildCorner(top: 0, left: 0, isTop: true, isLeft: true),
                      _buildCorner(top: 0, right: 0, isTop: true, isLeft: false),
                      _buildCorner(bottom: 0, left: 0, isTop: false, isLeft: true),
                      _buildCorner(bottom: 0, right: 0, isTop: false, isLeft: false),
                      
                      // Central Scanning Line
                      Center(
                        child: Container(
                          width: 250,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC6FF00),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFC6FF00).withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Top Controls (Close)
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Bottom Controls (Action Buttons)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
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
                  ],
                ),
              ],
            ),
          ),
          
          // Loading Overlay
          if (_scanning)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFC6FF00)),
                      SizedBox(height: 20),
                      Text(
                        'AI is analyzing your prescription...',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner({double? top, double? bottom, double? left, double? right, required bool isTop, required bool isLeft}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Color(0xFFC6FF00), width: 8) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: Color(0xFFC6FF00), width: 8) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Color(0xFFC6FF00), width: 8) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: Color(0xFFC6FF00), width: 8) : BorderSide.none,
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

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}