import 'dart:typed_data';

import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:apawtmentweb_admin/dashboardpage.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/medicationspage.dart';
import 'package:apawtmentweb_admin/notificationpage.dart';
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:apawtmentweb_admin/donationpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';
import 'package:apawtmentweb_admin/main.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  int _parseAgeToMonths(String ageStr) {
    int months = 0;
    final yearMatch = RegExp(r'(\d+)\s*year').firstMatch(ageStr.toLowerCase());
    final monthMatch = RegExp(
      r'(\d+)\s*month',
    ).firstMatch(ageStr.toLowerCase());
    if (yearMatch != null) months += int.parse(yearMatch.group(1)!) * 12;
    if (monthMatch != null) months += int.parse(monthMatch.group(1)!);
    return months;
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

enum _PetCategory { allRecords, availableForAdoption }

class PetAdoptionsPage extends StatefulWidget {
  final int? petId;
  final int? adoptionId;
  const PetAdoptionsPage({super.key, this.petId, this.adoptionId});

  @override
  State<PetAdoptionsPage> createState() => _PetAdoptionsPageState();
}

class _PetAdoptionsPageState extends State<PetAdoptionsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String _formatAgeText(String numText, String unitVal) {
    if (numText.trim().isEmpty) return '';
    final val = double.tryParse(numText.trim()) ?? 0.0;
    String base = 'month';
    if (unitVal.contains('day')) {
      base = 'day';
    } else if (unitVal.contains('week')) {
      base = 'week';
    } else if (unitVal.contains('month')) {
      base = 'month';
    } else if (unitVal.contains('year')) {
      base = 'year';
    }
    if (val == 1.0) {
      return '${numText.trim()} $base old';
    } else {
      return '${numText.trim()} ${base}s old';
    }
  }

  Map<String, String> _parseAge(String? ageStr) {
    if (ageStr == null || ageStr.trim().isEmpty) {
      return {'number': '', 'unit': 'month(s) old'};
    }
    final parts = ageStr.trim().split(' ');
    if (parts.length >= 2) {
      final number = parts[0];
      final unit = parts.sublist(1).join(' ').toLowerCase();
      String normalizedUnit = 'month(s) old';
      if (unit.contains('day')) {
        normalizedUnit = 'day(s) old';
      } else if (unit.contains('week')) {
        normalizedUnit = 'week(s) old';
      } else if (unit.contains('month')) {
        normalizedUnit = 'month(s) old';
      } else if (unit.contains('year')) {
        normalizedUnit = 'year(s) old';
      }
      return {'number': number, 'unit': normalizedUnit};
    } else if (parts.length == 1) {
      final number = parts[0];
      if (RegExp(r'^\d+$').hasMatch(number)) {
        return {'number': number, 'unit': 'month(s) old'};
      }
    }
    return {'number': ageStr, 'unit': 'month(s) old'};
  }

  late TabController _tabController;
  RealtimeChannel? _petsChannel;
  String _selectedItem = 'Pet Management';
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  List<Map<String, dynamic>> _declinedAdoptions = [];
  bool _loadingDeclined = true;
  _PetCategory _selectedCategory = _PetCategory.allRecords;

  DateTime _lastPetsFetch = DateTime(0);
  static const _petsFetchDebounce = Duration(milliseconds: 600);
  List<Map<String, dynamic>> _allPets = [];
  List<Map<String, dynamic>> _availablePets = [];
  bool _loadingPets = true;

  List<Map<String, dynamic>> _pendingAdoptions = [];
  List<Map<String, dynamic>> _cancelledAdoptions = [];
  List<Map<String, dynamic>> _approvedAdoptions = [];

  bool _loadingPending = true;
  bool _loadingCancelled = true;
  bool _loadingApproved = true;

  RealtimeChannel? _adoptionsChannel;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _loadProfileImageForAvatar();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadProfileImageForAvatar(),
    );
    _loadAll();
    _loadAllPets();
    _subscribeToAdoptions();
    _subscribeToPets();
  }

  @override
  void dispose() {
    _adoptionsChannel?.unsubscribe();
    _petsChannel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  void _subscribeToAdoptions() {
    _adoptionsChannel =
        supabase
            .channel('adoptions-realtime')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'adoptions',
              callback: (payload) {
                _loadAll();

                _debouncedLoadPets();
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'adoptions',
              callback: (payload) => _loadAll(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'adoptions',
              callback: (payload) => _loadAll(),
            )
            .subscribe();
  }

  void _subscribeToPets() {
    _petsChannel =
        supabase
            .channel('pets_rt_${identityHashCode(this)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'pets',
              callback: (_) => _debouncedLoadPets(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'pets',
              callback: (_) => _debouncedLoadPets(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'pets',
              callback: (_) => _debouncedLoadPets(),
            )
            .subscribe();
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

  void _debouncedLoadPets() {
    final now = DateTime.now();
    if (now.difference(_lastPetsFetch) < _petsFetchDebounce) return;
    _lastPetsFetch = now;
    if (mounted) _loadAllPets();
  }

  Future<void> _loadDeclined() async {
    if (mounted) setState(() => _loadingDeclined = true);
    try {
      final adoptions = await supabase
          .from('adoptions')
          .select('*')
          .eq('status', 'Declined')
          .order('created_at', ascending: false);
      final List<Map<String, dynamic>> result = [];
      for (final adoption in adoptions) {
        final pet =
            await supabase
                .from('pets')
                .select('*')
                .eq('pet_id', adoption['pet_id'])
                .maybeSingle();
        result.add({...adoption, 'pets': pet});
      }
      if (mounted) {
        setState(() {
          _declinedAdoptions = result;
          _loadingDeclined = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDeclined = false);
    }
  }

  void _showNewAdoptionBanner(Map<String, dynamic> record) {
    if (!mounted) return;
    final petName = record['pet_name'] as String? ?? 'a pet';
    final adopteeName = record['name'] as String? ?? 'Someone';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🐾 New Adoption Request!',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$adopteeName wants to adopt $petName',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.orange,
          onPressed: () => _tabController.animateTo(0),
        ),
      ),
    );
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadPending(),
      _loadCancelled(),
      _loadApproved(),
      _loadDeclined(),
    ]);
  }

  void _refreshAll() {
    _loadAll();
    _loadAllPets();
  }

  Future<void> _loadAllPets() async {
    if (mounted) setState(() => _loadingPets = true);
    try {
      final all = await supabase
          .from('pets')
          .select('*')
          .order('created_at', ascending: false);

      final allList = List<Map<String, dynamic>>.from(all);
      final availableList =
          allList
              .where(
                (p) => (p['status'] as String? ?? '') == 'Ready For Adoption',
              )
              .toList();

      if (mounted) {
        setState(() {
          _allPets = allList;
          _availablePets = availableList;
          _loadingPets = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPets = false);
    }
  }

  Future<void> _loadPending() async {
    if (mounted) setState(() => _loadingPending = true);
    try {
      final adoptions = await supabase
          .from('adoptions')
          .select('*')
          .eq('status', 'Pending')
          .order('created_at', ascending: false);
      final List<Map<String, dynamic>> result = [];
      for (final adoption in adoptions) {
        final pet =
            await supabase
                .from('pets')
                .select('*')
                .eq('pet_id', adoption['pet_id'])
                .maybeSingle();
        final profile =
            await supabase
                .from('profiles')
                .select('*')
                .eq('furparent_id', adoption['furparent_id'])
                .maybeSingle();
        result.add({...adoption, 'pets': pet, 'profiles': profile});
      }
      if (mounted)
        setState(() {
          _pendingAdoptions = result;
          _loadingPending = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _loadCancelled() async {
    if (mounted) setState(() => _loadingCancelled = true);
    try {
      final adoptions = await supabase
          .from('adoptions')
          .select(
            '*, cancel_category, reason, pet_name, pet_image, breed, status',
          )
          .inFilter('status', ['Cancelled', 'Pending to Cancel'])
          .order('created_at', ascending: false);
      final List<Map<String, dynamic>> result = [];
      for (final adoption in adoptions) {
        final pet =
            await supabase
                .from('pets')
                .select('*')
                .eq('pet_id', adoption['pet_id'])
                .maybeSingle();
        result.add({...adoption, 'pets': pet});
      }
      if (mounted)
        setState(() {
          _cancelledAdoptions = result;
          _loadingCancelled = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loadingCancelled = false);
    }
  }

  Future<void> _loadApproved() async {
    if (mounted) setState(() => _loadingApproved = true);
    try {
      final adoptions = await supabase
          .from('adoptions')
          .select('*')
          .eq('status', 'Approved')
          .order('created_at', ascending: false);
      final List<Map<String, dynamic>> result = [];
      for (final adoption in adoptions) {
        final profile =
            await supabase
                .from('profiles')
                .select('*')
                .eq('furparent_id', adoption['furparent_id'])
                .maybeSingle();
        result.add({...adoption, 'profiles': profile});
      }
      if (mounted)
        setState(() {
          _approvedAdoptions = result;
          _loadingApproved = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loadingApproved = false);
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
      if (mounted)
        setState(() {
          _cachedProfileImage = publicUrl;
          _isLoadingAvatar = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PetPage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101510),
        drawer: isDesktop ? null : Drawer(width: 200, child: _buildSidebar()),
        body: Row(
          children: [
            if (isDesktop) _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildTopHeader(isMobile: !isDesktop),

                  _buildCategorySwitcher(isDesktop),

                  Expanded(
                    child:
                        _selectedCategory == _PetCategory.allRecords
                            ? _buildPetRecordsView(isDesktop)
                            : _buildAdoptionNavigationView(isDesktop),
                  ),

                  _buildFooter(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySwitcher(bool isDesktop) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 12,
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: _categoryChip(
              label: 'All Pet Records',
              icon: Icons.pets,
              count: _allPets.length,
              selected: _selectedCategory == _PetCategory.allRecords,
              onTap:
                  () => setState(() {
                    _selectedCategory = _PetCategory.allRecords;
                  }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _categoryChip(
              label: 'Adopted Pets',
              icon: Icons.favorite,
              count: _availablePets.length,
              selected: _selectedCategory == _PetCategory.availableForAdoption,
              onTap:
                  () => setState(() {
                    _selectedCategory = _PetCategory.availableForAdoption;
                  }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required IconData icon,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? Colors.orange : Colors.white24,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    selected ? Colors.white.withOpacity(0.25) : Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white38,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetRecordsView(bool isDesktop) {
    if (_loadingPets) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    return Column(
      children: [
        Container(
          color: const Color(0xFF161616),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 12,
            vertical: 10,
          ),
          child: Row(
            children: [
              Text(
                '${_allPets.length} pet(s)',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddPetFromAdoptionsDialog(context),
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: const Text(
                  'Add Pet',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child:
              _allPets.isEmpty
                  ? _emptyState('No pet records found', Icons.inbox_outlined)
                  : ListView.builder(
                    padding: EdgeInsets.all(isDesktop ? 20 : 12),
                    itemCount: _allPets.length,
                    itemBuilder:
                        (context, i) =>
                            _buildPetRecordCard(_allPets[i], isDesktop),
                  ),
        ),
      ],
    );
  }

  Future<void> _showAddPetFromAdoptionsDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final colorController = TextEditingController(text: 'BLACK');
    final breedController = TextEditingController(text: 'Puspin');
    String selectedColor = 'BLACK';
    String selectedBreed = 'Puspin';
    final ageController = TextEditingController();
    final mainAgeNumberCtrl = TextEditingController();
    String mainAgeUnit = 'month(s) old';
    final descriptionController = TextEditingController();
    final originController = TextEditingController();
    final rescueAgeController = TextEditingController();
    final mainRescueAgeNumberCtrl = TextEditingController();
    String mainRescueAgeUnit = 'month(s) old';

    Uint8List? imageBytes;
    DateTime? selectedDob;

    String selectedType = 'Cat';
    String selectedEnergy = 'Low';
    String selectedGender = 'Male';
    String selectedOrigin = 'Shelter Born';
    String selectedStatus = 'In Shelter';
    String selectedHasDisability = 'No';
    String selectedHealthStatus = 'Healthy';

    bool isRescued = false;
    bool isOffspring = true;
    bool saveAttempted = false;
    List<Map<String, dynamic>> shelters = [];
    int? selectedShelterId;
    List<Map<String, dynamic>> offspringList = [];

    final originOptions = [
      'Shelter Born',
      'Rescued',
      'Surrendered by Owner',
      'Transfer from Another Shelter',
      'Found Stray',
      'Other',
    ];

    try {
      final data = await supabase
          .from('shelters')
          .select('shelter_id, name, type, capacity')
          .order('shelter_id', ascending: true);

      final rawShelters = List<Map<String, dynamic>>.from(data);

      final enriched = await Future.wait(
        rawShelters.map((s) async {
          final sid = s['shelter_id'];
          try {
            final countResult = await supabase
                .from('pets')
                .select('pet_id')
                .eq('shelter_id', sid)
                .eq('status', 'In Shelter');
            final currentCount = (countResult as List).length;
            return {...s, 'current_count': currentCount};
          } catch (_) {
            return {...s, 'current_count': 0};
          }
        }),
      );

      shelters = enriched;

      final firstAvailable = shelters.firstWhere((s) {
        final cap = (s['capacity'] as num?)?.toInt() ?? 0;
        final cur = (s['current_count'] as num?)?.toInt() ?? 0;
        return cap == 0 || cur < cap;
      }, orElse: () => shelters.isNotEmpty ? shelters.first : {});
      if (firstAvailable.isNotEmpty) {
        selectedShelterId = firstAvailable['shelter_id'] as int?;
      }
    } catch (_) {}

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final bool imageError = saveAttempted && imageBytes == null;

            Widget buildSection(String title) {
              return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.orange.withOpacity(0.3)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Divider(color: Colors.orange.withOpacity(0.3)),
                    ),
                  ],
                ),
              );
            }

            Widget buildField(
              String label,
              TextEditingController ctrl, {
              int maxLines = 1,
              TextInputType keyboardType = TextInputType.text,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ctrl,
                      maxLines: maxLines,
                      keyboardType: keyboardType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF252526),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.orange,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget buildDropdown(
              String label,
              String value,
              List<String> options,
              ValueChanged<String?> onChanged,
            ) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252526),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: value,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF252526),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                          ),
                          items:
                              options
                                  .map(
                                    (o) => DropdownMenuItem(
                                      value: o,
                                      child: Text(
                                        o,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget buildAgeFieldRow(
              String label,
              TextEditingController numCtrl,
              String selectedUnit,
              ValueChanged<String?> onUnitChanged, {
              required VoidCallback onChangedValue,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: numCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                            ),
                            onChanged: (_) => onChangedValue(),
                            decoration: InputDecoration(
                              hintText: 'e.g. 3',
                              hintStyle: const TextStyle(
                                color: Colors.white24,
                                fontFamily: 'Montserrat',
                              ),
                              filled: true,
                              fillColor: const Color(0xFF252526),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Colors.orange,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.only(left: 10, right: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252526),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedUnit,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF252526),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
                                  fontSize: 13,
                                ),
                                items: const ['day(s) old', 'week(s) old', 'month(s) old', 'year(s) old']
                                    .map(
                                      (unit) => DropdownMenuItem(
                                        value: unit,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            unit,
                                            style: const TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 13,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  onUnitChanged(val);
                                  onChangedValue();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              child: Container(
                width: 680,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.88,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pets, color: Colors.orange),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Add New Pet',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white54,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: GestureDetector(
                                  onTap: () async {
                                    final pickedFile = await ImagePicker()
                                        .pickImage(source: ImageSource.gallery);
                                    if (pickedFile != null) {
                                      final bytes =
                                          await pickedFile.readAsBytes();
                                      final decoded = img.decodeImage(bytes);
                                      if (decoded == null) return;
                                      final resized = img.copyResize(
                                        decoded,
                                        width: 800,
                                      );
                                      final jpgBytes = img.encodeJpg(
                                        resized,
                                        quality: 85,
                                      );
                                      setDialogState(() {
                                        imageBytes = Uint8List.fromList(
                                          jpgBytes,
                                        );
                                      });
                                    }
                                  },
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 50,
                                        backgroundColor:
                                            imageError
                                                ? Colors.red.withOpacity(0.1)
                                                : Colors.grey[850],
                                        backgroundImage:
                                            imageBytes != null
                                                ? MemoryImage(imageBytes!)
                                                : null,
                                        child:
                                            imageBytes == null
                                                ? Icon(
                                                  Icons.add_a_photo,
                                                  color:
                                                      imageError
                                                          ? Colors.red
                                                          : Colors.white70,
                                                )
                                                : null,
                                      ),
                                      if (imageError)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: Text(
                                            'Photo is required',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontFamily: 'Montserrat',
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              buildSection('Basic Info'),
                              buildField('Name *', nameController),
                              buildDropdown(
                                'Color',
                                selectedColor,
                                selectedType.toLowerCase() == 'cat'
                                    ? ['BLACK', 'WHITE', 'BROWN', 'GREY', 'TRI-COLOR', 'ORANGE', 'Others']
                                    : ['BLACK', 'WHITE', 'BROWN', 'GREY', 'TRI-COLOR', 'Others'],
                                (v) => setDialogState(() {
                                  selectedColor = v!;
                                  if (selectedColor != 'Others') {
                                    colorController.text = selectedColor;
                                  } else {
                                    colorController.text = '';
                                  }
                                }),
                              ),
                              if (selectedColor == 'Others')
                                buildField('Specify Color *', colorController),
                              buildDropdown(
                                'Breed',
                                selectedBreed,
                                ['Puspin', 'Aspin', 'Others'],
                                (v) => setDialogState(() {
                                  selectedBreed = v!;
                                  if (selectedBreed != 'Others') {
                                    breedController.text = selectedBreed;
                                  } else {
                                    breedController.text = '';
                                  }
                                }),
                              ),
                              if (selectedBreed == 'Others')
                                buildField('Specify Breed *', breedController),
                              buildAgeFieldRow(
                                'Age *',
                                mainAgeNumberCtrl,
                                mainAgeUnit,
                                (v) => setDialogState(() => mainAgeUnit = v!),
                                onChangedValue: () {
                                  ageController.text = _formatAgeText(mainAgeNumberCtrl.text, mainAgeUnit);
                                },
                              ),
                              buildField(
                                'Description',
                                descriptionController,
                                maxLines: 4,
                              ),

                              buildSection('Details'),
                              buildDropdown(
                                'Type',
                                selectedType,
                                ['Cat', 'Dog'],
                                (v) => setDialogState(() {
                                  selectedType = v!;
                                  if (selectedType == 'Dog' && selectedColor == 'ORANGE') {
                                    selectedColor = 'BLACK';
                                    colorController.text = 'BLACK';
                                  }
                                }),
                              ),
                              buildDropdown(
                                'Energy Level',
                                selectedEnergy,
                                ['Low', 'Medium', 'High'],
                                (v) =>
                                    setDialogState(() => selectedEnergy = v!),
                              ),
                              buildDropdown(
                                'Sex',
                                selectedGender,
                                ['Male', 'Female'],
                                (v) =>
                                    setDialogState(() => selectedGender = v!),
                              ),
                              buildDropdown(
                                'Origin',
                                selectedOrigin,
                                originOptions,
                                (value) {
                                  setDialogState(() {
                                    selectedOrigin = value!;
                                    isRescued =
                                        value == 'Rescued' ||
                                        value == 'Found Stray';
                                    isOffspring = value == 'Shelter Born';
                                    selectedStatus =
                                        isRescued
                                            ? 'Under Medication'
                                            : 'In Shelter';
                                    originController.clear();
                                    rescueAgeController.clear();
                                  });
                                },
                              ),
                              buildDropdown(
                                'Has Disability?',
                                selectedHasDisability,
                                ['Yes', 'No'],
                                (v) => setDialogState(
                                  () => selectedHasDisability = v!,
                                ),
                              ),

                              if (selectedGender == 'Female')
                                buildDropdown(
                                  'Health Status',
                                  selectedHealthStatus,
                                  [
                                    'Healthy',
                                    'Pregnant',
                                    'Recovering',
                                    'Under Treatment',
                                    'Critical',
                                    'Quarantined',
                                  ],
                                  (v) => setDialogState(
                                    () => selectedHealthStatus = v!,
                                  ),
                                ),
                              if (selectedGender == 'Female' &&
                                  selectedHealthStatus == 'Pregnant') ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.pink.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.pink.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ── Header row ──────────────────────────────────────
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.child_care,
                                            color: Colors.pinkAccent,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Litter / Offspring',
                                              style: TextStyle(
                                                color: Colors.pinkAccent,
                                                fontFamily: 'Montserrat',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              setDialogState(() {
                                                offspringList.add({
                                                  'nameCtrl':
                                                      TextEditingController(),
                                                  'colorCtrl':
                                                      TextEditingController(),
                                                  'breedCtrl':
                                                      TextEditingController(),
                                                  'ageCtrl':
                                                      TextEditingController(),
                                                  'ageNumCtrl':
                                                      TextEditingController(),
                                                  'ageUnit': 'month(s) old',
                                                  'descCtrl':
                                                      TextEditingController(),
                                                  'originCtrl':
                                                      TextEditingController(),
                                                  'rescueAgeCtrl':
                                                      TextEditingController(),
                                                  'rescueAgeNumCtrl':
                                                      TextEditingController(),
                                                  'rescueAgeUnit': 'month(s) old',
                                                  'sex': 'Male',
                                                  'energy': 'Low',
                                                  'type':
                                                      selectedType, // inherit parent type
                                                  'origin': 'Shelter Born',
                                                  'status': 'In Shelter',
                                                  'hasDisability': 'No',
                                                  'healthStatus': 'Healthy',
                                                  'isRescued': false,
                                                  'dob': null,
                                                  'shelterId':
                                                      selectedShelterId,
                                                });
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.pink.withOpacity(
                                                  0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.pink,
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.add,
                                                    color: Colors.pink,
                                                    size: 13,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Add Offspring',
                                                    style: TextStyle(
                                                      color: Colors.pink,
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // ── Empty hint ───────────────────────────────────────
                                      if (offspringList.isEmpty) ...[
                                        const SizedBox(height: 10),
                                        const Text(
                                          'Tap "Add Offspring" to register litter members.',
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontFamily: 'Montserrat',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],

                                      // ── Offspring cards ──────────────────────────────────
                                      ...offspringList.asMap().entries.map((
                                        entry,
                                      ) {
                                        final i = entry.key;
                                        final o = entry.value;

                                        // Parse age to detect auto-promotion eligibility
                                        final ageText =
                                            (o['ageCtrl']
                                                    as TextEditingController)
                                                .text
                                                .trim();
                                        int ageMonths = 0;
                                        final yearMatch = RegExp(
                                          r'(\d+)\s*year',
                                        ).firstMatch(ageText.toLowerCase());
                                        final monthMatch = RegExp(
                                          r'(\d+)\s*month',
                                        ).firstMatch(ageText.toLowerCase());
                                        if (yearMatch != null)
                                          ageMonths +=
                                              int.parse(yearMatch.group(1)!) *
                                              12;
                                        if (monthMatch != null)
                                          ageMonths += int.parse(
                                            monthMatch.group(1)!,
                                          );
                                        final willAutoPromote =
                                            ageText.isNotEmpty &&
                                            ageMonths >= 3;

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2D2D2D),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color:
                                                  willAutoPromote
                                                      ? Colors.green
                                                          .withOpacity(0.5)
                                                      : Colors.pink.withOpacity(
                                                        0.2,
                                                      ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // ── Card header ─────────────────────────────
                                              Row(
                                                children: [
                                                  Text(
                                                    'Offspring #${i + 1}',
                                                    style: const TextStyle(
                                                      color: Colors.pinkAccent,
                                                      fontFamily: 'Montserrat',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (willAutoPromote) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 7,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green
                                                            .withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.green
                                                              .withOpacity(0.4),
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        '3+ months → Auto-promoted to Pet List',
                                                        style: TextStyle(
                                                          color:
                                                              Colors
                                                                  .greenAccent,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const Spacer(),
                                                  GestureDetector(
                                                    onTap:
                                                        () => setDialogState(
                                                          () => offspringList
                                                              .removeAt(i),
                                                        ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      color: Colors.white38,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),

                                              // ── Name ────────────────────────────────────
                                              _buildOffspringField(
                                                'Name *',
                                                o['nameCtrl']
                                                    as TextEditingController,
                                                setDialogState,
                                              ),

                                              // ── Color ───────────────────────────────────
                                              _buildOffspringField(
                                                'Color',
                                                o['colorCtrl']
                                                    as TextEditingController,
                                                setDialogState,
                                              ),

                                              // ── Breed ───────────────────────────────────
                                              _buildOffspringField(
                                                'Breed',
                                                o['breedCtrl']
                                                    as TextEditingController,
                                                setDialogState,
                                                hint:
                                                    'Leave blank to inherit from mother',
                                              ),

                                              // ── Age (triggers auto-promote badge) ───────
                                              buildAgeFieldRow(
                                                'Age *',
                                                o['ageNumCtrl'] as TextEditingController,
                                                o['ageUnit'] as String,
                                                (v) => setDialogState(() => o['ageUnit'] = v!),
                                                onChangedValue: () {
                                                  final numCtrl = o['ageNumCtrl'] as TextEditingController;
                                                  final unit = o['ageUnit'] as String;
                                                  (o['ageCtrl'] as TextEditingController).text = _formatAgeText(numCtrl.text, unit);
                                                },
                                              ),

                                              // ── Description ──────────────────────────────
                                              _buildOffspringField(
                                                'Description',
                                                o['descCtrl']
                                                    as TextEditingController,
                                                setDialogState,
                                                maxLines: 3,
                                              ),

                                              const SizedBox(height: 6),

                                              // ── Sex & Energy (row) ───────────────────────
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child:
                                                        _buildOffspringDropdown(
                                                          'Sex',
                                                          o['sex'] as String,
                                                          ['Male', 'Female'],
                                                          (v) => setDialogState(
                                                            () => o['sex'] = v!,
                                                          ),
                                                        ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child:
                                                        _buildOffspringDropdown(
                                                          'Energy',
                                                          o['energy'] as String,
                                                          [
                                                            'Low',
                                                            'Medium',
                                                            'High',
                                                          ],
                                                          (v) => setDialogState(
                                                            () =>
                                                                o['energy'] =
                                                                    v!,
                                                          ),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),

                                              // ── Type ────────────────────────────────────
                                              _buildOffspringDropdown(
                                                'Type',
                                                o['type'] as String,
                                                ['Cat', 'Dog'],
                                                (v) => setDialogState(
                                                  () => o['type'] = v!,
                                                ),
                                              ),
                                              const SizedBox(height: 6),

                                              // ── Origin ──────────────────────────────────
                                              _buildOffspringDropdown(
                                                'Origin',
                                                o['origin'] as String,
                                                [
                                                  'Shelter Born',
                                                  'Rescued',
                                                  'Surrendered by Owner',
                                                  'Transfer from Another Shelter',
                                                  'Found Stray',
                                                  'Other',
                                                ],
                                                (v) {
                                                  setDialogState(() {
                                                    o['origin'] = v!;
                                                    o['isRescued'] =
                                                        v == 'Rescued' ||
                                                        v == 'Found Stray';
                                                  });
                                                },
                                              ),
                                              const SizedBox(height: 6),

                                              // ── Origin (Other) ───────────────────────────
                                              if (o['origin'] == 'Other')
                                                _buildOffspringField(
                                                  'Specify Origin',
                                                  o['originCtrl']
                                                      as TextEditingController,
                                                  setDialogState,
                                                ),

                                              // ── Rescue age ───────────────────────────────
                                              if (o['isRescued'] == true)
                                                buildAgeFieldRow(
                                                  'Age at Rescue *',
                                                  o['rescueAgeNumCtrl'] as TextEditingController,
                                                  o['rescueAgeUnit'] as String,
                                                  (v) => setDialogState(() => o['rescueAgeUnit'] = v!),
                                                  onChangedValue: () {
                                                    final numCtrl = o['rescueAgeNumCtrl'] as TextEditingController;
                                                    final unit = o['rescueAgeUnit'] as String;
                                                    (o['rescueAgeCtrl'] as TextEditingController).text = _formatAgeText(numCtrl.text, unit);
                                                  },
                                                ),

                                              // ── Has disability ───────────────────────────
                                              _buildOffspringDropdown(
                                                'Has Disability?',
                                                o['hasDisability'] as String,
                                                ['Yes', 'No'],
                                                (v) => setDialogState(
                                                  () => o['hasDisability'] = v!,
                                                ),
                                              ),
                                              const SizedBox(height: 6),

                                              // ── Health Status (female only) ──────────────
                                              if (o['sex'] == 'Female')
                                                _buildOffspringDropdown(
                                                  'Health Status',
                                                  o['healthStatus'] as String,
                                                  [
                                                    'Healthy',
                                                    'Pregnant',
                                                    'Recovering',
                                                    'Under Treatment',
                                                    'Critical',
                                                    'Quarantined',
                                                  ],
                                                  (v) => setDialogState(
                                                    () =>
                                                        o['healthStatus'] = v!,
                                                  ),
                                                ),

                                              const SizedBox(height: 6),

                                              // ── Initial Status ───────────────────────────
                                              _buildOffspringDropdown(
                                                'Initial Status',
                                                o['status'] as String,
                                                [
                                                  'In Shelter',
                                                  'Under Medication',
                                                ],
                                                (v) => setDialogState(
                                                  () => o['status'] = v!,
                                                ),
                                              ),
                                              const SizedBox(height: 6),

                                              // ── Assign shelter ───────────────────────────
                                              if (shelters.isNotEmpty) ...[
                                                const Text(
                                                  'Assign to Shelter',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF3C3C3E,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: DropdownButtonHideUnderline(
                                                    child: DropdownButton<int>(
                                                      value:
                                                          o['shelterId']
                                                              as int?,
                                                      isExpanded: true,
                                                      dropdownColor:
                                                          const Color(
                                                            0xFF3C3C3E,
                                                          ),
                                                      hint: const Text(
                                                        'Same as mother',
                                                        style: TextStyle(
                                                          color: Colors.white38,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontSize: 12,
                                                      ),
                                                      items:
                                                          shelters.map((s) {
                                                            final int cap =
                                                                (s['capacity']
                                                                        as num?)
                                                                    ?.toInt() ??
                                                                0;
                                                            final int cur =
                                                                (s['current_count']
                                                                        as num?)
                                                                    ?.toInt() ??
                                                                0;
                                                            final bool full =
                                                                cap > 0 &&
                                                                cur >= cap;
                                                            return DropdownMenuItem<
                                                              int
                                                            >(
                                                              value:
                                                                  s['shelter_id']
                                                                      as int,
                                                              enabled: !full,
                                                              child: Text(
                                                                '${s['name']} ($cur/$cap)${full ? ' FULL' : ''}',
                                                                style: TextStyle(
                                                                  color:
                                                                      full
                                                                          ? Colors
                                                                              .white38
                                                                          : Colors
                                                                              .white,
                                                                  fontFamily:
                                                                      'Montserrat',
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                      onChanged: (v) {
                                                        if (v == null) return;
                                                        setDialogState(
                                                          () =>
                                                              o['shelterId'] =
                                                                  v,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],

                                              const SizedBox(height: 6),

                                              // ── Date of Birth ────────────────────────────
                                              GestureDetector(
                                                onTap: () async {
                                                  final picked = await showDatePicker(
                                                    context: dialogContext,
                                                    initialDate:
                                                        (o['dob']
                                                            as DateTime?) ??
                                                        DateTime.now().subtract(
                                                          const Duration(
                                                            days: 30,
                                                          ),
                                                        ),
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime.now(),
                                                    builder:
                                                        (ctx, child) => Theme(
                                                          data: ThemeData.dark().copyWith(
                                                            colorScheme:
                                                                const ColorScheme.dark(
                                                                  primary:
                                                                      Colors
                                                                          .pink,
                                                                  onPrimary:
                                                                      Colors
                                                                          .white,
                                                                  surface: Color(
                                                                    0xFF2D2D30,
                                                                  ),
                                                                ),
                                                          ),
                                                          child: child!,
                                                        ),
                                                  );
                                                  if (picked != null)
                                                    setDialogState(
                                                      () => o['dob'] = picked,
                                                    );
                                                },
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF3C3C3E,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.pink
                                                          .withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.calendar_today,
                                                        color: Colors.pink,
                                                        size: 15,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        o['dob'] != null
                                                            ? '${(o['dob'] as DateTime).day}/${(o['dob'] as DateTime).month}/${(o['dob'] as DateTime).year}'
                                                            : 'Date of Birth (optional)',
                                                        style: TextStyle(
                                                          color:
                                                              o['dob'] != null
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .white38,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      if (o['dob'] != null) ...[
                                                        const Spacer(),
                                                        GestureDetector(
                                                          onTap:
                                                              () => setDialogState(
                                                                () =>
                                                                    o['dob'] =
                                                                        null,
                                                              ),
                                                          child: const Icon(
                                                            Icons.close,
                                                            color:
                                                                Colors.white38,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // ── Auto-promote info banner ──────────────────
                                              if (willAutoPromote) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withOpacity(0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.green
                                                          .withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      Icon(
                                                        Icons.auto_awesome,
                                                        color:
                                                            Colors.greenAccent,
                                                        size: 14,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'This offspring is 3+ months old and will be automatically added to the main Pet List. A mother link will be kept on the female pet\'s record.',
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .greenAccent,
                                                            fontFamily:
                                                                'Montserrat',
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (selectedOrigin == 'Other')
                                buildField('Specify Origin', originController),

                              if (isRescued) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.medical_services,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Rescue Details',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      buildAgeFieldRow(
                                        'Age at Rescue *',
                                        mainRescueAgeNumberCtrl,
                                        mainRescueAgeUnit,
                                        (v) => setDialogState(() => mainRescueAgeUnit = v!),
                                        onChangedValue: () {
                                          rescueAgeController.text = mainRescueAgeNumberCtrl.text.trim().isEmpty
                                              ? ''
                                              : '${mainRescueAgeNumberCtrl.text.trim()} $mainRescueAgeUnit';
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              if (isOffspring) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.child_care,
                                        color: Colors.lightBlueAccent,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This pet was born inside the shelter (offspring).',
                                          style: TextStyle(
                                            color: Colors.lightBlueAccent,
                                            fontFamily: 'Montserrat',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              buildDropdown(
                                'Initial Status',
                                selectedStatus,
                                ['In Shelter', 'Under Medication'],
                                (v) =>
                                    setDialogState(() => selectedStatus = v!),
                              ),

                              if (shelters.isNotEmpty) ...[
                                const Text(
                                  'Assign to Shelter',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3C3C3E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: selectedShelterId,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF3C3C3E),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Montserrat',
                                        fontSize: 14,
                                      ),
                                      items:
                                          shelters.map((s) {
                                            final int capacity =
                                                (s['capacity'] as num?)
                                                    ?.toInt() ??
                                                0;
                                            final int current =
                                                (s['current_count'] as num?)
                                                    ?.toInt() ??
                                                0;
                                            final bool isFull =
                                                capacity > 0 &&
                                                current >= capacity;
                                            return DropdownMenuItem<int>(
                                              value: s['shelter_id'] as int,
                                              enabled: !isFull,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${s['name']} (${s['type']})',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Montserrat',
                                                        color:
                                                            isFull
                                                                ? Colors.white38
                                                                : Colors.white,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          isFull
                                                              ? Colors.red
                                                                  .withOpacity(
                                                                    0.2,
                                                                  )
                                                              : Colors.green
                                                                  .withOpacity(
                                                                    0.15,
                                                                  ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            isFull
                                                                ? Colors.red
                                                                    .withOpacity(
                                                                      0.5,
                                                                    )
                                                                : Colors.green
                                                                    .withOpacity(
                                                                      0.4,
                                                                    ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      isFull
                                                          ? 'FULL'
                                                          : '$current/$capacity',
                                                      style: TextStyle(
                                                        color:
                                                            isFull
                                                                ? Colors.red
                                                                : Colors.green,
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (v) {
                                        if (v == null) return;
                                        final shelter = shelters.firstWhere(
                                          (s) => s['shelter_id'] == v,
                                        );
                                        final int capacity =
                                            (shelter['capacity'] as num?)
                                                ?.toInt() ??
                                            0;
                                        final int current =
                                            (shelter['current_count'] as num?)
                                                ?.toInt() ??
                                            0;
                                        final bool isFull =
                                            capacity > 0 && current >= capacity;
                                        if (isFull) return;
                                        setDialogState(
                                          () => selectedShelterId = v,
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                if (selectedShelterId != null) ...[
                                  const SizedBox(height: 6),
                                  Builder(
                                    builder: (_) {
                                      final shelter = shelters.firstWhere(
                                        (s) =>
                                            s['shelter_id'] ==
                                            selectedShelterId,
                                        orElse: () => {},
                                      );
                                      if (shelter.isEmpty)
                                        return const SizedBox.shrink();
                                      final int capacity =
                                          (shelter['capacity'] as num?)
                                              ?.toInt() ??
                                          0;
                                      final int current =
                                          (shelter['current_count'] as num?)
                                              ?.toInt() ??
                                          0;
                                      final int remaining = (capacity - current)
                                          .clamp(0, capacity);
                                      final bool isFull =
                                          capacity > 0 && current >= capacity;
                                      return Row(
                                        children: [
                                          Icon(
                                            isFull
                                                ? Icons.block
                                                : Icons.info_outline,
                                            size: 13,
                                            color:
                                                isFull
                                                    ? Colors.red
                                                    : Colors.white38,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isFull
                                                ? 'This shelter is full. Please choose another.'
                                                : '$remaining slot${remaining == 1 ? '' : 's'} remaining',
                                            style: TextStyle(
                                              color:
                                                  isFull
                                                      ? Colors.redAccent
                                                      : Colors.white38,
                                              fontFamily: 'Montserrat',
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                                const SizedBox(height: 10),
                              ],

                              buildSection('Date of Birth'),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate:
                                        selectedDob ??
                                        DateTime.now().subtract(
                                          const Duration(days: 365),
                                        ),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                    builder:
                                        (ctx, child) => Theme(
                                          data: ThemeData.dark().copyWith(
                                            colorScheme: const ColorScheme.dark(
                                              primary: Colors.orange,
                                              onPrimary: Colors.white,
                                              surface: Color(0xFF2D2D30),
                                            ),
                                          ),
                                          child: child!,
                                        ),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => selectedDob = picked);
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3C3C3E),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        color: Colors.orange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        selectedDob != null
                                            ? '${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}'
                                            : 'Select date of birth',
                                        style: TextStyle(
                                          color:
                                              selectedDob != null
                                                  ? Colors.white
                                                  : Colors.white38,
                                          fontFamily: 'Montserrat',
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (selectedDob != null) ...[
                                        const Spacer(),
                                        GestureDetector(
                                          onTap:
                                              () => setDialogState(
                                                () => selectedDob = null,
                                              ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white38,
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                setDialogState(() => saveAttempted = true);
                                if (imageBytes == null) return;

                                if (selectedOrigin == 'Other' &&
                                    originController.text.trim().isEmpty) {
                                  _showSnackBar(
                                    'Please specify the origin.',
                                    Colors.red,
                                  );
                                  return;
                                }

                                if (isRescued &&
                                    rescueAgeController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter the age at rescue.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                if ([
                                  nameController,
                                  colorController,
                                  breedController,
                                  ageController,
                                  descriptionController,
                                ].any((c) => c.text.trim().isEmpty)) {
                                  _showSnackBar(
                                    'Please fill out all fields.',
                                    Colors.red,
                                  );
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(dialogContext);

                                try {
                                  final filePath =
                                      'pets/images/${DateTime.now().millisecondsSinceEpoch}.jpg';
                                  await supabase.storage
                                      .from('pets')
                                      .uploadBinary(filePath, imageBytes!);
                                  final imageUrl = supabase.storage
                                      .from('pets')
                                      .getPublicUrl(filePath);

                                  final petResponse =
                                      await supabase
                                          .from('pets')
                                          .insert({
                                            'name': nameController.text.trim(),
                                            'color':
                                                colorController.text.trim(),
                                            'breed':
                                                breedController.text.trim(),
                                            'age': ageController.text.trim(),
                                            'type': selectedType,
                                            'energy': selectedEnergy,
                                            'sex': selectedGender,
                                            'status': selectedStatus,
                                            'description':
                                                descriptionController.text
                                                    .trim(),
                                            'image_url_1': imageUrl,
                                            'shelter_id': selectedShelterId,
                                            'origin':
                                                selectedOrigin == 'Other'
                                                    ? originController.text
                                                        .trim()
                                                    : selectedOrigin,
                                            'is_offspring': isOffspring,
                                            'rescue_age':
                                                isRescued
                                                    ? rescueAgeController.text
                                                        .trim()
                                                    : null,
                                            'date_of_birth':
                                                selectedDob?.toIso8601String(),
                                            'created_at':
                                                DateTime.now()
                                                    .toIso8601String(),
                                            'has_disability':
                                                selectedHasDisability,
                                          })
                                          .select('pet_id')
                                          .single();

                                  final int petId = petResponse['pet_id'];

                                  if (selectedStatus == 'Under Medication') {
                                    await supabase
                                        .from('pet_medications')
                                        .insert({
                                          'pet_id': petId,
                                          'name': nameController.text.trim(),
                                          'color': colorController.text.trim(),
                                          'breed': breedController.text.trim(),
                                          'age': ageController.text.trim(),
                                          'type': selectedType,
                                          'energy': selectedEnergy,
                                          'sex': selectedGender,
                                          'status': 'Under Medication',
                                          'description':
                                              descriptionController.text.trim(),
                                          'image_url_1': imageUrl,
                                          'shelter_id': selectedShelterId,
                                          'disease_type': null,
                                          'disease_details': null,
                                          'created_at':
                                              DateTime.now().toIso8601String(),
                                          'vaccination_status':
                                              'Not Vaccinated',
                                          'neutered_spayed_details':
                                              'Not Neutered/Spayed',
                                          'deworming_status': 'Not Dewormed',
                                          'surgery_type': 'No Surgical History',
                                          'surgery_details':
                                              'No Surgery Details',
                                        });
                                  }

                                  for (final o in offspringList) {
                                    final oName =
                                        (o['nameCtrl'] as TextEditingController)
                                            .text
                                            .trim();
                                    if (oName.isEmpty) continue;

                                    final oColor =
                                        (o['colorCtrl']
                                                as TextEditingController)
                                            .text
                                            .trim();
                                    final oBreed =
                                        (o['breedCtrl']
                                                as TextEditingController)
                                            .text
                                            .trim();
                                    final oAge =
                                        (o['ageCtrl'] as TextEditingController)
                                            .text
                                            .trim();
                                    final oDesc =
                                        (o['descCtrl'] as TextEditingController)
                                            .text
                                            .trim();
                                    final oOriginCustom =
                                        (o['originCtrl']
                                                as TextEditingController)
                                            .text
                                            .trim();
                                    final oRescueAge =
                                        (o['rescueAgeCtrl']
                                                as TextEditingController)
                                            .text
                                            .trim();
                                    final oSex = o['sex'] as String;
                                    final oEnergy = o['energy'] as String;
                                    final oType = o['type'] as String;
                                    final oStatus = o['status'] as String;
                                    final oHasDisability =
                                        o['hasDisability'] as String;
                                    final oOrigin =
                                        (o['origin'] == 'Other' &&
                                                oOriginCustom.isNotEmpty)
                                            ? oOriginCustom
                                            : o['origin'] as String;
                                    final oIsRescued = o['isRescued'] == true;
                                    final oShelterId =
                                        (o['shelterId'] as int?) ??
                                        selectedShelterId;
                                    final oDob = o['dob'] as DateTime?;

                                    // Determine if auto-promote (age ≥ 3 months)
                                    int ageMonths = 0;
                                    final yearMatch = RegExp(
                                      r'(\d+)\s*year',
                                    ).firstMatch(oAge.toLowerCase());
                                    final monthMatch = RegExp(
                                      r'(\d+)\s*month',
                                    ).firstMatch(oAge.toLowerCase());
                                    if (yearMatch != null)
                                      ageMonths +=
                                          int.parse(yearMatch.group(1)!) * 12;
                                    if (monthMatch != null)
                                      ageMonths += int.parse(
                                        monthMatch.group(1)!,
                                      );
                                    final autoPromote =
                                        oAge.isNotEmpty && ageMonths >= 3;

                                    final offspringRow =
                                        await supabase
                                            .from('pets')
                                            .insert({
                                              'name': oName,
                                              'color':
                                                  oColor.isEmpty
                                                      ? 'Unknown'
                                                      : oColor,
                                              'breed':
                                                  oBreed.isEmpty
                                                      ? breedController.text
                                                          .trim()
                                                      : oBreed,
                                              'age':
                                                  oAge.isEmpty
                                                      ? '0 months'
                                                      : oAge,
                                              'type': oType,
                                              'energy': oEnergy,
                                              'sex': oSex,
                                              // Auto-promoted offspring go straight to 'Ready For Adoption' or keep
                                              // their chosen status; non-promoted stay as chosen.
                                              'status':
                                                  autoPromote
                                                      ? 'Ready For Adoption'
                                                      : oStatus,
                                              'description':
                                                  oDesc.isEmpty
                                                      ? 'Offspring of ${nameController.text.trim()}.'
                                                      : oDesc,
                                              'image_url_1':
                                                  imageUrl, // inherit mother's image for now
                                              'shelter_id': oShelterId,
                                              'origin': oOrigin,
                                              'is_offspring': true,
                                              'motherpet_id':
                                                  petId, // always link back to mother
                                              'rescue_age':
                                                  oIsRescued
                                                      ? oRescueAge
                                                      : null,
                                              'date_of_birth':
                                                  oDob?.toIso8601String(),
                                              'created_at':
                                                  DateTime.now()
                                                      .toIso8601String(),
                                              'has_disability': oHasDisability,
                                            })
                                            .select('pet_id')
                                            .single();

                                    final int offspringPetId =
                                        offspringRow['pet_id'];

                                    // If status is 'Under Medication', create a pet_medications row too
                                    if (!autoPromote &&
                                        oStatus == 'Under Medication') {
                                      await supabase
                                          .from('pet_medications')
                                          .insert({
                                            'pet_id': offspringPetId,
                                            'name': oName,
                                            'color':
                                                oColor.isEmpty
                                                    ? 'Unknown'
                                                    : oColor,
                                            'breed':
                                                oBreed.isEmpty
                                                    ? breedController.text
                                                        .trim()
                                                    : oBreed,
                                            'age':
                                                oAge.isEmpty
                                                    ? '0 months'
                                                    : oAge,
                                            'type': oType,
                                            'energy': oEnergy,
                                            'sex': oSex,
                                            'status': 'Under Medication',
                                            'description':
                                                oDesc.isEmpty
                                                    ? 'Offspring of ${nameController.text.trim()}.'
                                                    : oDesc,
                                            'image_url_1': imageUrl,
                                            'shelter_id': oShelterId,
                                            'disease_type': null,
                                            'disease_details': null,
                                            'created_at':
                                                DateTime.now()
                                                    .toIso8601String(),
                                            'vaccination_status':
                                                'Not Vaccinated',
                                            'neutered_spayed_details':
                                                'Not Neutered/Spayed',
                                            'deworming_status': 'Not Dewormed',
                                            'surgery_type':
                                                'No Surgical History',
                                            'surgery_details':
                                                'No Surgery Details',
                                          });
                                    }

                                    // After saving all offspring, increment litter_count by the number saved
                                    final savedCount =
                                        offspringList
                                            .where(
                                              (o) =>
                                                  (o['nameCtrl']
                                                          as TextEditingController)
                                                      .text
                                                      .trim()
                                                      .isNotEmpty,
                                            )
                                            .length;

                                    if (savedCount > 0) {
                                      // Fetch current litter_count
                                      final petRow =
                                          await supabase
                                              .from('pets')
                                              .select('litter_count')
                                              .eq('pet_id', petId)
                                              .single();

                                      final currentCount =
                                          (petRow['litter_count'] as int?) ?? 0;

                                      await supabase
                                          .from('pets')
                                          .update({
                                            'litter_count':
                                                currentCount + savedCount,
                                          })
                                          .eq('pet_id', petId);
                                    }
                                  }
                                  nav.pop();
                                  _loadAllPets();

                                  _showSnackBar(
                                    'Pet added successfully.',
                                    Colors.green,
                                  );
                                } catch (e) {
                                  debugPrint(e.toString());
                                  if (dialogContext.mounted) {
                                    _showSnackBar(
                                      'Failed to add pet.',
                                      Colors.red,
                                    );
                                  }
                                }
                              },
                              child: const Text(
                                'Save Pet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
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
          },
        );
      },
    );
  }

  Widget _buildPetRecordCard(Map<String, dynamic> pet, bool isDesktop) {
    final String petName = pet['name'] as String? ?? 'Unknown Pet';
    final String petImage = pet['image_url_1'] as String? ?? '';
    final String breed = pet['breed'] as String? ?? 'Unknown';
    final String age = pet['age']?.toString() ?? 'Unknown';
    final String status = pet['status'] as String? ?? 'Unknown';
    final String type = pet['type'] as String? ?? 'Unknown';
    final String sex = pet['sex'] as String? ?? 'Unknown';
    final String energy = pet['energy'] as String? ?? 'Unknown';
    final bool isOffspring = pet['is_offspring'] == true;
    final bool isFemale = sex.toLowerCase() == 'female';

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'ready for adoption':
        statusColor = Colors.green;
        break;
      case 'in shelter':
        statusColor = Colors.blue;
        break;
      case 'adopted':
        statusColor = Colors.orange;
        break;
      case 'under medication':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.white38;
    }

    return GestureDetector(
      onTap: () => _showPetRecordDetailSheet(context, pet),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isDesktop ? 14 : 10),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isOffspring
                    ? Colors.pinkAccent.withOpacity(0.4)
                    : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            _petAvatar(petImage, petName, radius: isDesktop ? 30 : 26),
            SizedBox(width: isDesktop ? 14 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row with offspring/litter badges
                  Row(
                    children: [
                      if (isOffspring)
                        const Padding(
                          padding: EdgeInsets.only(right: 5),
                          child: Icon(
                            Icons.child_care,
                            color: Colors.pinkAccent,
                            size: 14,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          petName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                            fontSize: isDesktop ? 14 : 13,
                          ),
                        ),
                      ),
                      // Show litter count badge for females
                      if (isFemale)
                        FutureBuilder<int>(
                          future: _getOffspringCount(pet['pet_id']),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.pink.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.pinkAccent.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.child_care,
                                    color: Colors.pinkAccent,
                                    size: 11,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$count offspring',
                                    style: const TextStyle(
                                      color: Colors.pinkAccent,
                                      fontFamily: 'Montserrat',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _petInfoChip(type, Colors.white24),
                      _petInfoChip(breed, Colors.white24),
                      _petInfoChip(sex, Colors.white24),
                      _petInfoChip('Age: $age', Colors.white24),
                      _petInfoChip(energy, Colors.white24),
                      if (isOffspring)
                        _petInfoChip(
                          'Shelter Born',
                          Colors.pink.withOpacity(0.3),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white24,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _getOffspringCount(dynamic petId) async {
    if (petId == null) return 0;
    try {
      final result = await supabase
          .from('pets')
          .select('pet_id')
          .eq('motherpet_id', petId);
      return (result as List).length;
    } catch (_) {
      return 0;
    }
  }

  void _showPetRecordDetailSheet(
    BuildContext context,
    Map<String, dynamic> pet,
  ) {
    final String petName = pet['name'] as String? ?? 'Unknown Pet';
    final String petImage = pet['image_url_1'] as String? ?? '';
    final String breed = pet['breed'] as String? ?? 'Unknown';
    final String age = pet['age']?.toString() ?? 'Unknown';
    final String status = pet['status'] as String? ?? 'Unknown';
    final String type = pet['type'] as String? ?? 'Unknown';
    final String sex = pet['sex'] as String? ?? 'Unknown';
    final String color = pet['color'] as String? ?? 'Unknown';
    final String energy = pet['energy'] as String? ?? 'Unknown';
    final String origin = pet['origin'] as String? ?? 'Unknown';
    final String description =
        pet['description'] as String? ?? 'No description';
    final String hasDisability = pet['has_disability'] as String? ?? 'No';
    final String vaccinationStatus =
        pet['vaccination_status'] as String? ?? 'N/A';
    final String dewormingStatus = pet['deworming_status'] as String? ?? 'N/A';
    final String neuteredSpayed =
        pet['neutered_spayed_details'] as String? ?? 'N/A';
    final String? dob = pet['date_of_birth'] as String?;
    final String? shelter = pet['shelter_id']?.toString();
    final int? petId = pet['pet_id'] as int?;

    String dobFormatted = 'Not set';
    if (dob != null) {
      try {
        final dt = DateTime.parse(dob).toLocal();
        dobFormatted =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'ready for adoption':
        statusColor = Colors.green;
        break;
      case 'in shelter':
        statusColor = Colors.blue;
        break;
      case 'adopted':
        statusColor = Colors.orange;
        break;
      case 'under medication':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.white38;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (_, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            _petAvatar(petImage, petName, radius: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    petName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (petImage.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  showDialog(
                                    context: context,
                                    barrierColor: Colors.black87,
                                    builder:
                                        (_) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          insetPadding: const EdgeInsets.all(
                                            16,
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: InteractiveViewer(
                                                    child: Image.network(
                                                      petImage,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 0,
                                                right: 0,
                                                child: GestureDetector(
                                                  onTap:
                                                      () => Navigator.pop(
                                                        context,
                                                      ),
                                                  child: Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Colors.black54,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(6),
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
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const Divider(color: Colors.white12, height: 1),

                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            if (petImage.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  petImage,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Container(
                                        height: 180,
                                        color: Colors.grey[850],
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.pets,
                                          color: Colors.white24,
                                          size: 48,
                                        ),
                                      ),
                                ),
                              ),
                            if (petImage.isNotEmpty) const SizedBox(height: 16),

                            _detailSection('Basic Info', [
                              _detailRow('Type', type),
                              _detailRow('Breed', breed),
                              _detailRow('Age', age),
                              _detailRow('Color', color),
                              _detailRow('Sex', sex),
                              _detailRow('Energy', energy),
                              _detailRow('Date of Birth', dobFormatted),
                              _detailRow('Has Disability', hasDisability),
                            ]),
                            const SizedBox(height: 12),
                            _detailSection('Origin & Status', [
                              _detailRow('Origin', origin),
                              _detailRow('Status', status),
                              if (petId != null)
                                FutureBuilder<String>(
                                  future: () async {
                                    final sid = pet['shelter_id'];
                                    if (sid == null) return 'Not assigned';
                                    try {
                                      final result =
                                          await supabase
                                              .from('shelters')
                                              .select('name')
                                              .eq('shelter_id', sid)
                                              .maybeSingle();
                                      return result?['name'] as String? ??
                                          'Unknown Shelter';
                                    } catch (_) {
                                      return 'Unknown Shelter';
                                    }
                                  }(),
                                  builder: (context, snapshot) {
                                    final shelterName = snapshot.data ?? '...';
                                    return _detailRow('Shelter', shelterName);
                                  },
                                ),
                              const SizedBox(height: 12),
                              _detailSection('Medical Info', [
                                _detailRow('Vaccination', vaccinationStatus),
                                _detailRow('Deworming', dewormingStatus),
                                _detailRow('Spayed/Neutered', neuteredSpayed),
                              ]),
                              const SizedBox(height: 12),
                              _detailSection('Description', []),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  description,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (pet['sex']?.toString().toLowerCase() ==
                                  'female') ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'OFFSPRING',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _fetchOffspring(petId),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.orange,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    final offspring = snapshot.data ?? [];
                                    if (offspring.isEmpty) {
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white10,
                                          ),
                                        ),
                                        child: const Text(
                                          'No offspring recorded.',
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontFamily: 'Montserrat',
                                            fontSize: 13,
                                          ),
                                        ),
                                      );
                                    }
                                    return SizedBox(
                                      height: 100,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: offspring.length,
                                        separatorBuilder:
                                            (_, __) =>
                                                const SizedBox(width: 10),
                                        itemBuilder: (_, i) {
                                          final o = offspring[i];
                                          final oImg = o['image_url_1'] ?? '';
                                          final oName = o['name'] ?? 'Unnamed';
                                          final oSex = o['sex'] ?? '';
                                          return GestureDetector(
                                            onTap: () {
                                              Navigator.pop(context);
                                              _showPetRecordDetailSheet(
                                                context,
                                                o,
                                              );
                                            },
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ClipOval(
                                                  child:
                                                      oImg.isNotEmpty
                                                          ? Image.network(
                                                            oImg,
                                                            width: 60,
                                                            height: 60,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (_, __, ___) =>
                                                                    _petAvatarFallback(
                                                                      oName,
                                                                      30,
                                                                    ),
                                                          )
                                                          : _petAvatarFallback(
                                                            oName,
                                                            30,
                                                          ),
                                                ),
                                                const SizedBox(height: 4),
                                                SizedBox(
                                                  width: 60,
                                                  child: Text(
                                                    oName,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color:
                                                          oSex.toLowerCase() ==
                                                                  'female'
                                                              ? Colors
                                                                  .pinkAccent
                                                              : Colors
                                                                  .lightBlueAccent,
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  o['status'] ?? '',
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],

                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchOffspring(int? petId) async {
    if (petId == null) return [];
    try {
      final result = await supabase
          .from('pets')
          .select(
            'pet_id, name, sex, type, breed, color, age, '
            'image_url_1, status, is_offspring, energy, '
            'description, has_disability, vaccination_status, '
            'deworming_status, neutered_spayed_details, origin, '
            'date_of_birth, shelter_id',
          )
          .eq('motherpet_id', petId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('❌ fetchOffspring error: $e');
      return [];
    }
  }

  Widget _detailSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.orange,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontFamily: 'Montserrat',
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffspringDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF252526),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: const Color(0xFF252526),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                ),
                items:
                    options
                        .map(
                          (o) => DropdownMenuItem(
                            value: o,
                            child: Text(
                              o,
                              style: const TextStyle(fontFamily: 'Montserrat'),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffspringField(
    String label,
    TextEditingController ctrl,
    StateSetter setDialogState, {
    int maxLines = 1,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Montserrat',
              fontSize: 13,
            ),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Colors.white24,
                fontFamily: 'Montserrat',
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(0xFF252526),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Colors.orange,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _petInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontFamily: 'Montserrat',
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildAdoptionNavigationView(bool isDesktop) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF161616),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 12,
            vertical: 8,
          ),
          child: Row(
            children: [
              const Icon(Icons.manage_search, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Adoption Management',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        Container(
          color: const Color(0xFF1A1A1A),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.orange,
            indicatorWeight: 3,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white38,
            isScrollable: !isDesktop,
            tabAlignment: isDesktop ? TabAlignment.fill : TabAlignment.start,
            labelStyle: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: isDesktop ? 13 : 12,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: isDesktop ? 13 : 12,
            ),
            tabs: [
              _adoptionTab(
                label: 'Pending',
                count: _pendingAdoptions.length,
                color: Colors.orange,
              ),
              _adoptionTab(
                label: 'Approved',
                count: _approvedAdoptions.length,
                color: Colors.green,
              ),
              _adoptionTab(
                label: 'Cancelled',
                count: _cancelledAdoptions.length,
                color: Colors.redAccent,
              ),
              _adoptionTab(
                label: 'Declined',
                count: _declinedAdoptions.length,
                color: Colors.purple,
              ),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAdoptionList(
                items: _pendingAdoptions,
                isLoading: _loadingPending,
                type: 'pending',
              ),
              _buildAdoptionList(
                items: _approvedAdoptions,
                isLoading: _loadingApproved,
                type: 'approved',
              ),
              _buildAdoptionList(
                items: _cancelledAdoptions,
                isLoading: _loadingCancelled,
                type: 'cancelled',
              ),
              _buildAdoptionList(
                items: _declinedAdoptions,
                isLoading: _loadingDeclined,
                type: 'declined',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Tab _adoptionTab({
    required String label,
    required int count,
    required Color color,
  }) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdoptionList({
    required List<Map<String, dynamic>> items,
    required bool isLoading,
    required String type,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }
    if (items.isEmpty) {
      return _emptyState('No $type adoptions', Icons.inbox_outlined);
    }
    return ListView.builder(
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 800 ? 12 : 20,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (type == 'pending') return _buildPendingCard(item);
        if (type == 'approved') return _buildApprovedCard(item);
        if (type == 'declined') return _buildDeclineCard(item);
        return _buildCancelledCard(item);
      },
    );
  }

  Widget _buildDeclineCard(Map<String, dynamic> adoptionData) {
    final String petName = adoptionData['pet_name'] as String? ?? 'Unknown Pet';
    final String petImage = adoptionData['pet_image'] as String? ?? '';
    final String reason =
        adoptionData['reason_to_decline'] as String? ?? 'No reason provided';
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _petAvatar(petImage, petName, radius: isMobile ? 22 : 26),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 15,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Declined',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 11,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reason: $reason',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: isMobile ? 11 : 12,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 56),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white38,
              fontFamily: 'Montserrat',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> adoption) {
    final profile = adoption['profiles'] as Map<String, dynamic>?;
    final petImage =
        adoption['pet_image'] as String? ??
        (adoption['pets'] as Map<String, dynamic>?)?['pet_image'] as String? ??
        '';
    final petName =
        adoption['pet_name'] as String? ??
        (adoption['pets'] as Map<String, dynamic>?)?['pet_name'] as String? ??
        'Unknown Pet';
    final firstName = profile?['first_name'] as String? ?? 'User';
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _petAvatar(petImage, petName, radius: isMobile ? 22 : 26),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
                Text(
                  '$firstName wants to adopt',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: isMobile ? 34 : 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => PetDetailAdoptionPage(
                          adoptionId: adoption['adoption_id'],
                        ),
                  ),
                );
                if (result == true) _refreshAll();
              },
              child: Text(
                'View',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedCard(Map<String, dynamic> adoption) {
    final petImage = adoption['pet_image'] as String? ?? '';
    final petName = adoption['pet_name'] as String? ?? 'Unknown Pet';
    final adopteeName = adoption['name'] as String? ?? 'Unknown';
    final approvedAt = adoption['updated_at'] ?? adoption['created_at'];
    String dateStr = '';
    if (approvedAt != null) {
      try {
        final dt = DateTime.parse(approvedAt.toString()).toLocal();
        dateStr =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          _petAvatar(petImage, petName, radius: isMobile ? 22 : 26),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
                Text(
                  'Adopted by $adopteeName',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    'Approved: $dateStr',
                    style: TextStyle(
                      color: Colors.green,
                      fontFamily: 'Montserrat',
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: isMobile ? 34 : 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ApprovedAdoptionDetailPage(
                            adoption: adoption,
                            onRefresh: _refreshAll,
                          ),
                    ),
                  ),
              child: Text(
                'View',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledCard(Map<String, dynamic> adoptionData) {
    final String petName = adoptionData['pet_name'] as String? ?? 'Unknown Pet';
    final String petImage = adoptionData['pet_image'] as String? ?? '';
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _showPetInfoDialog(context, adoptionData),
            child: _petAvatar(petImage, petName, radius: isMobile ? 22 : 26),
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 15,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  adoptionData['status'] as String? ?? '',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: isMobile ? 11 : 12,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPetInfoDialog(
    BuildContext context,
    Map<String, dynamic> adoptionData,
  ) {
    final petImage = adoptionData['pet_image'] as String? ?? '';
    final petName = adoptionData['pet_name'] as String? ?? 'Unknown Pet';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101510),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder:
                (_, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          children: [
                            _petAvatar(petImage, petName, radius: 44),
                            const SizedBox(height: 12),
                            Text(
                              petName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _infoRow(
                        'Breed',
                        adoptionData['breed'] as String? ?? 'Unknown',
                      ),
                      _infoRow(
                        'Age',
                        adoptionData['age']?.toString() ?? 'Unknown',
                      ),
                      _infoRow(
                        'Sex',
                        adoptionData['sex'] as String? ?? 'Unknown',
                      ),
                      _infoRow(
                        'Color',
                        adoptionData['color'] as String? ?? 'Unknown',
                      ),
                      if (adoptionData['cancel_category'] != null ||
                          adoptionData['reason'] != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade700),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cancellation Details',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _infoRow(
                                'Category',
                                adoptionData['cancel_category'] as String? ??
                                    'N/A',
                              ),
                              _infoRow(
                                'Reason',
                                adoptionData['reason'] as String? ?? 'N/A',
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.orange,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _petAvatar(String petImage, String petName, {double radius = 26}) {
    if (petImage.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.network(
            petImage,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFF3A3A3A),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => _petAvatarFallback(petName, radius),
          ),
        ),
      );
    }
    return _petAvatarFallback(petName, radius);
  }

  Widget _petAvatarFallback(String petName, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF3A3A3A),
      child: Text(
        petName.isNotEmpty ? petName[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontFamily: 'Montserrat',
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) => Container(
    height: 40,
    width: double.infinity,
    color: const Color(0xFF181818),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: const Row(
      children: [
        Text(
          "Harvard 2025 Pet Adoption",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    ),
  );

  Widget _buildTopHeader({bool isMobile = false}) {
    return Container(
      height: isMobile ? 56 : null,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 20,
        vertical: isMobile ? 8 : 15,
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder:
                  (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
            ),
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed:
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PetPage()),
                  ),
            )
          else
            ElevatedButton.icon(
              onPressed:
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PetPage()),
                  ),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text(
                "Back",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Montserrat",
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF666666),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          SizedBox(width: isMobile ? 6 : 12),
          Expanded(
            child: Text(
              'Pets & Adoptions',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 15 : 20,
                fontWeight: FontWeight.bold,
                fontFamily: "Montserrat",
              ),
            ),
          ),
          SizedBox(width: isMobile ? 4 : 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              _NotificationBell(
                iconSize: isMobile ? 22 : 24,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
              SizedBox(width: isMobile ? 4 : 16),
              buildProfileAvatar(context, radius: isMobile ? 14 : 16),
            ],
          ),
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
                  ),
                )
                : Icon(Icons.person, color: Colors.black, size: radius),
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
}

class ApprovedAdoptionDetailPage extends StatefulWidget {
  final Map<String, dynamic> adoption;
  final VoidCallback onRefresh;
  const ApprovedAdoptionDetailPage({
    super.key,
    required this.adoption,
    required this.onRefresh,
  });
  @override
  State<ApprovedAdoptionDetailPage> createState() =>
      _ApprovedAdoptionDetailPageState();
}

class _ApprovedAdoptionDetailPageState
    extends State<ApprovedAdoptionDetailPage> {
  final supabase = Supabase.instance.client;
  bool _isBanning = false;
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

  Future<void> _banFurparent(BuildContext context) async {
    final furparentId = widget.adoption['furparent_id'];
    if (furparentId == null) return;
    int? banMonths = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int selected = 1;
        return StatefulBuilder(
          builder:
              (ctx, setS) => AlertDialog(
                backgroundColor: const Color(0xFF2D2D2D),
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                title: const Text(
                  'Ban Furparent',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How long should the ban last?',
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selected,
                      dropdownColor: const Color(0xFF3A3A3A),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF3A3A3A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                      items:
                          [1, 3, 6, 12, 24]
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    '$m month${m > 1 ? "s" : ""}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setS(() => selected = v ?? 1),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: const Text(
                      'Ban',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
        );
      },
    );
    if (banMonths == null) return;
    setState(() => _isBanning = true);
    try {
      final bannedUntil = DateTime.now().toUtc().add(
        Duration(days: banMonths * 30),
      );
      await supabase
          .from('profiles')
          .update({'banned_until': bannedUntil.toIso8601String()})
          .eq('furparent_id', furparentId);
      if (mounted) {
        _showSnackBar(
          'Furparent banned for $banMonths month${banMonths > 1 ? "s" : ""}.',
          Colors.red,
        );
        widget.onRefresh();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        _showSnackBar(
          'Furparent banned for $banMonths month${banMonths > 1 ? "s" : ""}.',
          Colors.red,
        );
    } finally {
      if (mounted) setState(() => _isBanning = false);
    }
  }

  void _openImageFullscreen(
    BuildContext context,
    String imageUrl,
    String title,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              height: 300,
                              alignment: Alignment.center,
                              child: const Text(
                                'Could not load image',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.adoption;
    final petImage = a['pet_image'] as String? ?? '';
    final petName = a['pet_name'] as String? ?? 'Unknown Pet';
    final adopteeName = a['name'] as String? ?? 'Unknown';
    final phone = a['phone'] as String? ?? 'N/A';
    final email = a['email'] as String? ?? 'N/A';
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Approved Adoption',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions:
            isMobile
                ? null
                : [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          _isBanning ? null : () => _banFurparent(context),
                      icon:
                          _isBanning
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(
                                Icons.block,
                                size: 18,
                                color: Colors.white,
                              ),
                      label: Text(
                        _isBanning ? 'Banning...' : 'Ban Furparent',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pet Information',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap:
                              petImage.isNotEmpty
                                  ? () => _openImageFullscreen(
                                    context,
                                    petImage,
                                    petName,
                                  )
                                  : null,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child:
                                    petImage.isNotEmpty
                                        ? Image.network(
                                          petImage,
                                          width: double.infinity,
                                          height: isMobile ? 160 : 180,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) => Container(
                                                height: isMobile ? 160 : 180,
                                                color: Colors.grey,
                                              ),
                                        )
                                        : Container(
                                          height: isMobile ? 160 : 180,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.pets,
                                            size: 60,
                                            color: Colors.grey,
                                          ),
                                        ),
                              ),
                              if (petImage.isNotEmpty)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          petName,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: isMobile ? 17 : 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _chip('Type', a['type'] ?? 'Unknown'),
                            _chip('Breed', a['breed'] ?? 'Unknown'),
                            _chip('Age', a['age']?.toString() ?? 'Unknown'),
                            _chip('Color', a['color'] ?? 'Unknown'),
                            _chip('Sex', a['sex'] ?? 'Unknown'),
                            _chip(
                              'Vaccination',
                              a['vaccination_status'] ?? 'None',
                            ),
                            _chip('Deworming', a['deworming_status'] ?? 'None'),
                            _chip(
                              'Spayed',
                              a['neutered_spayed_details'] ?? 'N/A',
                            ),
                            _chip('Energy', a['energy'] ?? 'Unknown'),
                          ],
                        ),
                        if (a['description'] != null) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Description:',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a['description'] ?? 'No description',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Furparent Information',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _infoRow('Name', adopteeName),
                        _infoRow('Phone', phone),
                        _infoRow('Email', email),
                        const SizedBox(height: 12),
                        const Text(
                          'Address',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _infoRow('Region', a['region'] ?? 'N/A'),
                        _infoRow('Province', a['province'] ?? 'N/A'),
                        _infoRow('City', a['city'] ?? 'N/A'),
                        _infoRow('Barangay', a['barangay'] ?? 'N/A'),
                        _infoRow('Postal Code', a['postal_code'] ?? 'N/A'),
                        _infoRow('Street', a['street'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Adoption Details',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _infoRow('Status', a['status'] ?? 'Unknown'),
                        if (a['created_at'] != null)
                          _infoRow(
                            'Applied',
                            _formatDate(a['created_at'].toString()),
                          ),
                        if (a['updated_at'] != null)
                          _infoRow(
                            'Approved',
                            _formatDate(a['updated_at'].toString()),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isBanning ? null : () => _banFurparent(context),
                  icon: const Icon(Icons.block, color: Colors.white),
                  label: const Text(
                    'Ban Furparent',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width < 800 ? 90 : 110,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontFamily: 'Montserrat',
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

class PetDetailAdoptionPage extends StatefulWidget {
  final int? adoptionId;
  const PetDetailAdoptionPage({super.key, required this.adoptionId});
  @override
  State<PetDetailAdoptionPage> createState() => _PetDetailAdoptionPageState();
}

class _PetDetailAdoptionPageState extends State<PetDetailAdoptionPage> {
  String selectedItem = 'Pet Management';
  bool isLoading = true;
  final List<String> declineReasons = [
    'Incomplete requirements',
    'Unstable living environment',
    'Pet not suitable for applicant',
    'Previous adoption issues',
    'Failed interview or visit',
    'Other',
  ];
  Map<String, dynamic>? adoptionData, petData, userData, addressData;
  bool isLoadingAvatar = false;
  String? cachedProfileImage;
  Map<String, dynamic>? verificationData;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    if (widget.adoptionId != null)
      loadAdoptionDetails();
    else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showError("Invalid adoption ID"),
      );
      isLoading = false;
    }
    loadProfileImageForAvatar();
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

  Future<void> loadProfileImageForAvatar() async {
    if (isLoadingAvatar) return;
    setState(() => isLoadingAvatar = true);
    try {
      final response =
          await supabase
              .from('admin')
              .select('admin_profile')
              .eq('admin_id', 1)
              .maybeSingle();
      if (response == null) {
        if (mounted) setState(() => isLoadingAvatar = false);
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
      if (mounted)
        setState(() {
          cachedProfileImage = publicUrl;
          isLoadingAvatar = false;
        });
    } catch (e) {
      if (mounted) setState(() => isLoadingAvatar = false);
    }
  }

  Future<void> loadAdoptionDetails() async {
    if (widget.adoptionId == null) return;
    setState(() => isLoading = true);
    try {
      final response =
          await supabase
              .from('adoptions')
              .select('*')
              .eq('adoption_id', widget.adoptionId!)
              .maybeSingle();

      if (response == null) {
        showError("Adoption record not found.");
        setState(() => isLoading = false);
        return;
      }

      final furparentId = response['furparent_id'];

      Map<String, dynamic>? verification;
      if (furparentId != null) {
        try {
          final rows = await supabase
              .from('verifications')
              .select(
                'id_front_url, id_back_url, selfie_url, submitted_at, status',
              )
              .eq('furparent_id', furparentId)
              .order('submitted_at', ascending: false)
              .limit(1);
          final list = List<Map<String, dynamic>>.from(rows);
          verification = list.isNotEmpty ? list.first : null;
        } catch (e) {
          debugPrint('Could not fetch verification: $e');
        }
      }

      String fullName = response['name'] as String? ?? 'Unknown';
      if (furparentId != null) {
        try {
          final profile =
              await supabase
                  .from('profiles')
                  .select('first_name, middle_name, last_name, suffix_name')
                  .eq('furparent_id', furparentId)
                  .maybeSingle();

          if (profile != null) {
            fullName = [
              profile['first_name']?.toString().trim(),
              profile['middle_name']?.toString().trim(),
              profile['last_name']?.toString().trim(),
              profile['suffix_name']?.toString().trim(),
            ].where((part) => part != null && part.isNotEmpty).join(' ');

            if (fullName.isEmpty)
              fullName = response['name'] as String? ?? 'Unknown';
          }
        } catch (e) {
          debugPrint('Could not fetch profile name: $e');
        }
      }

      setState(() {
        adoptionData = Map<String, dynamic>.from(response);
        verificationData = verification;
        petData = {
          'pet_name': response['pet_name'] as String? ?? 'Unknown Pet',
          'pet_image': response['pet_image'] as String? ?? '',
          'breed': response['breed'] as String? ?? 'Unknown',
          'age': response['age']?.toString() ?? 'Unknown',
          'color': response['color'] as String? ?? 'Unknown',
          'sex': response['sex'] as String? ?? 'Unknown',
          'type': response['type'] as String? ?? 'Unknown',
          'vaccination_status':
              response['vaccination_status'] as String? ?? 'None',
          'deworming_status': response['deworming_status'] as String? ?? 'None',
          'neutered_spayed_details':
              response['neutered_spayed_details'] as String? ??
              'Not Neutered/Spayed',
          'description': response['description'] as String? ?? 'No description',
          'energy': response['energy'] as String? ?? 'Unknown',
          'has_disability': response['has_disability'] as String? ?? 'No',
        };
        userData = {
          'name': fullName,
          'email': response['email'] as String? ?? 'No email',
          'phone': response['phone'] as String? ?? 'No phone',
        };
        addressData = {
          'region': response['region'] as String? ?? '',
          'province': response['province'] as String? ?? '',
          'city': response['city'] as String? ?? '',
          'barangay': response['barangay'] as String? ?? '',
          'postal_code': response['postal_code'] as String? ?? '',
          'street': response['street'] as String? ?? '',
        };
        isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Error fetching adoption: $e\n$st');
      showError("Error loading adoption details.");
      setState(() => isLoading = false);
    }
  }

  void showError(String message) {
    _showSnackBar(message, Colors.red);
  }

  Future<void> handleApproval(String action, {String? declineReason}) async {
    if (widget.adoptionId == null) return;
    try {
      final isApproved = action == 'Approved';

      await supabase
          .from('adoptions')
          .update({
            'status': isApproved ? 'Approved' : 'Declined',
            'reason_to_decline': declineReason,
          })
          .eq('adoption_id', widget.adoptionId!);

      if (isApproved) {
        final petId = adoptionData?['pet_id'];
        if (petId != null) {
          await supabase
              .from('adoptable_pets')
              .update({'status': 'Approved'})
              .eq('pet_id', petId);
        }
      }

      final furparentId = adoptionData?['furparent_id'];
      final petName = adoptionData?['pet_name'] as String? ?? 'your pet';
      if (furparentId != null) {
        await supabase.from('user_notifications').insert({
          'furparent_id': furparentId,
          'title':
              isApproved
                  ? '🎉 Adoption Approved!'
                  : 'Adoption Request Declined',
          'body':
              isApproved
                  ? 'Congratulations! Your adoption request for $petName has been approved!'
                  : 'Your adoption request for $petName was declined. Reason: ${declineReason ?? 'No reason provided.'}',
          'type': 'adoption_status',
          'screen': 'AdoptionPage',
          'read': false,
        });
      }

      await logActivity(
        action: 'Adoption Request $action',
        description:
            '${isApproved ? 'Approved' : 'Declined'} adoption request for $petName',
        entityType: 'Adoption',
        entityId: widget.adoptionId,
      );

      if (!mounted) return;
      _showSnackBar(
        'Adoption request ${action.toLowerCase()} successfully.',
        isApproved ? Colors.green : Colors.orange,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnackBar('Error updating status.', Colors.red);
    }
  }

  void _openImageFullscreen(
    BuildContext context,
    String imageUrl,
    String title,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              height: 300,
                              alignment: Alignment.center,
                              child: const Text(
                                'Could not load image',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: isDesktop ? null : Drawer(width: 200, child: _buildSidebar()),
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop)
              Container(
                width: 200,
                color: Colors.grey[900],
                child: _buildSidebar(),
              ),
            Expanded(
              child: Column(
                children: [
                  buildTopHeader(showMenuButton: !isDesktop),
                  const SizedBox(height: 12),
                  Expanded(
                    child:
                        isLoading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.orange,
                              ),
                            )
                            : SingleChildScrollView(
                              padding: EdgeInsets.all(isDesktop ? 20 : 14),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: isDesktop ? 800 : double.infinity,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      buildPetCard(),
                                      const SizedBox(height: 16),
                                      buildPersonalInfoCard(),
                                      const SizedBox(height: 16),
                                      buildActionButtons(),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                  ),
                  buildFooter(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPetCard() {
    final petImage = petData?['pet_image'] ?? '';
    final petName =
        petData?['pet_name'] ?? adoptionData?['pet_name'] ?? 'Unknown Pet';
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap:
                  petImage.isNotEmpty
                      ? () => _openImageFullscreen(context, petImage, petName)
                      : null,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        petImage.isNotEmpty
                            ? Image.network(
                              petImage,
                              width: double.infinity,
                              height: isMobile ? 140 : 160,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    color: Colors.grey,
                                    height: isMobile ? 140 : 160,
                                  ),
                            )
                            : Container(
                              height: isMobile ? 140 : 160,
                              color: Colors.grey,
                            ),
                  ),
                  if (petImage.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              petName,
              style: TextStyle(
                color: Colors.black,
                fontSize: isMobile ? 17 : 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _compactChip('Type', petData?['type'] ?? 'Unknown'),
                _compactChip('Breed', petData?['breed'] ?? 'Unknown'),
                _compactChip('Age', petData?['age'] ?? 'Unknown'),
                _compactChip('Color', petData?['color'] ?? 'Unknown'),
                _compactChip('Sex', petData?['sex'] ?? 'Unknown'),
                _compactChip('Energy', petData?['energy'] ?? 'Unknown'),
                _compactChip(
                  'Vaccination',
                  petData?['vaccination_status'] ?? 'None',
                ),
                _compactChip(
                  'Deworming',
                  petData?['deworming_status'] ?? 'None',
                ),
                _compactChip(
                  'Spayed/Neutered',
                  petData?['neutered_spayed_details'] ?? 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Details:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              petData?['description'] ?? 'None',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactChip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    ),
  );

  Widget buildPersonalInfoCard() {
    final fullName = userData?['name'] ?? 'Unknown';
    final phone = userData?['phone'] ?? 'No phone';
    final email = userData?['email'] ?? 'No email';
    final selfieUrl =
        verificationData?['selfie_url'] ?? adoptionData?['selfie_url'];
    final idFrontUrl =
        verificationData?['id_front_url'] ?? adoptionData?['id_url'];
    final idBackUrl = verificationData?['id_back_url'];
    final verificationStatus = verificationData?['status']?.toString() ?? 'N/A';
    final submittedAt =
        verificationData?['submitted_at'] != null
            ? DateTime.tryParse(verificationData!['submitted_at'])
            : null;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Personal Info"),
            const SizedBox(height: 8),
            _infoText("Name", fullName),
            _infoText("Phone", phone),
            _infoText("Email", email),
            const SizedBox(height: 14),
            _sectionTitle("Address Info"),
            const SizedBox(height: 8),
            _infoText("Region", addressData?['region']),
            _infoText("Province", addressData?['province']),
            _infoText("City", addressData?['city']),
            _infoText("Barangay", addressData?['barangay']),
            _infoText("Postal Code", addressData?['postal_code']),
            _infoText("Street", addressData?['street']),
            const SizedBox(height: 14),
            const Divider(),
            _sectionTitle("Verification"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        verificationStatus.toLowerCase() == 'approved'
                            ? Colors.green.shade100
                            : verificationStatus.toLowerCase() == 'rejected'
                            ? Colors.red.shade100
                            : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    verificationStatus.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color:
                          verificationStatus.toLowerCase() == 'approved'
                              ? Colors.green.shade800
                              : verificationStatus.toLowerCase() == 'rejected'
                              ? Colors.red.shade800
                              : Colors.orange.shade800,
                    ),
                  ),
                ),
                if (submittedAt != null)
                  Text(
                    'Submitted: ${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isMobile &&
                idBackUrl != null &&
                idBackUrl.toString().isNotEmpty)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _compactImageBox(
                          context,
                          selfieUrl,
                          'Selfie',
                          verificationData != null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _compactImageBox(
                          context,
                          idFrontUrl,
                          'ID (Front)',
                          verificationData != null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _compactImageBox(context, idBackUrl, 'ID (Back)', true),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _compactImageBox(
                      context,
                      selfieUrl,
                      'Selfie',
                      verificationData != null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _compactImageBox(
                      context,
                      idFrontUrl,
                      'ID (Front)',
                      verificationData != null,
                    ),
                  ),
                  if (idBackUrl != null && idBackUrl.toString().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _compactImageBox(
                        context,
                        idBackUrl,
                        'ID (Back)',
                        true,
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 8),
            Text(
              verificationData != null
                  ? '✅ Images sourced from verified identity documents.'
                  : '⚠️ No verification documents found.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                color: verificationData != null ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactImageBox(
    BuildContext context,
    String? imageUrl,
    String label,
    bool isVerified,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: Colors.green, size: 13),
            ],
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap:
              imageUrl != null && imageUrl.isNotEmpty
                  ? () => _openImageFullscreen(context, imageUrl, label)
                  : null,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          height:
                              MediaQuery.of(context).size.width < 800
                                  ? 90
                                  : 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbnailPlaceholder(),
                        )
                        : _thumbnailPlaceholder(),
              ),
              if (imageUrl != null && imageUrl.isNotEmpty)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumbnailPlaceholder() => Container(
    height: 90,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(8),
    ),
    alignment: Alignment.center,
    child: const Text(
      "No image",
      style: TextStyle(
        color: Colors.black54,
        fontFamily: 'Montserrat',
        fontSize: 11,
      ),
    ),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      fontFamily: 'Montserrat',
      color: Colors.black,
    ),
  );

  Widget buildActionButtons() {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => showConfirmationDialog('Declined'),
            child: const Text(
              "Decline",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B6B28),
              padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => showConfirmationDialog('Approved'),
            child: const Text(
              "Approve",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoText(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Text(
      "$label: ${value ?? 'Not specified'}",
      style: const TextStyle(
        fontSize: 13,
        fontFamily: 'Montserrat',
        color: Colors.black,
      ),
    ),
  );

  void showConfirmationDialog(String action) {
    String? selectedReason;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: const Color(0xFF2D2D2D),
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  title: Text(
                    '${action.toUpperCase()} ADOPTION',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Are you sure you want to $action this adoption request?',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      if (action == 'Declined') ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Reason for decline',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF3A3A3A),
                          value: selectedReason,
                          isExpanded: true,
                          hint: const Text(
                            'Select a reason',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          items:
                              declineReasons
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(
                                        r,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => selectedReason = v),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF3A3A3A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          action == 'Declined' && selectedReason == null
                              ? null
                              : () {
                                Navigator.pop(context);
                                handleApproval(
                                  action,
                                  declineReason: selectedReason,
                                );
                              },
                      child: Text(
                        'Yes',
                        style: TextStyle(
                          color:
                              action == 'Approved' ? Colors.green : Colors.red,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
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

  Widget buildTopHeader({bool showMenuButton = false}) {
    final isMobile = showMenuButton;
    return Container(
      height: isMobile ? 56 : null,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 20,
        vertical: isMobile ? 8 : 15,
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder:
                  (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
            ),
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => Navigator.pop(context),
            )
          else
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text(
                "Back",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Montserrat",
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF666666),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          SizedBox(width: isMobile ? 6 : 12),
          Expanded(
            child: Text(
              'Adoption Details',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 15 : 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          SizedBox(width: isMobile ? 4 : 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ShelterProjectsPage()),
                    ),
                child: Image.asset(
                  'assets/icons/shelterprojects.png',
                  width: isMobile ? 22 : 28,
                  height: isMobile ? 22 : 28,
                ),
              ),
              _NotificationBell(
                iconSize: isMobile ? 22 : 24,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
              SizedBox(width: isMobile ? 4 : 16),
              buildProfileAvatar(context, radius: isMobile ? 14 : 16),
            ],
          ),
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
          ).then((_) => loadProfileImageForAvatar()),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child:
            isLoadingAvatar
                ? SizedBox(
                  width: radius * 1.2,
                  height: radius * 1.2,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                )
                : (cachedProfileImage != null && cachedProfileImage!.isNotEmpty)
                ? ClipOval(
                  child: Image.network(
                    cachedProfileImage!,
                    key: ValueKey(cachedProfileImage),
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

  Widget buildFooter(BuildContext context) => Container(
    height: 40,
    width: double.infinity,
    color: const Color(0xFF181818),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: const Row(
      children: [
        Text(
          "Harvard 2025 Pet Adoption",
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
