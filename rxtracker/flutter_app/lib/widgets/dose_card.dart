import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/dose.dart';
import '../services/medicine_provider.dart';

class DoseCard extends StatefulWidget {
  final TodayDose dose;

  const DoseCard({super.key, required this.dose});

  @override
  State<DoseCard> createState() => _DoseCardState();
}

class _DoseCardState extends State<DoseCard> {
  bool _loading = false;

  Color get _bgColor {
    if (widget.dose.taken) return const Color(0xFFC6FF00); // Lime Green
    if (widget.dose.isOverdue) return const Color(0xFFFF1744); // Red
    return const Color(0xFFEEF2FF); // Soft Blue/Purple
  }

  Color get _textColor {
    if (widget.dose.taken || widget.dose.isOverdue) return Colors.black;
    return Colors.black;
  }

  Widget get _statusIcon {
    if (widget.dose.taken) {
      return const Icon(Icons.check_circle_rounded, color: Colors.black, size: 32);
    }
    if (widget.dose.isOverdue) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
          shape: BoxShape.circle,
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26, width: 3),
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatted = DateFormat('h:mm a').format(
      DateTime.parse(widget.dose.scheduledTime),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: _loading ? null : _toggle,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              _statusIcon,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dose.medicineName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    Text(
                      widget.dose.dosage,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.dose.isOverdue && !widget.dose.taken)
                    const Text(
                      'MISSED!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  Text(
                    timeFormatted,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: (widget.dose.isOverdue && !widget.dose.taken) ? Colors.white : _textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    final provider = context.read<MedicineProvider>();
    await provider.markDose(
      medicineId: widget.dose.medicineId,
      scheduledTime: widget.dose.scheduledTime,
      taken: !widget.dose.taken,
    );
    if (mounted) setState(() => _loading = false);
  }
}
