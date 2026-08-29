import 'dart:async';

import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:apawtmentweb_admin/skeleton_loading.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';

import 'package:apawtmentweb_admin/dashboardpage.dart';
import 'package:apawtmentweb_admin/donationpage.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/main.dart';
import 'package:apawtmentweb_admin/medicationspage.dart';
import 'package:apawtmentweb_admin/notificationpage.dart';
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountManagementPage extends StatefulWidget {
  final Map<String, dynamic>? subadmin;

  const AccountManagementPage({super.key, required this.subadmin});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  final supabase = Supabase.instance.client;
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  Map<String, dynamic>? _selectedAccount;
  final List<Map<String, dynamic>> _activityLog = [];
  bool _isLoading = true;
  String _selectedItem = "Account Management";
  RealtimeChannel? _statusSubscription;
  @override
  void initState() {
    super.initState();
    _loadProfileImageForAvatar();
    _fetchSubadminAccountAndLogs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImageForAvatar();
    });
    _subscribeToSubadminStatus();
  }

  Future<void> _loadProfileImageForAvatar() async {
    if (_isLoadingAvatar) return;
    setState(() => _isLoadingAvatar = true);

    try {
      const adminId = 1;
      final response =
          await supabase
              .from('admin')
              .select('admin_profile')
              .eq('admin_id', adminId)
              .maybeSingle();

      if (response == null) {
        if (mounted) setState(() => _isLoadingAvatar = false);
        return;
      }

      final profileData = response['admin_profile']?.toString();
      String? publicUrl;

      if (profileData != null && profileData.isNotEmpty) {
        if (profileData.startsWith('http://') ||
            profileData.startsWith('https://')) {
          publicUrl = profileData;
        } else {
          publicUrl = supabase.storage
              .from('admin_profile')
              .getPublicUrl(profileData);
        }
        publicUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      if (mounted) {
        setState(() {
          _cachedProfileImage = publicUrl;
          _isLoadingAvatar = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading profile image: $e');
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  Future<void> _fetchSubadminAccountAndLogs() async {
    if (widget.subadmin == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isVet =
          widget.subadmin?['role'] == 'Veterinarian' ||
          widget.subadmin?.containsKey('vet_id') == true;
      final idKey = isVet ? 'vet_id' : 'subadmin_id';
      final subadminId =
          widget.subadmin![idKey] ??
          widget.subadmin!['subadmin_id'] ??
          widget.subadmin!['user_id'];

      if (subadminId == null) {
        if (widget.subadmin!.containsKey('username') ||
            widget.subadmin!.containsKey('first_name')) {
          setState(() {
            _selectedAccount = Map<String, dynamic>.from(widget.subadmin!);
            _isLoading = false;
          });
          return;
        }
        setState(() => _isLoading = false);
        return;
      }

      final tableName = isVet ? 'veterinarians' : 'subadmin_profiles';

      final profileResponse =
          await supabase
              .from(tableName)
              .select()
              .eq(idKey, subadminId.toString())
              .maybeSingle();

      if (profileResponse == null) {
        setState(() {
          _selectedAccount = Map<String, dynamic>.from(widget.subadmin!);
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _selectedAccount = Map<String, dynamic>.from(profileResponse);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching subadmin: $e');
      if (widget.subadmin != null) {
        setState(() {
          _selectedAccount = Map<String, dynamic>.from(widget.subadmin!);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _statusSubscription?.unsubscribe();
    super.dispose();
  }

  String formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toUtc().add(const Duration(hours: 8));
      return DateFormat('MMMM dd, yyyy hh:mm:ss a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  void _subscribeToSubadminStatus() {
    final isVet =
        widget.subadmin?['role'] == 'Veterinarian' ||
        widget.subadmin?.containsKey('vet_id') == true;
    final idKey = isVet ? 'vet_id' : 'subadmin_id';
    final subadminId =
        widget.subadmin?[idKey] ??
        widget.subadmin?['subadmin_id'] ??
        widget.subadmin?['user_id'];
    if (subadminId == null) return;

    _statusSubscription?.unsubscribe();

    final tableName = isVet ? 'veterinarians' : 'subadmin_profiles';

    _statusSubscription = supabase
        .channel(
          'subadmin_status_${subadminId}_${DateTime.now().millisecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: tableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: idKey,
            value: subadminId.toString(),
          ),
          callback: (payload) {
            if (!mounted) return;
            final updated = payload.newRecord;
            if (updated.isEmpty) return;

            setState(() {
              _selectedAccount?['status'] = updated['status'];
              _selectedAccount?['last_seen'] = updated['last_seen'];
              _selectedAccount?['account_status'] = updated['account_status'];
            });

            debugPrint(
              '🔄 Realtime update — '
              'status: ${updated['status']} | '
              'account_status: ${updated['account_status']} | '
              'last_seen: ${updated['last_seen']}',
            );
          },
        )
        .subscribe((status, [error]) {
          debugPrint('📡 Realtime channel status: $status | error: $error');
        });
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

  Widget _buildAccountInfo() {
    final subadmin = _selectedAccount!;
    final f = subadmin['first_name'] ?? '';
    final m = subadmin['middle_name'] ?? '';
    final l = subadmin['last_name'] ?? '';
    final fullName = '$f ${m.isNotEmpty ? '$m ' : ''}$l'.trim();

    final String accStatus = subadmin['account_status'] ?? 'Active';

    final bool isActive = accStatus == 'Active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white,
            backgroundImage:
                subadmin['avatar_url'] != null
                    ? NetworkImage(subadmin['avatar_url'])
                    : const AssetImage('assets/images/profile.png')
                        as ImageProvider,
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoRow('Full name', fullName),
        _buildInfoRow('Username', subadmin['username'] ?? ''),
        _buildInfoRow('Status', subadmin['status'] ?? 'Unknown'),
        _buildInfoRow('Account Status', accStatus),
        if (subadmin['last_seen'] != null)
          _buildInfoRow('Last Seen', formatDate(subadmin['last_seen'])),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Disabled',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: isActive ? Colors.white38 : Colors.red,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            Switch(
              value: isActive,
              activeColor: Colors.green,
              inactiveThumbColor: Colors.red,
              inactiveTrackColor: Colors.red.withOpacity(0.3),
              onChanged: (newValue) async {
                final newStatus = newValue ? 'Active' : 'Disabled';

                try {
                  final isVet =
                      subadmin['role'] == 'Veterinarian' ||
                      subadmin.containsKey('vet_id') == true;
                  final idKey = isVet ? 'vet_id' : 'subadmin_id';
                  final subadminId =
                      subadmin[idKey] ??
                      subadmin['subadmin_id'] ??
                      subadmin['user_id'];
                  final tableName =
                      isVet ? 'veterinarians' : 'subadmin_profiles';

                  final updates = <String, dynamic>{};
                  if (isVet) {
                    if (newValue) {
                      updates['account_status'] = 'Active';
                      updates['status'] = 'Online';
                    } else {
                      updates['account_status'] = 'Archived';
                      updates['status'] = 'Offline';
                    }
                  } else {
                    if (newValue) {
                      updates['account_status'] = 'Active';
                      updates['is_archived'] = false;
                      updates['archived_at'] = null;
                      updates['status'] = 'Online';
                    } else {
                      updates['account_status'] = 'Disabled';
                      updates['is_archived'] = true;
                      updates['archived_at'] = DateTime.now().toIso8601String();
                      updates['status'] = 'Offline';
                    }
                  }

                  await supabase
                      .from(tableName)
                      .update(updates)
                      .eq(idKey, subadminId.toString());

                  await logActivity(
                    action: updates['account_status'] == 'Disabled'
                        ? 'Disabled Account'
                        : updates['account_status'] == 'Archived'
                            ? 'Archived Account'
                            : 'Activated Account',
                    description:
                        'Updated account status to ${updates['account_status']} for ${subadmin['username'] ?? subadmin['first_name'] ?? 'account'}',
                    entityType: isVet ? 'Vet Account' : 'Staff Account',
                    entityId: subadminId is int
                        ? subadminId
                        : int.tryParse(subadminId.toString()),
                  );

                  if (mounted) {
                    setState(() {
                      _selectedAccount!['account_status'] =
                          updates['account_status'];
                      _selectedAccount!['status'] = updates['status'];
                      if (!isVet) {
                        _selectedAccount!['is_archived'] =
                            updates['is_archived'];
                      }
                    });
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Account status updated: ${updates['account_status']}',
                          style: const TextStyle(fontFamily: 'Montserrat'),
                        ),
                        backgroundColor: newValue ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Error updating status.',
                          style: TextStyle(fontFamily: 'Montserrat'),
                        ),

                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    debugPrint('Error updating status: $e');
                  }
                }
              },
            ),

            Text(
              'Active',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: isActive ? Colors.green : Colors.white38,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFF101510),
      drawer: isMobile ? Drawer(width: 200, child: _buildSidebar()) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildTopHeader(isMobile),
                  Expanded(
                    child:
                        _isLoading
                            ? const SkeletonAccountDetail()
                            : _selectedAccount == null
                            ? const Center(
                              child: Text(
                                'No subadmin account found.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                            : Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 32,
                                    horizontal: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2C2C),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: _buildAccountInfo(),
                                ),
                              ),
                            ),
                  ),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder:
                  (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
            ),
          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'Account Management',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 13 : 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
              maxLines: 2,
            ),
          ),

          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ShelterProjectsPage()),
                ),
            child: Image.asset(
              'assets/icons/shelterprojects.png',
              width: 28,
              height: 28,
            ),
          ),
          SizedBox(width: 8),
          _NotificationBell(
            iconSize: isMobile ? 22 : 24,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
          ),
          SizedBox(width: 8),
          buildProfileAvatar(context, radius: 14),
        ],
      ),
    );
  }

  Widget buildProfileAvatar(BuildContext context, {double radius = 16}) {
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
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value:
                              progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.orange,
                          ),
                        ),
                      );
                    },
                  ),
                )
                : Icon(Icons.person, color: Colors.black, size: radius),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      height: 40,
      color: const Color(0xFF181818),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                        final id = notif['notification_id'];
                        final int? notifId =
                            id is int ? id : int.tryParse(id?.toString() ?? '');

                        final title =
                            notif['title'] as String? ?? 'Notification';
                        final message = notif['message'] as String? ?? '';
                        final type = notif['type'] as String? ?? 'system';
                        final timeStr = widget.timeAgo(
                          notif['created_at'] as String?,
                        );
                        final color = _colorFor(type);

                        return Dismissible(
                          key: ValueKey(
                            notifId != null
                                ? 'notif_$notifId'
                                : 'notif_idx_$index',
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            setState(() => _items.removeAt(index));
                            if (notifId != null) widget.onDelete(notifId);
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
                                notifId != null
                                    ? GestureDetector(
                                      onTap: () {
                                        setState(() => _items.removeAt(index));
                                        widget.onDelete(notifId);
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
