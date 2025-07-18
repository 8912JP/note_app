class CrmEntry {
  final String id;
  final DateTime anfrageDatum;
  final String titel;
  final String vorname;
  final String nachname;
  final String adresse;
  final String email;
  final String mobil;
  final String festnetz;
  final String krankheitsstatus;
  final List<ToDoItem> todos;
  final String status;
  final String bearbeiter;
  final DateTime? wiedervorlage;
  final String? typ;
  final String stadium;
  final String kontaktquelle;
  bool erledigt;

  CrmEntry({
    required this.id,
    required this.anfrageDatum,
    required this.titel,
    required this.vorname,
    required this.nachname,
    required this.adresse,
    required this.email,
    required this.mobil,
    required this.festnetz,
    required this.krankheitsstatus,
    required this.todos,
    required this.status,
    required this.bearbeiter,
    required this.wiedervorlage,
    required this.typ,
    required this.stadium,
    required this.kontaktquelle,
    this.erledigt = false,
  });

  String get fullName => '$vorname $nachname';
  String get todoSummary => todos.map((t) => t.done ? '✓ ${t.text}' : '• ${t.text}').join('\n');
}

class ToDoItem {
  String text;
  bool done;

  ToDoItem({required this.text, this.done = false});
}
