import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:note_app/note.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'crm_entry.dart';  // dein Modell

class ApiService {
  static final ApiService _instance = ApiService._internal();
  ApiService._internal();
  factory ApiService() => _instance;

  static const String baseUrl = 'http://iqmedix.cloud:8000';
  String? _accessToken;
  String? _loggedInUser;
  String? get loggedInUser => _loggedInUser;
  String? get accessToken => _accessToken;


WebSocketChannel? _channel;

  // ======================== 🔐 AUTH ========================
  Future<bool> login(String username, String password) async {
  final response = await http.post(
    Uri.parse('$baseUrl/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'username': username,
      'password': password,
    },
  );
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    _accessToken = data['access_token'];
    _loggedInUser = username;  // <-- Hier den aktuell eingeloggten User speichern
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
      Uri.parse('$baseUrl/register/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
    return response.statusCode == 200;
  }

  // ======================== 📋 CRUD NOTES ========================
  Future<List<Note>> fetchNotes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notes/'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((e) => Note.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Bitte erneut einloggen.');
    } else {
      throw Exception('Fehler beim Laden der Notizen (${response.statusCode})');
    }
  }

  Future<Note> createNote(Note note) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notes/'),
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
    final response = await http.put(
      Uri.parse('$baseUrl/notes/${note.id}'),
      headers: _authHeaders,
      body: json.encode(note.toJson()),
    );
    if (response.statusCode == 200) {
      return Note.fromJson(json.decode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Bitte erneut einloggen.');
    } else {
      throw Exception('Fehler beim Aktualisieren (${response.statusCode})');
    }
  }

  Future<void> deleteNote(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/notes/$id'),
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
      Uri.parse('$baseUrl/notes/groups/'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map<List<int>>((group) => List<int>.from(group)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Bitte erneut einloggen.');
    } else {
      throw Exception('Fehler beim Abrufen der Gruppen (${response.statusCode})');
    }
  }

  // ======================== 🔄 WEBSOCKET ========================
  void connectToWebSocket({
  required void Function(Map<String, dynamic> data) onEvent,
  void Function(dynamic error)? onError,
}) {
  if (_accessToken == null) {
    print("⚠️ Kein AccessToken vorhanden. WebSocket wird nicht verbunden.");
    return;
  }

  // Dynamisch 'http' oder 'https' → 'ws' bzw. 'wss'
  String wsBaseUrl = baseUrl;
  if (baseUrl.startsWith('https')) {
    wsBaseUrl = baseUrl.replaceFirst('https', 'wss');
  } else if (baseUrl.startsWith('http')) {
    wsBaseUrl = baseUrl.replaceFirst('http', 'ws');
  }

  final uri = Uri.parse('$wsBaseUrl/ws/notes?token=$_accessToken');
  print("🔌 Verbinde WebSocket: $uri");

  try {
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        try {
          final data = json.decode(message);
          print("📥 WebSocket Nachricht: $data");
          onEvent(data);
        } catch (e) {
          print("❌ Fehler beim Parsen der WebSocket-Nachricht: $e");
        }
      },
      onError: (error) {
        print("❌ WebSocket Fehler: $error");
        if (onError != null) onError(error);
      },
      onDone: () {
        print("🔌 WebSocket Verbindung geschlossen.");
      },
      cancelOnError: true,
    );
  } catch (e) {
    print("❌ Fehler beim Aufbau der WebSocket-Verbindung: $e");
    if (onError != null) onError(e);
  }
}

  void disconnectWebSocket() {
    print("❌ WebSocket wird geschlossen...");
    _channel?.sink.close();
    _channel = null;
  }

Future<List<List<Note>>> fetchGroupedNotes() async {
  final response = await http.get(Uri.parse('$baseUrl/notes/grouped'),
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
    Uri.parse('$baseUrl/notes/$id'),
    headers: _authHeaders,
  );
  if (response.statusCode == 200) return Note.fromJson(jsonDecode(response.body));
  if (response.statusCode == 404) return null;
  throw Exception('Fehler: ${response.statusCode}');
}

Future<List<CrmEntry>> fetchCrmEntries() async {
    final response = await http.get(
      Uri.parse('$baseUrl/crm/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) => CrmEntry.fromJson(e)).toList();
    } else {
      throw Exception("CRM-Daten konnten nicht geladen werden: ${response.statusCode}");
    }
  }

  Future<void> createCrmEntry(CrmEntry entry) async {
    final response = await http.post(
      Uri.parse('$baseUrl/crm/'),
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
    Uri.parse('$baseUrl/crm/${entry.id}'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    },
    body: jsonEncode(entry.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception("Fehler beim Aktualisieren: ${response.statusCode}");
  }
}

}

