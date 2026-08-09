import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';
import 'package:apawtmentweb_admin/dashboardpage.dart';
import 'package:apawtmentweb_admin/donationpage.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/main.dart';
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> logActivity({
  required String action,
  required String description,
  required String entityType,
  dynamic entityId,
  int adminId = 1,
}) async {
  try {
    int? validEntityId;
    if (entityId != null) {
      final parsed = int.tryParse(entityId.toString());
      if (parsed != null && parsed <= 2147483647 && parsed >= -2147483648) {
        validEntityId = parsed;
      }
    }

    await Supabase.instance.client.from('activity_logs').insert({
      'admin_id': adminId,
      'action': action,
      'description': description,
      'entity_type': entityType,
      'entity_id': validEntityId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  } catch (e) {
    debugPrint('❌ logActivity error: $e');
  }
}

class ActivityLogsPage extends StatefulWidget {
  const ActivityLogsPage({super.key});

  @override
  State<ActivityLogsPage> createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends State<ActivityLogsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String selectedItem = 'Activity Logs';
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  RealtimeChannel? _channel;
  late TabController _tabController;

  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadLogs();
      }
    });
    saveLastVisitedPage('Activity Logs');
    _loadLogs();
    _loadProfileImageForAvatar();
    _setupRealtime();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadProfileImageForAvatar(),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

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

  void _setupRealtime() {
    _channel = supabase.channel('activity-logs-realtime');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'activity_logs',
          callback: (_) {
            if (_tabController.index == 0) _loadLogs();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subadmin_activity_logs',
          callback: (_) {
            if (_tabController.index == 1) _loadLogs();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vet_activity_logs',
          callback: (_) {
            if (_tabController.index == 2) _loadLogs();
          },
        )
        .subscribe();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      if (_tabController.index == 0) {
        final response = await supabase
            .from('activity_logs')
            .select()
            .order('created_at', ascending: false)
            .limit(200);

        if (mounted) {
          setState(() {
            _logs = List<Map<String, dynamic>>.from(response);
            _isLoading = false;
          });
        }
      } else if (_tabController.index == 1) {
        final response = await supabase
            .from('subadmin_activity_logs')
            .select(
              '*, subadmin_profiles(first_name, middle_name, last_name, suffix_name, username, to_email, is_archived, status)',
            )
            .order('created_at', ascending: false)
            .limit(200);

        if (mounted) {
          setState(() {
            _logs = List<Map<String, dynamic>>.from(response);
            _isLoading = false;
          });
        }
      } else {
        final response = await supabase
            .from('vet_activity_logs')
            .select(
              '*, veterinarians(first_name, middle_name, last_name, suffix_name, email, account_status, status)',
            )
            .order('created_at', ascending: false)
            .limit(200);

        if (mounted) {
          setState(() {
            _logs = List<Map<String, dynamic>>.from(response);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading activity logs: $e');
      if (mounted) {
        setState(() {
          _logs = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteLog(Map<String, dynamic> log) async {
    final id = log['logs_id'] ?? log['id'];
    if (id == null) return;

    String table = 'activity_logs';
    String idCol = 'logs_id';
    if (_tabController.index == 1) {
      table = 'subadmin_activity_logs';
      idCol = log.containsKey('logs_id') ? 'logs_id' : 'id';
    } else if (_tabController.index == 2) {
      table = 'vet_activity_logs';
      idCol = log.containsKey('logs_id') ? 'logs_id' : 'id';
    }

    try {
      await supabase.from(table).delete().eq(idCol, id);
      setState(() => _logs.removeWhere((l) => (l['logs_id'] ?? l['id']) == id));
      _showSnackBar('Activity log deleted.', Colors.green);
    } catch (e) {
      debugPrint('❌ Error deleting log: $e');
      _showSnackBar('Failed to delete log entry.', Colors.red);
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              _tabController.index == 0
                  ? 'Clear Admin Activity Logs'
                  : _tabController.index == 1
                      ? 'Clear Staff Activity Logs'
                      : 'Clear Veterinarian Activity Logs',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'This will permanently delete these activity logs. This cannot be undone.',
              style: TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    String table = 'activity_logs';
    String idCol = 'logs_id';
    if (_tabController.index == 1) {
      table = 'subadmin_activity_logs';
      idCol = (_logs.isNotEmpty && _logs.first.containsKey('logs_id')) ? 'logs_id' : 'id';
    } else if (_tabController.index == 2) {
      table = 'vet_activity_logs';
      idCol = (_logs.isNotEmpty && _logs.first.containsKey('logs_id')) ? 'logs_id' : 'id';
    }

    try {
      await supabase.from(table).delete().gt(idCol, 0);
      setState(() => _logs.clear());
      _showSnackBar('All activity logs cleared.', Colors.red);
    } catch (e) {
      debugPrint('❌ Error clearing logs: $e');
      _showSnackBar('Failed to clear logs.', Colors.red);
    }
  }

  Future<void> _loadProfileImageForAvatar() async {
    if (_isLoadingAvatar) return;
    setState(() => _isLoadingAvatar = true);
    try {
      final response =
          await supabase
              .from('admin')
              .select('admin_profile')
              .eq('admin_id', 1)
              .maybeSingle();
      if (response == null) {
        if (mounted) setState(() => _isLoadingAvatar = false);
        return;
      }
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

  IconData _iconForEntityType(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'pet':
        return Icons.pets;
      case 'appointment':
        return Icons.calendar_today;
      case 'request':
        return Icons.assignment_turned_in;
      default:
        return Icons.history;
    }
  }

  Color _colorForAction(String action) {
    final a = action.toLowerCase();
    if (a.contains('delete')) return Colors.redAccent;
    if (a.contains('move')) return Colors.orange;
    if (a.contains('approv')) return Colors.green;
    if (a.contains('reject')) return Colors.deepOrange;
    return Colors.blue;
  }

  String _timeAgo(String? s) {
    if (s == null) return '';
    try {
      final dt = DateTime.parse(s).toLocal();
      final d = DateTime.now().difference(dt);
      if (d.inMinutes < 1) return 'Just now';
      if (d.inHours < 1) return '${d.inMinutes}m ago';
      if (d.inDays < 1) return '${d.inHours}h ago';
      if (d.inDays < 7) return '${d.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF101010),
      drawer: _isMobile ? Drawer(width: 200, child: _buildSidebar()) : null,
      body: Row(
        children: [
          if (!_isMobile) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBarSection(),
                _buildSummaryStrip(),
                Expanded(child: _buildBody()),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarSection() {
    if (_isMobile) {
      return Container(
        color: const Color(0xFF181818),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              dropdownColor: const Color(0xFF1C1C1C),
              value: _tabController.index,
              isExpanded: true,
              style: const TextStyle(
                color: Colors.orange,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
              items: const [
                DropdownMenuItem<int>(
                  value: 0,
                  child: Text('Admin Logs'),
                ),
                DropdownMenuItem<int>(
                  value: 1,
                  child: Text('Staff Logs'),
                ),
                DropdownMenuItem<int>(
                  value: 2,
                  child: Text('Veterinarian Logs'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _tabController.index = val;
                  });
                  _loadLogs();
                }
              },
            ),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFF181818),
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.orange,
        labelColor: Colors.orange,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Admin'),
          Tab(text: 'Staff'),
          Tab(text: 'Veterinarian'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: _isMobile ? 8 : 16),
      color: const Color(0xFF1C1C1C),
      child: Row(
        children: [
          if (_isMobile)
            Builder(
              builder:
                  (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    padding: EdgeInsets.zero,
                  ),
            ),

          Padding(
            padding: EdgeInsets.only(left: _isMobile ? 4 : 0),
            child: Text(
              'Activity Logs',
              style: TextStyle(
                color: Colors.white,
                fontSize: _isMobile ? 14 : 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),

          const Spacer(),

          _isMobile
              ? IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white70,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                onPressed: _loadLogs,
                tooltip: 'Refresh',
              )
              : ElevatedButton.icon(
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text(
                  'Refresh',
                  style: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  elevation: 0,
                ),
              ),

          const SizedBox(width: 6),

          if (_logs.isNotEmpty) ...[
            _isMobile
                ? IconButton(
                  icon: const Icon(
                    Icons.delete_sweep,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _clearAll,
                  tooltip: 'Clear All',
                )
                : ElevatedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: const Text(
                    'Clear All',
                    style: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.15),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    elevation: 0,
                  ),
                ),
            const SizedBox(width: 6),
          ],

          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ShelterProjectsPage()),
                ),
            child: Image.asset(
              'assets/icons/shelterprojects.png',
              width: _isMobile ? 22 : 26,
              height: _isMobile ? 22 : 26,
            ),
          ),

          const SizedBox(width: 4),

          const SizedBox(width: 6),

          _buildProfileAvatar(),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final total = _logs.length;
    final today =
        _logs.where((l) {
          final raw = l['created_at']?.toString();
          if (raw == null) return false;
          try {
            final dt = DateTime.parse(raw).toLocal();
            final now = DateTime.now();
            return dt.year == now.year &&
                dt.month == now.month &&
                dt.day == now.day;
          } catch (_) {
            return false;
          }
        }).length;

    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _summaryChip(Icons.history, 'Total Logs', total, Colors.blue),
          const SizedBox(width: 8),
          _summaryChip(Icons.today, 'Today', today, Colors.orange),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 50,
        ),
      );
    }
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, color: Colors.white12, size: 56),
            const SizedBox(height: 12),
            const Text(
              'No activity logs yet',
              style: TextStyle(
                color: Colors.white38,
                fontFamily: 'Montserrat',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _tabController.index == 0
                  ? 'Admin actions like moving, deleting, or approving will appear here.'
                  : _tabController.index == 1
                      ? 'Staff actions and updates will appear here.'
                      : 'Veterinarian logs and diagnostic actions will appear here.',
              style: const TextStyle(
                color: Colors.white24,
                fontFamily: 'Montserrat',
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: Colors.blue,
      onRefresh: _loadLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _logs.length,
        itemBuilder: (_, i) => _logCard(_logs[i]),
      ),
    );
  }

  Widget _logCard(Map<String, dynamic> log) {
    final action = (log['action'] ?? 'Action').toString();
    final description = (log['description'] ?? '').toString();
    final entityType = (log['entity_type'] ?? '').toString();
    final color = _colorForAction(action);
    final logId = log['logs_id'] ?? log['id'];

    String? performerInfo;
    IconData? performerIcon;
    Color? performerColor;

    if (_tabController.index == 1) {
      final profile = log['subadmin_profiles'] as Map<String, dynamic>?;
      if (profile != null) {
        final fName = (profile['first_name'] ?? '').toString().trim();
        final lName = (profile['last_name'] ?? '').toString().trim();
        final username = (profile['username'] ?? '').toString().trim();
        final email = (profile['to_email'] ?? profile['email'] ?? '').toString().trim();
        final isArchived = profile['is_archived'] == true ||
            profile['status'] == 'Disabled' ||
            profile['status'] == 'Archived';

        String name = [fName, lName].where((n) => n.isNotEmpty).join(' ');
        if (name.isEmpty) name = username;
        if (name.isEmpty) name = email;
        if (name.isEmpty) name = 'Staff Member';

        performerInfo = name + (isArchived ? ' (Archived)' : '');
        performerIcon = Icons.person;
        performerColor = Colors.orange;
      } else {
        performerInfo = 'Unknown Staff';
        performerIcon = Icons.person;
        performerColor = Colors.orange;
      }
    } else if (_tabController.index == 2) {
      final profile = log['veterinarians'] as Map<String, dynamic>?;
      if (profile != null) {
        final fName = (profile['first_name'] ?? '').toString().trim();
        final lName = (profile['last_name'] ?? '').toString().trim();
        final email = (profile['email'] ?? '').toString().trim();
        final isArchived = profile['account_status'] == 'Archived' ||
            profile['status'] == 'Disabled' ||
            profile['status'] == 'Archived';

        String name = [fName, lName].where((n) => n.isNotEmpty).join(' ');
        if (name.isEmpty) name = email;
        if (name.isEmpty) name = 'Veterinarian';

        performerInfo = name + (isArchived ? ' (Archived)' : '');
        performerIcon = Icons.medical_services;
        performerColor = Colors.purple;
      } else {
        performerInfo = 'Unknown Vet';
        performerIcon = Icons.medical_services;
        performerColor = Colors.purple;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForEntityType(entityType), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (entityType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          entityType,
                          style: TextStyle(
                            color: color,
                            fontFamily: 'Montserrat',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                     description,
                     style: const TextStyle(
                       color: Colors.white60,
                       fontFamily: 'Montserrat',
                       fontSize: 12,
                     ),
                  ),
                ],
                if (performerInfo != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(performerIcon, size: 11, color: performerColor?.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        performerInfo,
                        style: TextStyle(
                          color: performerColor?.withOpacity(0.85),
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 11,
                      color: Colors.white30,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _timeAgo(log['created_at']?.toString()),
                      style: const TextStyle(
                        color: Colors.white30,
                        fontFamily: 'Montserrat',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (logId != null)
            GestureDetector(
              onTap: () => _deleteLog(log),
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.close, color: Colors.white24, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() => Container(
    height: 38,
    color: const Color(0xFF181818),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: const Row(
      children: [
        Text(
          'Harvard 2025 Pet Adoption',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    ),
  );

  Widget _buildProfileAvatar() {
    const double radius = 16;
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
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
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
                        (_, __, ___) => const Icon(
                          Icons.person,
                          color: Colors.black,
                          size: radius,
                        ),
                  ),
                )
                : const Icon(Icons.person, color: Colors.black, size: radius),
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
    final isActive = selectedItem == label;
    return _HoverSidebarItem(
      icon: icon,
      label: label,
      isActive: isActive,
      onTap: () {
        setState(() => selectedItem = label);
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
                      (r) => false,
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
