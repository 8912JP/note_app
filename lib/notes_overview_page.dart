import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'note.dart';       // Import der Note-Klasse aus note.dart
import 'form_page.dart';
import 'api_service.dart';
import 'dart:async';
import 'websocket_manager.dart';
import 'stress_test.dart';

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
  bool _wsListenersAdded = false;

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
    
    // Initialisiere WebSocket-Manager und registriere beide Updater
    WebSocketManager().initialize();
    WebSocketManager().registerNotesFullReloadUpdater(_loadNotes);
    WebSocketManager().registerNotesUpdater(_handleNoteUpdate);
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
        apiService.removeWebSocketErrorListener(_wsErrorListener!);
        apiService.addWebSocketListener(_wsListener!);
        apiService.addWebSocketErrorListener(_wsErrorListener!);
      }
    });
  }

  void _setupWebSocket() {
    _wsListener ??= (data) {
        print("📥 WebSocket Event in NotesOverview: $data");
        _handleWebSocketEvent(data);
      };

    _wsErrorListener ??= (error) {
        print("❌ WebSocket Fehler in NotesOverview: $error");
        print("❌ Fehler-Typ: ${error.runtimeType}");
        print("❌ Aktuelle Verbindung: ${apiService.isWebSocketConnected()}");
        
        // Versuche manuellen Reconnect bei kritischen Fehlern
        if (error.toString().contains('Connection refused') ||
            error.toString().contains('SocketException') ||
            error.toString().contains('timeout')) {
          print("🔄 Versuche manuellen Reconnect...");
          apiService.forceReconnect();
        }
      };

    // Prüfe ob die Listener bereits hinzugefügt wurden
    if (!_wsListenersAdded) {
      apiService.addWebSocketListener(_wsListener!);
      apiService.addWebSocketErrorListener(_wsErrorListener!);
      _wsListenersAdded = true;
      print("📡 WebSocket-Listener in NotesOverview hinzugefügt");
    }
  }

  Future<void> _handleWebSocketEvent(dynamic data) async {
  try {
    // Prüfe ob es eine Pong-Nachricht ist (Heartbeat-Antwort)
    if (data is Map && data['type'] == 'pong') {
      print("↪️ Pong-Nachricht empfangen: ${data['timestamp']}");
      return; // Ignoriere Pong-Nachrichten
    }
    
    // Prüfe ob es ein gültiges Event ist
    if (data is! Map || data['event'] == null) {
      print("⚠️ Ungültige WebSocket-Nachricht: $data");
      return;
    }
    
    final String event = data['event'];
    final String? noteId = data['id']?.toString();

    if (!mounted || noteId == null) return;

    print("📥 Verarbeite WebSocket-Event: $event für Note ID: $noteId");

    switch (event) {
        case 'note_updated':
        if (data['note'] != null) {
          final incoming = Note.fromJson(Map<String, dynamic>.from(data['note']));
          if (!mounted) return;
          setState(() {
            final idx = allNotes.indexWhere((n) => n.id == incoming.id);
            if (idx != -1) {
              allNotes[idx] = incoming;
            } else {
              allNotes.add(incoming);
            }
            // Sortiere nach created_at (neueste zuerst)
            allNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          });
          print("✅ Note aktualisiert: ${incoming.id}");
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
              // Sortiere nach created_at (neueste zuerst)
              allNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            });
            print("✅ Note nachgeladen und aktualisiert: ${fetched.id}");
          }
        }
        break;

      case 'note_deleted':
        if (!mounted) return;
        setState(() {
          allNotes.removeWhere((n) => n.id.toString() == noteId);
        });
        print("🗑️ Note gelöscht: $noteId");
        break;

        case 'note_created':
        if (data['note'] != null) {
          final incoming = Note.fromJson(Map<String, dynamic>.from(data['note']));
          if (!mounted) return;
          setState(() {
            if (!allNotes.any((n) => n.id == incoming.id)) {
              allNotes.add(incoming);
              // Sortiere nach created_at (neueste zuerst)
              allNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            }
          });
          print("✅ Neue Note erstellt: ${incoming.id}");
        } else {
          // Fallback: Note nachladen
          final fetched = await apiService.fetchNoteById(noteId);
          if (fetched != null && mounted) {
            setState(() {
              if (!allNotes.any((n) => n.id == fetched.id)) {
                allNotes.add(fetched);
                // Sortiere nach created_at (neueste zuerst)
                allNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              }
            });
            print("✅ Neue Note nachgeladen: ${fetched.id}");
          }
        }
        break;
        
      default:
        print("⚠️ Unbekanntes WebSocket-Event: $event");
        break;
    }
  } catch (e, stack) {
    debugPrint('❌ Fehler im WebSocket-Eventhandler: $e');
    debugPrint('❌ Daten die den Fehler verursacht haben: $data');
    debugPrint('$stack'); // Zeigt dir, wo der Fehler auftrat
  }
}

  // keine zusätzlichen HTTP-Fetches oder Buffer nötig

  @override
  void dispose() {
    // Entferne vom WebSocket-Manager
    WebSocketManager().unregisterNotesFullReloadUpdater(_loadNotes);
    WebSocketManager().unregisterNotesUpdater(_handleNoteUpdate);
    
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
      
      // Markiere Notes als gesehen (entferne rote Punkte)
      apiService.notificationService.markNotesAsSeen();
      
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

  // Intelligente Note-Update-Behandlung ohne vollständiges Neuladen
  void _handleNoteUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    
    try {
      final noteData = data['note'] as Map<String, dynamic>?;
      if (noteData != null) {
        final updatedNote = Note.fromJson(noteData);
        
        setState(() {
          final index = allNotes.indexWhere((note) => note.id == updatedNote.id);
          if (index != -1) {
            // Aktualisiere bestehende Note
            allNotes[index] = updatedNote;
            print("✅ Note aktualisiert: ${updatedNote.id}");
            
            // Release-Build: Zeige SnackBar-Benachrichtigung
            final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
            if (isReleaseMode) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Note aktualisiert: ${updatedNote.firstName} ${updatedNote.lastName}'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            // Füge neue Note hinzu (falls sie nicht bereits vorhanden ist)
            allNotes.add(updatedNote);
            print("✅ Neue Note hinzugefügt: ${updatedNote.id}");
          }
          // Sortiere nach created_at (neueste zuerst)
          allNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }
    } catch (e) {
      print("❌ Fehler beim Aktualisieren der Note: $e");
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
    print("🔄 _toggleDone aufgerufen für Note ID: ${note.id}");
    print("🔄 Aktueller isDone Status: ${note.isDone}");
    
    _updatingNoteIds.add(note.id!);
    if (mounted) setState(() {});
    
    final updated = note.copyWith(
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
    
    print("🔄 Neuer isDone Status: ${updated.isDone}");
    
    try {
      print("🔄 Rufe apiService.updateNote auf...");
      final result = await apiService.updateNote(updated);
      print("🔄 updateNote erfolgreich abgeschlossen");
      setState(() {
        final index = allNotes.indexWhere((n) => n.id == result.id);
        if (index != -1) allNotes[index] = result;
      });
    } catch (e) {
      print('❌ Fehler beim Aktualisieren der Notiz: $e');
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

  void _showSnackBar(String message, {bool isSuccess = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showSnackBarWithColor(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  void _showWebSocketDebugInfo() {
    final isConnected = apiService.isWebSocketConnected();
    final listenerCount = apiService.getWebSocketListenerCount();
    final errorListenerCount = apiService.getWebSocketErrorListenerCount();
    final stressTest = StressTest();

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
            onPressed: () async {
              Navigator.pop(context);
              final success = await apiService.testWebSocketConnection();
              _showSnackBar(
                success ? 'WebSocket-Test erfolgreich!' : 'WebSocket-Test fehlgeschlagen',
                isSuccess: success,
              );
            },
            child: const Text('WebSocket testen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final status = await apiService.getWebSocketStatus();
              if (status != null) {
                _showSnackBarWithColor(
                  'Server: ${status['active_clients']} Clients',
                  Colors.blue,
                );
              } else {
                _showSnackBar('Status-Abfrage fehlgeschlagen', isSuccess: false);
              }
            },
            child: const Text('Server-Status'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await apiService.testServerBroadcast();
              _showSnackBarWithColor(
                success ? 'Test-Broadcast gesendet!' : 'Test-Broadcast fehlgeschlagen',
                success ? Colors.orange : Colors.red,
              );
            },
            child: const Text('Test-Broadcast'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await apiService.testDirectWebSocket();
              if (result != null) {
                _showSnackBarWithColor(
                  'Direkter Test: ${result['successful_sends']}/${result['total_clients']} erfolgreich',
                  result['successful_sends'] > 0 ? Colors.green : Colors.red,
                );
              } else {
                _showSnackBar('Direkter Test fehlgeschlagen', isSuccess: false);
              }
            },
            child: const Text('Direkter Test'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await apiService.testBackendConnection();
              _showSnackBar(
                success ? 'Backend-Verbindungstest abgeschlossen' : 'Backend-Verbindungstest fehlgeschlagen',
                isSuccess: success,
              );
            },
            child: const Text('Backend-Test'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await apiService.testNetworkConfiguration();
              _showSnackBar('Netzwerk-Test abgeschlossen - siehe Konsole', isSuccess: true);
            },
            child: const Text('Netzwerk-Test'),
          ),
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
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _showStressTestDialog(stressTest);
            },
            child: const Text('Stresstest'),
          ),
        ],
      ),
    );
  }

  void _showStressTestDialog(StressTest stressTest) {
    String logOutput = "";
    bool isRunning = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Stresstest'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      logOutput.isEmpty ? "Klicken Sie 'Start' um den Stresstest zu beginnen..." : logOutput,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: isRunning ? null : () async {
                        setState(() {
                          isRunning = true;
                          logOutput = "";
                        });
                        
                        stressTest.startStressTest(
                          duration: 30,
                          updateInterval: 2,
                          maxConcurrent: 3,
                          statusCallback: (message) {
                            setState(() {
                              logOutput += "$message\n";
                            });
                          },
                          completeCallback: (stats) {
                            setState(() {
                              isRunning = false;
                              logOutput += "\n🏁 TEST BEENDET\n";
                              logOutput += "📊 Erfolgsrate: ${stats['successRate']}%\n";
                              logOutput += "📊 Gesamt-Updates: ${stats['totalUpdates']}\n";
                              logOutput += "✅ Erfolgreich: ${stats['successfulUpdates']}\n";
                              logOutput += "❌ Fehlgeschlagen: ${stats['failedUpdates']}\n";
                            });
                          },
                        );
                      },
                      child: const Text('Start (30s)'),
                    ),
                    ElevatedButton(
                      onPressed: isRunning ? null : () async {
                        setState(() {
                          isRunning = true;
                          logOutput = "";
                        });
                        
                        stressTest.runFullStressTest();
                        
                        // Stoppe nach 60 Sekunden
                        Timer(Duration(seconds: 60), () {
                          if (mounted) {
                            setState(() {
                              isRunning = false;
                              logOutput += "\n🏁 VOLLSTÄNDIGER TEST BEENDET\n";
                            });
                          }
                        });
                      },
                      child: const Text('Vollständig'),
                    ),
                    ElevatedButton(
                      onPressed: isRunning ? null : () {
                        stressTest.stopStressTest();
                        setState(() {
                          isRunning = false;
                          logOutput += "\n⏹️ TEST GESTOPPT\n";
                        });
                      },
                      child: const Text('Stop'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        ),
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
          // Aktueller Benutzer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                apiService.loggedInUser ?? 'Nicht eingeloggt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
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
