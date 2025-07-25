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
  String? crmEntryId;
  String? trackingType;

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
    required this.labels,
    this.isDone = false,
    DateTime? createdAt,
    this.crmEntryId,
    this.trackingType,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      firstName: json['first_name'] ?? json['firstName'],
      lastName: json['last_name'] ?? json['lastName'],
      email: json['email'],
      telephone: json['telephone'],
      address: json['address'],
      noteText: json['note_text'] ?? json['noteText'],
      customDate: json['custom_date'] != null ? DateTime.tryParse(json['custom_date']) : (json['customDate'] != null ? DateTime.tryParse(json['customDate']) : null),
      gender: json['gender'],
      labels: (json['labels'] as List<dynamic>?)?.map((l) => l is String ? l : (l is Map && l['name'] != null ? l['name'].toString() : l.toString())).toList() ?? [],
      isDone: json['is_done'] ?? json['isDone'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null),
      crmEntryId: json['crm_entry_id'] ?? json['crmEntryId'],
      trackingType: json['tracking_type'] ?? json['trackingType'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'telephone': telephone,
        'address': address,
        'note_text': noteText,
        'custom_date': customDate?.toIso8601String(),
        'gender': gender,
        'labels': labels.map((l) => l is String ? l : l.toString()).toList(),
        'is_done': isDone,
        'created_at': createdAt.toIso8601String(),
        'crm_entry_id': crmEntryId,
        'tracking_type': trackingType,
      };

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
