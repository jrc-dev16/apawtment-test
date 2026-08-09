import 'dart:html' as html;
import 'dart:async';

class WebNotificationService {
  static final WebNotificationService _instance =
      WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  bool _permissionGranted = false;

  Future<void> requestPermission() async {
    final permission = await html.Notification.requestPermission();
    _permissionGranted = permission == 'granted';
    print('🔔 Notification permission: $permission');
  }

  void showNotification({
    required String title,
    required String body,
    String? iconUrl,
  }) {
    if (!_permissionGranted) {
      print('⚠️ Notification permission not granted');
      return;
    }

    try {
      html.Notification(
        title,
        body: body,
        icon: iconUrl ?? 'icons/Icon-192.png',
      );
      print('✅ Web notification shown: $title - $body');
    } catch (e) {
      print('❌ Failed to show notification: $e');
    }
  }

  void notifyVerificationStatus({
    required int verificationId,
    required String status,
    String? iconUrl,
  }) {
    final title =
        status.toLowerCase() == 'approved'
            ? '✅ Verification Approved'
            : '❌ Verification Declined';

    final body =
        status.toLowerCase() == 'approved'
            ? 'Verification was approved.'
            : 'Verification was declined.';

    showNotification(title: title, body: body, iconUrl: iconUrl);
    print('📣 Verification status notification: $title — $body');
  }

  void notifyPetReport({
    required int reportId,
    required String petName,
    required String reporterName,
    String? iconUrl,
  }) {
    final title = '🐾 New Pet Report Received';
    final body = 'Report #$reportId: $petName reported by $reporterName';
    showNotification(title: title, body: body, iconUrl: iconUrl);
    print('📣 Pet report notification triggered: $title — $body');
  }

  void notifyReportMovedToRescue({
    required int reportId,
    required String petName,
    String? iconUrl,
  }) {
    final title = '🚑 Report Moved to Rescue';
    final body =
        'Report #$reportId for ${petName.isNotEmpty ? petName : "pet"} has been moved to rescue operations';
    showNotification(title: title, body: body, iconUrl: iconUrl);
    print('📣 Report to Rescue notification triggered: $title — $body');
  }

  void notifyRescueMovedToMedication({
    required int rescueId,
    required String petName,
    String? iconUrl,
  }) {
    final title = '💊 Rescue Moved to Medication';
    final body =
        '${petName.isNotEmpty ? petName : "Pet"} (Rescue #$rescueId) has been moved to medication care';
    showNotification(title: title, body: body, iconUrl: iconUrl);
    print('📣 Rescue to Medication notification triggered: $title — $body');
  }

  void startHeartbeatNotifications() {
    Timer.periodic(const Duration(seconds: 30), (_) {
      showNotification(
        title: "System Update",
        body: "Still connected and running fine! 🟢",
      );
    });
  }
}
