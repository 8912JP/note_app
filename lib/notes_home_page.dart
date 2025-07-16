import 'package:flutter/material.dart';
import 'notes_overview_page.dart';
import 'grouped_notes_page.dart';
import 'api_service.dart';

class NotesHomePage extends StatefulWidget {
  final ApiService apiService;

  const NotesHomePage({super.key, required this.apiService});

  @override
  _NotesHomePageState createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notizen App'),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: 'Übersicht'),
          Tab(text: 'Gruppiert'),
        ]),
      ),
      body: TabBarView(controller: _tabController, children: [
        NotesOverviewPage(apiService: widget.apiService),
        GroupedNotesPage(apiService: widget.apiService),
      ]),
    );
  }
}


