import 'package:flutter/material.dart';
import 'api_service.dart';
import 'login_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final ApiService apiService = ApiService();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notiz App',
      home: LoginPage(apiService: apiService),  // hier apiService übergeben
    );
  }
}
