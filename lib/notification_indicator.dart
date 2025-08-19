import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationIndicator extends StatelessWidget {
  final Widget child;
  final bool showNotification;
  final Color notificationColor;
  final double size;

  const NotificationIndicator({
    super.key,
    required this.child,
    required this.showNotification,
    this.notificationColor = Colors.red,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (showNotification)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: notificationColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Spezialisierte Widgets für verschiedene Anwendungsfälle
class NoteNotificationIndicator extends StatelessWidget {
  final Widget child;
  final NotificationService notificationService;

  const NoteNotificationIndicator({
    super.key,
    required this.child,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationIndicator(
      showNotification: notificationService.hasNewNotes,
      child: child,
    );
  }
}

class CrmNotificationIndicator extends StatelessWidget {
  final Widget child;
  final NotificationService notificationService;

  const CrmNotificationIndicator({
    super.key,
    required this.child,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationIndicator(
      showNotification: notificationService.hasNewCrmEntries,
      child: child,
    );
  }
}

