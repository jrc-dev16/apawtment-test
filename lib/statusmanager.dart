import 'dart:async';

import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StatusManager with WidgetsBindingObserver {
  static final StatusManager _instance = StatusManager._internal();
  factory StatusManager() => _instance;
  StatusManager._internal();

  int? _currentSubadminId;
  bool _isOnline = false;
  bool _isConnected = true;
  bool _isObserverAdded = false;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  bool get isOnline => _isOnline;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _heartbeatTimer;
  Timer? _backgroundTimer;

  void onAppPaused() => _handleAppPaused();
  void onAppResumed() => _handleAppResumed();
  void onAppHidden() => _handleAppHidden();

  Future<void> startMonitoring(int subadminId, BuildContext context) async {
    _currentSubadminId = subadminId;
    _log('🚀 Starting monitoring for subadmin: $subadminId');

    if (!_isObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverAdded = true;
      _log('👀 Lifecycle observer added');
    }

    _setupConnectivityListener(context);

    final hasNet = await hasConnection();
    if (!hasNet) {
      _isOnline = false;
      _isConnected = false;
      if (context.mounted) _showSnackBar(context, "You are offline");
      await _updateStatus('Offline', 'No connection');
      return;
    }

    _isConnected = true;
    await _handleOnline(context);
    _startForegroundTask();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('📱 App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.detached:
        _log('🔴 App detached detected (cannot reliably mark offline)');
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }

  void _handleAppHidden() async {
    _log('👁️ App hidden - marking offline after short delay');
    _heartbeatTimer?.cancel();
    _backgroundTimer?.cancel();

    _backgroundTimer = Timer(const Duration(seconds: 5), () async {
      if (_currentSubadminId != null) {
        _isOnline = false;
        await _updateStatus('Offline', 'App hidden');
        _log('📴 Status set to Offline (app hidden)');
      }
    });
  }

  void _handleAppResumed() async {
    _log('✅ App resumed');
    _backgroundTimer?.cancel();

    if (_currentSubadminId != null) {
      final hasNet = await hasConnection();
      if (hasNet) {
        _isOnline = true;
        _isConnected = true;
        await _updateStatus('Online', 'App resumed');
        _startHeartbeatTimer();
        _log('🟢 Status set to Online (app resumed)');
      }
    }
  }

  void _handleAppPaused() async {
    _log('⏸️ App paused');
    _heartbeatTimer?.cancel();
    _backgroundTimer?.cancel();

    _backgroundTimer = Timer(const Duration(seconds: 5), () async {
      if (_currentSubadminId != null) {
        _isOnline = false;
        await _updateStatus('Offline', 'App in background');
        _log('📴 Status set to Offline (background)');
      }
    });
  }

  void _handleAppInactive() {
    _log('⏸️ App inactive');
  }

  Future<void> stopMonitoring() async {
    _heartbeatTimer?.cancel();
    _backgroundTimer?.cancel();
    _connectivitySubscription?.cancel();

    if (_currentSubadminId != null) {
      await _updateStatus('Offline', 'Logged out');
    }

    _stopForegroundTask();

    if (_isObserverAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverAdded = false;
    }

    _currentSubadminId = null;
    _isOnline = false;
    _log('✅ Monitoring stopped');
  }

  void _setupConnectivityListener(BuildContext context) {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) async {
      final bool connected = result != ConnectivityResult.none;

      if (connected && !_isConnected) {
        final online = await hasConnection();
        if (online) {
          _isConnected = true;
          if (context.mounted) _showSnackBar(context, "Connection restored");
          await _handleOnline(context);
        }
      } else if (!connected && _isConnected) {
        _isConnected = false;
        if (context.mounted) _showSnackBar(context, "You are offline");
        await _handleOffline();
      }
    });
  }

  Future<void> _handleOnline(BuildContext context) async {
    if (_currentSubadminId == null) return;
    _isOnline = true;
    await _updateStatus('Online', 'Connection restored');
    _startHeartbeatTimer();
  }

  Future<void> _handleOffline() async {
    _isOnline = false;
    _heartbeatTimer?.cancel();
    await _updateStatus('Offline', 'Connection lost');
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_currentSubadminId != null && _isOnline) {
        await _updateStatus('Online', 'Heartbeat');
        _log('💓 Heartbeat sent');
      }
    });
  }

  Future<bool> hasConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnectivity = connectivityResult != ConnectivityResult.none;

      if (!hasConnectivity) return false;

      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateStatus(String status, String action) async {
    if (_currentSubadminId == null) return;

    try {
      final supabase = SupabaseClient(
        dotenv.env['SUPABASE_URL']!,
        dotenv.env['SUPABASE_ANON_KEY']!,
      );

      await supabase
          .from('subadmin_profiles')
          .update({
            'status': status,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentSubadminId!);

      if (action != 'Heartbeat') {
        await supabase.from('subadmin_activity_logs').insert({
          'subadmin_id': _currentSubadminId!,
          'action': action,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      _statusController.add({
        'status': status,
        'isOnline': status == 'Online',
        'timestamp': DateTime.now().toIso8601String(),
      });

      _log('✅ Status updated: $status - $action');
    } catch (e) {
      _log('❌ Status update error: $e');
    }
  }

  static Future<void> cleanupStaleSessions() async {
    try {
      final supabase = SupabaseClient(
        dotenv.env['SUPABASE_URL']!,
        dotenv.env['SUPABASE_ANON_KEY']!,
      );
      final threshold = DateTime.now().subtract(const Duration(minutes: 1));

      await supabase
          .from('subadmin_profiles')
          .update({'status': 'Offline'})
          .eq('status', 'Online')
          .lt('last_seen', threshold.toIso8601String());

      _staticLog('✅ Stale sessions cleaned up');
    } catch (e) {
      _staticLog('❌ Cleanup error: $e');
    }
  }

  void _log(String message) {
    debugPrint('[StatusManager] $message');
    developer.log(message, name: 'StatusManager');
  }

  static void _staticLog(String message) {
    debugPrint('[StatusManager] $message');
    developer.log(message, name: 'StatusManager');
  }

  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _startForegroundTask() {
    if (_currentSubadminId == null) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'subadmin_status_channel',
        channelName: 'Subadmin Status Service',
        channelDescription: 'Keeps your online status active',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        autoRunOnBoot: false,
        allowWifiLock: true,
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );

    FlutterForegroundTask.startService(
      notificationTitle: 'Subadmin Status Active',
      notificationText: 'Keeping your status online',
      callback: startCallback,
    );
  }

  void _stopForegroundTask() => FlutterForegroundTask.stopService();

  @pragma('vm:entry-point')
  static void startCallback() {
    FlutterForegroundTask.setTaskHandler(StatusTaskHandler());
  }
}

class StatusTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
  @override
  void onNotificationButtonPressed(String id) {}
  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}
