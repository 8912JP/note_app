import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'package:note_app/note.dart';

class FormPage extends StatefulWidget {
  final Note? existingNote;

  const FormPage({super.key, this.existingNote});

  @override
  _FormPageState createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _telephoneController;
  late TextEditingController _addressController;
  late TextEditingController _noteTextController;

  DateTime? _selectedDate;
  String _selectedGender = 'männlich';
  List<String> _selectedLabels = [];
  bool _isDone = false;

  final List<String> _allLabels = ['Dringend', 'Rückmeldung', 'Andere'];
  final List<String> _genders = ['männlich', 'weiblich', 'divers', 'keine Angabe'];

  late ApiService apiService;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    apiService = ApiService();

    _firstNameController = TextEditingController(text: widget.existingNote?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.existingNote?.lastName ?? '');
    _emailController = TextEditingController(text: widget.existingNote?.email ?? '');
    _telephoneController = TextEditingController(text: widget.existingNote?.telephone ?? '');
    _addressController = TextEditingController(text: widget.existingNote?.address ?? '');
    _noteTextController = TextEditingController(text: widget.existingNote?.noteText ?? '');
    _selectedDate = widget.existingNote?.customDate;
    _selectedGender = widget.existingNote?.gender ?? 'männlich';
    _selectedLabels = widget.existingNote?.labels.toList() ?? [];
    _isDone = widget.existingNote?.isDone ?? false;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _addressController.dispose();
    _noteTextController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _removeDate() {
    setState(() {
      _selectedDate = null;
    });
  }

  Future<void> _saveForm() async {
    if (_isSaving) {
      print('Speichern wird schon ausgeführt, abbrechen');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final noteToSave = Note(
      id: widget.existingNote?.id,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      telephone: _telephoneController.text.trim(),
      address: _addressController.text.trim(),
      noteText: _noteTextController.text.trim(),
      customDate: _selectedDate,
      gender: _selectedGender,
      labels: _selectedLabels,
      isDone: _isDone,
      createdAt: widget.existingNote?.createdAt ?? DateTime.now(),
    );

    try {
      Note savedNote;
      if (widget.existingNote == null) {
        savedNote = await apiService.createNote(noteToSave);
      } else {
        savedNote = await apiService.updateNote(noteToSave);
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      Navigator.of(context).pop(savedNote);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingNote != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Notiz bearbeiten' : 'Neue Notiz'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(labelText: 'Vorname'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte Vorname eingeben';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(labelText: 'Nachname'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte Nachname eingeben';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    maxLines: 1,
                  ),
                  TextFormField(
                    controller: _telephoneController,
                    decoration: const InputDecoration(labelText: 'Telefonnummer'),
                    maxLines: 1,
                  ),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: _noteTextController,
                    decoration: const InputDecoration(labelText: 'Notiz'),
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte Notiz eingeben';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDate == null
                              ? 'Kein Datum ausgewählt'
                              : 'Datum: ${DateFormat.yMd().format(_selectedDate!)}',
                        ),
                      ),
                      TextButton(
                        onPressed: _pickDate,
                        child: const Text('Datum wählen'),
                      ),
                      if (_selectedDate != null)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _removeDate,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Geschlecht'),
                    value: _selectedGender,
                    items: _genders
                        .map((gender) =>
                            DropdownMenuItem(value: gender, child: Text(gender)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedGender = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: _allLabels.map((label) {
                      final isSelected = _selectedLabels.contains(label);
                      return FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedLabels.add(label);
                            } else {
                              _selectedLabels.remove(label);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Erledigt'),
                    value: _isDone,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _isDone = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveForm,
                    child: Text(isEditing ? 'Speichern' : 'Anlegen'),
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
