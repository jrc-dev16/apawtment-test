import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apawtmentweb_admin/webnotifservice.dart';

class RealtimeNotificationListener {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  final WebNotificationService _notifier = WebNotificationService();

  /// Start listening to notifications
  void startListening(BuildContext context, {VoidCallback? onNewNotification}) {
    _channel =
        supabase
            .channel('public:notifications')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              callback: (payload) {
                final newNotif = payload.newRecord;

                final title = newNotif['title'] ?? 'New Notification';
                final message = newNotif['message'] ?? '';

                // 🔔 Browser notification
                _notifier.showNotification(title: title, body: message);

                // 💬 In-app Snackbar safely
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title — $message'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }

                // 🔁 Callback to refresh list or UI
                if (onNewNotification != null) {
                  onNewNotification();
                }
              },
            )
            .subscribe();
  }

  /// Stop listening and remove channel
  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
      _channel = null;
    }
  }
}
