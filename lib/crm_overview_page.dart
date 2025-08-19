import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer';

import 'crm_entry.dart';
import 'api_service.dart';
import 'crm_entry_edit_form.dart';
import 'form_page.dart';
import 'note.dart';
import 'websocket_manager.dart';

class CrmEntryProvider extends ChangeNotifier {
  List<CrmEntry> _entries = [];
  String _searchText = '';
  DateTimeRange? _selectedDateRange;
  String? _selectedRolle;
  String? _selectedBearbeiter;
  String? _selectedStatus;
  DateTimeRange? _selectedWiedervorlageRange;

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

  set selectedRolle(String? value) {
    _selectedRolle = value;
    notifyListeners();
  }
  set selectedBearbeiter(String? value) {
    _selectedBearbeiter = value;
    notifyListeners();
  }
  set selectedStatus(String? value) {
    _selectedStatus = value;
    notifyListeners();
  }
  set selectedWiedervorlageRange(DateTimeRange? value) {
    _selectedWiedervorlageRange = value;
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
      if (_selectedRolle != null && _selectedRolle!.isNotEmpty && e.rolle != _selectedRolle) return false;
      if (_selectedBearbeiter != null && _selectedBearbeiter!.isNotEmpty && e.bearbeiter != _selectedBearbeiter) return false;
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty && e.status != _selectedStatus) return false;
      if (_selectedWiedervorlageRange != null) {
        if (e.wiedervorlage == null || e.wiedervorlage!.isBefore(_selectedWiedervorlageRange!.start) || e.wiedervorlage!.isAfter(_selectedWiedervorlageRange!.end)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> loadEntries(ApiService apiService) async {
    try {
      _entries = await apiService.fetchCrmEntries();
      // Backend sortiert bereits nach anfrage_datum, aber wir sortieren nochmal zur Sicherheit
      _entries.sort((a, b) {
        final aDate = a.anfrageDatum ?? DateTime(1900);
        final bDate = b.anfrageDatum ?? DateTime(1900);
        final dateComparison = bDate.compareTo(aDate);
        if (dateComparison != 0) return dateComparison;
        // Bei gleichem Datum nach ID sortieren (neueste zuerst)
        return b.id.compareTo(a.id);
      });
      sortColumnIndex = 0;
      sortAscending = false;
      notifyListeners();
      
      // Aktualisiere alle Tracking-Icons nach dem Laden
      _updateAllTrackingIcons();
    } catch (e) {
      log("Fehler beim Laden der CRM-Daten: $e");
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
  CRMOverviewPageState createState() => CRMOverviewPageState();
}

class CRMOverviewPageState extends State<CRMOverviewPage> {
  void Function(Map<String, dynamic> data)? _notesWsListener;
  DateTimeRange? _selectedDateRange;

  bool _initialized = false; // Damit loadEntries & WS nur einmal starten

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      final provider = Provider.of<CrmEntryProvider>(context, listen: false);
      provider.loadEntries(widget.apiService);
      _registerSharedWebSocketListener();
      _initialized = true;
    }
  }

  void _registerSharedWebSocketListener() {
    // Initialisiere WebSocket-Manager und registriere CRM-Updater
    WebSocketManager().initialize();
    WebSocketManager().registerCrmUpdater(() {
      if (mounted) {
        final provider = Provider.of<CrmEntryProvider>(context, listen: false);
        provider.loadEntries(widget.apiService);
      }
    });
    
    // Debug: Zeige WebSocket-Status
    WebSocketManager().testWebSocketConnection();
  }

  @override
  void dispose() {
    // Entferne vom WebSocket-Manager
    WebSocketManager().unregisterCrmUpdater(() {
      if (mounted) {
        final provider = Provider.of<CrmEntryProvider>(context, listen: false);
        provider.loadEntries(widget.apiService);
      }
    });
    
    super.dispose();
  }

  void showFilterDialog() {
    final provider = Provider.of<CrmEntryProvider>(context, listen: false);
    DateTimeRange? tempRange = provider._selectedDateRange;
    String? tempRolle = provider._selectedRolle;
    String? tempBearbeiter = provider._selectedBearbeiter;
    String? tempStatus = provider._selectedStatus;
    DateTimeRange? tempWiedervorlage = provider._selectedWiedervorlageRange;
    final rollen = provider._entries.map((e) => e.rolle ?? '').toSet().where((r) => r.isNotEmpty).toList();
    final bearbeiter = provider._entries.map((e) => e.bearbeiter ?? '').toSet().where((b) => b.isNotEmpty).toList();
    final statusList = provider._entries.map((e) => e.status ?? '').toSet().where((s) => s.isNotEmpty).toList();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Filter'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Rolle'),
                  value: tempRolle,
                  items: [const DropdownMenuItem(value: '', child: Text('Alle'))] + rollen.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setStateDialog(() => tempRolle = val),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Bearbeiter'),
                  value: tempBearbeiter,
                  items: [const DropdownMenuItem(value: '', child: Text('Alle'))] + bearbeiter.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (val) => setStateDialog(() => tempBearbeiter = val),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Status'),
                  value: tempStatus,
                  items: [const DropdownMenuItem(value: '', child: Text('Alle'))] + statusList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setStateDialog(() => tempStatus = val),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: tempWiedervorlage,
                    );
                    if (!context.mounted) return;
                    if (picked != null) setStateDialog(() => tempWiedervorlage = picked);
                  },
                  child: Text(tempWiedervorlage == null ? 'Wiedervorlage-Datum wählen' : '${tempWiedervorlage!.start.day}.${tempWiedervorlage!.start.month}.${tempWiedervorlage!.start.year} – ${tempWiedervorlage!.end.day}.${tempWiedervorlage!.end.month}.${tempWiedervorlage!.end.year}'),
                ),
                if (tempWiedervorlage != null)
                  TextButton(
                    onPressed: () => setStateDialog(() => tempWiedervorlage = null),
                    child: const Text('Wiedervorlage zurücksetzen'),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: tempRange,
                    );
                    if (!context.mounted) return;
                    if (picked != null) setStateDialog(() => tempRange = picked);
                  },
                  child: Text(tempRange == null ? 'Anfragedatum wählen' : '${tempRange!.start.day}.${tempRange!.start.month}.${tempRange!.start.year} – ${tempRange!.end.day}.${tempRange!.end.month}.${tempRange!.end.year}'),
                ),
                if (tempRange != null)
                  TextButton(
                    onPressed: () => setStateDialog(() => tempRange = null),
                    child: const Text('Anfragedatum zurücksetzen'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            TextButton(
              onPressed: () {
                provider.selectedRolle = tempRolle == '' ? null : tempRolle;
                provider.selectedBearbeiter = tempBearbeiter == '' ? null : tempBearbeiter;
                provider.selectedStatus = tempStatus == '' ? null : tempStatus;
                provider.selectedWiedervorlageRange = tempWiedervorlage;
                provider.selectedDateRange = tempRange;
                setState(() {});
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
            onPressed: showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sort_by_alpha),
            tooltip: 'Nach Status "Offen", "Auto Email" und Datum sortieren',
            onPressed: () {
              final provider = Provider.of<CrmEntryProvider>(context, listen: false);
              provider._entries.sort((a, b) {
                // Zuerst nach Status 'Offen' und 'Auto Email' (beide nach oben), dann nach anfrageDatum absteigend
                final aStatus = (a.status ?? '').toLowerCase();
                final bStatus = (b.status ?? '').toLowerCase();
                final aIsOffen = aStatus == 'offen';
                final bIsOffen = bStatus == 'offen';
                final aIsAutoEmail = aStatus == 'auto email';
                final bIsAutoEmail = bStatus == 'auto email';
                
                // Priorität: Offen > Auto Email > andere
                if (aIsOffen && !bIsOffen) return -1;
                if (!aIsOffen && bIsOffen) return 1;
                if (aIsAutoEmail && !bIsAutoEmail && !bIsOffen) return -1;
                if (!aIsAutoEmail && bIsAutoEmail && !aIsOffen) return 1;
                
                final aDate = a.anfrageDatum ?? DateTime(1900);
                final bDate = b.anfrageDatum ?? DateTime(1900);
                return bDate.compareTo(aDate);
              });
              provider.notifyListeners();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: () async {
              final provider = Provider.of<CrmEntryProvider>(context, listen: false);
              await provider.loadEntries(widget.apiService);
              // Markiere CRM als gesehen (entferne rote Punkte)
              widget.apiService.notificationService.markCrmAsSeen();
              // Aktualisiere alle Tracking-Icons
              _updateAllTrackingIcons();
            },
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
                showCheckboxColumn: false,
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
      DataColumn(label: const Text('Rolle'), onSort: (i, a) => provider.sortBy(i, (e) => e.rolle ?? '', a)),
      DataColumn(label: const Text('Adresse'), onSort: (i, a) => provider.sortBy(i, (e) => [e.strasse ?? '', e.hausnummer ?? '', e.plz ?? '', e.ort ?? '', e.land ?? ''].where((v) => v.isNotEmpty).join(' '), a)),
      DataColumn(label: const Text('E-Mail'), onSort: (i, a) => provider.sortBy(i, (e) => e.email ?? '', a)),
      DataColumn(label: const Text('Mobil'), onSort: (i, a) => provider.sortBy(i, (e) => e.mobil ?? '', a)),
      DataColumn(label: const Text('Festnetz'), onSort: (i, a) => provider.sortBy(i, (e) => e.festnetz ?? '', a)),
      DataColumn(label: const Text('Typ / Stadium'), onSort: (i, a) => provider.sortBy(i, (e) => ((e.typ ?? '') + (e.stadium ?? '')), a)),
      DataColumn(label: const Text('Kommentar'), onSort: (i, a) => provider.sortBy(i, (e) => (e.krankheitsstatus ?? '').length, a)),
      DataColumn(label: const Text('Infos'), onSort: (i, a) => provider.sortBy(i, (e) => e.infos ?? '', a)),
      DataColumn(label: const Text('Nachricht'), onSort: (i, a) => provider.sortBy(i, (e) => e.nachricht ?? '', a)),
      DataColumn(label: const Text('ToDos'), onSort: (i, a) => provider.sortBy(i, (e) => e.todos.length, a)),
      DataColumn(label: const Text('Bearbeiter'), onSort: (i, a) => provider.sortBy(i, (e) => e.bearbeiter ?? '', a)),
      DataColumn(label: const Text('Kontaktquelle'), onSort: (i, a) => provider.sortBy(i, (e) => e.kontaktquelle ?? '', a)),
      DataColumn(label: const Text('Status'), onSort: (i, a) => provider.sortBy(i, (e) => e.status ?? '', a)),
      DataColumn(label: const Text('Wiedervorlage'), onSort: (i, a) => provider.sortBy(i, (e) => e.wiedervorlage ?? DateTime(1900), a)),
      DataColumn(label: const Text('Verfolgung')),
      const DataColumn(label: Text(' ')),
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
        if (!context.mounted) return;
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
    final isCompleted = (e.status ?? '').toLowerCase() == 'einsender' || (e.status ?? '').toLowerCase() == 'nicht einsender';
    
    return DataRow.byIndex(
      index: index,
      onSelectChanged: (selected) {
        if (selected == true) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CrmEntryEditForm(
                existingEntry: e,
                currentUser: ApiService().loggedInUser ?? 'Unbekannt',
              ),
            ),
          );
        }
      },

      cells: [
        DataCell(
          Row(
            children: [
              if (isCompleted)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                ),
              Expanded(child: _wrapText(_formatDate(e.anfrageDatum))),
            ],
          ),
        ),
        DataCell(_wrapText(e.titel ?? '')),
        DataCell(_wrapText(e.vorname ?? '')),
        DataCell(_wrapText(e.nachname ?? '')),
        DataCell(_wrapText(e.rolle ?? '')),
        DataCell(_wrapText(adresse)),
        DataCell(_wrapText(e.email ?? '')),
        DataCell(_wrapText(e.mobil ?? '')),
        DataCell(_wrapText(e.festnetz ?? '')),
        DataCell(_wrapText(
          ((e.typ ?? '').isNotEmpty && (e.stadium ?? '').isNotEmpty)
            ? '${e.typ} / ${e.stadium}'
            : (e.typ ?? '') + (e.stadium ?? ''),
        )),
        DataCell(_wrapText(e.krankheitsstatus ?? '')),
        DataCell(_wrapText(e.infos ?? '')),
        DataCell(_wrapText(e.nachricht ?? '')),
        DataCell(_wrapText(e.todoSummary)),
        DataCell(_wrapText(e.bearbeiter ?? '')),
        DataCell(_wrapText(e.kontaktquelle ?? '')),
        DataCell(_wrapText(e.status ?? '')),
        DataCell(
          Row(
            children: [
              Text(
                _formatDate(e.wiedervorlage),
                style: TextStyle(
                  color: _isDueDate(e.wiedervorlage) ? Colors.red : Colors.black,
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
        // Infos und Nachricht jetzt vor Verfolgung und Aktionen:
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CrmEntryEditForm(
                      existingEntry: e,
                      currentUser: ApiService().loggedInUser ?? 'Unbekannt',
                    ),
                  ),
                );
              } else if (value == 'note') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FormPage(fromCrmEntry: e),
                  ),
                );
              } else if (value == 'delete') {
                _deleteCrmEntry(context, e);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Bearbeiten'),
                ),
              ),
              const PopupMenuItem(
                value: 'note',
                child: ListTile(
                  leading: Icon(Icons.note_add),
                  title: Text('Notiz aus CRM erstellen'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Löschen'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _wrapText(String text, {double minWidth = 0, double? maxWidth, int maxLines = 6, TextStyle? textStyle}) {
    final screenWidth = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    double effectiveMaxWidth;
    double effectiveFontSize;
    if (screenWidth < 1500) {
      effectiveMaxWidth = 70;
      effectiveFontSize = 10.0;
    } else if (screenWidth < 2000) {
      effectiveMaxWidth = 90;
      effectiveFontSize = 11.0;
    } else {
      effectiveMaxWidth = maxWidth ?? 170;
      effectiveFontSize = 14.0;
    }
    final effectiveMinWidth = minWidth.clamp(0, effectiveMaxWidth).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: effectiveMinWidth, maxWidth: effectiveMaxWidth),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        maxLines: maxLines,
        style: (textStyle ?? const TextStyle(height: 1.4)).copyWith(fontSize: effectiveFontSize),
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

// Globale Liste aller aktiven Tracking-Icons für manuelle Updates
final Set<_TrackingIconState> _activeTrackingIcons = <_TrackingIconState>{};

// Globale Funktion um alle Tracking-Icons zu aktualisieren
void _updateAllTrackingIcons() {
  for (final icon in _activeTrackingIcons) {
    if (icon.mounted && !icon._disposed) {
      icon._fetchNote();
    }
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
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _fetchNote();
    _activeTrackingIcons.add(this);
    
    // Initialisiere WebSocket-Manager und registriere Tracking-Icon Updater
    WebSocketManager().initialize();
    WebSocketManager().registerTrackingIconUpdater(_fetchNote);
    
    // Debug: Zeige WebSocket-Status für Tracking-Icon
    print("🔍 Tracking-Icon initialisiert für ${widget.trackingType} (CRM-ID: ${widget.crmEntryId})");
  }

  @override
  void dispose() {
    _disposed = true;
    _activeTrackingIcons.remove(this);
    
    // Entferne vom WebSocket-Manager
    WebSocketManager().unregisterTrackingIconUpdater(_fetchNote);
    
    super.dispose();
  }

  Future<void> _fetchNote() async {
    if (!mounted || _disposed) return;
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
      if (mounted && !_disposed) setState(() => _note = note);
    } catch (_) {
      if (mounted && !_disposed) setState(() => _note = null);
    } finally {
      if (mounted && !_disposed) setState(() => _loading = false);
    }
  }

  Color get _iconColor {
    if (_note == null) return widget.colorIfNone;
    if (_note!.isDone) return widget.colorIfDone;
    return widget.colorIfOpen;
  }

  void _onTap() async {
    final note = _note;
    if (!mounted) return;
    if (note == null) {
      // Neue Notiz anlegen
      final result = await Navigator.of(context).push<Note>(
        MaterialPageRoute(
          builder: (_) => FormPage(
            fromCrmEntry: widget.crmEntry,
            existingNote: null,
            trackingType: widget.trackingType,
          ),
        ),
      );
      if (result != null) {
        // Nach Rückkehr immer neu laden, damit Status/Farbe stimmt
        await _fetchNote();
      }
    } else {
      // Notiz bearbeiten
      final result = await Navigator.of(context).push<Note>(
        MaterialPageRoute(
          builder: (_) => FormPage(
            fromCrmEntry: widget.crmEntry,
            existingNote: note,
            trackingType: widget.trackingType,
          ),
        ),
      );
      if (result != null) {
        // Nach Rückkehr immer neu laden, damit Status/Farbe stimmt
        await _fetchNote();
      }
    }
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
