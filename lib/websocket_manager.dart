import 'dart:async';
import 'dart:developer';
import 'api_service.dart';
import 'note.dart';
import 'note_cache_manager.dart';

// Globaler WebSocket-Manager für zentrale Event-Verarbeitung
class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  WebSocketManager._internal();
  factory WebSocketManager() => _instance;

  final ApiService _apiService = ApiService();
  
  // Registrierte Event-Handler
  final Map<String, List<Function(Map<String, dynamic>)>> _eventHandlers =
      <String, List<Function(Map<String, dynamic>)>>{};
  
  // Tracking-Icon Updates
  final Set<Function()> _trackingIconUpdaters = <Function()>{};
  
  // Notification Updates
  final Set<Function()> _notificationUpdaters = <Function()>{};
  
  // CRM Updates
  final Set<Function()> _crmUpdaters = <Function()>{};
  
  // Notes Updates - verschiedene Typen für intelligente Updates
  final Set<Function(Map<String, dynamic>)> _notesUpdaters =
      <Function(Map<String, dynamic>)>{};
  final Set<Function()> _notesFullReloadUpdaters = <Function()>{};
  
  bool _isInitialized = false;

  // Debug-Logging nur in Debug-Builds ausführen
  void _dlog(String message) {
    assert(() {
      log(message, name: 'WebSocketManager');
      return true;
    }());
  }

  // Initialisiere den WebSocket-Manager
  void initialize() {
    if (_isInitialized) return;
    
    final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
    _dlog("🔧 Initialisiere WebSocket-Manager (${isReleaseMode ? 'Release' : 'Debug'}-Modus)");
    
    _apiService.addWebSocketListener(_handleWebSocketEvent);
    _isInitialized = true;
    _dlog("📡 WebSocket-Manager initialisiert");
    
    // Release-spezifische Optimierungen
    if (isReleaseMode) {
      _dlog("🔧 Release-Modus: Aktiviere erweiterte WebSocket-Optimierungen");
      
      // Teste die Verbindung nach kurzer Verzögerung
      Timer(const Duration(seconds: 2), () {
        testWebSocketConnection();
      });
      
      // Zusätzliche Verbindungsvalidierung für Release-Builds
      Timer(const Duration(seconds: 10), () {
        if (!_apiService.isWebSocketConnected()) {
          _dlog("⚠️ Release-Modus: WebSocket nicht verbunden nach 10s - versuche Reconnect");
          _apiService.forceReconnect();
        }
      });
    }
  }

  // Cleanup beim Beenden der App
  void dispose() {
    _apiService.removeWebSocketListener(_handleWebSocketEvent);
    _eventHandlers.clear();
    _trackingIconUpdaters.clear();
    _notificationUpdaters.clear();
    _crmUpdaters.clear();
    _notesUpdaters.clear();
    _isInitialized = false;
    _dlog("📡 WebSocket-Manager aufgeräumt");
  }

  // Zentrale Event-Verarbeitung
  void _handleWebSocketEvent(Map<String, dynamic> data) {
    try {
      final event = data['event'] as String?;
      if (event == null) return;

      // Release-Modus: Zeige UI-Benachrichtigung für WebSocket-Events
      final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
      if (isReleaseMode) {
        _dlog("📥 Release-Modus: WebSocket-Event empfangen: $event");
      }

      // Verarbeite Event für Notifications
      _apiService.notificationService.handleWebSocketEvent(data);

      // EINFACHE LÖSUNG: Alle Events behandeln
      switch (event) {
        case 'note_created':
        case 'note_updated':
        case 'note_deleted':
          _handleNoteEvent(data);
          break;
        case 'crm_created':
        case 'crm_updated':
        case 'crm_deleted':
          _handleCrmEvent(data);
          break;
      }

      // Benachrichtige allgemeine Event-Handler
      if (_eventHandlers.containsKey(event)) {
        for (final handler in _eventHandlers[event]!) {
          try {
            handler(data);
          } catch (e) {
            // Fehler still behandeln
          }
        }
      }
    } catch (e) {
      // Fehler still behandeln
    }
  }

  void _handleNoteEvent(Map<String, dynamic> data) {
    final noteData = data['note'] as Map<String, dynamic>?;
    final event = data['event'] as String?;
    
        // Einfache Updates für Tracking-Icons - nur Farbe ändern, keine API-Calls
  if (event == 'note_updated' || event == 'note_created' || event == 'note_deleted') {
    _dlog("🎨 Aktualisiere ${_trackingIconUpdaters.length} Tracking-Icon Farben");
    
    // Aktualisiere Note-Cache wenn Note-Daten vorhanden
    if (noteData != null && event != 'note_deleted') {
      try {
        final note = Note.fromJson(noteData);
        // Aktualisiere Cache für diese spezifische Note
        final crmEntryId = note.crmEntryId?.toString() ?? '';
        final trackingType = note.trackingType ?? '';
        if (crmEntryId.isNotEmpty && trackingType.isNotEmpty) {
          _dlog("💾 Aktualisiere Cache für CRM-ID: $crmEntryId, Tracking-Type: $trackingType");
          // Aktualisiere den Cache direkt
          _updateNoteCache(note, crmEntryId, trackingType);
        }
      } catch (e) {
        _dlog("❌ Fehler beim Parsen der Note-Daten: $e");
      }
    } else if (event == 'note_deleted') {
      // Bei Löschung: Entferne aus Cache basierend auf ID
      final String? id = data['id']?.toString();
      if (id != null) {
        _dlog("🗑️ Entferne Note aus Cache: ID $id");
        // Hier könnten wir den Cache basierend auf der ID leeren
        // Für jetzt aktualisieren wir einfach alle Icons
      }
    }
    
    // Sofortige Updates - nur UI-Rebuild, keine API-Calls
    for (final updater in _trackingIconUpdaters) {
      try {
        updater();
      } catch (e) {
        _dlog("❌ Fehler in Tracking-Icon Updater: $e");
      }
    }
  }
    
    // Intelligente Notes-Updates - nur bei neuen Notes oder Löschungen vollständig neu laden
    if (event == 'note_created' || event == 'note_deleted') {
      // Vollständiges Neuladen nur bei neuen oder gelöschten Notes
      for (final updater in _notesFullReloadUpdaters) {
        try {
          updater();
        } catch (e) {
          // Fehler still behandeln
        }
      }
    } else if (event == 'note_updated') {
      // Bei Updates nur die spezifische Note aktualisieren
      if (noteData != null) {
        for (final updater in _notesUpdaters) {
          try {
            updater(data);
          } catch (e) {
            // Fehler still behandeln
          }
        }
      } else {
        // Fallback: Note laden, wenn Payload fehlt
        final String? id = data['id']?.toString();
        if (id != null) {
          () async {
            try {
              final fetched = await _apiService.fetchNoteById(id);
              if (fetched != null) {
                final Map<String, dynamic> augmented = Map<String, dynamic>.from(data);
                augmented['note'] = fetched.toJson();
                for (final updater in _notesUpdaters) {
                  try {
                    updater(augmented);
                  } catch (e) {
                    // Fehler still behandeln
                  }
                }
              } else {
                // Wenn nicht ladbar, mache Full-Reload
                for (final updater in _notesFullReloadUpdaters) {
                  try { updater(); } catch (_) {}
                }
              }
            } catch (_) {
              for (final updater in _notesFullReloadUpdaters) {
                try { updater(); } catch (_) {}
              }
            }
          }();
        } else {
          // Kein ID-Feld -> Full-Reload
          for (final updater in _notesFullReloadUpdaters) {
            try { updater(); } catch (_) {}
          }
        }
      }
    }
  }

  void _handleCrmEvent(Map<String, dynamic> data) {
    // EINFACHE LÖSUNG: Bei allen CRM-Events vollständig neu laden
    
    // Aktualisiere CRM-Listen
    for (final updater in _crmUpdaters) {
      try {
        updater();
      } catch (e) {
        // Fehler still behandeln
      }
    }

    // Aktualisiere Notifications
    for (final updater in _notificationUpdaters) {
      try {
        updater();
      } catch (e) {
        // Fehler still behandeln
      }
    }
  }

  // Registriere Event-Handler
  void registerEventHandler(String event, Function(Map<String, dynamic>) handler) {
    _eventHandlers.putIfAbsent(event, () => []).add(handler);
    _dlog("📡 Event-Handler für '$event' registriert");
  }

  // Entferne Event-Handler
  void unregisterEventHandler(String event, Function(Map<String, dynamic>) handler) {
    _eventHandlers[event]?.remove(handler);
    if (_eventHandlers[event]?.isEmpty == true) {
      _eventHandlers.remove(event);
    }
    _dlog("📡 Event-Handler für '$event' entfernt");
  }

  // Registriere Tracking-Icon Updater
  void registerTrackingIconUpdater(Function() updater) {
    // Verhindere Duplikate
    if (!_trackingIconUpdaters.contains(updater)) {
      // Begrenze die Anzahl der Tracking-Icon-Updater
      if (_trackingIconUpdaters.length >= 50) {
        _dlog("⚠️ Zu viele Tracking-Icon-Updater (${_trackingIconUpdaters.length}) - entferne älteste");
        _trackingIconUpdaters.remove(_trackingIconUpdaters.first);
      }
      
      _trackingIconUpdaters.add(updater);
      _dlog("📡 Tracking-Icon Updater registriert. Gesamt: ${_trackingIconUpdaters.length}");
    } else {
      _dlog("⚠️ Tracking-Icon Updater bereits registriert - überspringe");
    }
  }

  // Entferne Tracking-Icon Updater
  void unregisterTrackingIconUpdater(Function() updater) {
    _trackingIconUpdaters.remove(updater);
    _dlog("📡 Tracking-Icon Updater entfernt. Verbleibend: ${_trackingIconUpdaters.length}");
  }

  // Entferne Tracking-Icon Updater mit Verzögerung (verhindert Überlastung)
  void unregisterTrackingIconUpdaterDelayed(Function() updater) {
    Timer(const Duration(milliseconds: 100), () {
      _trackingIconUpdaters.remove(updater);
      _dlog("📡 Tracking-Icon Updater verzögert entfernt. Verbleibend: ${_trackingIconUpdaters.length}");
    });
  }

  // Bereinige alle Tracking-Icon-Updater
  void cleanupTrackingIconUpdaters() {
    final count = _trackingIconUpdaters.length;
    _trackingIconUpdaters.clear();
    _dlog("🧹 Tracking-Icon-Updater bereinigt: $count entfernt");
  }

  // Bereinige Tracking-Icon-Updater schrittweise (verhindert Überlastung)
  void cleanupTrackingIconUpdatersGradually() {
    final count = _trackingIconUpdaters.length;
    if (count == 0) return;
    
    _dlog("🧹 Starte schrittweise Bereinigung von $count Tracking-Icon-Updaters");
    
    final updaters = _trackingIconUpdaters.toList();
    _trackingIconUpdaters.clear();
    
    // Entferne Updater in kleinen Gruppen mit Verzögerung
    const batchSize = 3;
    for (int i = 0; i < updaters.length; i += batchSize) {
      final end = (i + batchSize < updaters.length) ? i + batchSize : updaters.length;
      final batch = updaters.sublist(i, end);
      
      Timer(Duration(milliseconds: i * 200), () {
        _dlog("🧹 Entferne Batch ${(i ~/ batchSize) + 1}/${(updaters.length + batchSize - 1) ~/ batchSize} (${batch.length} Updater)");
      });
    }
  }

  // Registriere Notification Updater
  void registerNotificationUpdater(Function() updater) {
    _notificationUpdaters.add(updater);
    _dlog("📡 Notification Updater registriert");
  }

  // Entferne Notification Updater
  void unregisterNotificationUpdater(Function() updater) {
    _notificationUpdaters.remove(updater);
    _dlog("📡 Notification Updater entfernt");
  }

  // Registriere CRM Updater
  void registerCrmUpdater(Function() updater) {
    _crmUpdaters.add(updater);
    _dlog("📡 CRM Updater registriert. Gesamt: ${_crmUpdaters.length}");
  }

  // Entferne CRM Updater
  void unregisterCrmUpdater(Function() updater) {
    _crmUpdaters.remove(updater);
    _dlog("📡 CRM Updater entfernt");
  }

  // Registriere Notes Updater für spezifische Updates
  void registerNotesUpdater(Function(Map<String, dynamic>) updater) {
    _notesUpdaters.add(updater);
    _dlog("📡 Notes Updater (spezifisch) registriert");
  }

  // Entferne Notes Updater
  void unregisterNotesUpdater(Function(Map<String, dynamic>) updater) {
    _notesUpdaters.remove(updater);
    _dlog("📡 Notes Updater (spezifisch) entfernt");
  }

  // Registriere Notes Full-Reload Updater
  void registerNotesFullReloadUpdater(Function() updater) {
    _notesFullReloadUpdaters.add(updater);
    _dlog("📡 Notes Full-Reload Updater registriert");
  }

  // Entferne Notes Full-Reload Updater
  void unregisterNotesFullReloadUpdater(Function() updater) {
    _notesFullReloadUpdaters.remove(updater);
    _dlog("📡 Notes Full-Reload Updater entfernt");
  }

  // Debug-Informationen
  void debugInfo() {
    _dlog("📊 WebSocket-Manager Debug Info:");
    _dlog("  - Event-Handler: ${_eventHandlers.length}");
    _dlog("  - Tracking-Icon Updaters: ${_trackingIconUpdaters.length}");
    _dlog("  - Notification Updaters: ${_notificationUpdaters.length}");
    _dlog("  - CRM Updaters: ${_crmUpdaters.length}");
    _dlog("  - Notes Updaters (spezifisch): ${_notesUpdaters.length}");
    _dlog("  - Notes Updaters (full-reload): ${_notesFullReloadUpdaters.length}");
    _dlog("  - Initialisiert: $_isInitialized");
    _dlog("  - WebSocket verbunden: ${_apiService.isWebSocketConnected()}");
  }

  // Debug-Methode zum Testen der WebSocket-Verbindung
  void testWebSocketConnection() {
    _dlog("🧪 Teste WebSocket-Verbindung...");
    _dlog("  - Manager initialisiert: $_isInitialized");
    _dlog("  - WebSocket verbunden: ${_apiService.isWebSocketConnected()}");
    _dlog("  - Aktive Updater:");
    _dlog("    - Tracking-Icons: ${_trackingIconUpdaters.length}");
    _dlog("    - CRM: ${_crmUpdaters.length}");
    _dlog("    - Notes (spezifisch): ${_notesUpdaters.length}");
    _dlog("    - Notes (full-reload): ${_notesFullReloadUpdaters.length}");
  }

  // Aktualisiere Note-Cache bei WebSocket-Events
  void _updateNoteCache(Note note, String crmEntryId, String trackingType) {
    NoteCacheManager().updateNote(note);
  }

  // Release-Build-spezifische UI-Benachrichtigung
  void showReleaseNotification(String message) {
    final isReleaseMode = const bool.fromEnvironment('dart.vm.product');
    if (isReleaseMode) {
      // In Release-Builds: Zeige SnackBar oder andere UI-Benachrichtigung
      _dlog("🔔 Release-Benachrichtigung: $message");
    }
  }
}
