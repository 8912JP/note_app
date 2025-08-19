import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

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
      // In Release keine Logs spammen
      // Teste die Verbindung nach kurzer Verzögerung
      Timer(const Duration(seconds: 2), () {
        testWebSocketConnection();
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
    
    // Aktualisiere Tracking-Icons bei allen Note-Events
    for (final updater in _trackingIconUpdaters) {
      try {
        updater();
      } catch (e) {
        // Fehler still behandeln
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
    _trackingIconUpdaters.add(updater);
    _dlog("📡 Tracking-Icon Updater registriert. Gesamt: ${_trackingIconUpdaters.length}");
  }

  // Entferne Tracking-Icon Updater
  void unregisterTrackingIconUpdater(Function() updater) {
    _trackingIconUpdaters.remove(updater);
    _dlog("📡 Tracking-Icon Updater entfernt");
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
}
