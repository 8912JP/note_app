import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';

import 'crm_entry.dart';
import 'api_service.dart';
import 'crm_entry_edit_form.dart';
import 'form_page.dart';

class CrmEntryProvider extends ChangeNotifier {
  List<CrmEntry> _entries = [];
  String _searchText = '';
  DateTimeRange? _selectedDateRange;

  int sortColumnIndex = 0;
  bool sortAscending = true;

  set searchText(String value) {
    _searchText = value;
    notifyListeners();
  }

  set selectedDateRange(DateTimeRange? range) {
    _selectedDateRange = range;
    notifyListeners();
  }

  List<CrmEntry> get filteredEntries {
    return _entries.where((e) {
      final text = '${e.vorname} ${e.nachname} ${e.email} ${e.adresse}'.toLowerCase();
      if (_searchText.isNotEmpty && !text.contains(_searchText.toLowerCase())) {
        return false;
      }
      if (_selectedDateRange != null) {
        if (e.anfrageDatum.isBefore(_selectedDateRange!.start) ||
            e.anfrageDatum.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> loadEntries(ApiService apiService) async {
    try {
      _entries = await apiService.fetchCrmEntries();
      _entries.sort((a, b) => b.anfrageDatum.compareTo(a.anfrageDatum));
      sortColumnIndex = 0;
      sortAscending = false;
      notifyListeners();
    } catch (e) {
      print("Fehler beim Laden der CRM-Daten: $e");
    }
  }

  void sortBy<T>(int columnIndex, Comparable<T> Function(CrmEntry e) getField, bool ascending) {
    sortColumnIndex = columnIndex;
    sortAscending = ascending;
    _entries.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
    });
    notifyListeners();
  }

  void toggleErledigt(String id, bool erledigt) {
    final entry = _entries.firstWhere((e) => e.id == id);
    entry.erledigt = erledigt;
    notifyListeners();
    // Optional: API-Patch call
  }
}

class CRMOverviewPage extends StatefulWidget {
  final ApiService apiService;
  const CRMOverviewPage({Key? key, required this.apiService}) : super(key: key);

  @override
  _CRMOverviewPageState createState() => _CRMOverviewPageState();
}

class _CRMOverviewPageState extends State<CRMOverviewPage> {
  WebSocketChannel? _channel;
  DateTimeRange? _selectedDateRange;

  bool _initialized = false; // Damit loadEntries & WS nur einmal starten

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      final provider = Provider.of<CrmEntryProvider>(context, listen: false);
      provider.loadEntries(widget.apiService);
      _connectToCrmWebSocket();
      _initialized = true;
    }
  }

  void _connectToCrmWebSocket() {
    if (_channel != null) return; // Verhindere Mehrfachverbindungen

    final token = widget.apiService.accessToken;
    if (token == null) {
      print("❌ Kein Token für WebSocket");
      return;
    }

    final uri = Uri.parse('ws://iqmedix.cloud:8000/ws/crm?token=$token');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        try {
          final data = json.decode(message);
          print("📥 CRM-Event: $data");
          final event = data['event'];
          if (event == 'crm_created' || event == 'crm_updated') {
            final provider = Provider.of<CrmEntryProvider>(context, listen: false);
            provider.loadEntries(widget.apiService);
          }
        } catch (e) {
          print("❌ Fehler beim Parsen der CRM WebSocket Nachricht: $e");
        }
      },
      onError: (error) {
        print("❌ WebSocket Fehler: $error");
      },
      onDone: () {
        print("🔌 WebSocket Verbindung geschlossen");
      },
    );
  }

  @override
  void dispose() {
    _channel?.sink.close(status.normalClosure);
    super.dispose();
  }

  void _showFilterDialog() {
    DateTimeRange? tempRange = _selectedDateRange;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Datum filtern'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: ctx,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange: tempRange,
                  );
                  if (picked != null) setStateDialog(() => tempRange = picked);
                },
                child: Text(tempRange == null
                    ? 'Datum auswählen'
                    : '${tempRange!.start.day}.${tempRange!.start.month}.${tempRange!.start.year} – ${tempRange!.end.day}.${tempRange!.end.month}.${tempRange!.end.year}'),
              ),
              if (tempRange != null)
                TextButton(
                  onPressed: () {
                    Provider.of<CrmEntryProvider>(context, listen: false).selectedDateRange = null;
                    setState(() => _selectedDateRange = null);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Zurücksetzen'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            TextButton(
              onPressed: () {
                Provider.of<CrmEntryProvider>(context, listen: false).selectedDateRange = tempRange;
                setState(() => _selectedDateRange = tempRange);
                Navigator.pop(ctx);
              },
              child: const Text('Anwenden'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM Übersicht'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Suche...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                Provider.of<CrmEntryProvider>(context, listen: false).searchText = value;
              },
            ),
          ),
        ),
      ),
      body: const CrmDataTableWrapper(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CrmEntryEditForm(
                currentUser: widget.apiService.loggedInUser ?? 'Unbekannt',
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CrmDataTableWrapper extends StatelessWidget {
  const CrmDataTableWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CrmEntryProvider>(context);

    final filteredEntries = provider.filteredEntries;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Theme(
              data: Theme.of(context).copyWith(
                dataTableTheme: const DataTableThemeData(
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 144,
                  headingRowHeight: 44,
                  horizontalMargin: 4,
                  columnSpacing: 8,
                ),
              ),
              child: PaginatedDataTable(
                columnSpacing: 8,
                rowsPerPage: 10,
                sortColumnIndex: provider.sortColumnIndex,
                sortAscending: provider.sortAscending,
                columns: _buildColumns(provider),
                source: CrmDataSource(filteredEntries, context),
              ),
            ),
          ),
        );
      },
    );
  }

  List<DataColumn> _buildColumns(CrmEntryProvider provider) {
    return [
      DataColumn(label: const Text('Anfrage'), onSort: (i, a) => provider.sortBy(i, (e) => e.anfrageDatum, a)),
      DataColumn(label: const Text('Anrede'), onSort: (i, a) => provider.sortBy(i, (e) => e.titel, a)),
      DataColumn(label: const Text('Vorname'), onSort: (i, a) => provider.sortBy(i, (e) => e.vorname, a)),
      DataColumn(label: const Text('Nachname'), onSort: (i, a) => provider.sortBy(i, (e) => e.nachname, a)),
      DataColumn(label: const Text('Adresse'), onSort: (i, a) => provider.sortBy(i, (e) => e.adresse, a)),
      DataColumn(label: const Text('E-Mail'), onSort: (i, a) => provider.sortBy(i, (e) => e.email, a)),
      DataColumn(label: const Text('Mobil'), onSort: (i, a) => provider.sortBy(i, (e) => e.mobil, a)),
      DataColumn(label: const Text('Festnetz'), onSort: (i, a) => provider.sortBy(i, (e) => e.festnetz, a)),
      DataColumn(label: const Text('Status'), onSort: (i, a) => provider.sortBy(i, (e) => e.status, a)),
      DataColumn(label: const Text('Erledigt')),
      DataColumn(label: const Text('Aktionen')),
    ];
  }
}

class CrmDataSource extends DataTableSource {
  final List<CrmEntry> entries;
  final BuildContext context;

  CrmDataSource(this.entries, this.context);

  @override
  DataRow getRow(int index) {
    if (index >= entries.length) return const DataRow(cells: []);

    final entry = entries[index];

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text('${entry.anfrageDatum.day}.${entry.anfrageDatum.month}.${entry.anfrageDatum.year}')),
        DataCell(Text(entry.titel)),
        DataCell(Text(entry.vorname)),
        DataCell(Text(entry.nachname)),
        DataCell(Text(entry.adresse)),
        DataCell(Text(entry.email)),
        DataCell(Text(entry.mobil)),
        DataCell(Text(entry.festnetz)),
        DataCell(Text(entry.status)),
        DataCell(
          Checkbox(
            value: entry.erledigt,
            onChanged: (value) {
              if (value == null) return;
              final provider = Provider.of<CrmEntryProvider>(context, listen: false);
              provider.toggleErledigt(entry.id, value);
            },
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Bearbeiten',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CrmEntryEditForm(currentUser: 'Unbekannt', existingEntry: entry),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Löschen',
                onPressed: () {
                  // TODO: Lösch-Logik ergänzen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Löschen nicht implementiert')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.note_add),
                tooltip: 'Notiz aus CRM erstellen',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FormPage(fromCrmEntry: entry),
                    ),
                  );
                },
              )

            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => entries.length;

  @override
  int get selectedRowCount => 0;
}
