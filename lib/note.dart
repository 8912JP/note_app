class Note {
  final int? id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? telephone;
  final String? address;
  final String noteText;
  final DateTime? customDate;
  final String gender;
  final bool isDone;
  final DateTime createdAt;
  final List<String> labels;

  Note({
    this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.telephone,
    this.address,
    required this.noteText,
    this.customDate,
    required this.gender,
    required this.isDone,
    required this.createdAt,
    required this.labels,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      telephone: json['telephone'],
      address: json['address'],
      noteText: json['note_text'],
      customDate: json['custom_date'] != null
          ? DateTime.parse(json['custom_date'])
          : null,
      gender: json['gender'],
      isDone: json['is_done'],
      createdAt: DateTime.parse(json['created_at']),
      labels: List<String>.from(json['labels'].map((label) => label['name'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'telephone': telephone,
      'address': address,
      'note_text': noteText,
      'custom_date': customDate?.toIso8601String(),
      'gender': gender,
      'is_done': isDone,
      'created_at': createdAt.toIso8601String(),
      'labels': labels,
    };
  }

  // Hier die copyWith Methode
  Note copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? telephone,
    String? address,
    String? noteText,
    DateTime? customDate,
    String? gender,
    bool? isDone,
    DateTime? createdAt,
    List<String>? labels,
  }) {
    return Note(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      address: address ?? this.address,
      noteText: noteText ?? this.noteText,
      customDate: customDate ?? this.customDate,
      gender: gender ?? this.gender,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      labels: labels ?? this.labels,
    );
  }
}
