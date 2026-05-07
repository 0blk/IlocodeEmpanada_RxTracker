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

  Color get _statusColor {
    if (widget.dose.taken) return Colors.green;
    if (widget.dose.isOverdue) return Colors.red;
    if (widget.dose.isUpcoming) return Colors.blue;
    return Colors.orange;
  }

  IconData get _statusIcon {
    if (widget.dose.taken) return Icons.check_circle;
    if (widget.dose.isOverdue) return Icons.warning_rounded;
    if (widget.dose.isUpcoming) return Icons.schedule;
    return Icons.circle_notifications;
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

  @override
  Widget build(BuildContext context) {
    final timeFormatted = DateFormat('h:mm a').format(
      DateTime.parse(widget.dose.scheduledTime),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _loading ? null : _toggle,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Icon
              Icon(_statusIcon, color: _statusColor, size: 28),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dose.medicineName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration: widget.dose.taken
                                ? TextDecoration.lineThrough
                                : null,
                            color: widget.dose.taken ? Colors.grey : null,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.dose.dosage,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    if (widget.dose.instructions != null)
                      Text(
                        widget.dose.instructions!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[500], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Time + action
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeFormatted,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                  ),
                  const SizedBox(height: 6),
                  _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton(
                          onPressed: _toggle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: widget.dose.taken
                                ? Colors.grey
                                : Colors.green,
                            side: BorderSide(
                              color: widget.dose.taken
                                  ? Colors.grey
                                  : Colors.green,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            widget.dose.taken ? 'Undo' : 'Take',
                            style: const TextStyle(fontSize: 12),
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
}
