import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _error;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getDoseHistory(days: _days);
      setState(() {
        _history = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final entry in _history) {
      final scheduledStr = (entry['scheduled_time'] ?? entry['taken_at'] ?? DateTime.now().toIso8601String()).toString();
      final dt = DateTime.parse(scheduledStr);
      final dateKey = DateFormat('yyyy-MM-dd').format(dt);
      grouped.putIfAbsent(dateKey, () => []).add(entry);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _history.isEmpty
                  ? const Center(child: Text('No dose history yet'))
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView.builder(
                        itemCount: sortedDates.length,
                        itemBuilder: (_, i) {
                          final dateKey = sortedDates[i];
                          final entries = grouped[dateKey]!;
                          final taken =
                              entries.where((e) => e['taken'] == 1 || e['taken'] == true).length;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                padding: const EdgeInsets.fromLTRB(
                                    16, 10, 16, 10),
                                child: Row(
                                  children: [
                                    Text(
                                      _formatDate(dateKey),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$taken/${entries.length} taken',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                              color: taken == entries.length
                                                  ? Colors.green
                                                  : Colors.orange),
                                    ),
                                  ],
                                ),
                              ),
                              ...entries.map((e) => _HistoryItem(entry: e)),
                            ],
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    if (DateFormat('yyyy-MM-dd').format(today) == iso) return 'Today';
    if (DateFormat('yyyy-MM-dd').format(yesterday) == iso) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(dt);
  }
}

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _HistoryItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final taken = entry['taken'] == 1 || entry['taken'] == true;
    final scheduledStr = (entry['scheduled_time'] ?? entry['taken_at'] ?? DateTime.now().toIso8601String()).toString();
    final scheduledDt = DateTime.parse(scheduledStr);
    final timeStr = DateFormat('h:mm a').format(scheduledDt);

    return ListTile(
      leading: Icon(
        taken ? Icons.check_circle : Icons.cancel,
        color: taken ? Colors.green : Colors.red[300],
      ),
      title: Text((entry['medicine_name'] ?? 'Unknown').toString()),
      subtitle: Text((entry['dosage'] ?? '').toString()),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeStr,
              style: Theme.of(context).textTheme.bodySmall),
          Text(
            taken ? 'Taken' : 'Missed',
            style: TextStyle(
              color: taken ? Colors.green : Colors.red[300],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
