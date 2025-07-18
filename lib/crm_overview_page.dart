import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';

class CrmEntry {
  final String id;
  final DateTime anfrageDatum;
  final String titel;
  final String vorname;
  final String nachname;
  final String adresse;
  final String email;
  final String mobil;
  final String festnetz;
  final String krankheitsstatus;
  final List<ToDoItem> todos;
  final String status;
  final String bearbeiter;
  final DateTime? wiedervorlage;
  bool erledigt;

  CrmEntry({
    required this.id,
    required this.anfrageDatum,
    required this.titel,
    required this.vorname,
    required this.nachname,
    required this.adresse,
    required this.email,
    required this.mobil,
    required this.festnetz,
    required this.krankheitsstatus,
    required this.todos,
    required this.status,
    required this.bearbeiter,
    required this.wiedervorlage,
    this.erledigt = false,
  });

  String get todoSummary =>
      todos.map((t) => '${t.done ? '✓' : '•'} ${t.text}').join(', ');
}

class ToDoItem {
  String text;
  bool done;

  ToDoItem({required this.text, this.done = false});
}

class CrmEntryProvider extends ChangeNotifier {
  List<CrmEntry> _entries = [];
  int sortColumnIndex = 0;
  bool sortAscending = true;

  List<CrmEntry> get filteredEntries => _entries;

  void loadEntries() {
    _entries = dummyData;
    notifyListeners();
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
  }
}

class CRMOverviewPage extends StatelessWidget {
  final ApiService apiService;

  const CRMOverviewPage({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CrmEntryProvider()..loadEntries(),
      child: Scaffold(
        appBar: AppBar(title: const Text('CRM Übersicht')),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: CrmDataTable(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // TODO: Eintrag hinzufügen
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class CrmDataTable extends StatelessWidget {
  const CrmDataTable({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CrmEntryProvider>(context);
    final entries = provider.filteredEntries;

return Theme(
  data: Theme.of(context).copyWith(
    dataTableTheme: DataTableThemeData(
      dataRowMinHeight: 72,        // doppelt so hoch wie vorher
      headingRowHeight: 44,
      horizontalMargin: 4,         // minimaler Rand links/rechts
      columnSpacing: 6,            // enge Spalten
    ),
  ),
      child: PaginatedDataTable(
        header: const Text('Kundenanfragen'),
        rowsPerPage: 10,
        sortColumnIndex: provider.sortColumnIndex,
        sortAscending: provider.sortAscending,
        columns: [
          DataColumn(label: const Text('Anfrage-Datum'), onSort: (i, asc) => provider.sortBy(i, (e) => e.anfrageDatum, asc)),
          DataColumn(label: const Text('Anrede'), onSort: (i, asc) => provider.sortBy(i, (e) => e.titel, asc)),
          DataColumn(label: const Text('Vorname'), onSort: (i, asc) => provider.sortBy(i, (e) => e.vorname.toLowerCase(), asc)),
          DataColumn(label: const Text('Nachname'), onSort: (i, asc) => provider.sortBy(i, (e) => e.nachname.toLowerCase(), asc)),
          DataColumn(label: const Text('Adresse'), onSort: (i, asc) => provider.sortBy(i, (e) => e.adresse.toLowerCase(), asc)),
          DataColumn(label: const Text('E-Mail'), onSort: (i, asc) => provider.sortBy(i, (e) => e.email.toLowerCase(), asc)),
          DataColumn(label: const Text('Mobil'), onSort: (i, asc) => provider.sortBy(i, (e) => e.mobil, asc)),
          DataColumn(label: const Text('Festnetz'), onSort: (i, asc) => provider.sortBy(i, (e) => e.festnetz, asc)),
          DataColumn(label: const Text('Krankheitsstatus'), onSort: (i, asc) => provider.sortBy(i, (e) => e.krankheitsstatus.length, asc)),
          DataColumn(label: const Text('ToDos'), onSort: (i, asc) => provider.sortBy(i, (e) => e.todos.length, asc)),
          DataColumn(label: const Text('Bearbeiter'), onSort: (i, asc) => provider.sortBy(i, (e) => e.bearbeiter.toLowerCase(), asc)),
          DataColumn(label: const Text('Status'), onSort: (i, asc) => provider.sortBy(i, (e) => e.status.toLowerCase(), asc)),
          DataColumn(label: const Text('Erledigt'), onSort: (i, asc) => provider.sortBy(i, (e) => e.erledigt.toString(), asc)),
          DataColumn(label: const Text('Wiedervorlage'), onSort: (i, asc) => provider.sortBy(i, (e) => e.wiedervorlage ?? DateTime(1900), asc)),
          const DataColumn(label: Text('Aktionen')),
        ],
        source: CrmDataSource(entries, context),
      ),
    );
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
        DataCell(_wrapText(_formatDate(entry.anfrageDatum))),
        DataCell(_wrapText(entry.titel)),
        DataCell(_wrapText(entry.vorname)),
        DataCell(_wrapText(entry.nachname)),
        DataCell(_wrapText(entry.adresse)),
        DataCell(_wrapText(entry.email)),
        DataCell(_wrapText(entry.mobil)),
        DataCell(_wrapText(entry.festnetz)),
        DataCell(_wrapText(entry.krankheitsstatus)),
        DataCell(_wrapText(entry.todoSummary)),
        DataCell(_wrapText(entry.bearbeiter)),
        DataCell(_wrapText(entry.status)),
        DataCell(Checkbox(
          value: entry.erledigt,
          onChanged: (val) {
            Provider.of<CrmEntryProvider>(context, listen: false)
                .toggleErledigt(entry.id, val ?? false);
          },
        )),
        DataCell(_wrapText(_formatDate(entry.wiedervorlage))),
        DataCell(Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: zur Bearbeitungsseite navigieren
              },
            ),
          ],
        )),
      ],
    );
  }

  static Widget _wrapText(String text, {double maxWidth = 160, int maxLines = 3}) {
  return ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: maxLines * 20.0, // z. B. 3 Zeilen à 20px
    ),
    child: Text(
      text,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, height: 1.3),
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
}

final List<CrmEntry> dummyData = [
  CrmEntry(
    id: '1',
    anfrageDatum: DateTime(2025, 6, 20),
    titel: 'Herr',
    vorname: 'Max',
    nachname: 'Mustermann',
    adresse: 'Musterstraße 1, 12345 Musterstadt',
    email: 'max@muster.de',
    mobil: '0123456789',
    festnetz: '0987654321',
    krankheitsstatus: 'Rückenschmerzen seit zwei Wochen. Keine Besserung trotz Medikation.',
    todos: [ToDoItem(text: 'Rückmeldung geben'), ToDoItem(text: 'Termin abstimmen')],
    status: 'Offen',
    bearbeiter: 'Dr. Müller',
    wiedervorlage: DateTime(2025, 7, 25),
    erledigt: false,
  ),
];