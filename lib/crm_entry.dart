class CrmEntry {
  final String id;
  final DateTime? anfrageDatum;
  final String? titel; // Anrede (Herr, Frau, etc.)
  final String? vorname;
  final String? nachname;
  final String? adresse; // legacy, nicht mehr genutzt
  final String? strasse;
  final String? hausnummer;
  final String? plz;
  final String? ort;
  final String? land;
  final String? email;
  final String? mobil;
  final String? festnetz;
  final String? krankheitsstatus;
  final List<ToDoItem> todos;
  final String? status;
  final String? bearbeiter;
  final DateTime? wiedervorlage;
  final String? typ;
  final String? stadium;
  final String? kontaktquelle;
  final String? nachricht;
  final String? infos;
  final bool erledigt;

  CrmEntry({
    required this.id,
    this.anfrageDatum,
    this.titel,
    this.vorname,
    this.nachname,
    this.adresse,
    this.strasse,
    this.hausnummer,
    this.plz,
    this.ort,
    this.land,
    this.email,
    this.mobil,
    this.festnetz,
    this.krankheitsstatus,
    this.todos = const [],
    this.status,
    this.bearbeiter,
    this.wiedervorlage,
    this.typ,
    this.stadium,
    this.kontaktquelle,
    this.nachricht,
    this.infos,
    this.erledigt = false,
  });

  String get fullName => '${vorname ?? ''} ${nachname ?? ''}';
  String get todoSummary => todos.map((t) => t.done ? '✓ ${t.text}' : '• ${t.text}').join('\n');

  // ✅ FROM JSON
  factory CrmEntry.fromJson(Map<String, dynamic> json) {
    return CrmEntry(
      id: json['id'],
      anfrageDatum: json['anfrage_datum'] != null ? DateTime.tryParse(json['anfrage_datum']) : null,
      titel: json['titel'] as String?,
      vorname: json['vorname'] as String?,
      nachname: json['nachname'] as String?,
      adresse: json['adresse'] as String?,
      strasse: json['strasse'] as String?,
      hausnummer: json['hausnummer'] as String?,
      plz: json['plz'] as String?,
      ort: json['ort'] as String?,
      land: json['land'] as String?,
      email: json['email'] as String?,
      mobil: json['mobil'] as String?,
      festnetz: json['festnetz'] as String?,
      krankheitsstatus: json['krankheitsstatus'] as String?,
      todos: (json['todos'] as List<dynamic>?)?.map((e) => ToDoItem.fromJson(e)).toList() ?? [],
      status: json['status'] as String?,
      bearbeiter: json['bearbeiter'] as String?,
      wiedervorlage: json['wiedervorlage'] != null ? DateTime.tryParse(json['wiedervorlage']) : null,
      typ: json['typ'] as String?,
      stadium: json['stadium'] as String?,
      kontaktquelle: json['kontaktquelle'] as String?,
      erledigt: json['erledigt'] ?? false,
      nachricht: json['nachricht'] as String?,
      infos: json['infos'] as String?,
    );
  }

  // ✅ TO JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'anfrage_datum': anfrageDatum?.toIso8601String(),
      'titel': titel,
      'vorname': vorname,
      'nachname': nachname,
      'adresse': adresse,
      'strasse': strasse,
      'hausnummer': hausnummer,
      'plz': plz,
      'ort': ort,
      'land': land,
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
      'nachricht': nachricht,
      'infos': infos,
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
