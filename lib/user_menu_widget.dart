import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'build_info.dart';

class UserMenuWidget extends StatefulWidget {
  final String? username;
  final VoidCallback? onLogout;

  const UserMenuWidget({
    super.key,
    this.username,
    this.onLogout,
  });

  @override
  State<UserMenuWidget> createState() => _UserMenuWidgetState();
}

class _UserMenuWidgetState extends State<UserMenuWidget> {
  bool _buildInfoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeBuildInfo();
  }

  Future<void> _initializeBuildInfo() async {
    await BuildInfo.initialize();
    if (mounted) {
      setState(() {
        _buildInfoInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue[600],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
                         Text(
               widget.username ?? 'Gast',
               style: const TextStyle(
                 color: Colors.white,
                 fontSize: 14,
                 fontWeight: FontWeight.w500,
               ),
             ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
             itemBuilder: (context) => [
         // Benutzer-Info
         PopupMenuItem<String>(
           enabled: false,
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 widget.username ?? 'Gast',
                 style: const TextStyle(
                   fontWeight: FontWeight.bold,
                   fontSize: 16,
                 ),
               ),
               const SizedBox(height: 4),
               Text(
                 'Angemeldet',
                 style: TextStyle(
                   color: Colors.grey[600],
                   fontSize: 12,
                 ),
               ),
             ],
           ),
         ),
         const PopupMenuDivider(),
         
         // App-Info
         PopupMenuItem<String>(
           enabled: false,
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text(
                 'App-Informationen',
                 style: TextStyle(
                   fontWeight: FontWeight.bold,
                   fontSize: 14,
                 ),
               ),
                               const SizedBox(height: 8),
                if (_buildInfoInitialized) ...[
                  _buildInfoRow('Version', BuildInfo.fullVersion),
                  _buildInfoRow('Build', '#${BuildInfo.buildNumber}'),
                  _buildInfoRow('Build-Datum', BuildInfo.buildTimestamp),
                  _buildInfoRow('Plattform', BuildInfo.platform),
                ] else ...[
                  const Text('Lade Build-Info...', style: TextStyle(fontStyle: FontStyle.italic)),
                ],
             ],
           ),
         ),
        const PopupMenuDivider(),
        
                 // Aktionen
         if (widget.onLogout != null)
           PopupMenuItem<String>(
             value: 'logout',
             child: Row(
               children: [
                 Icon(Icons.logout, size: 18, color: Colors.red[600]),
                 const SizedBox(width: 8),
                 Text(
                   'Abmelden',
                   style: TextStyle(color: Colors.red[600]),
                 ),
               ],
             ),
           ),
       ],
       onSelected: (value) {
         if (value == 'logout' && widget.onLogout != null) {
           widget.onLogout!();
         }
       },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
