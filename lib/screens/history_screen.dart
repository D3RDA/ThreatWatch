import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/risk_level.dart';
import '../models/scan_history_item.dart';
import '../services/local_storage_service.dart';
import '../utils/formatters.dart';
import '../widgets/risk_badge.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = LocalStorageService.instance;
  late Future<List<ScanHistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _storage.loadHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _storage.loadHistory();
    });
  }

  Future<void> _clearHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Előzmények törlése'),
        content: const Text('Biztosan törölni szeretnéd az összes mentett ellenőrzést?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await _storage.clearHistory();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ScanHistoryItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        final safeCount = items.where((item) => item.level == RiskLevel.safe).length;
        final suspiciousCount =
            items.where((item) => item.level == RiskLevel.suspicious).length;
        final dangerousCount =
            items.where((item) => item.level == RiskLevel.dangerous).length;
        final urlCount = items.where((item) => item.type == 'url').length;
        final messageCount = items.where((item) => item.type == 'message').length;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 430;
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mentett elemzések: ${items.length}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: items.isEmpty ? null : _clearHistory,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Előzmények törlése'),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mentett elemzések: ${items.length}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: items.isEmpty ? null : _clearHistory,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Törlés'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Még nincs elmentett URL scan vagy üzenetelemzés.'),
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kockázati megoszlás',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 240,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 44,
                              sections: [
                                PieChartSectionData(
                                  value: safeCount == 0 ? 0.01 : safeCount.toDouble(),
                                  color: Colors.green,
                                  title: 'Safe\n$safeCount',
                                  radius: 70,
                                ),
                                PieChartSectionData(
                                  value: suspiciousCount == 0
                                      ? 0.01
                                      : suspiciousCount.toDouble(),
                                  color: Colors.orange,
                                  title: 'Gyanús\n$suspiciousCount',
                                  radius: 70,
                                ),
                                PieChartSectionData(
                                  value: dangerousCount == 0
                                      ? 0.01
                                      : dangerousCount.toDouble(),
                                  color: Colors.red,
                                  title: 'Veszély\n$dangerousCount',
                                  radius: 70,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Típus szerinti megoszlás',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (items.length + 2).toDouble(),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: true),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      switch (value.toInt()) {
                                        case 0:
                                          return const Padding(
                                            padding: EdgeInsets.only(top: 6),
                                            child: Text('URL'),
                                          );
                                        case 1:
                                          return const Padding(
                                            padding: EdgeInsets.only(top: 6),
                                            child: Text('Üzenet'),
                                          );
                                        default:
                                          return const SizedBox.shrink();
                                      }
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: urlCount.toDouble(),
                                      color: Colors.indigo,
                                      width: 34,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: messageCount.toDouble(),
                                      color: Colors.teal,
                                      width: 34,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Legutóbbi mentések',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...items.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item.summary),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text('${item.type.toUpperCase()} • ${formatDate(item.timestamp)}'),
                          const SizedBox(height: 4),
                          Text(truncateMiddle(item.input, maxLength: 72)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RiskBadge(level: item.level),
                          const SizedBox(height: 6),
                          Text('${item.score}/100'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
