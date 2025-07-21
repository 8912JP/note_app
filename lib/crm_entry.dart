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

  // ✅ FROM JSON
  factory CrmEntry.fromJson(Map<String, dynamic> json) {
    return CrmEntry(
      id: json['id'],
      anfrageDatum: DateTime.parse(json['anfrage_datum']),
      titel: json['titel'],
      vorname: json['vorname'],
      nachname: json['nachname'],
      adresse: json['adresse'],
      email: json['email'],
      mobil: json['mobil'],
      festnetz: json['festnetz'],
      krankheitsstatus: json['krankheitsstatus'],
      todos: (json['todos'] as List<dynamic>).map((e) => ToDoItem.fromJson(e)).toList(),
      status: json['status'],
      bearbeiter: json['bearbeiter'],
      wiedervorlage: json['wiedervorlage'] != null ? DateTime.tryParse(json['wiedervorlage']) : null,
      typ: json['typ'],
      stadium: json['stadium'],
      kontaktquelle: json['kontaktquelle'],
      erledigt: json['erledigt'] ?? false,
    );
  }

  // ✅ TO JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anfrage_datum': anfrageDatum.toIso8601String(),
      'titel': titel,
      'vorname': vorname,
      'nachname': nachname,
      'adresse': adresse,
      'email': email,
      'mobil': mobil,
      'festnetz': festnetz,
      'krankheitsstatus': krankheitsstatus,
      'todos': todos.map((e) => e.toJson()).toList(),
      'status': status,
      'bearbeiter': bearbeiter,
      'wiedervorlage': wiedervorlage?.toIso8601String(),
      'typ': typ,
      'stadium': stadium,
      'kontaktquelle': kontaktquelle,
      'erledigt': erledigt,
    };
  }
}

class ToDoItem {
  String text;
  bool done;

  ToDoItem({required this.text, this.done = false});

  factory ToDoItem.fromJson(Map<String, dynamic> json) {
    return ToDoItem(
      text: json['text'],
      done: json['done'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'done': done,
      };
}
