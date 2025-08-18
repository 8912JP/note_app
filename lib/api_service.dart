import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:note_app/note.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'crm_entry.dart'; // dein Modell

class ApiService {
  static final ApiService _instance = ApiService._internal();
  ApiService._internal();
  factory ApiService() => _instance;

  static const String baseUrl = 'https://iqmedix.cloud';
  String? _accessToken;
  String? _loggedInUser;
  String? get loggedInUser => _loggedInUser;
  String? get accessToken => _accessToken;

  WebSocketChannel? _channel;
  Timer? _wsHeartbeatTimer;

  // Automatische Reconnect-Logik für Server-Client-Desynchronisation
  Timer? _autoReconnectTimer;
  bool _isAutoReconnecting = false;

  void _startAutoReconnectMonitoring() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_isAutoReconnecting || _isConnecting || _isDisconnecting) return;
      
      try {
        // Prüfe Server-Status
        final status = await getWebSocketStatus();
        final serverClientCount = status?['active_clients'] ?? 0;
        final isConnected = isWebSocketConnected();
        
        print("🔍 Auto-Reconnect Check: Server=$serverClientCount Clients, Client=${isConnected ? 'verbunden' : 'getrennt'}");
        
        // Wenn Server 0 Clients meldet, aber wir denken wir sind verbunden
        if (serverClientCount == 0 && isConnected) {
          print("⚠️ Server meldet 0 Clients, aber Client denkt er ist verbunden - Reconnect nötig");
          _isAutoReconnecting = true;
          forceReconnect();
          _isAutoReconnecting = false;
        }
        // Wenn wir nicht verbunden sind, aber Server Clients meldet
        else if (serverClientCount > 0 && !isConnected) {
          print("⚠️ Client ist getrennt, aber Server meldet $serverClientCount Clients - Reconnect nötig");
          _isAutoReconnecting = true;
          forceReconnect();
          _isAutoReconnecting = false;
        }
      } catch (e) {
        print("❌ Fehler beim Auto-Reconnect Check: $e");
      }
    });
  }

  void _stopAutoReconnectMonitoring() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;
  }

  // ======================== 🔐 AUTH ========================
  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _accessToken = data['access_token'];
      _loggedInUser =
          username; // <-- Hier den aktuell eingeloggten User speichern
      print("✅ AccessToken gesetzt: $_accessToken");
      return true;
    } else {
      print("❌ Login fehlgeschlagen: ${response.statusCode}");
      print(response.body);
      return false;
    }
  }

  Map<String, String> get _authHeaders {
    final headers = {'Content-Type': 'application/json'};
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<bool> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/register/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
    return response.statusCode == 200;
  }

  // ======================== 📋 CRUD NOTES ========================
  Future<List<Note>> fetchNotes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notes/'),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((e) => Note.fromJson(e)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Bitte erneut einloggen.');
      } else if (response.statusCode == 404) {
        throw Exception('Server nicht verfügbar (404). Bitte starten Sie den Backend-Server.');
      } else {
        throw Exception('Fehler beim Laden der Notizen (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        throw Exception('Server nicht erreichbar. Bitte starten Sie den Backend-Server mit: cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000');
      }
      rethrow;
    }
  }

  Future<Note> createNote(Note note) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/notes/'),
      headers: _authHeaders,
      body: json.encode(note.toJson()),
    );
    if (response.statusCode == 201) {
      return Note.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Bitte erneut einloggen.');
    } else {
      throw Exception('Fehler beim Erstellen (${response.statusCode})');
    }
  }

  Future<Note> updateNote(Note note) async {
    print("🔄 updateNote aufgerufen für Note ID: ${note.id}");
    print("🔄 Note isDone: ${note.isDone}");
    print("🔄 AccessToken vorhanden: ${_accessToken != null}");
    print("🔄 AccessToken Länge: ${_accessToken?.length ?? 0}");
    
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/notes/${note.id}'),
        headers: _authHeaders,
        body: json.encode(note.toJson()),
      );
      print("🔄 HTTP Response Status: ${response.statusCode}");
      print("🔄 HTTP Response Body: ${response.body}");
      
      if (response.statusCode == 200) {
        return Note.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        print("❌ 401 Unauthorized - Token möglicherweise abgelaufen");
        throw Exception('Unauthorized: Bitte erneut einloggen.');
      } else if (response.statusCode == 404) {
        print("❌ 404 Not Found - Note nicht gefunden");
        throw Exception('Server nicht verfügbar (404). Bitte starten Sie den Backend-Server.');
      } else {
        print("❌ HTTP ${response.statusCode} - Unbekannter Fehler");
        throw Exception('Fehler beim Aktualisieren (${response.statusCode})');
      }
    } catch (e) {
      print("❌ Exception in updateNote: $e");
      print("❌ Exception Typ: ${e.runtimeType}");
      if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        throw Exception('Server nicht erreichbar. Bitte starten Sie den Backend-Server mit: cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000');
      }
      rethrow;
    }
  }

  Future<void> deleteNote(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/notes/$id'),
      headers: _authHeaders,
    );
    if (response.statusCode != 204) {
      if (response.statusCode == 401) {
        throw Exception('Unauthorized: Bitte erneut einloggen.');
      }
      throw Exception('Fehler beim Löschen (${response.statusCode})');
    }
  }

  // ======================== 🧠 GRUPPIERUNG ========================
  Future<List<List<int>>> fetchNoteGroups() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/notes/groups/'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map<List<int>>((group) => List<int>.from(group)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Bitte erneut einloggen.');
    } else {
      throw Exception(
        'Fehler beim Abrufen der Gruppen (${response.statusCode})',
      );
    }
  }

  // ======================== 🔄 WEBSOCKET ========================
  final List<void Function(Map<String, dynamic> data)> _webSocketListeners = [];
  final List<void Function(dynamic error)?> _webSocketErrorListeners = [];
  
  // Verbesserte WebSocket-Verwaltung
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  
  void addWebSocketListener(void Function(Map<String, dynamic> data) listener) {
    final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
    
    if (!_webSocketListeners.contains(listener)) {
      _webSocketListeners.add(listener);
      print("📡 WebSocket-Listener hinzugefügt. Gesamt: ${_webSocketListeners.length}");
      
      // Release-spezifische Listener-Validierung
      if (isReleaseMode) {
        print("🔧 Release-Modus: Listener-Validierung aktiviert");
        // Prüfe nach kurzer Zeit, ob der Listener noch aktiv ist
        Timer(const Duration(seconds: 5), () {
          if (_webSocketListeners.contains(listener)) {
            print("🔧 Release-Modus: Listener ist noch aktiv");
          } else {
            print("⚠️ Release-Modus: Listener wurde entfernt");
          }
        });
      }
      
      // Automatische WebSocket-Verbindung, falls noch nicht verbunden
      if (_channel == null && _accessToken != null) {
        print("🔌 Automatische WebSocket-Verbindung aufgrund neuer Listener");
        _connectToWebSocket();
      }
    } else {
      print("⚠️ WebSocket-Listener bereits vorhanden");
    }
  }

  void removeWebSocketListener(void Function(Map<String, dynamic> data) listener) {
    final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
    
    if (_webSocketListeners.remove(listener)) {
      print("📡 WebSocket-Listener entfernt. Verbleibend: ${_webSocketListeners.length}");
      
      // Release-spezifische Verbindungsverwaltung
      if (isReleaseMode && _webSocketListeners.isEmpty) {
        print("🔧 Release-Modus: Keine Listener mehr - trenne Verbindung in 10 Sekunden");
        // Im Release-Modus warten wir länger, bevor wir die Verbindung trennen
        Timer(const Duration(seconds: 10), () {
          if (_webSocketListeners.isEmpty) {
            print("🔧 Release-Modus: Trenne Verbindung - keine Listener mehr");
            disconnectWebSocket();
          }
        });
      } else if (!isReleaseMode && _webSocketListeners.isEmpty) {
        // Debug-Modus: Sofortige Trennung
        print("🔧 Debug-Modus: Trenne Verbindung sofort - keine Listener mehr");
        disconnectWebSocket();
      }
    } else {
      print("⚠️ WebSocket-Listener nicht gefunden");
    }
  }

  void addWebSocketErrorListener(void Function(dynamic error) errorListener) {
    final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
    
    if (!_webSocketErrorListeners.contains(errorListener)) {
      _webSocketErrorListeners.add(errorListener);
      print("📡 WebSocket-Error-Listener hinzugefügt. Gesamt: ${_webSocketErrorListeners.length}");
      
      // Release-spezifische Error-Listener-Validierung
      if (isReleaseMode) {
        print("🔧 Release-Modus: Error-Listener-Validierung aktiviert");
      }
    } else {
      print("⚠️ WebSocket-Error-Listener bereits vorhanden");
    }
  }

  void removeWebSocketErrorListener(void Function(dynamic error) errorListener) {
    if (_webSocketErrorListeners.remove(errorListener)) {
      print("📡 WebSocket-Error-Listener entfernt. Verbleibend: ${_webSocketErrorListeners.length}");
    } else {
      print("⚠️ WebSocket-Error-Listener nicht gefunden");
    }
  }
  
  void _connectToWebSocket({
    bool enableReconnect = true,
  }) {
    if (_accessToken == null) {
      print("⚠️ Kein AccessToken vorhanden. WebSocket wird nicht verbunden.");
      return;
    }

    // Prüfe ob bereits eine Verbindung existiert oder gerade aufgebaut wird
    if (_channel != null || _isConnecting) {
      print("⚠️ WebSocket-Verbindung bereits aktiv oder wird aufgebaut.");
      return;
    }

    _isConnecting = true;
    print("🔌 WebSocket wird über Node.js-Proxy aktiviert (Versuch ${_reconnectAttempts + 1})");

    try {
      // Intelligente WebSocket-URL-Auswahl
      String wsUrl;
      final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
      
      if (baseUrl.startsWith('https')) {
        // Verwende immer die gleiche URL für Debug und Release
        // Der Proxy sollte in beiden Modi funktionieren
        wsUrl = 'wss://iqmedix.cloud/ws/notes?token=$_accessToken';
        print("🔌 Verwende WebSocket-URL: $wsUrl");
      } else {
        wsUrl = 'ws://iqmedix.cloud/ws/notes?token=$_accessToken';
      }
      
      // Debug: Zeige alle relevanten Informationen
      print("🔌 WebSocket Debug Info:");
      print("  - AccessToken vorhanden: ${_accessToken != null}");
      print("  - AccessToken Länge: ${_accessToken?.length ?? 0}");
      print("  - AccessToken Start: ${_accessToken?.substring(0, 10)}...");
      print("  - BaseUrl: $baseUrl");
      print("  - WebSocket URL: $wsUrl");
      print("  - WebSocket Listeners: ${_webSocketListeners.length}");
      print("  - Reconnect Versuche: $_reconnectAttempts");
      print("  - Build-Modus: ${isReleaseMode ? 'Release' : 'Debug'}");
      print("  - Platform: ${const String.fromEnvironment('FLUTTER_TARGET', defaultValue: 'unknown')}");
      
      print("🔌 Verbinde WebSocket: $wsUrl");
      
      // Verwende WebSocketChannel.connect direkt mit String-URL
      final uri = Uri.parse(wsUrl);
      print("🔌 Parsed URI: $uri");
      _channel = WebSocketChannel.connect(uri);

      // Release-spezifische Heartbeat-Konfiguration
      _wsHeartbeatTimer?.cancel();
      int heartbeatInterval;
      if (isReleaseMode) {
        // Release-Modus: Häufigere Heartbeats für stabilere Verbindung
        heartbeatInterval = 8; // 8 Sekunden statt 10
        print("🔧 Release-Modus: Verwende häufigeren Heartbeat (8s)");
      } else {
        // Debug-Modus: Normale Heartbeats
        heartbeatInterval = 10;
        print("🔧 Debug-Modus: Verwende normalen Heartbeat (10s)");
      }
      
      _wsHeartbeatTimer = Timer.periodic(Duration(seconds: heartbeatInterval), (_) {
        try {
          if (_channel != null && !_isDisconnecting) {
            _channel?.sink.add('{"type":"ping","timestamp":"${DateTime.now().toIso8601String()}"}');
            print("↪️ WS ping gesendet - ${DateTime.now().toIso8601String()}");
          }
        } catch (e) {
          print("❌ Fehler beim Senden des Heartbeats: $e");
          // Bei Heartbeat-Fehler Verbindung neu aufbauen
          _scheduleReconnect();
        }
      });

      // Token-Validierung alle 5 Minuten
      Timer.periodic(Duration(minutes: 5), (_) {
        _validateAndRefreshToken();
      });

      // Verbesserte Stream-Behandlung mit robusterer Fehlerbehandlung
      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            print("📥 WebSocket Nachricht empfangen: $data");
            
            // Benachrichtige alle Listener mit robusterer Fehlerbehandlung
            final listenersToNotify = List<void Function(Map<String, dynamic> data)>.from(_webSocketListeners);
            for (var listener in listenersToNotify) {
              try {
                listener(data);
              } catch (e) {
                print("❌ Fehler in WebSocket-Listener: $e");
                // Entferne fehlerhafte Listener
                _webSocketListeners.remove(listener);
              }
            }
          } catch (e) {
            print("❌ Fehler beim Parsen der WebSocket-Nachricht: $e");
            print("❌ Rohe Nachricht: $message");
          }
        },
        onError: (error) {
          print("❌ WebSocket Fehler: $error");
          print("❌ Fehler-Typ: ${error.runtimeType}");
          print("❌ Fehler-Details: $error");
          
          // Spezifische Fehlerbehandlung
          if (error.toString().contains('HTTP status code: 500')) {
            print("⚠️ Server-Problem erkannt. Versuche später erneut...");
          } else if (error.toString().contains('Connection refused')) {
            print("⚠️ Verbindung verweigert. Server möglicherweise nicht erreichbar.");
          } else if (error.toString().contains('HandshakeException')) {
            print("⚠️ Handshake-Fehler. Möglicherweise SSL/TLS-Problem.");
          } else if (error.toString().contains('SocketException')) {
            print("⚠️ Socket-Fehler. Netzwerk-Problem.");
          } else if (error.toString().contains('WebSocketException')) {
            print("⚠️ WebSocket-spezifischer Fehler.");
          } else if (error.toString().contains('timeout')) {
            print("⚠️ Timeout-Fehler. Verbindung zu langsam.");
          }
          
          // Benachrichtige alle Error-Listener mit robusterer Fehlerbehandlung
          final errorListenersToNotify = List<void Function(dynamic error)?>.from(_webSocketErrorListeners);
          for (var errorListener in errorListenersToNotify) {
            if (errorListener != null) {
              try {
                errorListener(error);
              } catch (e) {
                print("❌ Fehler in Error-Listener: $e");
                // Entferne fehlerhafte Error-Listener
                _webSocketErrorListeners.remove(errorListener);
              }
            }
          }
          
          _cleanupWebSocket();
          
          // Automatischer Reconnect nach Fehler
          if (enableReconnect) {
            _scheduleReconnect();
          }
        },
        onDone: () {
          print("🔌 WebSocket Verbindung geschlossen.");
          _cleanupWebSocket();
          
          // Automatischer Reconnect nach Verbindungsende
          if (enableReconnect) {
            _scheduleReconnect();
          }
        },
        cancelOnError: false,
      );
      
      _isConnecting = false;
      _reconnectAttempts = 0; // Reset bei erfolgreicher Verbindung
      print("✅ WebSocket-Verbindung erfolgreich aufgebaut");
      
      // Starte Auto-Reconnect-Monitoring
      _startAutoReconnectMonitoring();
      
      // Release-spezifische Verbindungsvalidierung
      if (isReleaseMode) {
        print("🔧 Release-Modus: Führe Verbindungsvalidierung durch...");
        // Warte kurz und prüfe dann die Verbindung
        Timer(const Duration(seconds: 2), () {
          if (_channel != null && _webSocketListeners.isNotEmpty) {
            print("🔧 Release-Modus: Verbindung validiert - ${_webSocketListeners.length} Listener aktiv");
            // Sende einen Test-Ping zur Validierung
            try {
              _channel?.sink.add('{"type":"ping","timestamp":"${DateTime.now().toIso8601String()}","validation":true}');
              print("🔧 Release-Modus: Validierungs-Ping gesendet");
            } catch (e) {
              print("❌ Release-Modus: Validierungs-Ping fehlgeschlagen: $e");
            }
          } else {
            print("⚠️ Release-Modus: Verbindungsvalidierung fehlgeschlagen");
            print("  - Channel null: ${_channel == null}");
            print("  - Listener vorhanden: ${_webSocketListeners.isNotEmpty}");
          }
        });
      }
      
    } catch (e) {
      print("❌ Fehler beim Aufbau der WebSocket-Verbindung: $e");
      _isConnecting = false;
      
      // Benachrichtige alle Error-Listener mit robusterer Fehlerbehandlung
      final errorListenersToNotify = List<void Function(dynamic error)?>.from(_webSocketErrorListeners);
      for (var errorListener in errorListenersToNotify) {
        if (errorListener != null) {
          try {
            errorListener(e);
          } catch (listenerError) {
            print("❌ Fehler in Error-Listener: $listenerError");
            // Entferne fehlerhafte Error-Listener
            _webSocketErrorListeners.remove(errorListener);
          }
        }
      }
      
      _cleanupWebSocket();
      
      // Automatischer Reconnect nach Fehler
      if (enableReconnect) {
        _scheduleReconnect();
      }
    }
  }

  // Token-Validierung und Erneuerung
  Future<void> _validateAndRefreshToken() async {
    if (_accessToken == null || _loggedInUser == null) {
      print("⚠️ Kein Token oder User für Validierung vorhanden");
      return;
    }

    try {
      print("🔍 Validiere Token...");
      final response = await http.get(
        Uri.parse('$baseUrl/api/status'),
        headers: _authHeaders,
      );
      
      if (response.statusCode == 401) {
        print("⚠️ Token abgelaufen - versuche automatische Erneuerung...");
        // Hier könnte man einen Refresh-Token-Mechanismus implementieren
        // Für jetzt: WebSocket neu verbinden
        if (_webSocketListeners.isNotEmpty) {
          print("🔄 Token abgelaufen - WebSocket neu verbinden...");
          disconnectWebSocket();
          Future.delayed(Duration(seconds: 2), () {
            if (_webSocketListeners.isNotEmpty) {
              _connectToWebSocket();
            }
          });
        }
      } else if (response.statusCode == 200) {
        print("✅ Token ist noch gültig");
      }
    } catch (e) {
      print("❌ Fehler bei Token-Validierung: $e");
    }
  }

  void _cleanupWebSocket() {
    _channel?.sink.close();
    _channel = null;
    _wsHeartbeatTimer?.cancel();
    _wsHeartbeatTimer = null;
    _isConnecting = false;
    _stopAutoReconnectMonitoring(); // Stoppe Auto-Reconnect-Monitoring beim Cleanup
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("❌ Maximale Reconnect-Versuche erreicht. Stoppe automatische Verbindungsversuche.");
      return;
    }
    
    if (_webSocketListeners.isEmpty) {
      print("ℹ️ Keine WebSocket-Listener mehr vorhanden. Kein Reconnect nötig.");
      return;
    }
    
    _reconnectAttempts++;
    final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
    
    // Angepasste Reconnect-Verzögerung für Release-Modus
    int delaySeconds;
    if (isReleaseMode) {
      // Release-Modus: Längere Verzögerungen für stabilere Verbindung
      delaySeconds = _reconnectAttempts * 3; // 3, 6, 9, 12, 15 Sekunden
      print("🔧 Release-Modus: Verwende längere Reconnect-Verzögerungen");
    } else {
      // Debug-Modus: Normale Verzögerungen
      delaySeconds = _reconnectAttempts * 2; // 2, 4, 6, 8, 10 Sekunden
    }
    
    final delay = Duration(seconds: delaySeconds);
    
    print("🔄 Plane Reconnect in ${delay.inSeconds} Sekunden (Versuch $_reconnectAttempts/$_maxReconnectAttempts)");
    print("🔧 Build-Modus: ${isReleaseMode ? 'Release' : 'Debug'}");
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_channel == null && _accessToken != null && _webSocketListeners.isNotEmpty && !_isDisconnecting) {
        print("🔄 Führe Reconnect durch...");
        print("🔧 Aktive Listener: ${_webSocketListeners.length}");
        _connectToWebSocket(enableReconnect: true);
      } else {
        print("⚠️ Reconnect abgebrochen - Bedingungen nicht erfüllt");
        print("  - Channel null: ${_channel == null}");
        print("  - AccessToken vorhanden: ${_accessToken != null}");
        print("  - Listener vorhanden: ${_webSocketListeners.isNotEmpty}");
        print("  - Nicht beim Trennen: ${!_isDisconnecting}");
      }
    });
  }

  void disconnectWebSocket() {
    print("❌ WebSocket wird manuell geschlossen...");
    _isDisconnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _stopAutoReconnectMonitoring(); // Stoppe Auto-Reconnect-Monitoring
    _cleanupWebSocket();
    _isDisconnecting = false;
  }

  // Hilfsmethode zum Testen der WebSocket-Verbindung
  bool isWebSocketConnected() {
    return _channel != null && !_isConnecting && !_isDisconnecting;
  }

  // Hilfsmethode zum manuellen Senden von Nachrichten
  void sendWebSocketMessage(Map<String, dynamic> message) {
    if (_channel != null && !_isDisconnecting) {
      try {
        final jsonMessage = json.encode(message);
        _channel!.sink.add(jsonMessage);
        print("📤 WebSocket Nachricht gesendet: $jsonMessage");
      } catch (e) {
        print("❌ Fehler beim Senden der WebSocket-Nachricht: $e");
      }
    } else {
      print("⚠️ WebSocket nicht verbunden. Nachricht kann nicht gesendet werden.");
    }
  }

  // Debug-Methoden für WebSocket-Status
  int getWebSocketListenerCount() {
    return _webSocketListeners.length;
  }

  int getWebSocketErrorListenerCount() {
    return _webSocketErrorListeners.length;
  }

  // Methode zum manuellen Reconnect
  void forceReconnect() {
    print("🔄 Manueller WebSocket-Reconnect wird erzwungen...");
    disconnectWebSocket();
    Future.delayed(Duration(seconds: 1), () {
      if (_webSocketListeners.isNotEmpty) {
        _connectToWebSocket(enableReconnect: true);
      }
    });
  }

  // Test-Methode für WebSocket-Verbindung
  Future<bool> testWebSocketConnection() async {
    if (_accessToken == null) {
      print("❌ Kein AccessToken für WebSocket-Test");
      return false;
    }

    print("🧪 Teste WebSocket-Verbindung...");
    final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
    print("🔍 Build-Modus: ${isReleaseMode ? 'Release' : 'Debug'}");
    
    try {
      // Teste verschiedene WebSocket-URLs basierend auf Build-Modus
      final testUrls = [
        'wss://iqmedix.cloud/ws/notes?token=$_accessToken',
        'wss://iqmedix.cloud:8443/ws/notes?token=$_accessToken',
        'wss://iqmedix.cloud/api/ws/notes?token=$_accessToken',
      ];

      for (int i = 0; i < testUrls.length; i++) {
        final testUrl = testUrls[i];
        print("🧪 Teste URL ${i + 1}: $testUrl");
        
        try {
          final testChannel = WebSocketChannel.connect(Uri.parse(testUrl));
          
          // Warte auf Verbindung oder Timeout
          bool connected = false;
          bool receivedPong = false;
          Timer? timeoutTimer;
          
          timeoutTimer = Timer(Duration(seconds: 10), () {
            if (!connected) {
              print("⏰ Timeout für URL ${i + 1}");
              testChannel.sink.close();
            }
          });
          
          testChannel.stream.listen(
            (message) {
              connected = true;
              print("📥 Test-Nachricht empfangen: $message");
              
              // Prüfe ob es eine Pong-Nachricht ist
              if (message is String && message.contains('"type":"pong"')) {
                receivedPong = true;
                print("✅ Pong-Nachricht empfangen - Verbindung funktioniert!");
              }
              
              // Schließe Test-Verbindung nach erfolgreicher Nachricht
              timeoutTimer?.cancel();
              testChannel.sink.close();
            },
            onError: (error) {
              timeoutTimer?.cancel();
              print("❌ WebSocket-Test fehlgeschlagen für URL ${i + 1}: $error");
              print("❌ Fehler-Typ: ${error.runtimeType}");
            },
            onDone: () {
              timeoutTimer?.cancel();
              if (connected) {
                print("✅ WebSocket-Test abgeschlossen für URL ${i + 1}");
              }
            },
          );
          
          // Sende Ping-Nachricht nach kurzer Verzögerung
          Timer(Duration(milliseconds: 500), () {
            if (!connected) {
              testChannel.sink.add('{"type":"ping","timestamp":"${DateTime.now().toIso8601String()}"}');
              print("↪️ Ping-Nachricht gesendet für Test");
            }
          });
          
          // Warte auf Ergebnis
          await Future.delayed(Duration(seconds: 12));
          
          if (connected && receivedPong) {
            print("✅ Beste WebSocket-URL gefunden: $testUrl");
            return true;
          } else if (connected) {
            print("⚠️ Verbindung hergestellt, aber kein Pong empfangen für URL ${i + 1}");
          }
          
        } catch (e) {
          print("❌ Fehler beim Testen von URL ${i + 1}: $e");
          print("❌ Fehler-Typ: ${e.runtimeType}");
        }
      }
      
      print("❌ Keine funktionierende WebSocket-URL gefunden");
      return false;
      
    } catch (e) {
      print("❌ WebSocket-Test fehlgeschlagen: $e");
      return false;
    }
  }

  // Test-Broadcast vom Server anfordern
  Future<bool> testServerBroadcast() async {
    try {
      print("🧪 Fordere Test-Broadcast vom Server an...");
      final response = await http.post(
        Uri.parse('$baseUrl/api/debug/broadcast'),
        headers: _authHeaders,
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print("✅ Test-Broadcast angefordert: $result");
        return true;
      } else {
        print("❌ Test-Broadcast fehlgeschlagen: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ Fehler beim Test-Broadcast: $e");
      return false;
    }
  }

  // WebSocket-Status vom Server abfragen
  Future<Map<String, dynamic>?> getWebSocketStatus() async {
    try {
      print("🔍 Frage WebSocket-Status vom Server ab...");
      final response = await http.get(
        Uri.parse('$baseUrl/api/debug/websocket'),
        headers: _authHeaders,
      );
      
      if (response.statusCode == 200) {
        final status = json.decode(response.body);
        print("📊 WebSocket-Status vom Server: $status");
        return status;
      } else {
        print("❌ WebSocket-Status-Abfrage fehlgeschlagen: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Fehler beim Abfragen des WebSocket-Status: $e");
      return null;
    }
  }

  // Direkter WebSocket-Test
  Future<Map<String, dynamic>?> testDirectWebSocket() async {
    try {
      print("🧪 Führe direkten WebSocket-Test durch...");
      final response = await http.post(
        Uri.parse('$baseUrl/api/debug/test-websocket'),
        headers: _authHeaders,
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print("✅ Direkter WebSocket-Test abgeschlossen: $result");
        return result;
      } else {
        print("❌ Direkter WebSocket-Test fehlgeschlagen: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Fehler beim direkten WebSocket-Test: $e");
      return null;
    }
  }

  // Test Backend-Verbindung direkt
  Future<bool> testBackendConnection() async {
    try {
      print("🧪 Teste Backend-Verbindung direkt...");
      final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
      print("🔍 Build-Modus: ${isReleaseMode ? 'Release' : 'Debug'}");
      
      // Teste verschiedene Backend-Endpoints
      final testEndpoints = [
        '$baseUrl/api/status',
        '$baseUrl/status',
        '$baseUrl/api/debug/websocket',
      ];
      
      for (int i = 0; i < testEndpoints.length; i++) {
        final endpoint = testEndpoints[i];
        print("🧪 Teste Endpoint ${i + 1}: $endpoint");
        
        try {
          final response = await http.get(
            Uri.parse(endpoint),
            headers: _authHeaders,
          );
          
          print("✅ Endpoint ${i + 1} erreichbar: ${response.statusCode}");
          print("📄 Response Headers: ${response.headers}");
          if (response.statusCode == 200) {
            final body = json.decode(response.body);
            print("📄 Response Body: $body");
          }
        } catch (e) {
          print("❌ Endpoint ${i + 1} nicht erreichbar: $e");
          print("❌ Fehler-Typ: ${e.runtimeType}");
        }
      }
      
      return true;
    } catch (e) {
      print("❌ Fehler beim Backend-Verbindungstest: $e");
      return false;
    }
  }

  // Teste Netzwerk-Konfiguration
  Future<void> testNetworkConfiguration() async {
    print("🌐 Teste Netzwerk-Konfiguration...");
    final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
    print("🔍 Build-Modus: ${isReleaseMode ? 'Release' : 'Debug'}");
    print("🔍 BaseUrl: $baseUrl");
    print("🔍 AccessToken vorhanden: ${_accessToken != null}");
    print("🔍 AccessToken Länge: ${_accessToken?.length ?? 0}");
    
    // Teste verschiedene Netzwerk-Konfigurationen
    final testUrls = [
      'https://iqmedix.cloud/api/status',
      'https://iqmedix.cloud/status',
      'wss://iqmedix.cloud/ws/notes',
    ];
    
    for (int i = 0; i < testUrls.length; i++) {
      final testUrl = testUrls[i];
      print("🌐 Teste Netzwerk-URL ${i + 1}: $testUrl");
      
      try {
        if (testUrl.startsWith('wss://')) {
          // WebSocket-Test
          final uri = Uri.parse(testUrl);
          print("🌐 WebSocket URI: $uri");
          print("🌐 WebSocket Host: ${uri.host}");
          print("🌐 WebSocket Port: ${uri.port}");
          print("🌐 WebSocket Path: ${uri.path}");
        } else {
          // HTTP-Test
          final response = await http.get(Uri.parse(testUrl));
          print("🌐 HTTP Response: ${response.statusCode}");
        }
      } catch (e) {
        print("🌐 Netzwerk-Fehler für URL ${i + 1}: $e");
      }
    }
  }

  Future<List<List<Note>>> fetchGroupedNotes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/notes/grouped'),
      headers: _authHeaders,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map<List<Note>>((group) {
        return group.map<Note>((json) => Note.fromJson(json)).toList();
      }).toList();
    } else {
      throw Exception('Fehler beim Laden der gruppierten Notizen');
    }
  }

  Future<Note?> fetchNoteById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/notes/$id'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return Note.fromJson(jsonDecode(response.body));
    }
    if (response.statusCode == 404) return null;
    throw Exception('Fehler: ${response.statusCode}');
  }

  Future<List<CrmEntry>> fetchCrmEntries() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/crm/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) => CrmEntry.fromJson(e)).toList();
    } else {
      throw Exception(
        "CRM-Daten konnten nicht geladen werden: ${response.statusCode}",
      );
    }
  }

  Future<void> createCrmEntry(CrmEntry entry) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/crm/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
      body: jsonEncode(entry.toJson()),
    );

    if (response.statusCode != 201) {
      throw Exception("Fehler beim Erstellen: ${response.statusCode}");
    }
  }

  Future<void> updateCrmEntry(CrmEntry entry) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/crm/${entry.id}'),
      headers: _authHeaders,
      body: jsonEncode(entry.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception("Fehler beim Aktualisieren: ${response.statusCode}");
    }
  }

  Future<void> deleteCrmEntry(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/crm/$id'),
      headers: _authHeaders,
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw Exception('Unauthorized: Bitte erneut einloggen.');
      }
      throw Exception('Fehler beim Löschen (${response.statusCode})');
    }
  }

  Future<bool> checkServerStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/status'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['status'] == 'ok';
      }
    } catch (_) {
      return false;
    }
    return false;
  }
}
