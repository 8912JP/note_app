import 'dart:developer';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  NotificationService._internal();
  factory NotificationService() => _instance;

  // Speichere Timestamps der letzten gesehenen Änderungen
  DateTime? _lastNoteUpdate;
  DateTime? _lastCrmUpdate;
  
  // Speichere IDs der letzten gesehenen Änderungen (um Status-Änderungen zu erkennen)
  int? _lastNoteId;
  int? _lastCrmId;
  
  // Aktueller Benutzer (wird vom ApiService gesetzt)
  String? _currentUser;
  
  // Callback-Funktionen für UI-Updates
  void Function()? _onNoteNotificationChanged;
  void Function()? _onCrmNotificationChanged;

  // Getter für UI
  bool get hasNewNotes => _lastNoteUpdate != null;
  bool get hasNewCrmEntries => _lastCrmUpdate != null;

  // Registriere Callbacks für UI-Updates
  void setNoteNotificationCallback(void Function() callback) {
    _onNoteNotificationChanged = callback;
  }

  void setCrmNotificationCallback(void Function() callback) {
    _onCrmNotificationChanged = callback;
  }

  // Entferne Callbacks
  void removeNoteNotificationCallback() {
    _onNoteNotificationChanged = null;
  }

  void removeCrmNotificationCallback() {
    _onCrmNotificationChanged = null;
  }

  // Setze aktuellen Benutzer
  void setCurrentUser(String? username) {
    _currentUser = username;
    log("👤 Aktueller Benutzer gesetzt: $username");
  }

  // Verarbeite WebSocket-Events
  void handleWebSocketEvent(Map<String, dynamic> data) {
    try {
      final event = data['event'] as String?;
      final timestamp = data['timestamp'] as String?;
      final user = data['user'] as String?; // Benutzer der die Änderung gemacht hat
      // ID kann als String oder int kommen, konvertiere sicher zu int?
      final idRaw = data['id'];
      final id = idRaw is int ? idRaw : (idRaw is String ? int.tryParse(idRaw) : null);
      
      if (timestamp == null) return;
      
      // Ignoriere eigene Änderungen
      if (user != null && _currentUser != null && user == _currentUser) {
        log("👤 Eigene Änderung ignoriert: $event von $user");
        return;
      }
      
      final eventTime = DateTime.parse(timestamp);
      
      switch (event) {
        case 'note_created':
        case 'note_updated':
        case 'note_deleted':
          _handleNoteEvent(eventTime, id);
          break;
        case 'crm_created':
        case 'crm_updated':
        case 'crm_deleted':
          _handleCrmEvent(eventTime, id);
          break;
      }
    } catch (e) {
      log("❌ Fehler beim Verarbeiten des WebSocket-Events: $e");
    }
  }

  void _handleNoteEvent(DateTime eventTime, int? id) {
    // Notification bei neuer Note oder Status-Änderung
    bool shouldNotify = false;
    
    if (_lastNoteUpdate == null) {
      // Erste Änderung
      shouldNotify = true;
    } else if (eventTime.isAfter(_lastNoteUpdate!)) {
      // Neue Änderung (neue Note oder Update)
      shouldNotify = true;
    } else if (id != null && _lastNoteId != null && id == _lastNoteId) {
      // Gleiche Note, aber Status-Änderung (z.B. "erledigt" markieren)
      shouldNotify = true;
    }
    
    if (shouldNotify) {
      _lastNoteUpdate = eventTime;
      _lastNoteId = id;
      log("📝 Note-Änderung erkannt: $eventTime (ID: $id)");
      _onNoteNotificationChanged?.call();
    }
  }

  void _handleCrmEvent(DateTime eventTime, int? id) {
    // Notification bei neuem CRM-Eintrag oder Status-Änderung
    bool shouldNotify = false;
    
    if (_lastCrmUpdate == null) {
      // Erste Änderung
      shouldNotify = true;
    } else if (eventTime.isAfter(_lastCrmUpdate!)) {
      // Neue Änderung (neuer Eintrag oder Update)
      shouldNotify = true;
    } else if (id != null && _lastCrmId != null && id == _lastCrmId) {
      // Gleicher Eintrag, aber Status-Änderung
      shouldNotify = true;
    }
    
    if (shouldNotify) {
      _lastCrmUpdate = eventTime;
      _lastCrmId = id;
      log("📊 CRM-Änderung erkannt: $eventTime (ID: $id)");
      _onCrmNotificationChanged?.call();
    }
  }

  // Markiere als "gesehen" (wird aufgerufen, wenn User die Seite öffnet)
  void markNotesAsSeen() {
    _lastNoteUpdate = null;
    _lastNoteId = null;
    log("✅ Notes als gesehen markiert");
    _onNoteNotificationChanged?.call();
  }

  void markCrmAsSeen() {
    _lastCrmUpdate = null;
    _lastCrmId = null;
    log("✅ CRM als gesehen markiert");
    _onCrmNotificationChanged?.call();
  }

  // Debug-Methoden
  void debugPrintStatus() {
    log("🔔 Notification Status:");
    log("  - Notes: ${hasNewNotes ? 'NEU' : 'OK'} ($_lastNoteUpdate)");
    log("  - CRM: ${hasNewCrmEntries ? 'NEU' : 'OK'} ($_lastCrmUpdate)");
  }
}
