// note_model.dart

class Note {
  final int? id;
  String firstName;
  String lastName;
  String? address;
  String? email;
  String? telephone;
  String noteText;
  DateTime? customDate;
  String gender;
  bool isDone;
  DateTime? createdAt;
  List<String> labels;

  Note({
    this.id,
    required this.firstName,
    required this.lastName,
    this.address,
    this.email,
    this.telephone,
    required this.noteText,
    this.customDate,
    required this.gender,
    this.isDone = false,
    this.createdAt,
    this.labels = const [],
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      address: json['address'],
      email: json['email'],
      telephone: json['telephone'],
      noteText: json['note_text'] ?? '',
      customDate: json['custom_date'] != null
          ? DateTime.parse(json['custom_date'])
          : null,
      gender: json['gender'] ?? '',
      isDone: json['is_done'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      labels: (json['labels'] as List<dynamic>?)?.map((l) => l.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'address': address,
      'email': email,
      'telephone': telephone,
      'note_text': noteText,
      'custom_date': customDate?.toIso8601String(),
      'gender': gender,
      'is_done': isDone,
      'labels': labels,
    };
  }
}
