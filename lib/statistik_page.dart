import 'package:flutter/material.dart';
import 'crm_entry.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum Zeitraum { letzte30Tage, woche, monat, jahr, vergleichVorjahr }

class StatistikPage extends StatefulWidget {
  final ApiService apiService;
  const StatistikPage({super.key, required this.apiService});

  @override
  State<StatistikPage> createState() => _StatistikPageState();
}

class _StatistikPageState extends State<StatistikPage> {
  List<CrmEntry> _entries = [];
  bool _loading = true;
  String? _error;
  Zeitraum _zeitraum = Zeitraum.letzte30Tage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.apiService.fetchCrmEntries();
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<CrmEntry> _filteredEntries() {
    final now = DateTime.now();
    switch (_zeitraum) {
      case Zeitraum.letzte30Tage:
        return _entries.where((e) => e.anfrageDatum != null && e.anfrageDatum!.isAfter(now.subtract(const Duration(days: 30)))).toList();
      case Zeitraum.woche:
        return _entries.where((e) => e.anfrageDatum != null && e.anfrageDatum!.isAfter(now.subtract(const Duration(days: 7)))).toList();
      case Zeitraum.monat:
        return _entries.where((e) => e.anfrageDatum != null && e.anfrageDatum!.year == now.year && e.anfrageDatum!.month == now.month).toList();
      case Zeitraum.jahr:
        return _entries.where((e) => e.anfrageDatum != null && e.anfrageDatum!.year == now.year).toList();
      case Zeitraum.vergleichVorjahr:
        // Für Vergleich werden beide Zeiträume benötigt, handled in Diagrammen
        return _entries;
    }
  }

  // KPI-Kacheln (optisch verbessert)
  Widget _buildKpiCards() {
    final filtered = _filteredEntries();
    final total = filtered.length;
    final abgeschlossen = filtered.where((e) => (e.status ?? '').toLowerCase().contains('abgeschlossen')).length;
    final offen = filtered.where((e) => (e.status ?? '').toLowerCase().contains('offen')).length;
    final abgelehnt = filtered.where((e) => (e.status ?? '').toLowerCase().contains('abgelehnt')).length;
    final quote = total > 0 ? (abgeschlossen / total * 100).toStringAsFixed(1) : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _kpiCard('Gesamt', total.toString(), Icons.all_inbox, Colors.blue[700]!),
            const SizedBox(width: 16),
            _kpiCard('Abgeschlossen', abgeschlossen.toString(), Icons.check_circle, Colors.green[700]!),
            const SizedBox(width: 16),
            _kpiCard('Offen', offen.toString(), Icons.pending, Colors.amber[800]!),
            const SizedBox(width: 16),
            _kpiCard('Abgelehnt', abgelehnt.toString(), Icons.cancel, Colors.red[700]!),
            const SizedBox(width: 16),
            _kpiCard('Abschlussquote', '$quote %', Icons.percent, Colors.teal[700]!),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 120,
        height: 160,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // PieChart für Kontaktquellen (mit Titel, Untertitel, schöner Legende)
  Widget _buildQuellePieChart() {
    final filtered = _filteredEntries();
    final quelleMap = <String, int>{};
    for (final e in filtered) {
      var quelle = (e.kontaktquelle ?? '').trim();
      if (quelle.isEmpty || quelle.toLowerCase() == 'unbekannt') {
        quelle = 'Sonstiges';
      }
      quelleMap[quelle] = (quelleMap[quelle] ?? 0) + 1;
    }
    final total = filtered.length;
    int? touchedIndex;
    final quelleKeys = quelleMap.keys.toList();
    return StatefulBuilder(
      builder: (context, setState) {
        final sections = quelleMap.entries.map((e) {
          final idx = quelleKeys.indexOf(e.key);
          final percent = total > 0 ? e.value / total * 100 : 0.0;
          return PieChartSectionData(
            value: e.value.toDouble(),
            title: '${percent.toStringAsFixed(1)}%',
            color: Colors.primaries[idx % Colors.primaries.length],
            radius: touchedIndex == idx ? 52 : 44,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: touchedIndex == idx
                ? Card(
                    color: Colors.white,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
                    ),
                  )
                : null,
            badgePositionPercentageOffset: 1.2,
          );
        }).toList();
        return Center(
          child: SizedBox(
            width: 500,
            child: Card(
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pie_chart, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Kontaktquellen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Verteilung der Anfragen nach Quelle im gewählten Zeitraum', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sections: sections,
                          sectionsSpace: 2,
                          centerSpaceRadius: 24,
                          borderData: FlBorderData(show: false),
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                touchedIndex = response?.touchedSection?.touchedSectionIndex;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: quelleKeys.map((k) {
                        final idx = quelleKeys.indexOf(k);
                        final color = Colors.primaries[idx % Colors.primaries.length];
                        final value = quelleMap[k] ?? 0;
                        final percent = total > 0 ? value / total * 100 : 0.0;
                        return Container(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 6),
                              Flexible(child: Text(k, style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                              Text(' $value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 4),
                              Text('(${percent.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Gestapeltes Balkendiagramm: Status pro Kontaktquelle (mit Tooltips)
  Widget _buildStackedBarStatusPerQuelle() {
    final filtered = _filteredEntries();
    final quellen = filtered.map((e) => (e.kontaktquelle ?? '').trim().isEmpty || (e.kontaktquelle ?? '').trim().toLowerCase() == 'unbekannt' ? 'Sonstiges' : (e.kontaktquelle ?? '').trim()).toSet().toList();
    final statusSet = filtered.map((e) => (e.status ?? '').trim().isEmpty || (e.status ?? '').trim().toLowerCase() == 'unbekannt' ? 'Sonstiges' : (e.status ?? '').trim()).toSet().toList();
    final data = <String, Map<String, int>>{};
    for (final q in quellen) {
      data[q] = {};
      for (final s in statusSet) {
        data[q]![s] = 0;
      }
    }
    for (final e in filtered) {
      final q = (e.kontaktquelle ?? '').trim().isEmpty || (e.kontaktquelle ?? '').trim().toLowerCase() == 'unbekannt' ? 'Sonstiges' : (e.kontaktquelle ?? '').trim();
      final s = (e.status ?? '').trim().isEmpty || (e.status ?? '').trim().toLowerCase() == 'unbekannt' ? 'Sonstiges' : (e.status ?? '').trim();
      data[q]![s] = (data[q]![s] ?? 0) + 1;
    }
    int? touchedGroup;
    int? touchedRod;
    return StatefulBuilder(
      builder: (context, setState) {
        final total = filtered.length;
        final barGroups = data.entries.map((entry) {
          final quelle = entry.key;
          final statusMap = entry.value;
          return BarChartGroupData(
            x: quellen.indexOf(quelle),
            barRods: statusMap.entries.map((statusEntry) {
              final status = statusEntry.key;
              final count = statusEntry.value;
              final idx = statusSet.indexOf(status);
              final color = Colors.primaries[idx % Colors.primaries.length];
              return BarChartRodData(
                toY: count.toDouble(),
                color: color,
                width: 12,
                borderRadius: BorderRadius.circular(3),
              );
            }).toList(),
            barsSpace: 4,
          );
        }).toList();
        return Center(
          child: SizedBox(
            width: 500,
            child: Card(
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bar_chart, color: Colors.purple, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Status pro Kontaktquelle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Anzahl der Anfragen nach Status und Kontaktquelle im gewählten Zeitraum', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          barGroups: barGroups,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.white,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final quelleIndex = quellen.indexOf(quellen[group.x]);
                                final statusIndex = statusSet.indexOf(statusSet[rodIndex]);
                                return BarTooltipItem(
                                  '${quellen[quelleIndex]}\n${statusSet[statusIndex]}: ${rod.toY.toInt()}',
                                  const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                );
                              },
                            ),
                            touchCallback: (event, response) {
                              setState(() {
                                touchedGroup = response?.spot?.touchedBarGroupIndex;
                                touchedRod = response?.spot?.touchedRodDataIndex;
                              });
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 22),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  if (value < 0 || value >= quellen.length) return const SizedBox.shrink();
                                  return Text(quellen[value.toInt()], style: const TextStyle(fontSize: 9));
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                          groupsSpace: 10,
                          maxY: barGroups.expand((g) => g.barRods).map((r) => r.toY).fold(0.0, (a, b) => a > b ? a : b) + 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: statusSet.map((s) {
                        final idx = statusSet.indexOf(s);
                        final color = Colors.primaries[idx % Colors.primaries.length];
                        final value = quellen.fold<int>(0, (sum, q) => sum + (data[q]![s] ?? 0));
                        final percent = total > 0 ? value / total * 100 : 0.0;
                        return Container(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 6),
                              Flexible(child: Text(s, style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                              Text(' $value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 4),
                              Text('(${percent.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Monatsbalkendiagramm (jetzt mit _filteredEntries, X-Achse je nach Zeitraum)
  List<BarChartGroupData> _buildMonthlyBarGroups() {
    final filtered = _filteredEntries();
    final now = DateTime.now();
    List<DateTime> xAxis;
    if (_zeitraum == Zeitraum.woche) {
      xAxis = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    } else if (_zeitraum == Zeitraum.monat) {
      final firstDay = DateTime(now.year, now.month, 1);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      xAxis = List.generate(daysInMonth, (i) => firstDay.add(Duration(days: i)));
    } else if (_zeitraum == Zeitraum.jahr) {
      xAxis = List.generate(12, (i) => DateTime(now.year, i + 1));
    } else {
      xAxis = List.generate(12, (i) => DateTime(now.year, now.month - 11 + i));
    }
    final counts = <String, int>{};
    for (final d in xAxis) {
      String key;
      if (_zeitraum == Zeitraum.woche || _zeitraum == Zeitraum.monat) {
        key = DateFormat('yyyy-MM-dd').format(d);
      } else {
        key = DateFormat('yyyy-MM').format(d);
      }
      counts[key] = 0;
    }
    for (final e in filtered) {
      if (e.anfrageDatum != null) {
        String key;
        if (_zeitraum == Zeitraum.woche || _zeitraum == Zeitraum.monat) {
          key = DateFormat('yyyy-MM-dd').format(e.anfrageDatum!);
        } else {
          key = DateFormat('yyyy-MM').format(DateTime(e.anfrageDatum!.year, e.anfrageDatum!.month));
        }
        if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
      }
    }
    return List.generate(xAxis.length, (i) {
      final d = xAxis[i];
      String key;
      if (_zeitraum == Zeitraum.woche || _zeitraum == Zeitraum.monat) {
        key = DateFormat('yyyy-MM-dd').format(d);
      } else {
        key = DateFormat('yyyy-MM').format(d);
      }
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (counts[key] ?? 0).toDouble(),
            color: Colors.blue,
            width: 12,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    });
  }

  // Monatsbalkendiagramm-Widget (kompakt, X-Achse dynamisch, mit Tooltips und Legende)
  Widget _buildMonthlyBarChart() {
    return StatefulBuilder(
      builder: (context, setState) {
        final filtered = _filteredEntries();
        final total = filtered.length;
        final now = DateTime.now();
        final barGroups = _buildMonthlyBarGroups();
        List<String> labels;
        if (_zeitraum == Zeitraum.woche) {
          labels = List.generate(7, (i) => DateFormat('E').format(now.subtract(Duration(days: 6 - i))));
        } else if (_zeitraum == Zeitraum.monat) {
          final firstDay = DateTime(now.year, now.month, 1);
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          labels = List.generate(daysInMonth, (i) => (i + 1).toString());
        } else if (_zeitraum == Zeitraum.jahr) {
          labels = List.generate(12, (i) => DateFormat('MMM').format(DateTime(now.year, i + 1)));
        } else {
          labels = List.generate(12, (i) {
            final d = DateTime(now.year, now.month - 11 + i);
            return DateFormat('MM.yy').format(d);
          });
        }
        return Center(
          child: SizedBox(
            width: 500,
            child: Card(
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.indigo, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Anfragen im Verlauf', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Anzahl der Anfragen pro Monat im gewählten Zeitraum', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (barGroups.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b) + 2).clamp(4, 999),
                          barGroups: barGroups,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.white,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${labels[group.x]}: ${rod.toY.toInt()}',
                                  const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 22),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  if (value < 0 || value >= labels.length) return const SizedBox.shrink();
                                  return Text(labels[value.toInt()], style: const TextStyle(fontSize: 9));
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Anfragen', style: TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                        Text('Gesamt: $total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Heatmap: Anfragen pro Wochentag (mit kompakter Legende)
  Widget _buildWeekdayHeatmap() {
    final filtered = _filteredEntries();
    final weekdayCounts = List.filled(7, 0);
    for (final e in filtered) {
      if (e.anfrageDatum != null) {
        final wd = e.anfrageDatum!.weekday % 7; // 0=Sonntag, 6=Samstag
        weekdayCounts[wd]++;
      }
    }
    final maxCount = weekdayCounts.reduce((a, b) => a > b ? a : b);
    final weekDays = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
    final total = filtered.length;
    return StatefulBuilder(
      builder: (context, setState) {
        return Center(
          child: SizedBox(
            width: 500,
            child: Card(
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.thermostat, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Anfragen nach Wochentag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Anzahl der Anfragen pro Wochentag im gewählten Zeitraum', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(7, (i) {
                          final intensity = maxCount > 0 ? (weekdayCounts[i] / maxCount) : 0.0;
                          final color = Color.lerp(Colors.grey[200], Colors.blue, intensity)!;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Center(
                                    child: Text(
                                      weekdayCounts[i].toString(),
                                      style: TextStyle(
                                        color: intensity > 0.5 ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(weekDays[i], style: const TextStyle(fontSize: 12, color: Colors.black87)),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 6),
                            const Text('Mehr Anfragen', style: TextStyle(fontSize: 12, color: Colors.black87)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 6),
                            const Text('Weniger Anfragen', style: TextStyle(fontSize: 12, color: Colors.black87)),
                          ],
                        ),
                        Text('Gesamt: $total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Liniendiagramm: Abschlussquote im Zeitverlauf (mit kompakter Legende)
  Widget _buildQuoteLineChart() {
    return StatefulBuilder(
      builder: (context, setState) {
        final filtered = _filteredEntries();
        final total = filtered.length;
        final now = DateTime.now();
        List<DateTime> xAxis;
        if (_zeitraum == Zeitraum.woche) {
          xAxis = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
        } else if (_zeitraum == Zeitraum.monat) {
          final firstDay = DateTime(now.year, now.month, 1);
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          xAxis = List.generate(daysInMonth, (i) => firstDay.add(Duration(days: i)));
        } else if (_zeitraum == Zeitraum.jahr) {
          xAxis = List.generate(12, (i) => DateTime(now.year, i + 1));
        } else {
          xAxis = List.generate(12, (i) => DateTime(now.year, now.month - 11 + i));
        }
        final quotePoints = <FlSpot>[];
        for (int i = 0; i < xAxis.length; i++) {
          final d = xAxis[i];
          List<CrmEntry> periodEntries;
          if (_zeitraum == Zeitraum.woche || _zeitraum == Zeitraum.monat) {
            periodEntries = filtered.where((e) => e.anfrageDatum != null && DateFormat('yyyy-MM-dd').format(e.anfrageDatum!) == DateFormat('yyyy-MM-dd').format(d)).toList();
          } else {
            periodEntries = filtered.where((e) => e.anfrageDatum != null && e.anfrageDatum!.year == d.year && e.anfrageDatum!.month == d.month).toList();
          }
          final total = periodEntries.length;
          final abgeschlossen = periodEntries.where((e) => (e.status ?? '').toLowerCase().contains('abgeschlossen')).length;
          final quote = total > 0 ? abgeschlossen / total * 100 : 0.0;
          quotePoints.add(FlSpot(i.toDouble(), quote));
        }
        List<String> labels;
        if (_zeitraum == Zeitraum.woche) {
          labels = List.generate(7, (i) => DateFormat('E').format(now.subtract(Duration(days: 6 - i))));
        } else if (_zeitraum == Zeitraum.monat) {
          final firstDay = DateTime(now.year, now.month, 1);
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          labels = List.generate(daysInMonth, (i) => (i + 1).toString());
        } else if (_zeitraum == Zeitraum.jahr) {
          labels = List.generate(12, (i) => DateFormat('MMM').format(DateTime(now.year, i + 1)));
        } else {
          labels = List.generate(12, (i) {
            final d = DateTime(now.year, now.month - 11 + i);
            return DateFormat('MM.yy').format(d);
          });
        }
        return Center(
          child: SizedBox(
            width: 500,
            child: Card(
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_up, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Abschlussquote im Verlauf', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Abschlussquote im gewählten Zeitraum', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    SizedBox(height: 24),
                    SizedBox(
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: quotePoints,
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 2.5,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              tooltipBgColor: Colors.white,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    '${labels[spot.x.toInt()]}: ${spot.y.toStringAsFixed(1)}%',
                                    const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  if (value < 0 || value >= labels.length) return const SizedBox.shrink();
                                  return Text(labels[value.toInt()], style: const TextStyle(fontSize: 9));
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Abschlussquote (%)', style: TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Vergleichsdiagramm: aktueller Zeitraum vs. Vorjahreszeitraum (mit Tooltips und Legende)
  Widget _buildCompareWithLastYearChart() {
    final now = DateTime.now();
    List<DateTime> xAxis;
    if (_zeitraum == Zeitraum.woche) {
      xAxis = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    } else if (_zeitraum == Zeitraum.monat) {
      final firstDay = DateTime(now.year, now.month, 1);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      xAxis = List.generate(daysInMonth, (i) => firstDay.add(Duration(days: i)));
    } else if (_zeitraum == Zeitraum.jahr) {
      xAxis = List.generate(12, (i) => DateTime(now.year, i + 1));
    } else {
      xAxis = List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));
    }
    final filtered = _entries;
    final currentCounts = <int, int>{};
    final lastYearCounts = <int, int>{};
    int totalCurrent = 0;
    int totalLastYear = 0;
    for (int i = 0; i < xAxis.length; i++) {
      final d = xAxis[i];
      List<CrmEntry> currentEntries;
      List<CrmEntry> lastYearEntries;
      if (_zeitraum == Zeitraum.woche || _zeitraum == Zeitraum.monat || _zeitraum == Zeitraum.letzte30Tage) {
        currentEntries = filtered.where((e) => e.anfrageDatum != null && DateFormat('yyyy-MM-dd').format(e.anfrageDatum!) == DateFormat('yyyy-MM-dd').format(d)).toList();
        final dLastYear = DateTime(d.year - 1, d.month, d.day);
        lastYearEntries = filtered.where((e) => e.anfrageDatum != null && DateFormat('yyyy-MM-dd').format(e.anfrageDatum!) == DateFormat('yyyy-MM-dd').format(dLastYear)).toList();
      } else {
        currentEntries = filtered.where((e) => e.anfrageDatum != null && e.anfrageDatum!.year == d.year && e.anfrageDatum!.month == d.month).toList();
        final dLastYear = DateTime(d.year - 1, d.month);
        lastYearEntries = filtered.where((e) => e.anfrageDatum != null && e.anfrageDatum!.year == dLastYear.year && e.anfrageDatum!.month == dLastYear.month).toList();
      }
      currentCounts[i] = currentEntries.length;
      lastYearCounts[i] = lastYearEntries.length;
      totalCurrent += currentEntries.length;
      totalLastYear += lastYearEntries.length;
    }
    List<String> labels;
    if (_zeitraum == Zeitraum.woche) {
      labels = List.generate(7, (i) => DateFormat('E').format(now.subtract(Duration(days: 6 - i))));
    } else if (_zeitraum == Zeitraum.monat) {
      final firstDay = DateTime(now.year, now.month, 1);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      labels = List.generate(daysInMonth, (i) => (i + 1).toString());
    } else if (_zeitraum == Zeitraum.jahr) {
      labels = List.generate(12, (i) => DateFormat('MMM').format(DateTime(now.year, i + 1)));
    } else {
      labels = List.generate(30, (i) => DateFormat('d.M.').format(now.subtract(Duration(days: 29 - i))));
    }
    final barGroups = List.generate(xAxis.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (currentCounts[i] ?? 0).toDouble(),
            color: Colors.blue,
            width: 8,
            borderRadius: BorderRadius.circular(2),
            rodStackItems: [],
          ),
          BarChartRodData(
            toY: (lastYearCounts[i] ?? 0).toDouble(),
            color: Colors.orange,
            width: 8,
            borderRadius: BorderRadius.circular(2),
            rodStackItems: [],
          ),
        ],
        barsSpace: 4,
      );
    });
    return StatefulBuilder(
      builder: (context, setState) {
        return Center(
          child: SizedBox(
            width: 500,
            child: Card(
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.compare_arrows, color: Colors.purple, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Vergleich: Aktueller Zeitraum vs. Vorjahr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Vergleich der Anfragenanzahl zwischen aktuellem und vorherigem Jahr im gewählten Zeitraum', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (barGroups.expand((g) => g.barRods).map((r) => r.toY).reduce((a, b) => a > b ? a : b) + 2).clamp(4, 999),
                          barGroups: barGroups,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.white,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final isCurrent = rodIndex == 0;
                                return BarTooltipItem(
                                  '${labels[group.x]}\n${isCurrent ? 'Aktuell' : 'Vorjahr'}: ${rod.toY.toInt()}',
                                  TextStyle(color: isCurrent ? Colors.blue : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 22),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  if (value < 0 || value >= labels.length) return const SizedBox.shrink();
                                  return Text(labels[value.toInt()], style: const TextStyle(fontSize: 9));
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        const Text('Aktuell', style: TextStyle(fontSize: 13, color: Colors.black87)),
                        const Spacer(),
                        Text('Gesamt: $totalCurrent', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        const Text('Vorjahr', style: TextStyle(fontSize: 13, color: Colors.black87)),
                        const Spacer(),
                        Text('Gesamt: $totalLastYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportExcel() async {
    final excel = excel_pkg.Excel.createExcel();
    // Rohdaten-Blatt
    final sheetRaw = excel['Rohdaten'];
    sheetRaw.appendRow([
      'ID', 'Datum', 'Status', 'Kontaktquelle', // 'Name', 'Notiz' entfernt
    ]);
    for (final e in _entries) {
      sheetRaw.appendRow([
        e.id?.toString() ?? '',
        e.anfrageDatum != null ? DateFormat('yyyy-MM-dd').format(e.anfrageDatum!) : '',
        (e.status ?? '').trim().isEmpty || (e.status ?? '').trim().toLowerCase() == 'unbekannt' ? 'Sonstiges' : (e.status ?? '').trim(),
        (e.kontaktquelle ?? '').trim().isEmpty || (e.kontaktquelle ?? '').trim().toLowerCase() == 'unbekannt' ? 'Sonstiges' : (e.kontaktquelle ?? '').trim(),
      ]);
    }
    // Statistik-Blatt
    final sheetStat = excel['Statistik'];
    sheetStat.appendRow(['Kategorie', 'Wert', 'Anzahl', 'Prozent']);
    // Kontaktquellen
    final quelleMap = <String, int>{};
    for (final e in _entries) {
      var quelle = (e.kontaktquelle ?? '').trim();
      if (quelle.isEmpty || quelle.toLowerCase() == 'unbekannt') quelle = 'Sonstiges';
      quelleMap[quelle] = (quelleMap[quelle] ?? 0) + 1;
    }
    final total = _entries.length;
    for (final k in quelleMap.keys) {
      final value = quelleMap[k] ?? 0;
      final percent = total > 0 ? value / total * 100 : 0.0;
      sheetStat.appendRow(['Kontaktquelle', k, value, percent]);
    }
    // Status
    final statusMap = <String, int>{};
    for (final e in _entries) {
      var status = (e.status ?? '').trim();
      if (status.isEmpty || status.toLowerCase() == 'unbekannt') status = 'Sonstiges';
      statusMap[status] = (statusMap[status] ?? 0) + 1;
    }
    for (final k in statusMap.keys) {
      final value = statusMap[k] ?? 0;
      final percent = total > 0 ? value / total * 100 : 0.0;
      sheetStat.appendRow(['Status', k, value, percent]);
    }
    // Speichern
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/statistik_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
    await file.writeAsBytes(excel.encode()!);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel-Datei gespeichert: ${file.path}')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Fehler: $_error'));
    if (_entries.isEmpty) return const Center(child: Text('Keine Daten'));

    final now = DateTime.now();
    final last30 = now.subtract(const Duration(days: 30));
    final thisMonth = DateTime(now.year, now.month);
    final thisYear = DateTime(now.year);

    List<CrmEntry> filter(DateTime from) => _entries.where((e) => e.anfrageDatum != null && e.anfrageDatum!.isAfter(from)).toList();
    List<CrmEntry> filterMonth() => _entries.where((e) => e.anfrageDatum != null && e.anfrageDatum!.year == now.year && e.anfrageDatum!.month == now.month).toList();
    List<CrmEntry> filterYear() => _entries.where((e) => e.anfrageDatum != null && e.anfrageDatum!.year == now.year).toList();

    // Angepasstes statsBlock mit Sonstiges-Gruppierung und schönerem Layout
    Widget statsBlock(String title, List<CrmEntry> list) {
      final statusMap = <String, int>{};
      final quelleMap = <String, int>{};
      for (final e in list) {
        var status = (e.status ?? '').trim();
        if (status.isEmpty || status.toLowerCase() == 'unbekannt') status = 'Sonstiges';
        statusMap[status] = (statusMap[status] ?? 0) + 1;
        var quelle = (e.kontaktquelle ?? '').trim();
        if (quelle.isEmpty || quelle.toLowerCase() == 'unbekannt') quelle = 'Sonstiges';
        quelleMap[quelle] = (quelleMap[quelle] ?? 0) + 1;
      }
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Anfragen insgesamt: ${list.length}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 8),
              // Statt Row(...), nutze Wrap:
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Status-Verteilung:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 12,
                          runSpacing: 2,
                          children: statusMap.entries.map((e) => Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)).toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kontaktquelle-Verteilung:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 12,
                          runSpacing: 2,
                          children: quelleMap.entries.map((e) => Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // statsBlocks in ein Grid/Wrap-Layout
    final statsBlocks = [
      statsBlock('Letzte 30 Tage', filter(last30)),
      statsBlock('Aktueller Monat (${DateFormat.yMMMM().format(now)})', filterMonth()),
      statsBlock('Aktuelles Jahr (${now.year})', filterYear()),
      statsBlock('Alle Anfragen', _entries),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Excel-Export',
            onPressed: _exportExcel,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1100;
            return ListView(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButton<Zeitraum>(
                    value: _zeitraum,
                    isExpanded: true,
                    onChanged: (z) => setState(() => _zeitraum = z!),
                    items: const [
                      DropdownMenuItem(value: Zeitraum.letzte30Tage, child: Text('Letzte 30 Tage')),
                      DropdownMenuItem(value: Zeitraum.woche, child: Text('Letzte 7 Tage')),
                      DropdownMenuItem(value: Zeitraum.monat, child: Text('Aktueller Monat')),
                      DropdownMenuItem(value: Zeitraum.jahr, child: Text('Aktuelles Jahr')),
                      DropdownMenuItem(value: Zeitraum.vergleichVorjahr, child: Text('Vergleich Vorjahr')),
                    ],
                  ),
                ),
                _buildKpiCards(),
                const SizedBox(height: 8),
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildQuellePieChart()),
                          Expanded(child: _buildStackedBarStatusPerQuelle()),
                          Expanded(child: _buildMonthlyBarChart()),
                          Expanded(child: _buildWeekdayHeatmap()),
                          Expanded(child: _buildQuoteLineChart()),
                          if (_zeitraum == Zeitraum.vergleichVorjahr) Expanded(child: _buildCompareWithLastYearChart()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildQuellePieChart(),
                          _buildStackedBarStatusPerQuelle(),
                          _buildMonthlyBarChart(),
                          _buildWeekdayHeatmap(),
                          _buildQuoteLineChart(),
                          if (_zeitraum == Zeitraum.vergleichVorjahr) _buildCompareWithLastYearChart(),
                        ],
                      ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      return isWide
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: statsBlocks.map((b) => SizedBox(width: 340, child: b)).toList(),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: statsBlocks,
                            );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
} 