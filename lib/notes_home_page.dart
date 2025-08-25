import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notes_overview_page.dart';
import 'grouped_notes_page.dart';
import 'api_service.dart';
import 'crm_overview_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'statistik_page.dart';
import 'notification_indicator.dart';
import 'websocket_manager.dart';
import 'user_menu_widget.dart';
import 'login_page.dart';

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
    
    // Registriere Notification-Callbacks
    widget.apiService.notificationService.setNoteNotificationCallback(() {
      if (mounted) setState(() {});
    });
    widget.apiService.notificationService.setCrmNotificationCallback(() {
      if (mounted) setState(() {});
    });
    
    // Listener für Tab-Wechsel
    _tabController.addListener(_onTabChanged);
  }
  
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Markiere Notifications als gesehen basierend auf aktivem Tab
      switch (_tabController.index) {
        case 0: // Notizen
        case 1: // Gruppiert
          widget.apiService.notificationService.markNotesAsSeen();
          break;
        case 2: // CRM
          widget.apiService.notificationService.markCrmAsSeen();
          // Bereinige Tracking-Icon-Updater schrittweise beim Wechsel zur CRM-Seite
          WebSocketManager().cleanupTrackingIconUpdatersGradually();
          break;
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    
    // Entferne Notification-Callbacks
    widget.apiService.notificationService.removeNoteNotificationCallback();
    widget.apiService.notificationService.removeCrmNotificationCallback();
    
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
        actions: [
          // Benutzer-Menü mit Versionsinformationen
          UserMenuWidget(
            username: widget.apiService.loggedInUser,
            onLogout: () {
              // Zurück zur Login-Seite
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginPage(apiService: widget.apiService),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            NoteNotificationIndicator(
              notificationService: widget.apiService.notificationService,
              child: const Tab(text: 'Notizen'),
            ),
            NoteNotificationIndicator(
              notificationService: widget.apiService.notificationService,
              child: const Tab(text: 'Gruppiert'),
            ),
            CrmNotificationIndicator(
              notificationService: widget.apiService.notificationService,
              child: const Tab(text: 'CRM'),
            ),
            const Tab(text: 'Statistik'),
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


