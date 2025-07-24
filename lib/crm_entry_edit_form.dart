import 'package:flutter/material.dart';
import 'api_service.dart';
import 'crm_entry.dart';

class CrmEntryEditForm extends StatefulWidget {
  final CrmEntry? existingEntry;
  final String currentUser;

  const CrmEntryEditForm({
    super.key,
    this.existingEntry,
    required this.currentUser,
  });

  @override
  State<CrmEntryEditForm> createState() => _CrmEntryEditFormState();
}

class _CrmEntryEditFormState extends State<CrmEntryEditForm> {
  final _formKey = GlobalKey<FormState>();

  String? _titel; // Anrede (Herr, Frau, etc.)
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
  final _typController = TextEditingController();
  final _stadiumController = TextEditingController();
  final _nachrichtController = TextEditingController();
  final _infosController = TextEditingController();
  final _anfrageDatumController = TextEditingController();

  String? _status;
  String? _kontaktquelle;
  String? _nachricht;
  String? _infos;

  final List<ToDoItem> _todoItems = [];
  final _todoController = TextEditingController();

  final List<String> _titelOptions = ['', 'Herr', 'Frau', 'Divers', 'Dr.', 'Prof.'];
  final List<String> _statusOptions = ['', 'Offen', 'In Bearbeitung', 'Abgeschlossen'];
  final List<String> _kontaktquelleOptions = ['', 'E-Mail', 'Telefon', 'Onlineformular', 'Empfehlung'];

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;
    if (entry != null) {
      _titel = entry.titel;
      if (!_titelOptions.contains(_titel)) _titel = null;
      _vornameController.text = entry.vorname ?? '';
      _nachnameController.text = entry.nachname ?? '';
      _strasseController.text = entry.strasse ?? '';
      _hausnummerController.text = entry.hausnummer ?? '';
      _plzController.text = entry.plz ?? '';
      _ortController.text = entry.ort ?? '';
      _landController.text = entry.land ?? '';
      _nachricht = entry.nachricht;
      _infos = entry.infos;
      _nachrichtController.text = entry.nachricht ?? '';
      _infosController.text = entry.infos ?? '';
      _emailController.text = entry.email ?? '';
      _mobilController.text = entry.mobil ?? '';
      _festnetzController.text = entry.festnetz ?? '';
      _krankheitController.text = entry.krankheitsstatus ?? '';
      _status = entry.status;
      if (!_statusOptions.contains(_status)) _status = null;
      _kontaktquelle = entry.kontaktquelle;
      if (!_kontaktquelleOptions.contains(_kontaktquelle)) _kontaktquelle = null;
      _typController.text = entry.typ ?? '';
      _stadiumController.text = entry.stadium ?? '';
      _wiedervorlageController.text =
          entry.wiedervorlage?.toIso8601String().split('T').first ?? '';
      _todoItems.addAll(entry.todos); // ✅ Status bleibt erhalten
      _anfrageDatumController.text = entry.anfrageDatum != null
          ? entry.anfrageDatum!.toIso8601String().split('T').first
          : '';
    } else {
      // Default-Wert für neue Einträge
      _landController.text = 'Deutschland';
      _titel = 'Frau';
      _anfrageDatumController.text = DateTime.now().toIso8601String().split('T').first;
    }
  }

  void _addToDoItem(String text) {
    if (text.trim().isNotEmpty) {
      setState(() {
        _todoItems.add(ToDoItem(text: text.trim(), createdAt: DateTime.now()));
      });
      _todoController.clear();
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final entry = CrmEntry(
        id: widget.existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        anfrageDatum: _anfrageDatumController.text.isNotEmpty
            ? DateTime.tryParse(_anfrageDatumController.text)
            : DateTime.now(),
        titel: _titel ?? '',
        vorname: _vornameController.text,
        nachname: _nachnameController.text,
        strasse: _strasseController.text,
        hausnummer: _hausnummerController.text,
        plz: _plzController.text,
        ort: _ortController.text,
        land: _landController.text,
        email: _emailController.text,
        mobil: _mobilController.text,
        festnetz: _festnetzController.text,
        krankheitsstatus: _krankheitController.text,
        todos: _todoItems,
        status: _status ?? '',
        bearbeiter: widget.currentUser,
        wiedervorlage: _wiedervorlageController.text.isNotEmpty
            ? DateTime.tryParse(_wiedervorlageController.text)
            : null,
        typ: _typController.text,
        stadium: _stadiumController.text,
        kontaktquelle: _kontaktquelle ?? '',
        erledigt: widget.existingEntry?.erledigt ?? false,
        nachricht: _nachrichtController.text,
        infos: _infosController.text,
      );

      try {
        if (widget.existingEntry != null) {
          await ApiService().updateCrmEntry(entry);
        } else {
          await ApiService().createCrmEntry(entry);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ CRM Eintrag gespeichert")),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Fehler beim Speichern: $e")),
        );
      }
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
    _typController.dispose();
    _stadiumController.dispose();
    _nachrichtController.dispose();
    _infosController.dispose();
    _anfrageDatumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingEntry == null ? "Neuer CRM Eintrag" : "CRM Eintrag bearbeiten")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // Anfragedatum-Feld (über Anrede/Titel)
              TextFormField(
                controller: _anfrageDatumController,
                decoration: const InputDecoration(
                  labelText: 'Anfragedatum',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  DateTime? initialDate;
                  if (_anfrageDatumController.text.isNotEmpty) {
                    initialDate = DateTime.tryParse(_anfrageDatumController.text);
                  }
                  final now = DateTime.now();
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: initialDate ?? now,
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _anfrageDatumController.text = pickedDate.toIso8601String().split('T').first;
                    });
                  }
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Anrede / Titel'),
                items: _titelOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                value: _titel,
                onChanged: (val) => setState(() => _titel = val),
              ),
              TextFormField(controller: _vornameController, decoration: const InputDecoration(labelText: 'Vorname')),
              TextFormField(controller: _nachnameController, decoration: const InputDecoration(labelText: 'Nachname')),
              TextFormField(controller: _strasseController, decoration: const InputDecoration(labelText: 'Straße')),
              TextFormField(controller: _hausnummerController, decoration: const InputDecoration(labelText: 'Hausnummer')),
              TextFormField(controller: _plzController, decoration: const InputDecoration(labelText: 'PLZ')),
              TextFormField(controller: _ortController, decoration: const InputDecoration(labelText: 'Ort')),
              TextFormField(controller: _landController, decoration: const InputDecoration(labelText: 'Land')),
              TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-Mail')),
              TextFormField(controller: _mobilController, decoration: const InputDecoration(labelText: 'Mobil')),
              TextFormField(controller: _festnetzController, decoration: const InputDecoration(labelText: 'Festnetz')),
              TextFormField(controller: _krankheitController, decoration: const InputDecoration(labelText: 'Krankheitsstatus')),
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
              TextFormField(controller: _typController, decoration: const InputDecoration(labelText: 'Typ')),
              TextFormField(controller: _stadiumController, decoration: const InputDecoration(labelText: 'Stadium')),
              TextFormField(controller: _nachrichtController, decoration: const InputDecoration(labelText: 'Nachricht')),
              TextFormField(controller: _infosController, decoration: const InputDecoration(labelText: 'Infos')),
              TextFormField(
  controller: _wiedervorlageController,
  decoration: const InputDecoration(
    labelText: 'Wiedervorlage (Datum auswählen)',
    suffixIcon: Icon(Icons.calendar_today),
  ),
  readOnly: true, // Damit die Tastatur nicht erscheint
  onTap: () async {
    DateTime? initialDate;
    if (_wiedervorlageController.text.isNotEmpty) {
      initialDate = DateTime.tryParse(_wiedervorlageController.text);
    }
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate != null) {
      setState(() {
        _wiedervorlageController.text = pickedDate.toIso8601String().split('T').first;
      });
    }
  },
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
                children: _todoItems.map((todo) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(todo.text),
                              Text('Erstellt: ' + (todo.createdAt != null ? todo.createdAt!.toIso8601String().split('T').first : '-'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              if (todo.done && todo.doneAt != null)
                                Text('Erledigt: ' + todo.doneAt!.toIso8601String().split('T').first, style: const TextStyle(fontSize: 11, color: Colors.green)),
                            ],
                          ),
                          value: todo.done,
                          onChanged: (val) {
                            setState(() {
                              todo.done = val ?? false;
                              if (todo.done) {
                                todo.doneAt = DateTime.now();
                              } else {
                                todo.doneAt = null;
                              }
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _todoItems.remove(todo);
                          });
                        },
                      )
                    ],
                  );
                }).toList(),
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
