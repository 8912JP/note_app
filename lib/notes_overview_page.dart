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
  void Function(Map<String, dynamic>)? _wsListener;
  void Function(dynamic error)? _wsErrorListener;
  // Vereinfachte Event-Verarbeitung: keine Buffer/Debounce
  final Set<int> _updatingNoteIds = <int>{};

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
    _startWebSocketMonitoring();
  }

  Timer? _wsMonitoringTimer;

  void _startWebSocketMonitoring() {
    // Überwache WebSocket-Status alle 30 Sekunden
    _wsMonitoringTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final isConnected = apiService.isWebSocketConnected();
      print('🔍 WebSocket Monitoring: ${isConnected ? "Verbunden" : "Nicht verbunden"}');
      
      // Wenn nicht verbunden und Listener vorhanden, versuche Reconnect
      if (!isConnected && _wsListener != null) {
        print('⚠️ WebSocket nicht verbunden, aber Listener vorhanden. Versuche Reconnect...');
        apiService.removeWebSocketListener(_wsListener!);
        apiService.addWebSocketListener(_wsListener!, _wsErrorListener);
      }
    });
  }

  void _setupWebSocket() {
    _wsListener = (data) {
      print("📥 WebSocket Event in NotesOverview: $data");
      unawaited(_handleWebSocketEvent(data));
    };
    _wsErrorListener = (error) {
      debugPrint('❌ WebSocket Fehler in NotesOverview: $error');
      print('❌ WebSocket Fehler Details: $error');
      print('❌ Fehler-Typ: ${error.runtimeType}');
      
      // Zeige WebSocket-Status
      print('🔌 WebSocket Status: ${apiService.isWebSocketConnected() ? "Verbunden" : "Nicht verbunden"}');
      
      // Versuche manuellen Reconnect bei kritischen Fehlern
      if (error.toString().contains('Connection refused') || 
          error.toString().contains('SocketException') ||
          error.toString().contains('timeout')) {
        print('🔄 Versuche manuellen Reconnect...');
        // Kurze Verzögerung, dann neu verbinden
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            apiService.removeWebSocketListener(_wsListener!);
            apiService.addWebSocketListener(_wsListener!, _wsErrorListener);
          }
        });
      }
    };
    apiService.addWebSocketListener(_wsListener!, _wsErrorListener);
  }

  Future<void> _handleWebSocketEvent(dynamic data) async {
  try {
    final String event = data['event'];
    final String? noteId = data['id']?.toString();

    if (!mounted || noteId == null) return;

    switch (event) {
        case 'note_updated':
        if (data is Map && data['note'] != null) {
          final incoming = Note.fromJson(Map<String, dynamic>.from(data['note']));
          if (!mounted) return;
          setState(() {
            final idx = allNotes.indexWhere((n) => n.id == incoming.id);
            if (idx != -1) {
              allNotes[idx] = incoming;
            } else {
              allNotes.add(incoming);
            }
          });
        } else {
          // Fallback: Note nachladen, falls Event ohne payload kommt
          final fetched = await apiService.fetchNoteById(noteId);
          if (fetched != null && mounted) {
            setState(() {
              final idx = allNotes.indexWhere((n) => n.id == fetched.id);
              if (idx != -1) {
                allNotes[idx] = fetched;
              } else {
                allNotes.add(fetched);
              }
            });
          }
        }
        break;

      case 'note_deleted':
        if (!mounted) return;
        setState(() {
          allNotes.removeWhere((n) => n.id.toString() == noteId);
        });
        break;

        case 'note_created':
        if (data is Map && data['note'] != null) {
          final incoming = Note.fromJson(Map<String, dynamic>.from(data['note']));
          if (!mounted) return;
          setState(() {
            if (!allNotes.any((n) => n.id == incoming.id)) {
              allNotes.add(incoming);
            }
          });
        } else {
          // Fallback: Note nachladen
          final fetched = await apiService.fetchNoteById(noteId);
          if (fetched != null && mounted) {
            setState(() {
              if (!allNotes.any((n) => n.id == fetched.id)) {
                allNotes.add(fetched);
              }
            });
          }
        }
        break;
    }
  } catch (e, stack) {
    debugPrint('❌ Fehler im WebSocket-Eventhandler: $e');
    debugPrint('$stack'); // Zeigt dir, wo der Fehler auftrat
  }
}

  // keine zusätzlichen HTTP-Fetches oder Buffer nötig

  @override
  void dispose() {
    // WebSocket-Listener entfernen
    if (_wsListener != null) {
      apiService.removeWebSocketListener(_wsListener!);
    }
    // Monitoring-Timer stoppen
    _wsMonitoringTimer?.cancel();
    super.dispose();
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
      
      // Zeige Benutzer-freundliche Fehlermeldung
      if (e.toString().contains('Server nicht erreichbar') || e.toString().contains('404')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backend-Server nicht verfügbar. Bitte starten Sie den Server mit: cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
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
    if (note.id == null) return;
    if (_updatingNoteIds.contains(note.id)) return; // schon in Arbeit
    _updatingNoteIds.add(note.id!);
    setState(() {});
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
    _updatingNoteIds.remove(note.id);
    if (mounted) setState(() {});
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

  void _showWebSocketDebugInfo() {
    final isConnected = apiService.isWebSocketConnected();
    final listenerCount = apiService.getWebSocketListenerCount();
    final errorListenerCount = apiService.getWebSocketErrorListenerCount();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WebSocket Debug Info'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              const Text('WebSocket Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Verbunden: ${isConnected ? "✅ Ja" : "❌ Nein"}'),
              const SizedBox(height: 10),
              const Text('Listener Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Allgemein: $listenerCount'),
              Text('Fehler: $errorListenerCount'),
              const SizedBox(height: 10),
              const Text('Debug Aktionen:', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              apiService.forceReconnect();
              Navigator.pop(context);
            },
            child: const Text('Reconnect erzwingen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
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
        actions: [
          // Debug-Button für WebSocket-Status
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: () {
              _showWebSocketDebugInfo();
            },
            tooltip: 'WebSocket Debug Info',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotes,
          ),
        ],
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
                          onChanged: _updatingNoteIds.contains(note.id ?? -1)
                              ? null
                              : (_) => _toggleDone(note),
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
