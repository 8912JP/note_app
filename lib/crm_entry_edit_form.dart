import 'package:flutter/material.dart';

class CrmEntryEditForm extends StatefulWidget {
  final String currentUser;

  const CrmEntryEditForm({super.key, required this.currentUser});

  @override
  State<CrmEntryEditForm> createState() => _CrmEntryEditFormState();
}

class _CrmEntryEditFormState extends State<CrmEntryEditForm> {
  final _formKey = GlobalKey<FormState>();

  // Form field controllers
  String? _titel;
  final _vornameController = TextEditingController();
  final _nachnameController = TextEditingController();
  final _strasseController = TextEditingController();
  final _hausnummerController = TextEditingController();
  final _plzController = TextEditingController();
  final _ortController = TextEditingController();
  final _landController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobilController = TextEditingController();
  final _festnetzController = TextEditingController();
  final _krankheitController = TextEditingController();
  final _wiedervorlageController = TextEditingController();

  String? _status;
  String? _kontaktquelle;
  final List<String> _todoItems = [];
  final _todoController = TextEditingController();

  final List<String> _titelOptions = ['Herr', 'Frau', 'Divers', 'Dr.', 'Prof.'];
  final List<String> _statusOptions = ['Offen', 'In Bearbeitung', 'Abgeschlossen'];
  final List<String> _kontaktquelleOptions = ['E-Mail', 'Telefon', 'Onlineformular', 'Empfehlung'];
  final List<String> _todoVorschlage = ['Erneut kontaktieren', 'Angebot senden', 'Dokument prüfen'];

  void _addToDoItem(String item) {
    if (item.trim().isNotEmpty && !_todoItems.contains(item)) {
      setState(() {
        _todoItems.add(item.trim());
      });
      _todoController.clear();
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Hier speicherst du das CRM Entry – kann mit Provider, API oder DB verbunden werden
      debugPrint("Speichern:");
      debugPrint("Titel: $_titel");
      debugPrint("Vorname: ${_vornameController.text}");
      debugPrint("Nachname: ${_nachnameController.text}");
      debugPrint("Adresse: ${_strasseController.text} ${_hausnummerController.text}, ${_plzController.text} ${_ortController.text}, ${_landController.text}");
      debugPrint("E-Mail: ${_emailController.text}");
      debugPrint("Mobil: ${_mobilController.text}");
      debugPrint("Festnetz: ${_festnetzController.text}");
      debugPrint("Status: $_status");
      debugPrint("Kontaktquelle: $_kontaktquelle");
      debugPrint("Bearbeiter: ${widget.currentUser}");
      debugPrint("ToDos: $_todoItems");
      debugPrint("Krankheit: ${_krankheitController.text}");
    }
  }

  @override
  void dispose() {
    _vornameController.dispose();
    _nachnameController.dispose();
    _strasseController.dispose();
    _hausnummerController.dispose();
    _plzController.dispose();
    _ortController.dispose();
    _landController.dispose();
    _emailController.dispose();
    _mobilController.dispose();
    _festnetzController.dispose();
    _krankheitController.dispose();
    _wiedervorlageController.dispose();
    _todoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CRM Eintrag bearbeiten")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Anrede / Titel'),
                items: _titelOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                value: _titel,
                onChanged: (val) => setState(() => _titel = val),
              ),
              TextFormField(
                controller: _vornameController,
                decoration: const InputDecoration(labelText: 'Vorname'),
                validator: (val) => val!.isEmpty ? 'Pflichtfeld' : null,
              ),
              TextFormField(
                controller: _nachnameController,
                decoration: const InputDecoration(labelText: 'Nachname'),
                validator: (val) => val!.isEmpty ? 'Pflichtfeld' : null,
              ),
              TextFormField(
                controller: _strasseController,
                decoration: const InputDecoration(labelText: 'Straße'),
              ),
              TextFormField(
                controller: _hausnummerController,
                decoration: const InputDecoration(labelText: 'Hausnummer'),
              ),
              TextFormField(
                controller: _plzController,
                decoration: const InputDecoration(labelText: 'PLZ'),
              ),
              TextFormField(
                controller: _ortController,
                decoration: const InputDecoration(labelText: 'Ort'),
              ),
              TextFormField(
                controller: _landController,
                decoration: const InputDecoration(labelText: 'Land'),
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-Mail'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _mobilController,
                decoration: const InputDecoration(labelText: 'Mobilnummer'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _festnetzController,
                decoration: const InputDecoration(labelText: 'Festnetznummer'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _krankheitController,
                decoration: const InputDecoration(labelText: 'Krankheitsstatus'),
                maxLines: 4,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                value: _status,
                onChanged: (val) => setState(() => _status = val),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Kontaktquelle'),
                items: _kontaktquelleOptions.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                value: _kontaktquelle,
                onChanged: (val) => setState(() => _kontaktquelle = val),
              ),
              TextFormField(
                controller: _wiedervorlageController,
                decoration: const InputDecoration(labelText: 'Wiedervorlage (optional)'),
              ),
              TextFormField(
                controller: _todoController,
                decoration: InputDecoration(
                  labelText: 'ToDo hinzufügen',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addToDoItem(_todoController.text),
                  ),
                ),
                onFieldSubmitted: _addToDoItem,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _todoItems.map((todo) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(todo)),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _todoItems.remove(todo);
                        });
                      },
                    )
                  ],
                )).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
