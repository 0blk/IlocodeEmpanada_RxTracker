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
      final dt = DateTime.parse(entry['scheduled_time'] as String);
      final dateKey = DateFormat('yyyy-MM-dd').format(dt);
      grouped.putIfAbsent(dateKey, () => []).add(entry);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dose History'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _days,
            onSelected: (v) {
              setState(() => _days = v);
              _fetch();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 7, child: Text('Last 7 days')),
              const PopupMenuItem(value: 14, child: Text('Last 14 days')),
              const PopupMenuItem(value: 30, child: Text('Last 30 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('$_days days',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
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
                              entries.where((e) => e['taken'] == 1).length;

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
    final taken = entry['taken'] == 1;
    final scheduledDt = DateTime.parse(entry['scheduled_time'] as String);
    final timeStr = DateFormat('h:mm a').format(scheduledDt);

    return ListTile(
      leading: Icon(
        taken ? Icons.check_circle : Icons.cancel,
        color: taken ? Colors.green : Colors.red[300],
      ),
      title: Text(entry['medicine_name'] as String),
      subtitle: Text(entry['dosage'] as String),
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
