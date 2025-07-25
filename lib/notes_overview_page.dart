import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'note.dart';       // Import der Note-Klasse aus note.dart
import 'form_page.dart';
import 'api_service.dart';
import 'dart:async';

// für Datumsausgabe

class NotesOverviewPage extends StatefulWidget {
  final ApiService apiService;

  const NotesOverviewPage({super.key, required this.apiService});

  @override
  _NotesOverviewPageState createState() => _NotesOverviewPageState();
}

class _NotesOverviewPageState extends State<NotesOverviewPage> {
  late final ApiService apiService;
  List<Note> allNotes = [];
  bool isLoading = true;

  // Filter-States
  String _searchText = "";
  String _selectedStatus = "all"; // all, done, not_done
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
  apiService.connectToWebSocket(
    onEvent: (data) {
      unawaited(_handleWebSocketEvent(data));
    },
    onError: (error) => debugPrint('❌ WebSocket Fehler: $error'),
  );
}

Future<void> _handleWebSocketEvent(dynamic data) async {
  try {
    final String event = data['event'];
    final String? noteId = data['id']?.toString();

    if (!mounted || noteId == null) return;

    switch (event) {
      case 'note_updated':
        final updatedNote = await apiService.fetchNoteById(noteId);
        if (updatedNote == null) return;
        if (!mounted) return;
        setState(() {
          final index = allNotes.indexWhere((n) => n.id == updatedNote.id);
          if (index != -1) {
            allNotes[index] = updatedNote;
          } else {
            allNotes.add(updatedNote);
          }
        });
        break;

      case 'note_deleted':
        if (!mounted) return;
        setState(() {
          allNotes.removeWhere((n) => n.id == noteId);
        });
        break;

      case 'note_created':
        final newNote = await apiService.fetchNoteById(noteId);
        if (newNote == null || !mounted) return;
        setState(() {
          if (!allNotes.any((n) => n.id == newNote.id)) {
            allNotes.add(newNote);
          }
        });
        break;
    }
  } catch (e, stack) {
    debugPrint('❌ Fehler im WebSocket-Eventhandler: $e');
    debugPrint('$stack'); // Zeigt dir, wo der Fehler auftrat
  }
}


  Future<void> _loadNotes() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final notes = await apiService.fetchNotes();
      if (!mounted) return;
      setState(() {
        allNotes = notes;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('Fehler laden (Übersicht): $e');
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
          // Nach createdAt absteigend sortieren
          allNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
        if (!allNotes.any((n) => n.id == newNote.id)) {
          allNotes.add(newNote);
        }
        // Nach createdAt absteigend sortieren
        allNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
                    children: ['Dringend', 'Rückmeldung', 'Go!', 'UPS', 'Eilt nicht']
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
