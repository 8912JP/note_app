import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class TestEntry {
  final int id;
  final String vorname;
  final String nachname;
  final DateTime? geburtsdatum; // Nullable

  TestEntry({
    required this.id,
    required this.vorname,
    required this.nachname,
    this.geburtsdatum,
  });

  factory TestEntry.fromJson(Map<String, dynamic> json) {
    return TestEntry(
      id: json['id'],
      vorname: json['vorname'] ?? '',
      nachname: json['nachname'] ?? '',
      geburtsdatum: json['geburtsdatum'] != null
          ? DateTime.parse(json['geburtsdatum'])
          : null,
    );
  }
}

class MyApp extends StatelessWidget {
  // API URL mit Basic Auth (ändere hier die Adresse und Zugangsdaten)

    static const String apiUser = 'Julian';        // <<< dein API_USER
    static const String apiPass = 'Weissgelb2.4';      // <<< dein API_PASS
    static const String apiUrl = 'http://iqmedix.cloud:8000/test';

  const MyApp({super.key}); // <<< dein Backend-Endpunkt

@override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Tabelle',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: const Text('Test Tabelle')),
        body: FutureBuilder<List<TestEntry>>(
          future: fetchTestEntries(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Fehler: ${snapshot.error}'));
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const Center(child: Text('Keine Daten gefunden'));
            }
            return ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  title: Text('${entry.vorname} ${entry.nachname}'),
                  subtitle: Text(
                    entry.geburtsdatum != null
                        ? 'Geburtsdatum: ${entry.geburtsdatum!.day.toString().padLeft(2, '0')}.'
                          '${entry.geburtsdatum!.month.toString().padLeft(2, '0')}.'
                          '${entry.geburtsdatum!.year}'
                        : 'Geburtsdatum: unbekannt',
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<TestEntry>> fetchTestEntries() async {
    final basicAuth = 'Basic ${base64Encode(utf8.encode('$apiUser:$apiPass'))}';
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {'authorization': basicAuth},
    );

    if (response.statusCode != 200) {
      throw Exception('Fehler bei API-Aufruf: ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => TestEntry.fromJson(json)).toList();
  }
}
//flutter build web --base-href /demonstrator/
//uvicorn demonstrator-web:app --host 0.0.0.0 --port 8000