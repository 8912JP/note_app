import 'package:flutter/material.dart';
import 'api_service.dart';
import 'register_page.dart';
import 'notes_home_page.dart';

class LoginPage extends StatefulWidget {
  final ApiService apiService;

  const LoginPage({super.key, required this.apiService});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);

    bool success = await widget.apiService.login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (success) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => NotesHomePage(apiService: widget.apiService),
    ),
  );
} else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falscher Benutzername oder Passwort')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Benutzername'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Passwort'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: const Text('Anmelden'),
                  ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RegisterPage(apiService: widget.apiService),
                  ),
                );
              },
              child: const Text('Neu hier? Registrieren'),
            ),
          ],
        ),
      ),
    );
  }
}
