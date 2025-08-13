import 'dart:convert';
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
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/notes/${note.id}'),
        headers: _authHeaders,
        body: json.encode(note.toJson()),
      );
      if (response.statusCode == 200) {
        return Note.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Bitte erneut einloggen.');
      } else if (response.statusCode == 404) {
        throw Exception('Server nicht verfügbar (404). Bitte starten Sie den Backend-Server.');
      } else {
        throw Exception('Fehler beim Aktualisieren (${response.statusCode})');
      }
    } catch (e) {
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
  List<void Function(Map<String, dynamic> data)> _webSocketListeners = [];
  List<void Function(dynamic error)?> _webSocketErrorListeners = [];
  
  void addWebSocketListener(void Function(Map<String, dynamic> data) listener, void Function(dynamic error)? errorListener) {
    _webSocketListeners.add(listener);
    if (errorListener != null) {
      _webSocketErrorListeners.add(errorListener);
    }
    
    // Wenn noch keine Verbindung existiert, eine aufbauen
    if (_channel == null) {
      _connectToWebSocket();
    }
  }
  
  void removeWebSocketListener(void Function(Map<String, dynamic> data) listener) {
    _webSocketListeners.remove(listener);
    
    // Wenn keine Listener mehr vorhanden sind, Verbindung schließen
    if (_webSocketListeners.isEmpty) {
      disconnectWebSocket();
    }
  }
  
  void _connectToWebSocket({
    bool enableReconnect = true,
  }) {
    if (_accessToken == null) {
      print("⚠️ Kein AccessToken vorhanden. WebSocket wird nicht verbunden.");
      return;
    }

    // Prüfe ob bereits eine Verbindung existiert
    if (_channel != null) {
      print("⚠️ WebSocket-Verbindung bereits aktiv.");
      return;
    }

    // WebSocket über Node.js-Proxy aktiviert
    print("🔌 WebSocket wird über Node.js-Proxy aktiviert");

    try {
      // WebSocket über Node.js-Proxy
      String wsUrl;
      
      // WebSocket-URL-Konstruktion mit Fallback-Optionen
      if (baseUrl.startsWith('https')) {
        // Primäre WebSocket-URL
        wsUrl = 'wss://iqmedix.cloud/ws/notes?token=$_accessToken';
        
        // Alternative URLs für Fallback-Tests
        // wsUrl = 'wss://iqmedix.cloud/api/ws/notes?token=$_accessToken';
        // wsUrl = 'wss://iqmedix.cloud:8443/ws/notes?token=$_accessToken';
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
      
      print("🔌 Verbinde WebSocket: $wsUrl");
      print("🔌 baseUrl: $baseUrl");
      
      // Verwende WebSocketChannel.connect direkt mit String-URL
      final uri = Uri.parse(wsUrl);
      print("🔌 Parsed URI: $uri");
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            print("📥 WebSocket Nachricht: $data");
            
            // Benachrichtige alle Listener
            for (var listener in _webSocketListeners) {
              listener(data);
            }
          } catch (e) {
            print("❌ Fehler beim Parsen der WebSocket-Nachricht: $e");
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
          
          // Benachrichtige alle Error-Listener
          for (var errorListener in _webSocketErrorListeners) {
            if (errorListener != null) errorListener(error);
          }
          _channel = null;
          
          // Automatischer Reconnect nach 5 Sekunden, aber nur wenn nicht manuell getrennt
          if (enableReconnect) {
            Future.delayed(const Duration(seconds: 5), () {
              if (_channel == null && _accessToken != null && _webSocketListeners.isNotEmpty) {
                print("🔄 Versuche Reconnect nach Fehler...");
                _connectToWebSocket(enableReconnect: enableReconnect);
              }
            });
          }
        },
        onDone: () {
          print("🔌 WebSocket Verbindung geschlossen.");
          _channel = null;
          
          // Automatischer Reconnect nach 5 Sekunden, aber nur wenn nicht manuell getrennt
          if (enableReconnect) {
            Future.delayed(const Duration(seconds: 5), () {
              if (_channel == null && _accessToken != null && _webSocketListeners.isNotEmpty) {
                print("🔄 Versuche Reconnect nach Verbindungsende...");
                _connectToWebSocket(enableReconnect: enableReconnect);
              }
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      print("❌ Fehler beim Aufbau der WebSocket-Verbindung: $e");
      
      // Benachrichtige alle Error-Listener
      for (var errorListener in _webSocketErrorListeners) {
        if (errorListener != null) errorListener(e);
      }
      _channel = null;
    }
  }

  void disconnectWebSocket() {
    print("❌ WebSocket wird geschlossen...");
    _channel?.sink.close();
    _channel = null;
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
