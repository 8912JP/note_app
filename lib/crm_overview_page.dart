import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';

import 'crm_entry.dart';
import 'api_service.dart';
import 'crm_entry_edit_form.dart';
import 'form_page.dart';
import 'note.dart';

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
      final adresse = [e.strasse ?? '', e.hausnummer ?? '', e.plz ?? '', e.ort ?? '', e.land ?? ''].where((v) => v.isNotEmpty).join(' ');
      final text = '${e.vorname ?? ''} ${e.nachname ?? ''} ${e.email ?? ''} $adresse'.toLowerCase();
      if (_searchText.isNotEmpty && !text.contains(_searchText.toLowerCase())) {
        return false;
      }
      if (_selectedDateRange != null) {
        if ((e.anfrageDatum?.isBefore(_selectedDateRange!.start) ?? false) ||
            (e.anfrageDatum?.isAfter(_selectedDateRange!.end) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> loadEntries(ApiService apiService) async {
    try {
      _entries = await apiService.fetchCrmEntries();
      _entries.sort((a, b) => (b.anfrageDatum ?? DateTime(1900)).compareTo(a.anfrageDatum ?? DateTime(1900)));
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
    final index = _entries.indexWhere((e) => e.id == id);
    if (index != -1) {
      final old = _entries[index];
      _entries[index] = CrmEntry(
        id: old.id,
        anfrageDatum: old.anfrageDatum,
        titel: old.titel,
        vorname: old.vorname,
        nachname: old.nachname,
        adresse: old.adresse,
        email: old.email,
        mobil: old.mobil,
        festnetz: old.festnetz,
        krankheitsstatus: old.krankheitsstatus,
        todos: old.todos,
        status: old.status,
        bearbeiter: old.bearbeiter,
        wiedervorlage: old.wiedervorlage,
        typ: old.typ,
        stadium: old.stadium,
        kontaktquelle: old.kontaktquelle,
        nachricht: old.nachricht,
        infos: old.infos,
        erledigt: erledigt,
      );
      notifyListeners();
    }
    // Optional: API-Patch call
  }
}

class CRMOverviewPage extends StatefulWidget {
  final ApiService apiService;
  const CRMOverviewPage({super.key, required this.apiService});

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
  const CrmDataTableWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CrmEntryProvider>(context);
    final filteredEntries = provider.filteredEntries;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Theme(
              data: Theme.of(context).copyWith(
                dataTableTheme: const DataTableThemeData(
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 94,
                  headingRowHeight: 44,
                  horizontalMargin: 8,
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
      DataColumn(label: const Text('Anfrage'), onSort: (i, a) => provider.sortBy(i, (e) => e.anfrageDatum ?? DateTime(1900), a)),
      DataColumn(label: const Text('Anrede'), onSort: (i, a) => provider.sortBy(i, (e) => e.titel ?? '', a)),
      DataColumn(label: const Text('Vorname'), onSort: (i, a) => provider.sortBy(i, (e) => e.vorname ?? '', a)),
      DataColumn(label: const Text('Nachname'), onSort: (i, a) => provider.sortBy(i, (e) => e.nachname ?? '', a)),
      DataColumn(label: const Text('Adresse'), onSort: (i, a) => provider.sortBy(i, (e) => [e.strasse ?? '', e.hausnummer ?? '', e.plz ?? '', e.ort ?? '', e.land ?? ''].where((v) => v.isNotEmpty).join(' '), a)),
      DataColumn(label: const Text('E-Mail'), onSort: (i, a) => provider.sortBy(i, (e) => e.email ?? '', a)),
      DataColumn(label: const Text('Mobil'), onSort: (i, a) => provider.sortBy(i, (e) => e.mobil ?? '', a)),
      DataColumn(label: const Text('Festnetz'), onSort: (i, a) => provider.sortBy(i, (e) => e.festnetz ?? '', a)),
      DataColumn(label: const Text('Typ'), onSort: (i, a) => provider.sortBy(i, (e) => e.typ ?? '-', a)),
      DataColumn(label: const Text('Stadium'), onSort: (i, a) => provider.sortBy(i, (e) => e.stadium ?? '', a)),
      DataColumn(label: const Text('Krankheitsstatus'), onSort: (i, a) => provider.sortBy(i, (e) => (e.krankheitsstatus ?? '').length, a)),
      DataColumn(label: const Text('ToDos'), onSort: (i, a) => provider.sortBy(i, (e) => e.todos.length, a)),
      DataColumn(label: const Text('Bearbeiter'), onSort: (i, a) => provider.sortBy(i, (e) => e.bearbeiter ?? '', a)),
      DataColumn(label: const Text('Kontaktquelle'), onSort: (i, a) => provider.sortBy(i, (e) => e.kontaktquelle ?? '', a)),
      DataColumn(label: const Text('Status'), onSort: (i, a) => provider.sortBy(i, (e) => e.status ?? '', a)),
      DataColumn(label: const Text('Wiedervorlage'), onSort: (i, a) => provider.sortBy(i, (e) => e.wiedervorlage ?? DateTime(1900), a)),
      // Verfolgungsspalte jetzt vor Aktionen:
      DataColumn(label: const Text('Verfolgung')),
      const DataColumn(label: Text('Aktionen')),
      DataColumn(label: const Text('Infos'), onSort: (i, a) => provider.sortBy(i, (e) => e.infos ?? '', a)),
      DataColumn(label: const Text('Nachricht'), onSort: (i, a) => provider.sortBy(i, (e) => e.nachricht ?? '', a)),
    ];
  }
}

class CrmDataSource extends DataTableSource {
  final List<CrmEntry> entries;
  final BuildContext context;

  CrmDataSource(this.entries, this.context);

  void _deleteCrmEntry(BuildContext context, CrmEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: const Text('Möchtest du diesen CRM-Eintrag wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService().deleteCrmEntry(entry.id);
        Provider.of<CrmEntryProvider>(context, listen: false).loadEntries(ApiService());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eintrag gelöscht')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Löschen: $e')),
        );
      }
    }
  }

  @override
  DataRow getRow(int index) {
    if (index >= entries.length) return const DataRow(cells: []);
    final e = entries[index];

    final adresse = [e.strasse ?? '', e.hausnummer ?? '', e.plz ?? '', e.ort ?? '', e.land ?? ''].where((v) => v.isNotEmpty).join(' ');
    return DataRow.byIndex(
      index: index,
      // Kein spezieller Hintergrund mehr für abgeschlossene Zeilen
      cells: [
        DataCell(_wrapText(
          _formatDate(e.anfrageDatum),
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.titel ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.vorname ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.nachname ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(adresse,
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.email ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.mobil ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.festnetz ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.typ ?? '-',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.stadium ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.krankheitsstatus ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.todoSummary,
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.bearbeiter ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.kontaktquelle ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.status ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(
          Row(
            children: [
              Text(
                _formatDate(e.wiedervorlage),
                style: TextStyle(
                  color: (e.status ?? '').toLowerCase() == 'abgeschlossen'
                      ? Colors.grey
                      : (_isDueDate(e.wiedervorlage) ? Colors.red : Colors.black),
                  fontWeight: _isDueDate(e.wiedervorlage) ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (_isDueDate(e.wiedervorlage))
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                ),
            ],
          ),
        ),
        DataCell(
          Row(
            children: [
              _TrackingIcon(
                crmEntryId: e.id,
                trackingType: 'Kit',
                icon: Icons.inventory,
                colorIfNone: Colors.grey,
                colorIfOpen: Colors.amber,
                colorIfDone: Colors.green,
                context: context,
                crmEntry: e,
              ),
              const SizedBox(width: 8),
              _TrackingIcon(
                crmEntryId: e.id,
                trackingType: 'Abholung',
                icon: Icons.directions_car,
                colorIfNone: Colors.grey,
                colorIfOpen: Colors.amber,
                colorIfDone: Colors.green,
                context: context,
                crmEntry: e,
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CrmEntryEditForm(
                        existingEntry: e,
                        currentUser: ApiService().loggedInUser ?? 'Unbekannt',
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.note_add),
                tooltip: 'Notiz aus CRM erstellen',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FormPage(fromCrmEntry: e),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Löschen',
                onPressed: () => _deleteCrmEntry(context, e),
              ),
            ],
          ),
        ),
        DataCell(_wrapText(e.infos ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
        DataCell(_wrapText(e.nachricht ?? '',
          textStyle: (e.status ?? '').toLowerCase() == 'abgeschlossen'
              ? const TextStyle(color: Colors.grey)
              : null,
        )),
      ],
    );
  }

  static Widget _wrapText(String text, {double minWidth = 80, double maxWidth = 170, int maxLines = 6, TextStyle? textStyle}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        maxLines: maxLines,
        style: textStyle ?? const TextStyle(height: 1.4),
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => entries.length;

  @override
  int get selectedRowCount => 0;

  bool _isDueDate(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return !date.isAfter(today);
}
}

class _TrackingIcon extends StatefulWidget {
  final String crmEntryId;
  final String trackingType;
  final IconData icon;
  final Color colorIfNone;
  final Color colorIfOpen;
  final Color colorIfDone;
  final BuildContext context;
  final CrmEntry crmEntry;

  const _TrackingIcon({
    required this.crmEntryId,
    required this.trackingType,
    required this.icon,
    required this.colorIfNone,
    required this.colorIfOpen,
    required this.colorIfDone,
    required this.context,
    required this.crmEntry,
  });

  @override
  State<_TrackingIcon> createState() => _TrackingIconState();
}

class _TrackingIconState extends State<_TrackingIcon> {
  Note? _note;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchNote();
  }

  Future<void> _fetchNote() async {
    setState(() => _loading = true);
    try {
      final notes = await ApiService().fetchNotes();
      Note? note;
      try {
        note = notes.firstWhere(
          (n) => n.crmEntryId == widget.crmEntryId && n.trackingType == widget.trackingType,
        );
      } catch (_) {
        note = null;
      }
      setState(() => _note = note);
    } catch (_) {
      setState(() => _note = null);
    } finally {
      setState(() => _loading = false);
    }
  }

  Color get _iconColor {
    if (_note == null) return widget.colorIfNone;
    if (_note!.isDone) return widget.colorIfDone;
    return widget.colorIfOpen;
  }

  void _onTap() async {
    final note = _note;
    Note? result;
    if (note == null) {
      // Neue Notiz anlegen
      result = await Navigator.of(context).push<Note>(
        MaterialPageRoute(
          builder: (_) => FormPage(
            fromCrmEntry: widget.crmEntry,
            existingNote: null,
            trackingType: widget.trackingType,
          ),
        ),
      );
    } else {
      // Notiz bearbeiten
      result = await Navigator.of(context).push<Note>(
        MaterialPageRoute(
          builder: (_) => FormPage(
            fromCrmEntry: widget.crmEntry,
            existingNote: note,
            trackingType: widget.trackingType,
          ),
        ),
      );
    }
    // Nach Rückkehr immer neu laden, damit Status/Farbe stimmt
    await _fetchNote();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _loading
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(widget.icon, color: _iconColor),
      tooltip: widget.trackingType,
      onPressed: _onTap,
    );
  }
}
