import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notes_overview_page.dart';
import 'grouped_notes_page.dart';
import 'api_service.dart';
import 'crm_overview_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'statistik_page.dart';

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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/logo.svg',
              height: 40,
            ),
            const SizedBox(width: 10),
            const Text(
              'iQM App',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notizen'),
            Tab(text: 'Gruppiert'),
            Tab(text: 'CRM'),
            Tab(text: 'Statistik'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          NotesOverviewPage(apiService: widget.apiService),
          GroupedNotesPage(apiService: widget.apiService),
          ChangeNotifierProvider(
            create: (_) => CrmEntryProvider(),
            child: CRMOverviewPage(apiService: widget.apiService),
          ),
          StatistikPage(apiService: widget.apiService),
        ],
      ),
    );
  }
}


