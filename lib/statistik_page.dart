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
    final einsender = filtered.where((e) => (e.status ?? '').toLowerCase().contains('einsender')).length;
    final nichtEinsender = filtered.where((e) => (e.status ?? '').toLowerCase().contains('nicht einsender')).length;
    final offen = filtered.where((e) => (e.status ?? '').toLowerCase().contains('offen')).length;
    final quote = total > 0 ? (einsender / total * 100).toStringAsFixed(1) : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _kpiCard('Gesamt', total.toString(), Icons.all_inbox, Colors.blue[700]!),
            const SizedBox(width: 16),
            _kpiCard('Einsender', einsender.toString(), Icons.check_circle, Colors.green[700]!),
            const SizedBox(width: 16),
            _kpiCard('Offen', offen.toString(), Icons.pending, Colors.amber[800]!),
            const SizedBox(width: 16),
            _kpiCard('nicht Einsender', nichtEinsender.toString(), Icons.cancel, Colors.red[700]!),
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

  // PieChart für Typen
  Widget _buildTypPieChart() {
    final filtered = _filteredEntries();
    final typMap = <String, int>{};
    for (final e in filtered) {
      var typ = (e.typ ?? '').trim();
      if (typ.isEmpty) typ = 'Sonstiges';
      typMap[typ] = (typMap[typ] ?? 0) + 1;
    }
    final total = filtered.length;
    int? touchedIndex;
    final typKeys = typMap.keys.toList();
    return StatefulBuilder(
      builder: (context, setState) {
        final sections = typMap.entries.map((e) {
          final idx = typKeys.indexOf(e.key);
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
                        const Icon(Icons.pie_chart, color: Colors.deepPurple, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Typen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Verteilung der Anfragen nach Typ im gewählten Zeitraum', style: TextStyle(fontSize: 12, color: Colors.black54)),
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
                      children: typKeys.map((k) {
                        final idx = typKeys.indexOf(k);
                        final color = Colors.primaries[idx % Colors.primaries.length];
                        final value = typMap[k] ?? 0;
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

  // PieChart für Stadium
  Widget _buildStadiumPieChart() {
    final filtered = _filteredEntries();
    final stadiumMap = <String, int>{};
    for (final e in filtered) {
      var stadium = (e.stadium ?? '').trim();
      if (stadium.isEmpty) stadium = 'Sonstiges';
      stadiumMap[stadium] = (stadiumMap[stadium] ?? 0) + 1;
    }
    final total = filtered.length;
    int? touchedIndex;
    final stadiumKeys = stadiumMap.keys.toList();
    return StatefulBuilder(
      builder: (context, setState) {
        final sections = stadiumMap.entries.map((e) {
          final idx = stadiumKeys.indexOf(e.key);
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
                        const Icon(Icons.pie_chart, color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Stadium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Verteilung der Anfragen nach Stadium im gewählten Zeitraum', style: TextStyle(fontSize: 12, color: Colors.black54)),
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
                      children: stadiumKeys.map((k) {
                        final idx = stadiumKeys.indexOf(k);
                        final color = Colors.primaries[idx % Colors.primaries.length];
                        final value = stadiumMap[k] ?? 0;
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
                              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
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
        key = DateFormat('yyyy-MM-dd', 'de_DE').format(d);
      } else {
        key = DateFormat('yyyy-MM', 'de_DE').format(d);
      }
      counts[key] = 0;
    }
    for (final e in filtered) {
      if (e.anfrageDatum != null) {
        String key;
        if (_zeitraum == Zeitraum.woche || _zeitraum == Zeitraum.monat) {
          key = DateFormat('yyyy-MM-dd', 'de_DE').format(e.anfrageDatum!);
        } else {
          key = DateFormat('yyyy-MM', 'de_DE').format(DateTime(e.anfrageDatum!.year, e.anfrageDatum!.month));
        }
        if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
      }
    }
    return List.generate(xAxis.length, (i) {
      final d = xAxis[i];
      String key;
      if (_zeitraum == Zeitraum.woche || _zeitraum == Zeitraum.monat) {
        key = DateFormat('yyyy-MM-dd', 'de_DE').format(d);
      } else {
        key = DateFormat('yyyy-MM', 'de_DE').format(d);
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
          labels = List.generate(7, (i) => DateFormat('E', 'de_DE').format(now.subtract(Duration(days: 6 - i))));
        } else if (_zeitraum == Zeitraum.monat) {
          final firstDay = DateTime(now.year, now.month, 1);
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          labels = List.generate(daysInMonth, (i) => (i + 1).toString());
        } else if (_zeitraum == Zeitraum.jahr) {
          labels = List.generate(12, (i) => DateFormat('MMM', 'de_DE').format(DateTime(now.year, i + 1)));
        } else {
          labels = List.generate(12, (i) {
            final d = DateTime(now.year, now.month - 11 + i);
            return DateFormat('MM.yy', 'de_DE').format(d);
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
                          maxY: (barGroups.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b) + 2).clamp(4, 999).toDouble(),
                          barGroups: barGroups,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${labels[group.x.toInt()]}: ${rod.toY.toInt()}',
                                  const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                );
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

  // Balkendiagramm: Abschlussquote im Zeitverlauf (Einsender vs. nicht Einsender)
  Widget _buildQuoteBarChart() {
    List<DateTime> xAxis;
    List<String> labels;
    if (_zeitraum == Zeitraum.woche) {
      xAxis = getWeekXAxis();
      labels = getWeekLabels();
    } else if (_zeitraum == Zeitraum.monat) {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      xAxis = List.generate(daysInMonth, (i) => firstDay.add(Duration(days: i)));
      labels = List.generate(daysInMonth, (i) => (i + 1).toString());
    } else if (_zeitraum == Zeitraum.jahr) {
      final now = DateTime.now();
      xAxis = List.generate(12, (i) => DateTime(now.year, i + 1));
      labels = List.generate(12, (i) => DateFormat('MMM', 'de_DE').format(DateTime(now.year, i + 1)));
    } else {
      final now = DateTime.now();
      xAxis = List.generate(12, (i) => DateTime(now.year, now.month - 11 + i));
      labels = List.generate(12, (i) {
        final d = DateTime(now.year, now.month - 11 + i);
        return DateFormat('MM.yy', 'de_DE').format(d);
      });
    }
    final filtered = _filteredEntries();
    final einsenderCounts = List.filled(xAxis.length, 0);
    final nichtEinsenderCounts = List.filled(xAxis.length, 0);
    for (int i = 0; i < xAxis.length; i++) {
      final d = xAxis[i];
      List<CrmEntry> periodEntries;
      if (_zeitraum == Zeitraum.woche || _zeitraum == Zeitraum.monat) {
        periodEntries = filtered.where((e) => e.anfrageDatum != null && DateFormat('yyyy-MM-dd', 'de_DE').format(e.anfrageDatum!) == DateFormat('yyyy-MM-dd', 'de_DE').format(d)).toList();
      } else {
        periodEntries = filtered.where((e) => e.anfrageDatum != null && e.anfrageDatum!.year == d.year && e.anfrageDatum!.month == d.month).toList();
      }
      einsenderCounts[i] = periodEntries.where((e) => (e.status ?? '').toLowerCase().contains('einsender')).length;
      nichtEinsenderCounts[i] = periodEntries.where((e) => (e.status ?? '').toLowerCase().contains('nicht einsender')).length;
    }
    final barGroups = List.generate(xAxis.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: einsenderCounts[i].toDouble(),
            color: Colors.green,
            width: 12,
            borderRadius: BorderRadius.circular(3),
          ),
          BarChartRodData(
            toY: nichtEinsenderCounts[i].toDouble(),
            color: Colors.red,
            width: 12,
            borderRadius: BorderRadius.circular(3),
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
                        const Icon(Icons.bar_chart, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Einsender / nicht Einsender im Verlauf', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Anzahl der Einsender und nicht Einsender pro Zeitraum', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: ([...einsenderCounts, ...nichtEinsenderCounts].reduce((a, b) => a > b ? a : b) + 2).clamp(4, 999).toDouble(),
                          barGroups: barGroups,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final isEinsender = rodIndex == 0;
                                return BarTooltipItem(
                                  '${labels[group.x.toInt()]}\n${isEinsender ? 'Einsender' : 'nicht Einsender'}: ${rod.toY.toInt()}',
                                  TextStyle(color: isEinsender ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                );
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
                        const Text('Einsender', style: TextStyle(fontSize: 13, color: Colors.black87)),
                        const Spacer(),
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        const Text('nicht Einsender', style: TextStyle(fontSize: 13, color: Colors.black87)),
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
        currentEntries = filtered.where((e) => e.anfrageDatum != null && DateFormat('yyyy-MM-dd', 'de_DE').format(e.anfrageDatum!) == DateFormat('yyyy-MM-dd', 'de_DE').format(d)).toList();
        final dLastYear = DateTime(d.year - 1, d.month, d.day);
        lastYearEntries = filtered.where((e) => e.anfrageDatum != null && DateFormat('yyyy-MM-dd', 'de_DE').format(e.anfrageDatum!) == DateFormat('yyyy-MM-dd', 'de_DE').format(dLastYear)).toList();
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
      labels = List.generate(7, (i) => DateFormat('E', 'de_DE').format(now.subtract(Duration(days: 6 - i))));
    } else if (_zeitraum == Zeitraum.monat) {
      final firstDay = DateTime(now.year, now.month, 1);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      labels = List.generate(daysInMonth, (i) => (i + 1).toString());
    } else if (_zeitraum == Zeitraum.jahr) {
      labels = List.generate(12, (i) => DateFormat('MMM', 'de_DE').format(DateTime(now.year, i + 1)));
    } else {
      labels = List.generate(30, (i) => DateFormat('d.M.', 'de_DE').format(now.subtract(Duration(days: 29 - i))));
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
                          maxY: (barGroups.expand((g) => g.barRods).map((r) => r.toY).reduce((a, b) => a > b ? a : b) + 2).clamp(4, 999).toDouble(),
                          barGroups: barGroups,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final isCurrent = rodIndex == 0;
                                return BarTooltipItem(
                                  '${labels[group.x.toInt()]}\n${isCurrent ? 'Aktuell' : 'Vorjahr'}: ${rod.toY.toInt()}',
                                  TextStyle(color: isCurrent ? Colors.blue : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                );
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
    
    // 1. Vollständige Rohdaten-Blatt
    final sheetRaw = excel['Vollständige_Rohdaten'];
    sheetRaw.appendRow([
      excel_pkg.TextCellValue('ID'),
      excel_pkg.TextCellValue('Anfrage-Datum'),
      excel_pkg.TextCellValue('Titel'),
      excel_pkg.TextCellValue('Vorname'),
      excel_pkg.TextCellValue('Nachname'),
      excel_pkg.TextCellValue('Straße'),
      excel_pkg.TextCellValue('Hausnummer'),
      excel_pkg.TextCellValue('PLZ'),
      excel_pkg.TextCellValue('Ort'),
      excel_pkg.TextCellValue('Land'),
      excel_pkg.TextCellValue('E-Mail'),
      excel_pkg.TextCellValue('Mobil'),
      excel_pkg.TextCellValue('Festnetz'),
      excel_pkg.TextCellValue('Krankheitsstatus'),
      excel_pkg.TextCellValue('Status'),
      excel_pkg.TextCellValue('Bearbeiter'),
      excel_pkg.TextCellValue('Wiedervorlage'),
      excel_pkg.TextCellValue('Typ'),
      excel_pkg.TextCellValue('Stadium'),
      excel_pkg.TextCellValue('Kontaktquelle'),
      excel_pkg.TextCellValue('Nachricht'),
      excel_pkg.TextCellValue('Infos'),
      excel_pkg.TextCellValue('Erledigt'),
      excel_pkg.TextCellValue('Rolle'),
      excel_pkg.TextCellValue('Rabatt'),
      excel_pkg.TextCellValue('Krankenversicherung'),
      excel_pkg.TextCellValue('Test'),
      excel_pkg.TextCellValue('ToDos'),
    ]);
    
    for (final e in _entries) {
      sheetRaw.appendRow([
        excel_pkg.TextCellValue(e.id.toString()),
        excel_pkg.TextCellValue(e.anfrageDatum != null ? DateFormat('yyyy-MM-dd', 'de_DE').format(e.anfrageDatum!) : ''),
        excel_pkg.TextCellValue(e.titel ?? ''),
        excel_pkg.TextCellValue(e.vorname ?? ''),
        excel_pkg.TextCellValue(e.nachname ?? ''),
        excel_pkg.TextCellValue(e.strasse ?? ''),
        excel_pkg.TextCellValue(e.hausnummer ?? ''),
        excel_pkg.TextCellValue(e.plz ?? ''),
        excel_pkg.TextCellValue(e.ort ?? ''),
        excel_pkg.TextCellValue(e.land ?? ''),
        excel_pkg.TextCellValue(e.email ?? ''),
        excel_pkg.TextCellValue(e.mobil ?? ''),
        excel_pkg.TextCellValue(e.festnetz ?? ''),
        excel_pkg.TextCellValue(e.krankheitsstatus ?? ''),
        excel_pkg.TextCellValue(e.status ?? ''),
        excel_pkg.TextCellValue(e.bearbeiter ?? ''),
        excel_pkg.TextCellValue(e.wiedervorlage != null ? DateFormat('yyyy-MM-dd', 'de_DE').format(e.wiedervorlage!) : ''),
        excel_pkg.TextCellValue(e.typ ?? ''),
        excel_pkg.TextCellValue(e.stadium ?? ''),
        excel_pkg.TextCellValue(e.kontaktquelle ?? ''),
        excel_pkg.TextCellValue(e.nachricht ?? ''),
        excel_pkg.TextCellValue(e.infos ?? ''),
        excel_pkg.TextCellValue(e.erledigt ? 'Ja' : 'Nein'),
        excel_pkg.TextCellValue(e.rolle ?? ''),
        excel_pkg.TextCellValue(e.rabatt ?? ''),
        excel_pkg.TextCellValue(e.krankenversicherung ?? ''),
        excel_pkg.TextCellValue(e.test ?? ''),
        excel_pkg.TextCellValue(e.todoSummary),
      ]);
    }
    
    // 2. Statistik-Blatt (erweitert)
    final sheetStat = excel['Statistik'];
    sheetStat.appendRow([
      excel_pkg.TextCellValue('Kategorie'),
      excel_pkg.TextCellValue('Wert'),
      excel_pkg.TextCellValue('Anzahl'),
      excel_pkg.TextCellValue('Prozent'),
    ]);
    
    final total = _entries.length;
    
    // Kontaktquellen
    final quelleMap = <String, int>{};
    for (final e in _entries) {
      var quelle = (e.kontaktquelle ?? '').trim();
      if (quelle.isEmpty || quelle.toLowerCase() == 'unbekannt') quelle = 'Sonstiges';
      quelleMap[quelle] = (quelleMap[quelle] ?? 0) + 1;
    }
    for (final k in quelleMap.keys) {
      final value = quelleMap[k] ?? 0;
      final percent = total > 0 ? value / total * 100 : 0.0;
      sheetStat.appendRow([
        excel_pkg.TextCellValue('Kontaktquelle'),
        excel_pkg.TextCellValue(k),
        excel_pkg.IntCellValue(value),
        excel_pkg.DoubleCellValue(percent),
      ]);
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
      sheetStat.appendRow([
        excel_pkg.TextCellValue('Status'),
        excel_pkg.TextCellValue(k),
        excel_pkg.IntCellValue(value),
        excel_pkg.DoubleCellValue(percent),
      ]);
    }
    
    // Rollen
    final rolleMap = <String, int>{};
    for (final e in _entries) {
      var rolle = (e.rolle ?? '').trim();
      if (rolle.isEmpty) rolle = 'Nicht angegeben';
      rolleMap[rolle] = (rolleMap[rolle] ?? 0) + 1;
    }
    for (final k in rolleMap.keys) {
      final value = rolleMap[k] ?? 0;
      final percent = total > 0 ? value / total * 100 : 0.0;
      sheetStat.appendRow([
        excel_pkg.TextCellValue('Rolle'),
        excel_pkg.TextCellValue(k),
        excel_pkg.IntCellValue(value),
        excel_pkg.DoubleCellValue(percent),
      ]);
    }
    
    // Tests
    final testMap = <String, int>{};
    for (final e in _entries) {
      var test = (e.test ?? '').trim();
      if (test.isEmpty) test = 'Nicht angegeben';
      testMap[test] = (testMap[test] ?? 0) + 1;
    }
    for (final k in testMap.keys) {
      final value = testMap[k] ?? 0;
      final percent = total > 0 ? value / total * 100 : 0.0;
      sheetStat.appendRow([
        excel_pkg.TextCellValue('Test'),
        excel_pkg.TextCellValue(k),
        excel_pkg.IntCellValue(value),
        excel_pkg.DoubleCellValue(percent),
      ]);
    }
    
    // 3. Bearbeiter-Blatt
    final sheetBearbeiter = excel['Bearbeiter'];
    sheetBearbeiter.appendRow([
      excel_pkg.TextCellValue('Bearbeiter'),
      excel_pkg.TextCellValue('Anzahl_Einträge'),
      excel_pkg.TextCellValue('Einsender'),
      excel_pkg.TextCellValue('Nicht_Einsender'),
      excel_pkg.TextCellValue('Offen'),
      excel_pkg.TextCellValue('Abschlussquote_%'),
    ]);
    
    final bearbeiterMap = <String, List<CrmEntry>>{};
    for (final e in _entries) {
      final bearbeiter = e.bearbeiter ?? 'Unbekannt';
      bearbeiterMap[bearbeiter] = [...(bearbeiterMap[bearbeiter] ?? []), e];
    }
    
    for (final bearbeiter in bearbeiterMap.keys) {
      final entries = bearbeiterMap[bearbeiter]!;
      final totalEntries = entries.length;
      final einsender = entries.where((e) => (e.status ?? '').toLowerCase().contains('einsender')).length;
      final nichtEinsender = entries.where((e) => (e.status ?? '').toLowerCase().contains('nicht einsender')).length;
      final offen = entries.where((e) => (e.status ?? '').toLowerCase().contains('offen')).length;
      final quote = totalEntries > 0 ? (einsender / totalEntries * 100) : 0.0;
      
      sheetBearbeiter.appendRow([
        excel_pkg.TextCellValue(bearbeiter),
        excel_pkg.IntCellValue(totalEntries),
        excel_pkg.IntCellValue(einsender),
        excel_pkg.IntCellValue(nichtEinsender),
        excel_pkg.IntCellValue(offen),
        excel_pkg.DoubleCellValue(quote),
      ]);
    }
    
    // 4. Monatliche_Analyse-Blatt
    final sheetMonatlich = excel['Monatliche_Analyse'];
    sheetMonatlich.appendRow([
      excel_pkg.TextCellValue('Jahr'),
      excel_pkg.TextCellValue('Monat'),
      excel_pkg.TextCellValue('Anzahl_Einträge'),
      excel_pkg.TextCellValue('Einsender'),
      excel_pkg.TextCellValue('Nicht_Einsender'),
      excel_pkg.TextCellValue('Offen'),
      excel_pkg.TextCellValue('Abschlussquote_%'),
    ]);
    
    final monatlichMap = <String, List<CrmEntry>>{};
    for (final e in _entries) {
      if (e.anfrageDatum != null) {
        final key = '${e.anfrageDatum!.year}-${e.anfrageDatum!.month.toString().padLeft(2, '0')}';
        monatlichMap[key] = [...(monatlichMap[key] ?? []), e];
      }
    }
    
    final sortedMonths = monatlichMap.keys.toList()..sort();
    for (final monthKey in sortedMonths) {
      final entries = monatlichMap[monthKey]!;
      final totalEntries = entries.length;
      final einsender = entries.where((e) => (e.status ?? '').toLowerCase().contains('einsender')).length;
      final nichtEinsender = entries.where((e) => (e.status ?? '').toLowerCase().contains('nicht einsender')).length;
      final offen = entries.where((e) => (e.status ?? '').toLowerCase().contains('offen')).length;
      final quote = totalEntries > 0 ? (einsender / totalEntries * 100) : 0.0;
      
      final parts = monthKey.split('-');
      final year = parts[0];
      final month = parts[1];
      
      sheetMonatlich.appendRow([
        excel_pkg.TextCellValue(year),
        excel_pkg.TextCellValue(month),
        excel_pkg.IntCellValue(totalEntries),
        excel_pkg.IntCellValue(einsender),
        excel_pkg.IntCellValue(nichtEinsender),
        excel_pkg.IntCellValue(offen),
        excel_pkg.DoubleCellValue(quote),
      ]);
    }
    
    // 5. Wiedervorlagen-Blatt
    final sheetWiedervorlage = excel['Wiedervorlagen'];
    sheetWiedervorlage.appendRow([
      excel_pkg.TextCellValue('ID'),
      excel_pkg.TextCellValue('Name'),
      excel_pkg.TextCellValue('Wiedervorlage_Datum'),
      excel_pkg.TextCellValue('Status'),
      excel_pkg.TextCellValue('Bearbeiter'),
      excel_pkg.TextCellValue('Tage_bis_heute'),
    ]);
    
    final now = DateTime.now();
    final wiedervorlagen = _entries.where((e) => e.wiedervorlage != null).toList()
      ..sort((a, b) => (a.wiedervorlage ?? now).compareTo(b.wiedervorlage ?? now));
    
    for (final e in wiedervorlagen) {
      final tage = e.wiedervorlage != null ? now.difference(e.wiedervorlage!).inDays : 0;
      sheetWiedervorlage.appendRow([
        excel_pkg.TextCellValue(e.id.toString()),
        excel_pkg.TextCellValue('${e.vorname ?? ''} ${e.nachname ?? ''}'.trim()),
        excel_pkg.TextCellValue(DateFormat('yyyy-MM-dd', 'de_DE').format(e.wiedervorlage!)),
        excel_pkg.TextCellValue(e.status ?? ''),
        excel_pkg.TextCellValue(e.bearbeiter ?? ''),
        excel_pkg.IntCellValue(tage),
      ]);
    }
    
    // Speichern
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/vollständiger_crm_export_${DateFormat('yyyyMMdd_HHmmss', 'de_DE').format(DateTime.now())}.xlsx');
    await file.writeAsBytes(excel.encode()!);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Vollständiger CRM-Export gespeichert: ${file.path}'),
      duration: const Duration(seconds: 5),
    ));
  }

  // Hilfsfunktion für Woche: Mo-So Labels und xAxis
  List<DateTime> getWeekXAxis() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final startOfWeek = now.subtract(Duration(days: weekday - 1));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }
  List<String> getWeekLabels() => ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

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
          // Aktueller Benutzer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                widget.apiService.loggedInUser ?? 'Nicht eingeloggt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
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
                    ? Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(width: 520, child: _buildQuellePieChart()),
                          SizedBox(width: 520, child: _buildTypPieChart()),
                          SizedBox(width: 520, child: _buildStadiumPieChart()),
                          SizedBox(width: 520, child: _buildStackedBarStatusPerQuelle()),
                          SizedBox(width: 520, child: _buildMonthlyBarChart()),
                          SizedBox(width: 520, child: _buildWeekdayHeatmap()),
                          SizedBox(width: 520, child: _buildQuoteBarChart()),
                          if (_zeitraum == Zeitraum.vergleichVorjahr) SizedBox(width: 520, child: _buildCompareWithLastYearChart()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildQuellePieChart(),
                          _buildTypPieChart(),
                          _buildStadiumPieChart(),
                          _buildStackedBarStatusPerQuelle(),
                          _buildMonthlyBarChart(),
                          _buildWeekdayHeatmap(),
                          _buildQuoteBarChart(),
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