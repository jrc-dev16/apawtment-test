import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';
import 'package:apawtmentweb_admin/dashboardpage.dart';
import 'package:apawtmentweb_admin/donationpage.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/main.dart';
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';
import 'package:apawtmentweb_admin/webnotifservice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApprovalPage extends StatefulWidget {
  const ApprovalPage({super.key});

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _approvals = [];
  bool _isLoading = true;
  String _selectedStatus = 'All';
  String _selectedItem = 'Approval';

  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;

  RealtimeChannel? _verificationsChannel;
  RealtimeChannel? _profilesChannel;

  @override
  void initState() {
    super.initState();
    saveLastVisitedPage('Approval');
    _loadApprovals();
    _loadProfileImageForAvatar();
    _subscribeToVerifications();
    _subscribeToProfiles();
  }

  @override
  void dispose() {
    _verificationsChannel?.unsubscribe();
    _profilesChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToVerifications() {
    _verificationsChannel = supabase
        .channel('verifications_realtime_${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'verifications',
          callback: (payload) async {
            if (!mounted) return;

            final newRecord = await _fetchSingleApproval(
              payload.newRecord['verification_id'] as int?,
            );
            if (newRecord != null && mounted) {
              setState(() => _approvals.insert(0, newRecord));
              _showRealtimeSnackbar(
                'New verification submitted',
                Icons.new_releases,
                Colors.blue,
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'verifications',
          callback: (payload) async {
            if (!mounted) return;
            final id = payload.newRecord['verification_id'] as int?;
            final updated = await _fetchSingleApproval(id);
            if (updated != null && mounted) {
              setState(() {
                final idx = _approvals.indexWhere(
                  (a) => a['verification_id'] == id,
                );
                if (idx != -1) {
                  _approvals[idx] = updated;
                } else {
                  _approvals.insert(0, updated);
                }
              });
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'verifications',
          callback: (payload) {
            if (!mounted) return;
            final id = payload.oldRecord['verification_id'] as int?;
            if (id != null) {
              setState(() {
                _approvals.removeWhere((a) => a['verification_id'] == id);
              });
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('📡 Verifications channel: $status');
          if (error != null) debugPrint('❌ Channel error: $error');
        });
  }

  void _subscribeToProfiles() {
    _profilesChannel =
        supabase
            .channel('profiles_approval_${identityHashCode(this)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'profiles',
              callback: (payload) async {
                if (!mounted) return;
                final updatedFurparentId = payload.newRecord['furparent_id'];

                final idx = _approvals.indexWhere(
                  (a) => a['furparent_id'] == updatedFurparentId,
                );
                if (idx != -1) {
                  final refreshed = await _fetchSingleApproval(
                    _approvals[idx]['verification_id'] as int?,
                  );
                  if (refreshed != null && mounted) {
                    setState(() => _approvals[idx] = refreshed);
                  }
                }
              },
            )
            .subscribe();
  }

  Future<Map<String, dynamic>?> _fetchSingleApproval(int? id) async {
    if (id == null) return null;
    try {
      final response =
          await supabase
              .from('verifications')
              .select('''
            verification_id,
            furparent_id,
            id_type,
            id_front_url,
            id_back_url,
            selfie_url,
            status,
            submitted_at,
            screening_done,
            home_type,
            pets_allowed,
            outdoor_space,
            prior_pet_exp,
            hours_alone,
            caretaker,
            has_young_children,
            other_pets,
            why_adopt,
            additional_notes,
            profiles (
              first_name,
              last_name,
              email,
              cell_no,
              avatar_url
            )
          ''')
              .eq('verification_id', id)
              .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('❌ _fetchSingleApproval error: $e');
      return null;
    }
  }

  void _showRealtimeSnackbar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                color == Colors.green
                    ? Icons.check_circle_outline
                    : color == Colors.red
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
          backgroundColor: color,
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

  String _toTitleCase(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Pending';
    final s = raw.trim();
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Future<void> _loadApprovals() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('verifications')
          .select('''
            verification_id,
            furparent_id,
            id_type,
            id_front_url,
            id_back_url,
            selfie_url,
            status,
            submitted_at,
            screening_done,
            home_type,
            pets_allowed,
            outdoor_space,
            prior_pet_exp,
            hours_alone,
            caretaker,
            has_young_children,
            other_pets,
            why_adopt,
            additional_notes,
            profiles (
              first_name,
              last_name,
              email,
              cell_no,
              avatar_url
            )
          ''')
          .order('submitted_at', ascending: false);

      if (mounted) {
        setState(() {
          _approvals = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load approvals.')),
        );
        debugPrint('Failed to load approval: $e');
      }
    }
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
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  Future<void> _updateStatus(int verificationId, String status) async {
    if (mounted) {
      setState(() {
        final idx = _approvals.indexWhere(
          (a) => a['verification_id'] == verificationId,
        );
        if (idx != -1) {
          _approvals[idx] = Map<String, dynamic>.from(_approvals[idx])
            ..['status'] = status;
        }
      });
    }

    try {
      final approval = _approvals.firstWhere(
        (a) => a['verification_id'] == verificationId,
      );
      final furparentId = approval['furparent_id'] as int;

      await supabase
          .from('verifications')
          .update({'status': status})
          .eq('verification_id', verificationId);

      final isApproved = status == 'approved';
      await supabase.from('user_notifications').insert({
        'furparent_id': furparentId,
        'title':
            isApproved
                ? '🎉 Appointment Approved!'
                : 'Appointment Not Approved',
        'body':
            isApproved
                ? 'Great news! Your adoption appointment has been approved. We look forward to seeing you!'
                : 'Unfortunately, your adoption appointment was not approved at this time. Please contact us for more details.',
        'type': 'appointment_status',
        'screen': 'AppointmentPage',
        'read': false,
      });

      await supabase.functions.invoke(
        'adoption-approval',
        body: {'furparent_id': furparentId, 'status': status},
      );

      WebNotificationService().notifyVerificationStatus(
        verificationId: verificationId,
        status: status,
      );

      await logActivity(
        action: 'Updated Approval Status',
        description:
            'Updated verification status to ${_toTitleCase(status)} for ${_fullName(approval)}',
        entityType: 'Verification',
        entityId: verificationId,
      );

      _showRealtimeSnackbar(
        'Status updated to ${_toTitleCase(status)}',
        Icons.check_circle,
        status == 'approved' ? Colors.green : Colors.red,
      );
    } catch (e) {
      if (mounted) await _loadApprovals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to update.',
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
          ),
        );
      }
      debugPrint('Failed to update $e');
    }
  }

  String _fullName(Map<String, dynamic> approval) {
    final fp = approval['profiles'] as Map<String, dynamic>?;
    if (fp == null) return 'Unknown';
    final first = fp['first_name'] ?? '';
    final last = fp['last_name'] ?? '';
    return '$first $last'.trim().isEmpty ? 'Unknown' : '$first $last'.trim();
  }

  String _email(Map<String, dynamic> approval) {
    final fp = approval['profiles'] as Map<String, dynamic>?;
    return fp?['email'] ?? 'No email';
  }

  String _phone(Map<String, dynamic> approval) {
    final fp = approval['profiles'] as Map<String, dynamic>?;
    return fp?['cell_no'] ?? 'No phone';
  }

  String? _profilePhoto(Map<String, dynamic> approval) {
    final fp = approval['profiles'] as Map<String, dynamic>?;
    return fp?['avatar_url'] as String?;
  }

  List<Map<String, dynamic>> get _filteredApprovals {
    if (_selectedStatus == 'All') return _approvals;
    return _approvals
        .where((a) => _toTitleCase(a['status']?.toString()) == _selectedStatus)
        .toList();
  }

  Color _statusColor(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _showApprovalDetails(Map<String, dynamic> approval) {
    showDialog(
      context: context,
      builder:
          (_) => _ApprovalDetailDialog(
            approval: approval,
            toTitleCase: _toTitleCase,
            statusColor: _statusColor,
            fullName: _fullName,
            email: _email,
            phone: _phone,
            profilePhoto: _profilePhoto,
            onUpdateStatus: (id, status) async {
              Navigator.pop(context);
              await _updateStatus(id, status);
            },
          ),
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

  Widget _buildProfileAvatar({double radius = 16}) {
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

  Widget _buildTopHeader(bool isMobile) {
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
              'Adoption Approvals',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 14 : 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),

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

          _buildProfileAvatar(radius: isMobile ? 14 : 16),
        ],
      ),
    );
  }

  Widget _buildFooter() {
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

  @override
  Widget build(BuildContext context) {
    final filterOptions = ['All', 'Pending', 'Approved', 'Rejected'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFF101010),
          drawer: isMobile ? Drawer(width: 200, child: _buildSidebar()) : null,
          body: Row(
            children: [
              if (!isMobile) _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopHeader(isMobile),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: isMobile
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  dropdownColor: const Color(0xFF2A2A2A),
                                  value: _selectedStatus,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  items: filterOptions.map((filter) {
                                    final count =
                                        filter == 'All'
                                            ? _approvals.length
                                            : _approvals
                                                .where(
                                                  (a) =>
                                                      _toTitleCase(
                                                        a['status']?.toString(),
                                                      ) ==
                                                      filter,
                                                )
                                                .length;
                                    return DropdownMenuItem<String>(
                                      value: filter,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (filter == 'Approved')
                                                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                              if (filter == 'Rejected')
                                                const Icon(Icons.cancel, size: 14, color: Colors.red),
                                              if (filter == 'Pending')
                                                const Icon(Icons.hourglass_top, size: 14, color: Colors.orange),
                                              if (filter == 'All')
                                                const Icon(Icons.list, size: 14, color: Colors.white70),
                                              const SizedBox(width: 8),
                                              Text(filter),
                                            ],
                                          ),
                                          if (count > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.white12,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$count',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedStatus = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    filterOptions.map((filter) {
                                      final isSelected = _selectedStatus == filter;
                                      Color activeColor = Colors.orange;
                                      if (filter == 'Approved')
                                        activeColor = Colors.green;
                                      if (filter == 'Rejected')
                                        activeColor = Colors.red;

                                      final count =
                                          filter == 'All'
                                              ? _approvals.length
                                              : _approvals
                                                  .where(
                                                    (a) =>
                                                        _toTitleCase(
                                                          a['status']?.toString(),
                                                        ) ==
                                                        filter,
                                                  )
                                                  .length;

                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: GestureDetector(
                                          onTap:
                                              () => setState(
                                                () => _selectedStatus = filter,
                                              ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isSelected
                                                      ? activeColor
                                                      : const Color(0xFF2A2A2A),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color:
                                                    isSelected
                                                        ? activeColor
                                                        : Colors.white24,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (filter == 'Approved')
                                                  const Icon(
                                                    Icons.check_circle,
                                                    size: 13,
                                                    color: Colors.white70,
                                                  ),
                                                if (filter == 'Rejected')
                                                  const Icon(
                                                    Icons.cancel,
                                                    size: 13,
                                                    color: Colors.white70,
                                                  ),
                                                if (filter == 'Pending')
                                                  const Icon(
                                                    Icons.hourglass_top,
                                                    size: 13,
                                                    color: Colors.white70,
                                                  ),
                                                if (filter == 'All')
                                                  const Icon(
                                                    Icons.list,
                                                    size: 13,
                                                    color: Colors.white70,
                                                  ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  filter,
                                                  style: TextStyle(
                                                    color:
                                                        isSelected
                                                            ? Colors.white
                                                            : Colors.white70,
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 13,
                                                    fontWeight:
                                                        isSelected
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                  ),
                                                ),

                                                if (count > 0) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          isSelected
                                                              ? Colors.white
                                                                  .withOpacity(0.3)
                                                              : activeColor
                                                                  .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      '$count',
                                                      style: TextStyle(
                                                        color:
                                                            isSelected
                                                                ? Colors.white
                                                                : activeColor,
                                                        fontSize: 10,
                                                        fontFamily: 'Montserrat',
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                    ),

                    Expanded(
                      child:
                          _isLoading
                              ? Center(
                                  child: LoadingAnimationWidget.fallingDot(
                                    color: Colors.orange,
                                    size: 50,
                                  ),
                                )
                              : _filteredApprovals.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.verified_user_outlined,
                                      color: Colors.white24,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No $_selectedStatus requests',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : RefreshIndicator(
                                onRefresh: _loadApprovals,
                                color: Colors.orange,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredApprovals.length,
                                  itemBuilder: (context, index) {
                                    final approval = _filteredApprovals[index];
                                    final rawStatus =
                                        approval['status']?.toString();
                                    final status = _toTitleCase(rawStatus);
                                    final statusColor = _statusColor(rawStatus);
                                    final profileUrl = _profilePhoto(approval);
                                    final screeningDone =
                                        approval['status'] == 'approved' ||
                                        approval['status'] == 'Approved';

                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF282828),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              status == 'Pending'
                                                  ? Colors.orange.withOpacity(
                                                    0.2,
                                                  )
                                          : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: isMobile
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 26,
                                                      backgroundColor:
                                                          Colors.grey[700],
                                                      backgroundImage:
                                                          profileUrl != null
                                                              ? NetworkImage(
                                                                  profileUrl,
                                                                )
                                                              : null,
                                                      child: profileUrl == null
                                                          ? const Icon(
                                                              Icons.person,
                                                              color: Colors
                                                                  .white54,
                                                            )
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            _fullName(approval),
                                                            style: const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontFamily:
                                                                  'Montserrat',
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            _email(approval),
                                                            style: const TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontFamily:
                                                                  'Montserrat',
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            approval[
                                                                    'id_type'] ??
                                                                'Unknown ID type',
                                                            style: const TextStyle(
                                                              color: Colors
                                                                  .white38,
                                                              fontFamily:
                                                                  'Montserrat',
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              screeningDone
                                                                  ? Icons
                                                                      .check_circle
                                                                  : Icons
                                                                      .hourglass_top,
                                                              size: 11,
                                                              color:
                                                                  screeningDone
                                                                      ? Colors
                                                                          .green
                                                                      : Colors
                                                                          .orange,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              screeningDone
                                                                  ? 'Screening done'
                                                                  : 'Screening pending',
                                                              style: TextStyle(
                                                                color:
                                                                    screeningDone
                                                                        ? Colors
                                                                            .green
                                                                        : Colors
                                                                            .orange,
                                                                fontFamily:
                                                                    'Montserrat',
                                                                fontSize: 10,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (approval[
                                                                'submitted_at'] !=
                                                            null) ...[
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            DateFormat(
                                                              'MMM d',
                                                            ).format(
                                                              DateTime.parse(
                                                                approval[
                                                                    'submitted_at'],
                                                              ),
                                                            ),
                                                            style: const TextStyle(
                                                              color: Colors
                                                                  .white38,
                                                              fontFamily:
                                                                  'Montserrat',
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: statusColor
                                                                .withOpacity(
                                                                    0.2),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          child: Text(
                                                            status,
                                                            style: TextStyle(
                                                              color:
                                                                  statusColor,
                                                              fontSize: 11,
                                                              fontFamily:
                                                                  'Montserrat',
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        ElevatedButton(
                                                          onPressed: () =>
                                                              _showApprovalDetails(
                                                                approval,
                                                              ),
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                Colors.orange,
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 16,
                                                              vertical: 8,
                                                            ),
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                            ),
                                                          ),
                                                          child: const Text(
                                                            'Review',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontFamily:
                                                                  'Montserrat',
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 26,
                                                  backgroundColor:
                                                      Colors.grey[700],
                                                  backgroundImage:
                                                      profileUrl != null
                                                          ? NetworkImage(
                                                              profileUrl)
                                                          : null,
                                                  child: profileUrl == null
                                                      ? const Icon(
                                                          Icons.person,
                                                          color: Colors.white54,
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        _fullName(approval),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        _email(approval),
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        approval['id_type'] ??
                                                            'Unknown ID type',
                                                        style: const TextStyle(
                                                          color: Colors.white38,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            screeningDone
                                                                ? Icons
                                                                    .check_circle
                                                                : Icons
                                                                    .hourglass_top,
                                                            size: 11,
                                                            color: screeningDone
                                                                ? Colors.green
                                                                : Colors.orange,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            screeningDone
                                                                ? 'Screening done'
                                                                : 'Screening pending',
                                                            style: TextStyle(
                                                              color:
                                                                  screeningDone
                                                                      ? Colors
                                                                          .green
                                                                      : Colors
                                                                          .orange,
                                                              fontFamily:
                                                                  'Montserrat',
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: statusColor
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Text(
                                                        status,
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontSize: 11,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    if (approval[
                                                            'submitted_at'] !=
                                                        null)
                                                      Text(
                                                        DateFormat('MMM d')
                                                            .format(
                                                          DateTime.parse(
                                                            approval[
                                                                'submitted_at'],
                                                          ),
                                                        ),
                                                        style: const TextStyle(
                                                          color: Colors.white38,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    const SizedBox(height: 4),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          _showApprovalDetails(
                                                        approval,
                                                      ),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.orange,
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'Review',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                    );
                                  },
                                ),
                              ),
                    ),

                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovalDetailDialog extends StatelessWidget {
  final Map<String, dynamic> approval;
  final String Function(String?) toTitleCase;
  final Color Function(String?) statusColor;
  final String Function(Map<String, dynamic>) fullName;
  final String Function(Map<String, dynamic>) email;
  final String Function(Map<String, dynamic>) phone;
  final String? Function(Map<String, dynamic>) profilePhoto;
  final Future<void> Function(int id, String status) onUpdateStatus;

  const _ApprovalDetailDialog({
    required this.approval,
    required this.toTitleCase,
    required this.statusColor,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.profilePhoto,
    required this.onUpdateStatus,
  });

  Widget _buildSectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      color: Colors.orangeAccent,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      fontFamily: 'Montserrat',
    ),
  );

  Widget _buildInfoRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 3,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
      Expanded(
        flex: 5,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
    ],
  );

  Widget _statusBadge(String status) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        toTitleCase(status),
        style: TextStyle(
          color: color,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildImageCard(
    BuildContext context,
    String? url, {
    required String label,
  }) {
    if (url != null && url.isNotEmpty) {
      return GestureDetector(
        onTap:
            () => showDialog(
              context: context,
              builder:
                  (_) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.white54,
                                ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder:
                (_, child, progress) =>
                    progress == null
                        ? child
                        : Container(
                          height: 200,
                          color: Colors.grey[800],
                          child: Center(
                            child: LoadingAnimationWidget.fallingDot(
                              color: Colors.orange,
                              size: 50,
                            ),
                          ),
                        ),
            errorBuilder:
                (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
          ),
        ),
      );
    }
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'No $label uploaded',
          style: const TextStyle(
            color: Colors.white54,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
    );
  }

  Widget _buildScreeningGrid(Map<String, dynamic> a) {
    final pairs = [
      ['Home type', a['home_type']],
      ['Pets allowed', a['pets_allowed']],
      ['Outdoor space', a['outdoor_space']],
      ['Prior pet exp.', a['prior_pet_exp']],
      ['Hours alone/day', a['hours_alone']],
      ['Caretaker', a['caretaker']],
      ['Young children', a['has_young_children']],
      ['Other pets', a['other_pets']],
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          pairs.map((p) {
            final label = p[0] as String;
            final value = p[1]?.toString();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              constraints: const BoxConstraints(minWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value != null && value.isNotEmpty ? value : '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = toTitleCase(approval['status']?.toString());
    final idType = approval['id_type'] ?? 'Unknown ID';
    final screeningDone =
        approval['status'] == 'approved' || approval['status'] == 'Approved';
    final profileUrl = profilePhoto(approval);

    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.width < 600
              ? MediaQuery.of(context).size.height * 0.85
              : 800,
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Verification Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _statusBadge(status),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.credit_card,
                            color: Colors.white54,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            idType,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.grey[700],
                        backgroundImage:
                            approval['selfie_url'] != null
                                ? NetworkImage(approval['selfie_url'])
                                : (profileUrl != null
                                    ? NetworkImage(profileUrl)
                                    : null),
                        child:
                            (approval['selfie_url'] == null &&
                                    profileUrl == null)
                                ? const Icon(
                                  Icons.person,
                                  color: Colors.white54,
                                  size: 48,
                                )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        'Selfie photo',
                        style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Fur Parent Information'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Full Name:', fullName(approval)),
                    const SizedBox(height: 4),
                    _buildInfoRow('Email:', email(approval)),
                    const SizedBox(height: 4),
                    _buildInfoRow('Phone:', phone(approval)),
                    const SizedBox(height: 4),
                    _buildInfoRow(
                      'Submitted:',
                      approval['submitted_at'] != null
                          ? DateFormat(
                            'MMM d, yyyy • h:mm a',
                          ).format(DateTime.parse(approval['submitted_at']))
                          : 'N/A',
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Adoption Screening'),
                    const SizedBox(height: 6),
                    if (!screeningDone)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.4),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.hourglass_top,
                              color: Colors.orange,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Screening form not yet submitted by the fur parent.',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      const SizedBox(height: 8),
                      _buildScreeningGrid(approval),
                      const SizedBox(height: 12),
                      const Text(
                        'Why do they want to adopt?',
                        style: TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          approval['why_adopt']?.toString().isNotEmpty == true
                              ? approval['why_adopt']
                              : 'No answer provided.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (approval['additional_notes']?.toString().isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Additional notes',
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            approval['additional_notes'],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    _buildSectionHeader('ID Front'),
                    const SizedBox(height: 12),
                    _buildImageCard(
                      context,
                      approval['id_front_url'],
                      label: 'Front of ID',
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('ID Back'),
                    const SizedBox(height: 12),
                    _buildImageCard(
                      context,
                      approval['id_back_url'],
                      label: 'Back of ID',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap any image to view full size',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (status == 'Pending')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      offset: Offset(0, -2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            () => onUpdateStatus(
                              approval['verification_id'],
                              'rejected',
                            ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE57373),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            () => onUpdateStatus(
                              approval['verification_id'],
                              'approved',
                            ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Approve',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
                if (mounted)
                  setState(() => _notifications.insert(0, payload.newRecord));
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
        setState(
          () => _notifications = List<Map<String, dynamic>>.from(response),
        );
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
