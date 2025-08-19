import 'note.dart';

// Zentrale Note-Cache-Verwaltung für Tracking-Icons
class NoteCacheManager {
  static final NoteCacheManager _instance = NoteCacheManager._internal();
  NoteCacheManager._internal();
  factory NoteCacheManager() => _instance;

  // Cache für Note-Informationen: Key = "crmEntryId_trackingType"
  final Map<String, Note?> _noteCache = <String, Note?>{};

  // Aktualisiere Note im Cache
  void updateNote(Note note) {
    final crmEntryId = note.crmEntryId?.toString() ?? '';
    final trackingType = note.trackingType ?? '';
    if (crmEntryId.isNotEmpty && trackingType.isNotEmpty) {
      final cacheKey = '${crmEntryId}_$trackingType';
      _noteCache[cacheKey] = note;
      print("💾 Note-Cache aktualisiert: $cacheKey (ID: ${note.id}, Done: ${note.isDone})");
    }
  }

  // Entferne Note aus Cache (bei Löschung)
  void removeNote(String crmEntryId, String trackingType) {
    final cacheKey = '${crmEntryId}_$trackingType';
    _noteCache.remove(cacheKey);
    print("🗑️ Note aus Cache entfernt: $cacheKey");
  }

  // Hole Note aus Cache
  Note? getNote(String crmEntryId, String trackingType) {
    final cacheKey = '${crmEntryId}_$trackingType';
    return _noteCache[cacheKey];
  }

  // Prüfe ob Note im Cache existiert
  bool hasNote(String crmEntryId, String trackingType) {
    final cacheKey = '${crmEntryId}_$trackingType';
    return _noteCache.containsKey(cacheKey);
  }

  // Cache leeren
  void clearCache() {
    _noteCache.clear();
    print("🧹 Note-Cache geleert");
  }

  // Debug-Informationen
  void debugInfo() {
    print("📊 Note-Cache Debug Info:");
    print("  - Cache-Einträge: ${_noteCache.length}");
    for (final entry in _noteCache.entries) {
      final note = entry.value;
      print("    - ${entry.key}: ID=${note?.id}, Done=${note?.isDone}");
    }
  }
}
