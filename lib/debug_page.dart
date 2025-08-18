import 'package:flutter/material.dart';
import 'api_service.dart';

class DebugPage extends StatefulWidget {
  final ApiService apiService;

  const DebugPage({super.key, required this.apiService});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  Map<String, dynamic> _debugInfo = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runDebugChecks();
  }

  Future<void> _runDebugChecks() async {
    setState(() => _isLoading = true);
    
    final debugInfo = <String, dynamic>{};
    
    // 1. Basis-URL und Konfiguration
    debugInfo['baseUrl'] = ApiService.baseUrl;
    debugInfo['accessToken'] = widget.apiService.accessToken != null ? 'Vorhanden (${widget.apiService.accessToken!.length} Zeichen)' : 'Nicht vorhanden';
    debugInfo['loggedInUser'] = widget.apiService.loggedInUser ?? 'Nicht eingeloggt';
    
    // 2. Server-Status-Checks
    debugInfo['normalStatusCheck'] = await widget.apiService.checkServerStatus();
    debugInfo['alternativeStatusCheck'] = await widget.apiService.checkServerStatusAlternative();
    
    // 3. Backend-Verbindungstest
    debugInfo['backendConnectionTest'] = await widget.apiService.testBackendConnection();
    
    // 4. WebSocket-Status
    debugInfo['websocketConnected'] = widget.apiService.isWebSocketConnected();
    debugInfo['websocketListenerCount'] = widget.apiService.getWebSocketListenerCount();
    debugInfo['websocketErrorListenerCount'] = widget.apiService.getWebSocketErrorListenerCount();
    
    // 5. WebSocket-Status vom Server
    try {
      final wsStatus = await widget.apiService.getWebSocketStatus();
      debugInfo['websocketServerStatus'] = wsStatus;
    } catch (e) {
      debugInfo['websocketServerStatus'] = 'Fehler: $e';
    }
    
    setState(() {
      _debugInfo = debugInfo;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Information'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDebugChecks,
            tooltip: 'Neu laden',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Konfiguration', {
                    'Base URL': _debugInfo['baseUrl'] ?? 'N/A',
                    'Access Token': _debugInfo['accessToken'] ?? 'N/A',
                    'Eingeloggter User': _debugInfo['loggedInUser'] ?? 'N/A',
                  }),
                  
                  const SizedBox(height: 20),
                  
                  _buildSection('Server-Status', {
                    'Normaler Status-Check': _debugInfo['normalStatusCheck'] == true ? '✅ OK' : '❌ Fehler',
                    'Alternativer Status-Check': _debugInfo['alternativeStatusCheck'] == true ? '✅ OK' : '❌ Fehler',
                    'Backend-Verbindungstest': _debugInfo['backendConnectionTest'] == true ? '✅ OK' : '❌ Fehler',
                  }),
                  
                  const SizedBox(height: 20),
                  
                  _buildSection('WebSocket-Status', {
                    'WebSocket verbunden': _debugInfo['websocketConnected'] == true ? '✅ Ja' : '❌ Nein',
                    'Listener-Anzahl': _debugInfo['websocketListenerCount']?.toString() ?? 'N/A',
                    'Error-Listener-Anzahl': _debugInfo['websocketErrorListenerCount']?.toString() ?? 'N/A',
                  }),
                  
                  if (_debugInfo['websocketServerStatus'] != null) ...[
                    const SizedBox(height: 20),
                    _buildSection('WebSocket-Server-Status', {
                      'Server-Info': _debugInfo['websocketServerStatus'].toString(),
                    }),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  ElevatedButton(
                    onPressed: () async {
                      final success = await widget.apiService.testWebSocketConnection();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'WebSocket-Test erfolgreich' : 'WebSocket-Test fehlgeschlagen'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    },
                    child: const Text('WebSocket-Test durchführen'),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  ElevatedButton(
                    onPressed: () async {
                      final success = await widget.apiService.testServerBroadcast();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Broadcast-Test erfolgreich' : 'Broadcast-Test fehlgeschlagen'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    },
                    child: const Text('Broadcast-Test durchführen'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, Map<String, String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...items.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: entry.value.contains('✅') 
                            ? Colors.green 
                            : entry.value.contains('❌') 
                                ? Colors.red 
                                : null,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
