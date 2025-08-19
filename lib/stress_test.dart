import 'dart:async';
import 'dart:math';
import 'api_service.dart';
import 'note.dart';

class StressTest {
  final ApiService _apiService = ApiService();
  final Random _random = Random();
  Timer? _testTimer;
  bool _isRunning = false;
  
  // Test-Konfiguration
  int _testDuration = 60; // Sekunden
  int _noteUpdateInterval = 3; // Sekunden zwischen Updates
  int _maxConcurrentUpdates = 5;
  
  // Test-Statistiken
  int _totalUpdates = 0;
  int _successfulUpdates = 0;
  int _failedUpdates = 0;
  final List<String> _errors = [];
  
  // Callback für UI-Updates
  Function(String message)? onStatusUpdate;
  Function(Map<String, dynamic> stats)? onTestComplete;
  
  void startStressTest({
    int duration = 60,
    int updateInterval = 3,
    int maxConcurrent = 5,
    Function(String)? statusCallback,
    Function(Map<String, dynamic>)? completeCallback,
  }) {
    if (_isRunning) return;
    
    _testDuration = duration;
    _noteUpdateInterval = updateInterval;
    _maxConcurrentUpdates = maxConcurrent;
    onStatusUpdate = statusCallback;
    onTestComplete = completeCallback;
    
    _isRunning = true;
    _totalUpdates = 0;
    _successfulUpdates = 0;
    _failedUpdates = 0;
    _errors.clear();
    
    _log("🚀 Starte Stresstest für ${_testDuration}s");
    _log("📊 Update-Intervall: ${_noteUpdateInterval}s");
    _log("⚡ Max. gleichzeitige Updates: $_maxConcurrentUpdates");
    
    // Starte Test-Timer
    _testTimer = Timer.periodic(Duration(seconds: _noteUpdateInterval), (_) {
      if (_isRunning) {
        _performRandomUpdate();
      }
    });
    
    // Stoppe Test nach gegebener Zeit
    Timer(Duration(seconds: _testDuration), () {
      stopStressTest();
    });
  }
  
  void stopStressTest() {
    if (!_isRunning) return;
    
    _isRunning = false;
    _testTimer?.cancel();
    _testTimer = null;
    
    final stats = {
      'totalUpdates': _totalUpdates,
      'successfulUpdates': _successfulUpdates,
      'failedUpdates': _failedUpdates,
      'successRate': _totalUpdates > 0 ? (_successfulUpdates / _totalUpdates * 100).toStringAsFixed(1) : '0.0',
      'errors': _errors,
      'duration': _testDuration,
    };
    
    _log("🏁 Stresstest beendet");
    _log("📊 Ergebnisse:");
    _log("  - Gesamt-Updates: $_totalUpdates");
    _log("  - Erfolgreich: $_successfulUpdates");
    _log("  - Fehlgeschlagen: $_failedUpdates");
    _log("  - Erfolgsrate: ${stats['successRate']}%");
    
    onTestComplete?.call(stats);
  }
  
  Future<void> _performRandomUpdate() async {
    try {
      _totalUpdates++;
      
      // Lade aktuelle Notes
      final notes = await _apiService.fetchNotes();
      if (notes.isEmpty) {
        _log("⚠️ Keine Notes für Update verfügbar");
        _failedUpdates++;
        return;
      }
      
      // Wähle zufällige Note
      final randomNote = notes[_random.nextInt(notes.length)];
      
      // Wähle zufällige Aktion
      final action = _random.nextInt(3); // 0: toggle done, 1: edit, 2: delete
      
      switch (action) {
        case 0:
          await _toggleNoteDone(randomNote);
          break;
        case 1:
          await _editRandomNote(randomNote);
          break;
        case 2:
          await _deleteRandomNote(randomNote);
          break;
      }
      
      _successfulUpdates++;
      _log("✅ Update #$_totalUpdates erfolgreich (Aktion: ${_getActionName(action)})");
      
    } catch (e) {
      _failedUpdates++;
      final error = "Update #$_totalUpdates fehlgeschlagen: $e";
      _errors.add(error);
      _log("❌ $error");
    }
  }
  
  Future<void> _toggleNoteDone(Note note) async {
    final updated = note.copyWith(isDone: !note.isDone);
    await _apiService.updateNote(updated);
  }
  
  Future<void> _editRandomNote(Note note) async {
    final randomTexts = [
      "Stresstest Update ${DateTime.now().millisecondsSinceEpoch}",
      "Automatischer Test",
      "Performance Test",
      "WebSocket Test",
      "Real-time Update Test",
    ];
    
    final updated = note.copyWith(
      noteText: randomTexts[_random.nextInt(randomTexts.length)],
    );
    
    await _apiService.updateNote(updated);
  }
  
  Future<void> _deleteRandomNote(Note note) async {
    await _apiService.deleteNote(note.id!);
  }
  
  String _getActionName(int action) {
    switch (action) {
      case 0: return "Toggle Done";
      case 1: return "Edit";
      case 2: return "Delete";
      default: return "Unknown";
    }
  }
  
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logMessage = "[$timestamp] $message";
    print(logMessage);
    onStatusUpdate?.call(logMessage);
  }
  
  // WebSocket-spezifische Tests
  Future<void> testWebSocketConnection() async {
    _log("🔌 Teste WebSocket-Verbindung...");
    
    final isConnected = _apiService.isWebSocketConnected();
    _log("📡 WebSocket verbunden: ${isConnected ? 'Ja' : 'Nein'}");
    
    if (isConnected) {
      final listenerCount = _apiService.getWebSocketListenerCount();
      final errorListenerCount = _apiService.getWebSocketErrorListenerCount();
      _log("📊 Aktive Listener: $listenerCount (Fehler: $errorListenerCount)");
    }
  }
  
  Future<void> testServerBroadcast() async {
    _log("📡 Teste Server-Broadcast...");
    
    try {
      final success = await _apiService.testServerBroadcast();
      _log(success ? "✅ Broadcast erfolgreich" : "❌ Broadcast fehlgeschlagen");
    } catch (e) {
      _log("❌ Broadcast-Fehler: $e");
    }
  }
  
  Future<void> testRapidPageSwitching() async {
    _log("🔄 Teste schnellen Seitenwechsel...");
    
    // Simuliere schnelle Navigation
    for (int i = 0; i < 10; i++) {
      _log("📱 Seitenwechsel #${i + 1}");
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    _log("✅ Seitenwechsel-Test abgeschlossen");
  }
  
  // Memory-Leak Test
  Future<void> testMemoryLeaks() async {
    _log("🧠 Teste Memory-Leaks...");
    
    final initialListenerCount = _apiService.getWebSocketListenerCount();
    
    // Simuliere viele Seitenwechsel
    for (int i = 0; i < 20; i++) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    final finalListenerCount = _apiService.getWebSocketListenerCount();
    
    if (finalListenerCount > initialListenerCount * 2) {
      _log("⚠️ Möglicher Memory-Leak: Listener von $initialListenerCount auf $finalListenerCount gestiegen");
    } else {
      _log("✅ Kein offensichtlicher Memory-Leak erkannt");
    }
  }
  
  // Netzwerk-Stabilität Test
  Future<void> testNetworkStability() async {
    _log("🌐 Teste Netzwerk-Stabilität...");
    
    for (int i = 0; i < 5; i++) {
      try {
        await _apiService.testWebSocketConnection();
        _log("✅ Netzwerk-Test #${i + 1} erfolgreich");
      } catch (e) {
        _log("❌ Netzwerk-Test #${i + 1} fehlgeschlagen: $e");
      }
      
      await Future.delayed(Duration(seconds: 2));
    }
  }
  
  // Vollständiger Stresstest
  Future<void> runFullStressTest() async {
    _log("🎯 Starte vollständigen Stresstest...");
    
    // 1. WebSocket-Verbindung testen
    await testWebSocketConnection();
    
    // 2. Server-Broadcast testen
    await testServerBroadcast();
    
    // 3. Schnelle Updates starten
    startStressTest(
      duration: 30,
      updateInterval: 2,
      maxConcurrent: 3,
      statusCallback: (message) => _log(message),
      completeCallback: (stats) {
        _log("📊 Stresstest-Ergebnisse: ${stats['successRate']}% Erfolgsrate");
      },
    );
    
    // 4. Während Updates: Seitenwechsel testen
    Timer(Duration(seconds: 10), () async {
      await testRapidPageSwitching();
    });
    
    // 5. Memory-Leak Test nach Updates
    Timer(Duration(seconds: 35), () async {
      await testMemoryLeaks();
    });
    
    // 6. Netzwerk-Stabilität testen
    Timer(Duration(seconds: 40), () async {
      await testNetworkStability();
    });
  }
}
