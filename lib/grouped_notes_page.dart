import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'note.dart';
import 'form_page.dart';
import 'api_service.dart';

class GroupedNotesPage extends StatefulWidget {
  final ApiService apiService;
  const GroupedNotesPage({super.key, required this.apiService});

  @override
  _GroupedNotesPageState createState() => _GroupedNotesPageState();
}

class _GroupedNotesPageState extends State<GroupedNotesPage> {
  late ApiService apiService;
  List<List<Note>> groupedNotes = [];
  Map<String, bool> expansionState = {};

  String _searchText = "";
  String _selectedStatus = "all";
  DateTimeRange? _selectedDateRange;
  List<String> _selectedLabelsFilter = [];

  @override
  void initState() {
    super.initState();
    apiService = widget.apiService;
    _loadNotes();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    apiService.connectToWebSocket(onEvent: (data) async {
      if (!mounted) return;

      final id = data['id']?.toString();
      switch (data['event']) {
        case 'note_updated':
        case 'note_created':
          if (id == null) return;
          final updated = await apiService.fetchNoteById(id);
          if (updated != null) _updateOrInsertNote(updated);
          break;
        case 'note_deleted':
          if (id == null) return;
          _removeNoteById(id);
          break;
      }
    });
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await apiService.fetchGroupedNotes();
      if (!mounted) return;
      setState(() {
        groupedNotes = notes;
        // Reset expansion state
        expansionState = {
          for (var g in notes) _groupKey(g.first): expansionState[_groupKey(g.first)] ?? false,
        };
      });
    } catch (e) {
      debugPrint('Fehler beim Laden: $e');
    }
  }

  String _groupKey(Note note) =>
      '${note.firstName}_${note.lastName}_${note.email}_${note.telephone}';

  void _updateOrInsertNote(Note note) {
    setState(() {
      _removeNoteById(note.id.toString(), updateOnly: true);
      final key = _groupKey(note);
      var group = groupedNotes.firstWhere(
        (g) => _groupKey(g.first) == key,
        orElse: () {
          groupedNotes.add([note]);
          expansionState[key] = true;
          return [note];
        },
      );
      if (!group.contains(note)) group.add(note);
    });
  }

  void _removeNoteById(String id, {bool updateOnly = false}) {
    setState(() {
      for (var group in groupedNotes) {
        group.removeWhere((note) => note.id.toString() == id);
      }
      groupedNotes.removeWhere((group) => group.isEmpty);
      if (!updateOnly) {
        expansionState.removeWhere(
          (key, _) => !groupedNotes.any((group) => _groupKey(group.first) == key),
        );
      }
    });
  }

  bool _applyFilters(Note note) {
    final text = "${note.firstName} ${note.lastName} ${note.noteText}".toLowerCase();
    if (_searchText.isNotEmpty && !text.contains(_searchText.toLowerCase())) return false;
    if (_selectedLabelsFilter.isNotEmpty &&
        !note.labels.any((l) => _selectedLabelsFilter.contains(l))) {
      return false;
    }
    if (_selectedStatus == "done" && !note.isDone) return false;
    if (_selectedStatus == "not_done" && note.isDone) return false;
    if (_selectedDateRange != null &&
        (note.createdAt.isBefore(_selectedDateRange!.start) ||
            note.createdAt.isAfter(_selectedDateRange!.end))) {
      return false;
    }
    return true;
  }

  void _showFilterDialog() {
    String tempStatus = _selectedStatus;
    List<String> tempLabels = List.from(_selectedLabelsFilter);
    DateTimeRange? tempDateRange = _selectedDateRange;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Filter'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                const Text('Status'),
                RadioListTile(
                  title: const Text('Alle'),
                  value: 'all',
                  groupValue: tempStatus,
                  onChanged: (v) => setStateDialog(() => tempStatus = v!),
                ),
                RadioListTile(
                  title: const Text('Erledigt'),
                  value: 'done',
                  groupValue: tempStatus,
                  onChanged: (v) => setStateDialog(() => tempStatus = v!),
                ),
                RadioListTile(
                  title: const Text('Nicht erledigt'),
                  value: 'not_done',
                  groupValue: tempStatus,
                  onChanged: (v) => setStateDialog(() => tempStatus = v!),
                ),
                const SizedBox(height: 10),
                const Text('Labels'),
                Wrap(
                  spacing: 6,
                  children: ['Dringend', 'Rückmeldung', 'Go!', 'UPS', 'Eilt nicht'].map((label) {
                    final selected = tempLabels.contains(label);
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (yes) {
                        setStateDialog(() {
                          yes ? tempLabels.add(label) : tempLabels.remove(label);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: tempDateRange,
                    );
                    if (picked != null) setStateDialog(() => tempDateRange = picked);
                  },
                  child: Text(tempDateRange == null
                      ? 'Datum auswählen'
                      : '${DateFormat.yMd().format(tempDateRange!.start)} – ${DateFormat.yMd().format(tempDateRange!.end)}'),
                ),
                if (tempDateRange != null)
                  TextButton(
                    onPressed: () => setStateDialog(() => tempDateRange = null),
                    child: const Text('Datum entfernen'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = tempStatus;
                  _selectedLabelsFilter = tempLabels;
                  _selectedDateRange = tempDateRange;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Anwenden'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDone(Note note) async {
    final updated = note.copyWith(isDone: !note.isDone);
    await apiService.updateNote(updated);
    // Lade die Notiz nach dem Update erneut vom Server, damit der Status sicher aktuell ist!
    final fresh = await apiService.fetchNoteById(updated.id.toString());
    if (fresh != null) _updateOrInsertNote(fresh);
  }

  Future<void> _editNote(Note note) async {
    final updated = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => FormPage(existingNote: note)),
    );
    if (updated != null) {
      await apiService.updateNote(updated);
      _updateOrInsertNote(updated);
    }
  }

  Future<void> _deleteNote(Note note) async {
    await apiService.deleteNote(note.id!);
    _removeNoteById(note.id.toString());
  }

  Future<void> _addNewNote() async {
    final created = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => const FormPage()),
    );
    if (created != null) _updateOrInsertNote(created);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notizen (Gruppiert)'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterDialog),
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
              onChanged: (v) => setState(() => _searchText = v),
            ),
          ),
        ),
      ),
      body: groupedNotes.isEmpty
          ? const Center(child: Text('Keine Notizen'))
          : ListView(
              children: groupedNotes.map((group) {
                final filtered = group.where(_applyFilters).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                if (filtered.isEmpty) return const SizedBox.shrink();
                final first = filtered.first;
                final key = _groupKey(first);
                return ExpansionTile(
                  key: PageStorageKey(key),
                  initiallyExpanded: expansionState[key] ?? false,
                  onExpansionChanged: (open) => expansionState[key] = open,
                  title: Text(
                    "${first.firstName} ${first.lastName}".trim().isNotEmpty
                        ? "${first.firstName} ${first.lastName}"
                        : (first.email ?? first.telephone ?? 'Unbenannt'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(first.email ?? first.telephone ?? ''),
                  children: filtered.map((note) {
                    return ListTile(
                      leading: Checkbox(
                        value: note.isDone,
                        onChanged: (_) => _toggleDone(note),
                      ),
                      title: Text(note.noteText),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (note.customDate != null)
                            Text(
                              'Datum: ${DateFormat.yMd().format(note.customDate!)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          Wrap(
                            spacing: 6,
                            children: note.labels.map((l) => Chip(label: Text(l))).toList(),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _editNote(note);
                          if (v == 'delete') _deleteNote(note);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                          PopupMenuItem(value: 'delete', child: Text('Löschen')),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
