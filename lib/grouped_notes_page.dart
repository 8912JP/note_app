import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'note.dart';
import 'form_page.dart';
import 'api_service.dart';
import 'dart:async';

class GroupedNotesPage extends StatefulWidget {
  const GroupedNotesPage({super.key});

  @override
  _GroupedNotesPageState createState() => _GroupedNotesPageState();
}

class _GroupedNotesPageState extends State<GroupedNotesPage> {
  List<List<Note>> groupedNotes = [];

  String _searchText = "";
  String _selectedStatus = "all";
  DateTimeRange? _selectedDateRange;
  List<String> _selectedLabelsFilter = [];

  late ApiService apiService;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    apiService = ApiService();
    _loadNotes();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    apiService.connectToWebSocket(
      onEvent: (data) {
        if (!mounted) return;
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
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final notes = await apiService.fetchGroupedNotes();
      if (!mounted) return;
      setState(() {
        groupedNotes = notes;
        isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Notizen: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

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
    final updatedNote = note.copyWith(isDone: !note.isDone);
    try {
      final result = await apiService.updateNote(updatedNote);
      if (!mounted) return;
      _loadNotes();
    } catch (e) {
      print('Fehler beim Aktualisieren der Notiz: $e');
    }
  }

  void _deleteNote(Note note) async {
    try {
      await apiService.deleteNote(note.id!);
      if (!mounted) return;
      _loadNotes();
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
        await apiService.updateNote(updatedNote);
        if (!mounted) return;
        _loadNotes();
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
      if (!mounted) return;
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notizen (Gruppiert)"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Suche in Notizen...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {
                _searchText = value.toLowerCase();
              }),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedNotes.isEmpty
              ? const Center(child: Text('Keine Notizen gefunden.'))
              : ListView.builder(
                  itemCount: groupedNotes.length,
                  itemBuilder: (context, groupIndex) {
                    final group = groupedNotes[groupIndex]
                        .where(_applyFilters)
                        .toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    if (group.isEmpty) return const SizedBox.shrink();

                    final first = group.first;

                    return ExpansionTile(
                      title: Text(
                        "${first.firstName} ${first.lastName}".trim().isEmpty
                            ? (first.email ?? first.telephone ?? "Unbenannt")
                            : "${first.firstName} ${first.lastName}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(first.email ?? first.telephone ?? ""),
                      children: group.map((note) {
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
                        );
                      }).toList(),
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
