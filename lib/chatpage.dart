import 'dart:async';
import 'dart:typed_data';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:apawtmentweb_admin/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'accountmanagement/accountmanagementlist.dart';
import 'dashboardpage.dart';
import 'donationpage.dart';
import 'eventspage.dart';
import 'medicationspage.dart';
import 'notificationpage.dart';
import 'petpage.dart';
import 'profilepage.dart';
import 'reportpage.dart';
import 'shelterprojectspage.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  const ChatPage({super.key, this.user});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  int? selectedUserId;
  String _selectedItem = 'Chats';
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final int _adminId = 1;
  final Map<int, DateTime?> _lastActiveAt = {};
  RealtimeChannel? _profilesChannel;

  final Map<int, Map<String, dynamic>> _profiles = {};
  final Map<int, Map<String, dynamic>> _lastMessages = {};
  final Map<int, int> _unreadCounts = {};
  final Map<int, DateTime> _lastReadAt = {};
  Timer? _pollingTimer;
  DateTime _lastPolledAt = DateTime.now().subtract(const Duration(minutes: 1));
  final Set<int> _processedMessageIds = {};

  List<int> _sortedUserIds = [];
  RealtimeChannel? _messagesChannel;
  String _searchQuery = '';
  Timer? _timeUpdateTimer;

  DateTime _parseToLocal(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.now();
    try {
      final s = raw.trim();
      final DateTime utc;
      if (s.endsWith('Z') ||
          s.contains('+') ||
          RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
        utc = DateTime.parse(s).toUtc();
      } else {
        utc = DateTime.parse('${s}Z').toUtc();
      }
      return utc.toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  int _parseUtcMs(String? raw) {
    if (raw == null || raw.isEmpty)
      return DateTime.now().millisecondsSinceEpoch;
    try {
      final s = raw.trim();
      final DateTime utc;
      if (s.endsWith('Z') ||
          s.contains('+') ||
          RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
        utc = DateTime.parse(s).toUtc();
      } else {
        utc = DateTime.parse('${s}Z').toUtc();
      }
      return utc.millisecondsSinceEpoch;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  void initState() {
    super.initState();
    saveLastVisitedPage('Chats');
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text.toLowerCase()),
    );
    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadProfileImageForAvatar(),
    );
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      if (selectedUserId != null) await _refreshActiveStatus(selectedUserId!);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _chatScrollController.dispose();
    _timeUpdateTimer?.cancel();
    _pollingTimer?.cancel();
    _messagesChannel?.unsubscribe();
    _profilesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final messages = await supabase
          .from('messages')
          .select(
            'message_id, room_id, content, created_at, time, furparent_id, admin_id, image_url',
          )
          .order('created_at', ascending: true);

      for (final msg in messages) {
        _processMessage(msg, isInitialLoad: true);
      }

      await _loadMissingProfiles();
      await _loadReadReceipts();
      _rebuildUnreadCounts();
      _rebuildSortedList();

      if (mounted) setState(() {});

      _subscribeToMessages();
      _subscribeToProfileUpdates();

      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        await _pollForNewMessages();
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      _showSnackBar('Failed to load chat data.', Colors.red);
    }
  }

  Future<void> _loadReadReceipts() async {
    try {
      final rows = await supabase
          .from('admin_read_receipts')
          .select('furparent_id, last_read_at')
          .eq('admin_id', _adminId);
      for (final row in rows) {
        final fid = row['furparent_id'] as int;
        final ts = row['last_read_at'] as String?;
        if (ts != null) _lastReadAt[fid] = _parseToLocal(ts);
      }
    } catch (e) {
      debugPrint('Error loading read receipts: $e');
    }
  }

  void _subscribeToProfileUpdates() {
    _profilesChannel =
        supabase
            .channel('profiles-last-active')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'profiles',
              callback: (payload) {
                final row = payload.newRecord;
                final rawFid = row['furparent_id'];
                if (rawFid == null) return;
                final fid =
                    rawFid is int ? rawFid : int.tryParse(rawFid.toString());
                if (fid == null) return;
                final lastActive = row['last_read_chat_at'] as String?;
                _lastActiveAt[fid] =
                    lastActive != null ? _parseToLocal(lastActive) : null;
                if (mounted) setState(() {});
              },
            )
            .subscribe();
  }

  Future<void> _markAsRead(int furparentId) async {
    final nowLocal = DateTime.now();
    _lastReadAt[furparentId] = nowLocal;
    _unreadCounts[furparentId] = 0;
    if (nowLocal.toUtc().isAfter(_lastPolledAt)) {
      _lastPolledAt = nowLocal.toUtc();
    }
    if (mounted) setState(() {});
    try {
      await supabase.from('admin_read_receipts').upsert({
        'admin_id': _adminId,
        'furparent_id': furparentId,
        'last_read_at': nowLocal.toUtc().toIso8601String(),
      }, onConflict: 'admin_id,furparent_id');
    } catch (e) {
      debugPrint('Error persisting read receipt: $e');
    }
  }

  void _rebuildUnreadCounts() {
    for (final fid in _lastMessages.keys) {
      final lastMsg = _lastMessages[fid];
      if (lastMsg == null) continue;
      final fromAdmin = lastMsg['fromAdmin'] as bool? ?? false;
      if (fromAdmin) {
        _unreadCounts[fid] = 0;
        continue;
      }
      final msgTime = lastMsg['dateTime'] as DateTime?;
      final readAt = _lastReadAt[fid];
      if (msgTime == null) {
        _unreadCounts[fid] = 0;
      } else if (readAt != null && !msgTime.isAfter(readAt)) {
        _unreadCounts[fid] = 0;
      } else if (selectedUserId == fid) {
        _unreadCounts[fid] = 0;
      } else {
        if ((_unreadCounts[fid] ?? 0) == 0) _unreadCounts[fid] = 1;
      }
    }
  }

  int? _resolveFurparentId(Map<String, dynamic> msg) {
    final fid = msg['furparent_id'] as int?;
    if (fid != null) return fid;
    final roomId = msg['room_id'] as int?;
    if (roomId == null || roomId == 0) return null;
    final derived = roomId ~/ _adminId;
    return derived > 0 ? derived : null;
  }

  String? _bestTimestamp(Map<String, dynamic> msg) {
    final t = msg['time'] as String?;
    if (t != null && t.isNotEmpty) return t;
    return msg['created_at'] as String?;
  }

  void _processMessage(Map<String, dynamic> msg, {bool isInitialLoad = false}) {
    final fid = _resolveFurparentId(msg);
    if (fid == null) return;
    final timeStr = _bestTimestamp(msg);
    if (timeStr == null) return;

    final DateTime msgTime = _parseToLocal(timeStr);
    final int msgSortKey = _parseUtcMs(timeStr);

    final existing = _lastMessages[fid];
    final existingTime = existing?['dateTime'] as DateTime?;
    final fromAdmin = msg['admin_id'] == _adminId;
    final rawContent =
        (msg['image_url'] != null && (msg['image_url'] as String).isNotEmpty)
            ? 'Sent an image.'
            : (msg['content'] ?? '').toString();
    final content = fromAdmin ? 'You: $rawContent' : rawContent;
    if (existingTime == null || msgTime.isAfter(existingTime)) {
      _lastMessages[fid] = {
        'content': content,
        'timestamp': timeStr,
        'fromAdmin': fromAdmin,
        'dateTime': msgTime,
        'sortKey': msgSortKey,
      };
    }
    final msgId = msg['message_id'];
    final msgIdInt =
        msgId is int ? msgId : int.tryParse(msgId?.toString() ?? '');
    final alreadyCounted =
        msgIdInt != null && _processedMessageIds.contains(msgIdInt);
    if (msgIdInt != null) _processedMessageIds.add(msgIdInt);

    if (!isInitialLoad && !fromAdmin && !alreadyCounted) {
      if (selectedUserId == fid) {
        _unreadCounts[fid] = 0;
        _lastReadAt[fid] = msgTime;
      } else {
        _unreadCounts[fid] = (_unreadCounts[fid] ?? 0) + 1;
      }
    }
  }

  void _subscribeToMessages() {
    _messagesChannel = supabase
        .channel('messages-all-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final msg = payload.newRecord;
            if (msg.isEmpty) return;
            final fid = _resolveFurparentId(msg);
            if (fid == null) return;
            if (!_profiles.containsKey(fid)) await _loadProfileForUser(fid);
            _processMessage(msg, isInitialLoad: false);
            _rebuildSortedList();
            if (mounted) setState(() {});
          },
        )
        .subscribe((status, [error]) {
          debugPrint('📡 Messages channel: $status');
          if (error != null) debugPrint('❌ Channel error: $error');
        });
  }

  Future<void> _pollForNewMessages() async {
    try {
      final since = _lastPolledAt.toUtc().toIso8601String();
      _lastPolledAt = DateTime.now().toUtc();
      final newMessages = await supabase
          .from('messages')
          .select(
            'message_id, room_id, content, created_at, time, furparent_id, admin_id, image_url',
          )
          .gt('created_at', since)
          .order('created_at', ascending: true);
      if (newMessages.isEmpty) return;
      bool didUpdate = false;
      for (final msg in newMessages) {
        final fid = _resolveFurparentId(msg);
        if (fid == null) continue;
        if (!_profiles.containsKey(fid)) await _loadProfileForUser(fid);
        _processMessage(msg, isInitialLoad: false);
        didUpdate = true;
      }
      if (didUpdate) {
        _rebuildSortedList();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  Future<void> _loadMissingProfiles() async {
    final missing =
        _lastMessages.keys.where((id) => !_profiles.containsKey(id)).toList();
    if (missing.isEmpty) return;
    try {
      final rows = await supabase
          .from('profiles')
          .select(
            'furparent_id, first_name, last_name, avatar_url, last_read_chat_at',
          )
          .inFilter('furparent_id', missing);
      for (final row in rows) {
        final fid =
            row['furparent_id'] is int
                ? row['furparent_id'] as int
                : int.tryParse(row['furparent_id'].toString()) ?? 0;
        _profiles[fid] = {
          'name': '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
          'avatar_url': row['avatar_url'],
        };
        final lastActive = row['last_read_chat_at'] as String?;
        _lastActiveAt[fid] =
            lastActive != null ? _parseToLocal(lastActive) : null;
      }
      for (final id in missing) {
        _profiles.putIfAbsent(
          id,
          () => {'name': 'Unknown', 'avatar_url': null},
        );
        _lastActiveAt.putIfAbsent(id, () => null);
      }
    } catch (e) {
      debugPrint('Error loading profiles: $e');
    }
  }

  Future<void> _loadProfileForUser(int fid) async {
    try {
      final row =
          await supabase
              .from('profiles')
              .select(
                'furparent_id, first_name, last_name, avatar_url, last_read_chat_at',
              )
              .eq('furparent_id', fid)
              .maybeSingle();
      _profiles[fid] =
          row != null
              ? {
                'name':
                    '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'
                        .trim(),
                'avatar_url': row['avatar_url'],
              }
              : {'name': 'Unknown', 'avatar_url': null};
      final lastActive = row?['last_read_chat_at'] as String?;
      _lastActiveAt[fid] =
          lastActive != null ? _parseToLocal(lastActive) : null;
    } catch (e) {
      _profiles[fid] = {'name': 'Unknown', 'avatar_url': null};
      _lastActiveAt[fid] = null;
    }
  }

  Future<void> _refreshActiveStatus(int fid) async {
    try {
      final row =
          await supabase
              .from('profiles')
              .select('last_read_chat_at')
              .eq('furparent_id', fid)
              .maybeSingle();
      if (row == null) return;
      final lastActive = row['last_read_chat_at'] as String?;
      _lastActiveAt[fid] =
          lastActive != null ? _parseToLocal(lastActive) : null;
    } catch (_) {}
  }

  Map<String, dynamic> _formatActiveStatus(int userId) {
    final lastActive = _lastActiveAt[userId];
    if (lastActive != null) {
      final diff = DateTime.now().difference(lastActive);
      if (diff.inSeconds < 120) {
        return {'label': 'Active Now', 'isOnline': true};
      }
    }
    return {'label': 'Offline', 'isOnline': false};
  }

  void _rebuildSortedList() {
    _sortedUserIds =
        _lastMessages.keys.toList()..sort((a, b) {
          final ta = _lastMessages[a]?['sortKey'] as int?;
          final tb = _lastMessages[b]?['sortKey'] as int?;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
  }

  Future<void> _loadProfileImageForAvatar() async {
    if (_isLoadingAvatar) return;
    setState(() => _isLoadingAvatar = true);
    try {
      final response =
          await supabase
              .from('admin')
              .select('admin_profile')
              .eq('admin_id', _adminId)
              .maybeSingle();
      if (response == null) return;
      final profileData = response['admin_profile']?.toString();
      String? publicUrl;
      if (profileData != null && profileData.isNotEmpty) {
        publicUrl =
            profileData.startsWith('http')
                ? profileData
                : supabase.storage
                    .from('admin_profile')
                    .getPublicUrl(profileData);
        publicUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      }
      if (mounted) {
        setState(() {
          _cachedProfileImage = publicUrl;
          _isLoadingAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  int _generateRoomId(int adminId, int furparentId) => adminId * furparentId;

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || selectedUserId == null) return;
    final roomId = _generateRoomId(_adminId, selectedUserId!);
    final nowUtc = DateTime.now().toUtc();
    final nowIso = nowUtc.toIso8601String();
    final nowLocal = nowUtc.toLocal();
    final nowSortKey = nowUtc.millisecondsSinceEpoch;
    _messageController.clear();
    _lastMessages[selectedUserId!] = {
      'content': 'You: $text',
      'timestamp': nowIso,
      'fromAdmin': true,
      'dateTime': nowLocal,
      'sortKey': nowSortKey,
    };
    _unreadCounts[selectedUserId!] = 0;
    _rebuildSortedList();
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    try {
      await supabase.from('messages').insert({
        'room_id': roomId,
        'furparent_id': selectedUserId,
        'admin_id': _adminId,
        'content': text,
        'image_url': null,
        'created_at': nowIso,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      _showSnackBar('Failed to send message.', Colors.red);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (selectedUserId == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (e) {
      debugPrint('Error reading image bytes: $e');
      _showSnackBar('Failed to read image.', Colors.red);
      return;
    }

    final imageUrl = await _uploadImageToCloudinaryBytes(bytes, picked.name);
    if (imageUrl == null) {
      _showSnackBar('Failed to upload image.', Colors.red);
      return;
    }

    final roomId = _generateRoomId(_adminId, selectedUserId!);
    final nowUtc = DateTime.now().toUtc();
    final nowIso = nowUtc.toIso8601String();
    final nowLocal = nowUtc.toLocal();
    final nowSortKey = nowUtc.millisecondsSinceEpoch;
    _lastMessages[selectedUserId!] = {
      'content': 'You: Sent an Image',
      'timestamp': nowIso,
      'fromAdmin': true,
      'dateTime': nowLocal,
      'sortKey': nowSortKey,
    };
    _unreadCounts[selectedUserId!] = 0;
    _rebuildSortedList();
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      await supabase.from('messages').insert({
        'room_id': roomId,
        'furparent_id': selectedUserId,
        'admin_id': _adminId,
        'content': 'Sent an image.',
        'image_url': imageUrl,
        'created_at': nowIso,
      });
      _showSnackBar('Image sent successfully.', Colors.green);
    } catch (e) {
      debugPrint('Error inserting image message: $e');
      _showSnackBar('Failed to send image message.', Colors.red);
    }
  }

  Future<String?> _uploadImageToCloudinaryBytes(
    Uint8List bytes,
    String filename,
  ) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']!;
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );
    try {
      final request =
          http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: filename),
            );
      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      if (response.statusCode == 200)
        return jsonDecode(resBody)['secure_url'] as String?;
    } catch (e) {
      debugPrint('Cloudinary upload failed: $e');
    }
    return null;
  }

  // ─── SnackBar helper (matches ReadyToAdoptPage) ───────────────────────────
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                backgroundColor == Colors.green
                    ? Icons.check_circle_outline
                    : backgroundColor == Colors.red
                    ? Icons.error_outline
                    : Icons.info_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          duration: const Duration(seconds: 3),
        ),
      );
  }
  // ─────────────────────────────────────────────────────────────────────────

  String _formatRelativeTime(dynamic timeObj) {
    final DateTime dt =
        timeObj is DateTime ? timeObj : _parseToLocal(timeObj?.toString());
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  String _formatMessageTime(dynamic timeObj) {
    final DateTime dt =
        timeObj is DateTime ? timeObj : _parseToLocal(timeObj?.toString());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    final hour = dt.hour;
    final minute = dt.minute;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final time = '${_twoDigit(displayHour)}:${_twoDigit(minute)} $ampm';
    if (diff == 0) return time;
    if (diff == 1) return 'Yesterday $time';
    if (diff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[dt.weekday - 1]} $time';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, $time';
  }

  String _twoDigit(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return WillPopScope(
      onWillPop: () async {
        if (isMobile && selectedUserId != null) {
          setState(() => selectedUserId = null);
          return false;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2D2D2D),
        drawer: isMobile ? Drawer(width: 200, child: _buildSidebar()) : null,
        body: Row(
          children: [
            if (!isMobile) _buildSidebar(),
            Expanded(child: _buildMainContent(isMobile)),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 200,
      color: const Color(0xFF1C1C1C),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Image.asset(
              'assets/images/adminlogo.png',
              width: 100,
              height: 100,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _sidebarItem(
                    'assets/icons/dashboardicon.png',
                    'Dashboard',
                    () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DashboardPage()),
                    ),
                  ),
                  _sidebarItem(
                    'assets/icons/activitylogsicon.png',
                    'Activity Logs',
                    () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivityLogsPage(),
                      ),
                    ),
                  ),
                  _sidebarItem(
                    'assets/icons/appointment.png',
                    'Appointment',
                    () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppointmentPage(),
                      ),
                    ),
                  ),
                  _sidebarItem(
                    'assets/icons/approval.png',
                    'Approval',
                    () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ApprovalPage()),
                    ),
                  ),
                  _sidebarItem(
                    'assets/icons/accountmngmnt.png',
                    'Account Management',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountManagementListPage(),
                      ),
                    ),
                  ),
                  _sidebarItem(
                    'assets/icons/events.png',
                    'Events',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EventsPage()),
                    ),
                  ),
                  _sidebarItem(
                    'assets/icons/petsicon.png',
                    'Pet Management',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PetPage()),
                    ),
                  ),
                  _sidebarItem(
                    'assets/icons/chatsicon.png',
                    'Chats',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatPage()),
                    ),
                  ),
                  _sidebarItem(
                    'assets/icons/donationicon.png',
                    'Donation',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DonationPage()),
                    ),
                  ),
                  _sidebarItem(
                    'assets/icons/reportsicon.png',
                    'Report',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: _alertDialog,
            child: const Text(
              'Log out',
              style: TextStyle(
                color: Colors.white,
                decoration: TextDecoration.underline,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(String icon, String label, VoidCallback onTap) {
    final isActive = _selectedItem == label;
    return _HoverSidebarItem(
      icon: icon,
      label: label,
      isActive: isActive,
      onTap: () {
        setState(() => _selectedItem = label);
        onTap();
      },
    );
  }

  void _alertDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'LOG OUT',
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
            content: const Text(
              'Are you sure you want to log out?',
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('admin_id');

                  adminId = null;

                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnimatedAdminLoginPage(),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildTopHeader(isMobile),
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  final isChat = selectedUserId != null;
                  final offsetBegin =
                      isChat ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: offsetBegin,
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  );
                },
                child:
                    selectedUserId == null
                        ? KeyedSubtree(
                          key: const ValueKey('user-list'),
                          child: _buildUserList(),
                        )
                        : KeyedSubtree(
                          key: ValueKey('chat-$selectedUserId'),
                          child: _buildChatWindow(),
                        ),
              ),
            ),
          ),
          _buildFooter(context),
        ],
      );
    }

    return Column(
      children: [
        _buildTopHeader(isMobile),
        Expanded(
          child: Container(
            color: const Color(0xFF121212),
            child: Row(
              children: [_buildUserList(), Expanded(child: _buildChatWindow())],
            ),
          ),
        ),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildTopHeader(bool isMobile) {
    final totalUnread = _unreadCounts.values.fold(0, (a, b) => a + b);

    if (isMobile && selectedUserId != null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
      color: const Color(0xFF1C1C1C),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder:
                  (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    padding: EdgeInsets.zero,
                  ),
            ),

          Padding(
            padding: EdgeInsets.only(left: isMobile ? 4 : 0),
            child: Text(
              'Chats',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 14 : 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),

          if (totalUnread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalUnread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],

          const Spacer(),

          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ShelterProjectsPage()),
                ),
            child: Image.asset(
              'assets/icons/shelterprojects.png',
              width: isMobile ? 22 : 26,
              height: isMobile ? 22 : 26,
            ),
          ),

          const SizedBox(width: 4),

          _NotificationBell(
            iconSize: isMobile ? 20 : 22,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6),
          ),

          const SizedBox(width: 6),

          _buildProfileAvatar(context, radius: isMobile ? 14 : 16),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context, {double radius = 16}) {
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfilePage()),
          ).then((_) => _loadProfileImageForAvatar()),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child:
            _isLoadingAvatar
                ? SizedBox(
                  width: radius * 1.2,
                  height: radius * 1.2,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                )
                : (_cachedProfileImage != null &&
                    _cachedProfileImage!.isNotEmpty)
                ? ClipOval(
                  child: Image.network(
                    _cachedProfileImage!,
                    key: ValueKey(_cachedProfileImage),
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Icon(
                          Icons.person,
                          color: Colors.black,
                          size: radius,
                        ),
                  ),
                )
                : Icon(Icons.person, color: Colors.black, size: radius),
      ),
    );
  }

  Widget _buildUserList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 800;

    final double listWidth =
        isMobile ? double.infinity : (screenWidth < 1000 ? 280 : 350);

    final visibleIds =
        _searchQuery.isEmpty
            ? _sortedUserIds
            : _sortedUserIds.where((id) {
              final name =
                  (_profiles[id]?['name'] ?? '').toString().toLowerCase();
              final msg =
                  (_lastMessages[id]?['content'] ?? '')
                      .toString()
                      .toLowerCase();
              return name.contains(_searchQuery) || msg.contains(_searchQuery);
            }).toList();

    return Container(
      width: listWidth,
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                contentPadding: EdgeInsets.symmetric(
                  vertical: isMobile ? 10 : 14,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visibleIds.length,
              itemBuilder: (context, i) {
                final userId = visibleIds[i];
                final profile =
                    _profiles[userId] ??
                    {'name': 'Unknown', 'avatar_url': null};
                final lastMsg = _lastMessages[userId];
                return _buildUserTile(
                  userId: userId,
                  name: profile['name'] ?? 'Unknown',
                  avatarUrl: profile['avatar_url'],
                  messageText: lastMsg?['content'] ?? '',
                  timestamp: lastMsg?['timestamp'],
                  unreadCount: _unreadCounts[userId] ?? 0,
                  isSelected: userId == selectedUserId,
                  isMobile: isMobile,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile({
    required int userId,
    required String name,
    required String? avatarUrl,
    required String messageText,
    required dynamic timestamp,
    required int unreadCount,
    required bool isSelected,
    bool isMobile = false,
  }) {
    final hasUnread = unreadCount > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 2 : 3,
      ),
      decoration: BoxDecoration(
        border:
            isSelected
                ? const Border(left: BorderSide(color: Colors.orange, width: 4))
                : hasUnread
                ? const Border(left: BorderSide(color: Colors.orange, width: 3))
                : null,
        color:
            isSelected
                ? Colors.orange.withOpacity(0.15)
                : hasUnread
                ? Colors.white.withOpacity(0.04)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 12,
          vertical: isMobile ? 2 : 4,
        ),
        dense: isMobile,
        leading: Stack(
          children: [
            CircleAvatar(
              radius: isMobile ? 20 : 22,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              backgroundColor: Colors.orange.withOpacity(0.25),
              child:
                  avatarUrl == null
                      ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      )
                      : null,
            ),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding:
                      unreadCount > 9
                          ? const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          )
                          : const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape:
                        unreadCount > 9 ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius:
                        unreadCount > 9 ? BorderRadius.circular(8) : null,
                    border: Border.all(
                      color: const Color(0xFF1E1E1E),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.orange : Colors.white,
            fontFamily: 'Montserrat',
            fontWeight:
                (isSelected || hasUnread) ? FontWeight.bold : FontWeight.normal,
            fontSize: isMobile ? 13 : 14,
          ),
        ),
        subtitle: Text(
          messageText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hasUnread && !isSelected ? Colors.white : Colors.white54,
            fontFamily: 'Montserrat',
            fontWeight:
                hasUnread && !isSelected ? FontWeight.w700 : FontWeight.normal,
            fontSize: isMobile ? 11 : 12,
          ),
        ),
        trailing: Text(
          timestamp != null ? _formatRelativeTime(timestamp) : '',
          style: TextStyle(
            color: hasUnread && !isSelected ? Colors.orange : Colors.white38,
            fontSize: isMobile ? 10 : 11,
            fontFamily: 'Montserrat',
            fontWeight:
                hasUnread && !isSelected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() => selectedUserId = userId);
          _markAsRead(userId);
          _messageController.clear();
        },
      ),
    );
  }

  Widget _buildChatWindow() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    if (selectedUserId == null) {
      return const Center(
        child: Text(
          'Select a user to start chatting',
          style: TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
        ),
      );
    }

    final roomId = _generateRoomId(_adminId, selectedUserId!);
    final userName = _profiles[selectedUserId]?['name'] ?? 'Unknown';
    final avatarUrl = _profiles[selectedUserId]?['avatar_url'];
    final activeStatus = _formatActiveStatus(selectedUserId!);
    final activeLabel = activeStatus['label'] as String;
    final isOnline = activeStatus['isOnline'] as bool;

    return Column(
      children: [
        Container(
          color: const Color(0xFF1A1A1A),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 4 : 16,
            vertical: isMobile ? 6 : 10,
          ),
          child: Row(
            children: [
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () => setState(() => selectedUserId = null),
                ),
              Stack(
                children: [
                  CircleAvatar(
                    radius: isMobile ? 17 : 20,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    backgroundColor: Colors.orange.withOpacity(0.25),
                    child:
                        avatarUrl == null
                            ? Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 13 : 15,
                              ),
                            )
                            : null,
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFF31A24C),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1A1A1A),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 13 : 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color:
                                isOnline
                                    ? const Color(0xFF31A24C)
                                    : Colors.grey.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activeLabel,
                          style: TextStyle(
                            color:
                                isOnline
                                    ? const Color(0xFF31A24C)
                                    : Colors.white38,
                            fontSize: isMobile ? 10 : 11,
                            fontFamily: 'Montserrat',
                            fontWeight:
                                isOnline ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (isMobile) ...[
                GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShelterProjectsPage(),
                        ),
                      ),
                  child: Image.asset(
                    'assets/icons/shelterprojects.png',
                    width: 22,
                    height: 22,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NotificationPage()),
                      ),
                ),
                _buildProfileAvatar(context, radius: 14),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('messages')
                .stream(primaryKey: ['message_id'])
                .eq('room_id', roomId)
                .order('message_id', ascending: true),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                );
              }
              final msgs = snapshot.data!;
              if (msgs.isEmpty) {
                return const Center(
                  child: Text(
                    'No messages yet.',
                    style: TextStyle(
                      color: Colors.white38,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                controller: _chatScrollController,
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                itemCount: msgs.length,
                itemBuilder: (context, index) {
                  final msg = msgs[msgs.length - 1 - index];
                  final isAdmin = msg['admin_id'] == _adminId;
                  final tsStr = _bestTimestamp(msg);
                  final msgTimeLocal = _parseToLocal(tsStr);
                  final readAt = _lastReadAt[selectedUserId];
                  final isUnread =
                      !isAdmin &&
                      (readAt == null || msgTimeLocal.isAfter(readAt));
                  return _buildMessageBubble(
                    msg,
                    isAdmin,
                    msgTimeLocal: msgTimeLocal,
                    isUnread: isUnread,
                    isMobile: isMobile,
                  );
                },
              );
            },
          ),
        ),

        _buildMessageInput(isMobile: isMobile),
      ],
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isAdmin, {
    required DateTime msgTimeLocal,
    bool isUnread = false,
    bool isMobile = false,
  }) {
    final timeLabel = _formatMessageTime(msgTimeLocal);
    final readAt = _lastReadAt[selectedUserId];

    return Row(
      mainAxisAlignment:
          isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * (isMobile ? 0.85 : 0.75),
                ),
                child: Column(
                  crossAxisAlignment:
                      isAdmin
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(vertical: isMobile ? 2 : 4),
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color:
                            isAdmin
                                ? Colors.orange
                                : isUnread
                                ? const Color(0xFF3A3A3A).withOpacity(0.9)
                                : const Color(0xFF3A3A3A),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft:
                              isAdmin ? const Radius.circular(16) : Radius.zero,
                          bottomRight:
                              isAdmin ? Radius.zero : const Radius.circular(16),
                        ),
                        border:
                            isUnread && !isAdmin
                                ? Border.all(
                                  color: Colors.orange.withOpacity(0.5),
                                  width: 1,
                                )
                                : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg['is_deleted'] == true)
                            Text(
                              'Deleted a message',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color:
                                    isAdmin ? Colors.white70 : Colors.white54,
                                fontFamily: 'Montserrat',
                                fontSize: isMobile ? 13 : 14,
                              ),
                            )
                          else ...[
                            if (msg['image_url'] != null &&
                                (msg['image_url'] as String).isNotEmpty)
                              GestureDetector(
                                onTap:
                                    () => _openImageViewer(
                                      context,
                                      msg['image_url'],
                                    ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isMobile ? 140 : 160,
                                      maxHeight: isMobile ? 140 : 160,
                                    ),
                                    child: Image.network(
                                      msg['image_url'],
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (ctx, child, progress) =>
                                              progress == null
                                                  ? child
                                                  : SizedBox(
                                                    height:
                                                        isMobile ? 100 : 120,
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ),
                                      errorBuilder:
                                          (_, __, ___) => const Icon(
                                            Icons.broken_image,
                                            color: Colors.white54,
                                            size: 40,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            if ((msg['content'] ?? '').toString().isNotEmpty &&
                                msg['content'] != 'Sent an image.')
                              Padding(
                                padding: EdgeInsets.only(
                                  top:
                                      (msg['image_url'] != null &&
                                              (msg['image_url'] as String)
                                                  .isNotEmpty)
                                          ? 6
                                          : 0,
                                ),
                                child: Text(
                                  msg['content'],
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Montserrat',
                                    fontSize: isMobile ? 13 : 14,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 4,
                        left: 4,
                        right: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: isMobile ? 9 : 10,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all,
                              size: 13,
                              color:
                                  (readAt != null &&
                                          !readAt.isBefore(msgTimeLocal))
                                      ? Colors.orange
                                      : Colors.white38,
                            ),
                          ],
                          if (!isAdmin && isUnread) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'New',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openImageViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder:
          (_) => GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildMessageInput({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 8,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2C),
        border: Border(top: BorderSide(color: Colors.orange, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.image,
                color: Colors.orange,
                size: isMobile ? 22 : 24,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: isMobile ? 36 : 40,
                minHeight: isMobile ? 36 : 40,
              ),
              onPressed: _pickAndSendImage,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontSize: isMobile ? 13 : 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: isMobile ? 13 : 14,
                    color: Colors.white38,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 4,
                    vertical: 0,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.send,
                color: Colors.orange,
                size: isMobile ? 22 : 24,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: isMobile ? 36 : 40,
                minHeight: isMobile ? 36 : 40,
              ),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Container(
      height: isMobile ? 36 : 40,
      color: const Color(0xFF181818),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Center(
        child: Text(
          'Harvard 2025 Pet Adoption',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatefulWidget {
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const _NotificationBell({
    this.iconSize = 24,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _channel =
        supabase
            .channel('notif_bell_${identityHashCode(this)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              callback: (payload) {
                if (mounted) {
                  setState(() => _notifications.insert(0, payload.newRecord));
                }
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'notifications',
              callback: (payload) {
                final deletedId = payload.oldRecord['notification_id'];
                if (deletedId != null && mounted) {
                  setState(
                    () => _notifications.removeWhere(
                      (n) => n['notification_id'] == deletedId,
                    ),
                  );
                }
              },
            )
            .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Bell load error: $e');
    }
  }

  Future<void> _deleteNotification(int id) async {
    setState(
      () => _notifications.removeWhere((n) => n['notification_id'] == id),
    );
    try {
      await supabase.from('notifications').delete().eq('notification_id', id);
    } catch (e) {
      await _loadNotifications();
    }
  }

  String _timeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  void _openPanel(BuildContext context) {
    final notifs = List<Map<String, dynamic>>.from(_notifications);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _NotificationPanel(
            notifications: notifs,
            onDelete: _deleteNotification,
            onClearAll: () async {
              final ids =
                  _notifications.map((n) => n['notification_id']).toList();
              setState(() => _notifications.clear());
              Navigator.pop(context);
              for (final id in ids) {
                try {
                  await supabase
                      .from('notifications')
                      .delete()
                      .eq('notification_id', id);
                } catch (_) {}
              }
            },
            onRefresh: _loadNotifications,
            timeAgo: _timeAgo,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _notifications.length;
    return GestureDetector(
      onTap: () => _openPanel(context),
      child: Padding(
        padding: widget.padding,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications,
              color: Colors.white,
              size: widget.iconSize,
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function(int id) onDelete;
  final Future<void> Function() onClearAll;
  final Future<void> Function() onRefresh;
  final String Function(String?) timeAgo;

  const _NotificationPanel({
    required this.notifications,
    required this.onDelete,
    required this.onClearAll,
    required this.onRefresh,
    required this.timeAgo,
  });

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.notifications);
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'event_added':
        return Icons.event_available;
      case 'event_ended':
        return Icons.event_busy;
      case 'system':
        return Icons.info_outline;
      case 'pet_report':
        return Icons.pets;
      case 'report_to_rescue':
        return Icons.local_hospital;
      case 'rescue_to_medication':
        return Icons.medical_services;
      default:
        return Icons.notifications_active;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'event_added':
        return Colors.green;
      case 'event_ended':
        return Colors.orange;
      case 'system':
        return Colors.blue;
      case 'pet_report':
        return Colors.purple;
      case 'report_to_rescue':
        return Colors.red;
      case 'rescue_to_medication':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (_items.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      setState(() => _items.clear());
                      await widget.onClearAll();
                    },
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () async {
                    await widget.onRefresh();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          Flexible(
            child:
                _items.isEmpty
                    ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            color: Colors.white24,
                            size: 48,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No notifications',
                            style: TextStyle(
                              color: Colors.white38,
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _items.length,
                      separatorBuilder:
                          (_, __) =>
                              const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final notif = _items[index];
                        final id = notif['notification_id'] as int?;
                        final title =
                            notif['title'] as String? ?? 'Notification';
                        final message = notif['message'] as String? ?? '';
                        final type = notif['type'] as String? ?? 'system';
                        final timeStr = widget.timeAgo(
                          notif['created_at'] as String?,
                        );
                        final color = _colorFor(type);

                        return Dismissible(
                          key: ValueKey('panel_notif_${id}_$index'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            setState(() => _items.removeAt(index));
                            if (id != null) widget.onDelete(id);
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: Colors.red.shade900,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: color.withOpacity(0.18),
                              child: Icon(
                                _iconFor(type),
                                color: color,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (message.isNotEmpty)
                                  Text(
                                    message,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontFamily: 'Montserrat',
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (timeStr.isNotEmpty)
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontFamily: 'Montserrat',
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            trailing:
                                id != null
                                    ? GestureDetector(
                                      onTap: () {
                                        setState(() => _items.removeAt(index));
                                        widget.onDelete(id);
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white24,
                                        size: 18,
                                      ),
                                    )
                                    : null,
                          ),
                        );
                      },
                    ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _HoverSidebarItem extends StatefulWidget {
  final String icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _HoverSidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_HoverSidebarItem> createState() => _HoverSidebarItemState();
}

class _HoverSidebarItemState extends State<_HoverSidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final showHighlight = widget.isActive || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration:
              showHighlight
                  ? BoxDecoration(
                    color:
                        widget.isActive
                            ? Colors.orange
                            : Colors.orange.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  )
                  : BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
          child: ListTile(
            leading: Image.asset(
              widget.icon,
              width: 22,
              height: 22,
              color: Colors.white,
            ),
            title: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'OdorMeanChey',
                fontSize: 13,
              ),
            ),
            dense: true,
          ),
        ),
      ),
    );
  }
}
