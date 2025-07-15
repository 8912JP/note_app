import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'note.dart';       // Import der Note-Klasse aus note.dart
import 'form_page.dart';
import 'api_service.dart';
import 'dart:async';
// für Datumsausgabe

class NotesOverviewPage extends StatefulWidget {
  final ApiService apiService;

  const NotesOverviewPage({Key? key, required this.apiService}) : super(key: key);

  @override
  _NotesOverviewPageState createState() => _NotesOverviewPageState();
}

class _NotesOverviewPageState extends State<NotesOverviewPage> {
  List<Note> allNotes = [];

  // Filter-States
  String _searchText = "";
  String _selectedStatus = "all"; // all, done, not_done
  DateTimeRange? _selectedDateRange;
  List<String> _selectedLabelsFilter = [];

  late ApiService apiService;
  bool isLoading = true;


@override
void initState() {
  super.initState();
  apiService = widget.apiService; // <-- NICHT neu erzeugen, sondern den übergebenen verwenden
  _loadNotes();
  _setupWebSocket();
}

void _setupWebSocket() {
  apiService.connectToWebSocket(
    onEvent: (data) {
      final event = data['event'];
      final id = data['id'];
      print('📥 WebSocket Event: $event | ID: $id');

      // Optional: Nur aktualisieren, wenn sinnvoll (könntest auch differenziert nachladen)
      _loadNotes();
    },
    onError: (error) {
      print('❌ WebSocket Fehler: $error');
    },
  );
}

@override
void dispose() {
  apiService.disconnectWebSocket();
  super.dispose();
}

  Future<void> _loadNotes() async {
    try {
      final notes = await apiService.fetchNotes();
      setState(() {
        allNotes = notes;
        isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Notizen: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Filterfunktion
  bool _applyFilters(Note note) {
    final searchLower = _searchText.toLowerCase();
    if (searchLower.isNotEmpty) {
      final haystack =
          "${note.noteText} ${note.firstName} ${note.lastName}".toLowerCase();
      if (!haystack.contains(searchLower)) return false;
    }
    if (_selectedLabelsFilter.isNotEmpty) {
      bool labelMatch =
          note.labels.any((label) => _selectedLabelsFilter.contains(label));
      if (!labelMatch) return false;
    }
    if (_selectedStatus == "done" && !note.isDone) return false;
    if (_selectedStatus == "not_done" && note.isDone) return false;
    if (_selectedDateRange != null) {
      if (note.createdAt.isBefore(_selectedDateRange!.start) ||
          note.createdAt.isAfter(_selectedDateRange!.end)) {
        return false;
      }
    }
    return true;
  }

  void _toggleDone(Note note) async {
    final updatedNote = Note(
      id: note.id,
      firstName: note.firstName,
      lastName: note.lastName,
      email: note.email,
      telephone: note.telephone,
      address: note.address,
      noteText: note.noteText,
      customDate: note.customDate,
      gender: note.gender,
      labels: note.labels,
      isDone: !note.isDone,
      createdAt: note.createdAt,
    );
    try {
      final result = await apiService.updateNote(updatedNote);
      setState(() {
        final index = allNotes.indexWhere((n) => n.id == result.id);
        if (index != -1) allNotes[index] = result;
      });
    } catch (e) {
      print('Fehler beim Aktualisieren der Notiz: $e');
    }
  }

  void _deleteNote(Note note) async {
    try {
      await apiService.deleteNote(note.id!);
      setState(() {
        allNotes.removeWhere((n) => n.id == note.id);
      });
    } catch (e) {
      print('Fehler beim Löschen der Notiz: $e');
    }
  }

  void _editNote(Note note) async {
    final updatedNote = await Navigator.push<Note>(
      context,
      MaterialPageRoute(
        builder: (context) => FormPage(existingNote: note),
      ),
    );

    if (updatedNote != null) {
      try {
        final result = await apiService.updateNote(updatedNote);
        setState(() {
          final index = allNotes.indexWhere((n) => n.id == result.id);
          if (index != -1) allNotes[index] = result;
        });
      } catch (e) {
        print('Fehler beim Aktualisieren der Notiz: $e');
      }
    }
  }

  void _addNewNote() async {
    final newNote = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (context) => const FormPage()),
    );

    if (newNote != null) {
      setState(() {
        allNotes.add(newNote); // Nur Liste updaten, kein API-Call hier!
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempStatus = _selectedStatus;
        List<String> tempLabels = List.from(_selectedLabelsFilter);
        DateTimeRange? tempDateRange = _selectedDateRange;

        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Filter'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Status'),
                  RadioListTile(
                    title: const Text('Alle'),
                    value: 'all',
                    groupValue: tempStatus,
                    onChanged: (value) =>
                        setStateDialog(() => tempStatus = value!),
                  ),
                  RadioListTile(
                    title: const Text('Erledigt'),
                    value: 'done',
                    groupValue: tempStatus,
                    onChanged: (value) =>
                        setStateDialog(() => tempStatus = value!),
                  ),
                  RadioListTile(
                    title: const Text('Nicht erledigt'),
                    value: 'not_done',
                    groupValue: tempStatus,
                    onChanged: (value) =>
                        setStateDialog(() => tempStatus = value!),
                  ),
                  const SizedBox(height: 10),
                  const Text('Labels'),
                  Wrap(
                    spacing: 6,
                    children: ['dringend', 'Rückmeldung', 'Andere']
                        .map((label) {
                      final selected = tempLabels.contains(label);
                      return FilterChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (selected) {
                          setStateDialog(() {
                            if (selected) {
                              tempLabels.add(label);
                            } else {
                              tempLabels.remove(label);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange: tempDateRange,
                      );
                      if (picked != null) {
                        setStateDialog(() => tempDateRange = picked);
                      }
                    },
                    child: Text(tempDateRange == null
                        ? 'Datumsspanne auswählen'
                        : 'Von ${DateFormat.yMd().format(tempDateRange!.start)} bis ${DateFormat.yMd().format(tempDateRange!.end)}'),
                  ),
                  if (tempDateRange != null)
                    TextButton(
                      onPressed: () => setStateDialog(() => tempDateRange = null),
                      child: const Text('Datum löschen'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedStatus = tempStatus;
                    _selectedLabelsFilter = tempLabels;
                    _selectedDateRange = tempDateRange;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Übernehmen'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotes = allNotes.where(_applyFilters).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notizen Übersicht"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Suche in Notizen...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() {
                    _searchText = value.toLowerCase();
                  }),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFilterDialog,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : visibleNotes.isEmpty
              ? const Center(child: Text('Keine Notizen gefunden.'))
              : ListView.builder(
                  itemCount: visibleNotes.length,
                  itemBuilder: (context, index) {
                    final note = visibleNotes[index];
                    return Card(
                      child: ListTile(
                        enabled: !note.isDone,
                        leading: Checkbox(
                          value: note.isDone,
                          onChanged: (_) => _toggleDone(note),
                        ),
                        title: Text(
                          "${note.firstName} ${note.lastName}",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${note.email ?? ''} ${note.telephone ?? ''}\n${note.noteText}",
                            ),
                            if (note.customDate != null)
                              Text(
                                'Datum: ${DateFormat.yMd().format(note.customDate!)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            Wrap(
                              spacing: 6,
                              children: note.labels
                                  .map((label) => Chip(label: Text(label)))
                                  .toList(),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editNote(note);
                            } else if (value == 'delete') {
                              _deleteNote(note);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Bearbeiten'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Löschen'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
