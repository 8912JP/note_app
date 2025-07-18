import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'crm_entry.dart'; // dein CRMEntry Model
import 'api_service.dart';
import 'crm_entry_edit_form.dart';

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
        appBar: AppBar(
          title: const Text('CRM Übersicht'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                // TODO: Filterdialog öffnen
              },
            ),
          ],
        ),
        body: const CrmDataTableWrapper(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // TODO: Neuen Eintrag erstellen
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class CrmDataTableWrapper extends StatelessWidget {
  const CrmDataTableWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CrmEntryProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Theme(
              data: Theme.of(context).copyWith(
                dataTableTheme: DataTableThemeData(
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 144, // max 3× Standardhöhe
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
                source: CrmDataSource(provider.filteredEntries, context),
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
      DataColumn(label: const Text('Typ'), onSort: (i, a) => provider.sortBy(i, (e) => e.typ ?? '-', a)),
      DataColumn(label: const Text('Stadium'), onSort: (i, a) => provider.sortBy(i, (e) => e.stadium, a)),
      DataColumn(label: const Text('Krankheitsstatus'), onSort: (i, a) => provider.sortBy(i, (e) => e.krankheitsstatus.length, a)),
      DataColumn(label: const Text('ToDos'), onSort: (i, a) => provider.sortBy(i, (e) => e.todos.length, a)),
      DataColumn(label: const Text('Bearbeiter'), onSort: (i, a) => provider.sortBy(i, (e) => e.bearbeiter, a)),
      DataColumn(label: const Text('Kontaktquelle'), onSort: (i, a) => provider.sortBy(i, (e) => e.kontaktquelle, a)),
      DataColumn(label: const Text('Status'), onSort: (i, a) => provider.sortBy(i, (e) => e.status, a)),
      DataColumn(label: const Text('Erledigt'), onSort: (i, a) => provider.sortBy(i, (e) => e.erledigt.toString(), a)),
      DataColumn(label: const Text('Wiedervorlage'), onSort: (i, a) => provider.sortBy(i, (e) => e.wiedervorlage ?? DateTime(1900), a)),
      const DataColumn(label: Text('Aktionen')),
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
    final e = entries[index];

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(_wrapText(_formatDate(e.anfrageDatum))),
        DataCell(_wrapText(e.titel)),
        DataCell(_wrapText(e.vorname)),
        DataCell(_wrapText(e.nachname)),
        DataCell(_wrapText(e.adresse)),
        DataCell(_wrapText(e.email)),
        DataCell(_wrapText(e.mobil)),
        DataCell(_wrapText(e.festnetz)),
        DataCell(_wrapText(e.typ ?? '-')),
        DataCell(_wrapText(e.stadium)),
        DataCell(_wrapText(e.krankheitsstatus)),
        DataCell(_wrapText(e.todoSummary)),
        DataCell(_wrapText(e.bearbeiter)),
        DataCell(_wrapText(e.kontaktquelle)),
        DataCell(_wrapText(e.status)),
        DataCell(Checkbox(
          value: e.erledigt,
          onChanged: (val) {
            Provider.of<CrmEntryProvider>(context, listen: false).toggleErledigt(e.id, val ?? false);
          },
        )),
        DataCell(_wrapText(_formatDate(e.wiedervorlage))),
        DataCell(Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
               Navigator.of(context).push(
               MaterialPageRoute(
                builder: (_) => CrmEntryEditForm(
                  currentUser: 'Dr. Müller', // Hier sollte dein eingeloggter Benutzer stehen
                  // Falls du später bestehende Daten übergeben willst:
                  // initialEntry: entry,
      ),
    ),
  );
},
            ),
          ],
        )),
      ],
    );
  }

  static Widget _wrapText(String text, {double minWidth = 100, double maxWidth = 240, int maxLines = 6}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        maxLines: maxLines,
        style: const TextStyle(height: 1.4),
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


// Dummy-Daten zum Testen
final dummyData = List.generate(
  50,
  (index) => CrmEntry(
    id: 'id_$index',
    anfrageDatum: DateTime.now().subtract(Duration(days: index * 2)),
    titel: index % 2 == 0 ? 'Herr' : 'Frau',
    vorname: 'Vorname$index',
    nachname: 'Nachname$index',
    adresse: 'Musterstraße $index, Stadt',
    email: 'email$index@example.com',
    mobil: '+49123456789$index',
    festnetz: '+4901234567$index',
    krankheitsstatus: index % 3 == 0
        ? 'Chronische Krankheit, benötigt Unterstützung'
        : 'Gesund',
    todos: List.generate(
      (index % 3) + 1,
      (i) => ToDoItem(text: 'Aufgabe ${i + 1}', done: i % 2 == 0),
    ),
    status: index % 2 == 0 ? 'Neu' : 'In Bearbeitung',
    bearbeiter: 'Mitarbeiter ${index % 5}',
    wiedervorlage: index % 4 == 0 ? DateTime.now().add(Duration(days: index)) : null,
    typ: 'Privat',
    stadium: 'Interessent',
    kontaktquelle: 'Website',
  ),
);
