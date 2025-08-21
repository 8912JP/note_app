import 'package:flutter/material.dart';
import 'api_service.dart';
import 'login_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'websocket_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);
  
  // Initialisiere den WebSocket-Manager global
  WebSocketManager().initialize();
  
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
