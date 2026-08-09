import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';

import 'package:apawtmentweb_admin/dashboardpage.dart';
import 'package:apawtmentweb_admin/donationpage.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/main.dart';

import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> petReports = [];
  List<Map<String, dynamic>> rescues = [];
  List<Map<String, dynamic>> shelters = [];
  String _rescueStatusFilter = 'All';
  String _numberOfPetsFilter = 'All';
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  RealtimeChannel? _reportsChannel;
  RealtimeChannel? _rescuesChannel;
  RealtimeChannel? _sheltersChannel;

  bool isLoadingPetReports = true;
  bool isLoadingRescues = true;

  String selectedItem = 'Report';
  int? selectedShelterId;

  late TabController _tabController;

  final String _reportTypeFilter = 'All';
  String _lostStatusFilter = 'All';
  final String _foundStatusFilter = 'All';
  Timer? _pollTimer;
  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  List<Map<String, dynamic>> get _regularReports =>
      petReports
          .where((r) => (r['type'] ?? '') != 'Lost & Found')
          .where((r) => r['status'] == 'Pending')
          .where((r) {
            if (_reportTypeFilter == 'All') return true;
            return (r['type'] ?? '') == _reportTypeFilter;
          })
          .toList();

  List<Map<String, dynamic>> get _lostReports =>
      petReports
          .where((r) {
            if ((r['type'] ?? '') != 'Lost & Found') return false;
            final sub = (r['sub_type'] ?? '').toString().toLowerCase();
            return sub.isEmpty || sub == 'lost';
          })
          .where((r) {
            if (_lostStatusFilter == 'All') return true;
            return (r['status'] ?? 'Pending') == _lostStatusFilter;
          })
          .toList();

  List<Map<String, dynamic>> get _foundReports =>
      petReports
          .where((r) {
            if ((r['type'] ?? '') != 'Lost & Found') return false;

            final status = (r['status'] ?? '').toString();

            return status == 'Found';
          })
          .where((r) {
            if (_foundStatusFilter == 'All') return true;

            return (r['status'] ?? 'Pending') == _foundStatusFilter;
          })
          .toList();

  List<Map<String, dynamic>> get _filteredRescues =>
      rescues.where((r) {
        if (_rescueStatusFilter == 'All') return true;
        return (r['rescue_status'] ?? '') == _rescueStatusFilter;
      }).toList();
  @override
  void initState() {
    super.initState();
    saveLastVisitedPage('Report');
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _loadPetReports();
    _loadRescues();
    _loadShelters();
    _loadProfileImageForAvatar();

    _setupRealtimeListeners();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _softRefreshAll(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollTimer?.cancel();
    if (_reportsChannel != null) supabase.removeChannel(_reportsChannel!);
    if (_rescuesChannel != null) supabase.removeChannel(_rescuesChannel!);
    if (_sheltersChannel != null) supabase.removeChannel(_sheltersChannel!);
    super.dispose();
  }

  void _setupRealtimeListeners() {
    _setupReportsChannel();
    _setupRescuesChannel();
    _setupSheltersChannel();
  }

  void _setupReportsChannel() {
    if (_reportsChannel != null) {
      supabase.removeChannel(_reportsChannel!);
      _reportsChannel = null;
    }

    _reportsChannel = supabase
        .channel('reports_rt_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reports',
          callback: (payload) {
            if (!mounted) return;
            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                _handleReportInsert(payload.newRecord);
              case PostgresChangeEvent.update:
                _handleReportUpdate(payload.newRecord);
              case PostgresChangeEvent.delete:
                _handleReportDelete(payload.oldRecord);
              case PostgresChangeEvent.all:
                break;
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) debugPrint('❌ Reports channel error: $error');
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Reports channel live');
            _softRefreshReports();
          }
          if (status == RealtimeSubscribeStatus.closed && mounted) {
            Future.delayed(const Duration(seconds: 5), _setupReportsChannel);
          }
        });
  }

  void _handleReportInsert(Map<String, dynamic> record) {
    if (record.isEmpty) return;
    final id = record['reportid'];
    if (id == null) return;
    setState(() {
      if (!petReports.any((r) => r['reportid'].toString() == id.toString())) {
        petReports.insert(0, Map<String, dynamic>.from(record));
      }
    });
    debugPrint('➕ Report inserted: $id');
  }

  void _handleReportUpdate(Map<String, dynamic> updated) {
    if (updated.isEmpty) return;
    final id = updated['reportid'];
    if (id == null) return;

    setState(() {
      final idx = petReports.indexWhere(
        (r) => r['reportid'].toString() == id.toString(),
      );
      if (idx != -1) {
        petReports[idx] = {...petReports[idx], ...updated};
      } else {
        petReports.insert(0, Map<String, dynamic>.from(updated));
      }
    });
    debugPrint('✏️ Report updated: $id → status=${updated['status']}');
  }

  void _handleReportDelete(Map<String, dynamic> oldRecord) {
    if (oldRecord.isEmpty) return;
    final id = oldRecord['reportid'];
    if (id == null) return;

    setState(() {
      petReports.removeWhere((r) => r['reportid'].toString() == id.toString());
    });
    debugPrint('🗑 Report deleted: $id');
  }

  void _setupRescuesChannel() {
    if (_rescuesChannel != null) {
      supabase.removeChannel(_rescuesChannel!);
      _rescuesChannel = null;
    }

    _rescuesChannel = supabase
        .channel('rescues_rt_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rescue',
          callback: (payload) {
            if (!mounted) return;
            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                _handleRescueInsert(payload.newRecord);
              case PostgresChangeEvent.update:
                _handleRescueUpdate(payload.newRecord);
              case PostgresChangeEvent.delete:
                _handleRescueDelete(payload.oldRecord);
              case PostgresChangeEvent.all:
                break;
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) debugPrint('❌ Rescues channel error: $error');
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Rescues channel live');
            _softRefreshRescues();
          }
          if (status == RealtimeSubscribeStatus.closed && mounted) {
            Future.delayed(const Duration(seconds: 5), _setupRescuesChannel);
          }
        });
  }

  void _handleRescueInsert(Map<String, dynamic> record) {
    if (record.isEmpty) return;
    final id = record['rescueid'];
    if (id == null) return;
    setState(() {
      if (!rescues.any((r) => r['rescueid'].toString() == id.toString())) {
        rescues.insert(0, Map<String, dynamic>.from(record));
      }
    });
    debugPrint('➕ Rescue inserted: $id');
  }

  void _handleRescueUpdate(Map<String, dynamic> updated) {
    if (updated.isEmpty) return;
    final id = updated['rescueid'];
    if (id == null) return;

    setState(() {
      final idx = rescues.indexWhere(
        (r) => r['rescueid'].toString() == id.toString(),
      );
      if (idx != -1) {
        rescues[idx] = {...rescues[idx], ...updated};
      } else {
        rescues.insert(0, Map<String, dynamic>.from(updated));
      }
    });
    debugPrint('✏️ Rescue updated: $id → status=${updated['rescue_status']}');
  }

  void _handleRescueDelete(Map<String, dynamic> oldRecord) {
    if (oldRecord.isEmpty) return;
    final id = oldRecord['rescueid'];
    if (id == null) return;

    setState(() {
      rescues.removeWhere((r) => r['rescueid'].toString() == id.toString());
    });
    debugPrint('🗑 Rescue deleted: $id');
  }

  void _setupSheltersChannel() {
    if (_sheltersChannel != null) {
      supabase.removeChannel(_sheltersChannel!);
      _sheltersChannel = null;
    }

    _sheltersChannel = supabase
        .channel('shelters_rt_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shelters',
          callback: (payload) {
            if (!mounted) return;
            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                final s = Map<String, dynamic>.from(payload.newRecord);
                final sid = s['shelter_id'];
                setState(() {
                  if (!shelters.any(
                    (sh) => sh['shelter_id'].toString() == sid.toString(),
                  )) {
                    shelters.add(s);
                  }
                });
                break;
              case PostgresChangeEvent.update:
                final updated = Map<String, dynamic>.from(payload.newRecord);
                final sid = updated['shelter_id'];
                setState(() {
                  final idx = shelters.indexWhere(
                    (sh) => sh['shelter_id'].toString() == sid.toString(),
                  );
                  if (idx != -1) {
                    shelters[idx] = {...shelters[idx], ...updated};
                  } else {
                    shelters.add(updated);
                  }
                });
                break;
              case PostgresChangeEvent.delete:
                final deletedId = payload.oldRecord['shelter_id'];
                if (deletedId != null) {
                  setState(() {
                    shelters.removeWhere(
                      (sh) =>
                          sh['shelter_id'].toString() == deletedId.toString(),
                    );

                    if (selectedShelterId?.toString() == deletedId.toString()) {
                      selectedShelterId = null;
                    }
                  });
                }
                break;
              default:
                break;
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) debugPrint('❌ Shelters channel error: $error');
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

  Future<void> _softRefreshAll() async {
    await Future.wait([_softRefreshReports(), _softRefreshRescues()]);
  }

  Future<void> _softRefreshReports() async {
    if (!mounted) return;
    try {
      final fresh = List<Map<String, dynamic>>.from(
        await supabase
            .from('reports')
            .select('*')
            .order('created_at', ascending: false),
      );
      if (!mounted) return;
      _mergeList(list: petReports, fresh: fresh, idKey: 'reportid');
      setState(() {});
    } catch (e) {
      debugPrint('⚠️ _softRefreshReports: $e');
    }
  }

  Future<void> _softRefreshRescues() async {
    if (!mounted) return;
    try {
      final fresh = List<Map<String, dynamic>>.from(
        await supabase
            .from('rescue')
            .select('*')
            .order('created_at', ascending: false),
      );
      if (!mounted) return;
      _mergeList(list: rescues, fresh: fresh, idKey: 'rescueid');
      setState(() {});
    } catch (e) {
      debugPrint('⚠️ _softRefreshRescues: $e');
    }
  }

  void _mergeList({
    required List<Map<String, dynamic>> list,
    required List<Map<String, dynamic>> fresh,
    required String idKey,
  }) {
    for (final updated in fresh) {
      final id = updated[idKey];
      final idx = list.indexWhere((r) => r[idKey].toString() == id.toString());
      if (idx == -1) {
        list.insert(0, updated);
      } else {
        list[idx] = {...list[idx], ...updated};
      }
    }
    final freshIds = fresh.map((r) => r[idKey].toString()).toSet();
    list.removeWhere((r) => !freshIds.contains(r[idKey].toString()));
  }

  Future<void> _loadShelters() async {
    try {
      final response = await supabase
          .from('shelters')
          .select('shelter_id, name, type');
      if (mounted)
        setState(() => shelters = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('❌ _loadShelters error: $e');
    }
  }

  Future<void> _loadPetReports() async {
    if (!mounted) return;
    try {
      final response = await supabase
          .from('reports')
          .select('*')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        petReports = List<Map<String, dynamic>>.from(response);
        isLoadingPetReports = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoadingPetReports = false);
      debugPrint('❌ _loadPetReports error: $e');
    }
  }

  Future<void> _loadRescues() async {
    if (!mounted) return;
    try {
      final response = await supabase
          .from('rescue')
          .select('*')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        rescues = List<Map<String, dynamic>>.from(response);
        isLoadingRescues = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoadingRescues = false);
      debugPrint('❌ _loadRescues error: $e');
    }
  }

  Future<void> _sendReportNotification({
    required int furparentId,
    required String status,
    required String reportType,
  }) async {
    try {
      await supabase.functions.invoke(
        'report-status-notification',
        body: {
          'furparent_id': furparentId,
          'status': status,
          'report_type': reportType,
        },
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('❌ Failed to send notification [$status]: $e');
    }
  }

  Future<void> _moveToRescue(Map<String, dynamic> report) async {
    try {
      final reportId = report['reportid'];
      if (reportId == null) throw Exception('reportid is null');
      final reportType = (report['type'] ?? '').toString();
      final subType = (report['sub_type'] ?? '').toString();
      final isLostAndFound = reportType == 'Lost & Found';

      String rescueStatus = 'Ongoing';
      if (isLostAndFound) {
        rescueStatus =
            subType.toLowerCase() == 'found' ? 'Found Pet' : 'Lost & Found';
      }

      setState(() {
        final idx = petReports.indexWhere(
          (r) => r['reportid'].toString() == reportId.toString(),
        );
        if (idx != -1)
          petReports[idx] = {...petReports[idx], 'status': 'Approved'};
      });

      await supabase.from('rescue').insert({
        'report_id': reportId,
        'name': report['name'] ?? '',
        'pet_type': report['pet_type'] ?? '',
        'breed': report['breed'] ?? '',
        'color': report['color'] ?? '',
        'sex': report['sex'] ?? '',
        'personality': report['personality'] ?? '',
        'health_status': report['health_status'] ?? '',
        'pet_situation': report['pet_situation'] ?? '',
        'other_details': report['other_details'] ?? '',
        'rescue_date': DateTime.now().toIso8601String().split('T').first,
        'rescue_time': TimeOfDay.now().format(context),
        'rescue_location': report['venue'] ?? 'Unknown',
        'latitude': report['latitude'],
        'longitude': report['longitude'],
        'image_url_1': report['image_url_1'],
        'image_url_2': report['image_url_2'],
        'rescue_status': rescueStatus,
        'reporter_name': report['reporter_name'] ?? '',
        'reporter_number': report['contact_number'] ?? '',
        'sub_type': subType,
      });

      await supabase
          .from('reports')
          .update({'status': 'Approved'})
          .eq('reportid', reportId);

      await logActivity(
        action: 'Approved Report & Moved to Rescue',
        description:
            'Approved report "${report['name'] ?? 'Report'}" and created rescue record ($rescueStatus)',
        entityType: 'Report',
        entityId: reportId is int ? reportId : int.tryParse(reportId.toString()),
      );

      await _sendReportNotification(
        furparentId: report['furparent_id'] ?? 0,
        status: 'approved',
        reportType: reportType,
      );

      try {
        final int? fpId = report['furparent_id'] as int?;
        if (fpId != null) {
          await supabase.from('user_notifications').insert({
            'furparent_id': fpId,
            'type': 'report',
            'screen': 'report_approved',
            'title': 'Report Approved ✅',
            'body':
                'Your ${reportType.isNotEmpty ? reportType : 'report'} '
                'has been reviewed and approved by the admin.',
            'read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('⚠️ Report approved notification error: $e');
      }

      if (context.mounted) {
        _showSnackBar(
          'Report approved → moved to Rescue ($rescueStatus).',
          Colors.green,
        );

        _softRefreshRescues();
      }
    } catch (e) {
      _softRefreshReports();
      if (context.mounted) {
        _showSnackBar('Failed to approve report.', Colors.red);
      }
    }
  }

  Future<void> _moveToMedication(
    Map<String, dynamic> rescue,
    int shelterId,
  ) async {
    setState(() {
      rescues.removeWhere(
        (r) => r['rescueid'].toString() == rescue['rescueid'].toString(),
      );
    });

    try {
      int? petId = rescue['pet_id'];
      if (petId == null) {
        final insertedPet =
            await supabase
                .from('pets')
                .insert({
                  'name': rescue['name'],
                  'type': rescue['pet_type'],
                  'breed': rescue['breed'],
                  'color': rescue['color'],
                  'sex': rescue['sex'],
                  'personality': rescue['personality'],
                  'health_status': rescue['health_status'],
                  'shelter_id': shelterId,
                  'description': rescue['other_details'] ?? 'No description.',
                  'image_url_1': rescue['image_url_1'],
                  'status': 'Under Medication',
                  'created_at': DateTime.now().toIso8601String(),
                })
                .select()
                .single();
        petId = insertedPet['pet_id'];
      } else {
        await supabase
            .from('pets')
            .update({
              'status': 'Under Medication',
              'shelter_id': shelterId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('pet_id', petId);
      }

      await supabase.from('rescue').delete().eq('rescueid', rescue['rescueid']);

      await supabase.from('pet_medications').insert({
        'pet_id': petId,
        'shelter_id': shelterId,
        'name': rescue['name'] ?? '',
        'type': rescue['pet_type'] ?? '',
        'breed': rescue['breed'] ?? '',
        'age': rescue['age'] ?? '',
        'sex': rescue['sex'] ?? '',
        'color': rescue['color'] ?? '',
        'status': 'Under Medication',
        'image_url_1': rescue['image_url_1'] ?? '',
        'description': rescue['other_details'] ?? '',
        'energy': rescue['energy'] ?? 'Low',
        'vaccination_status': rescue['vaccination_status'] ?? 'Not Vaccinated',
        'neutered_spayed_details':
            rescue['neutered_spayed_details'] ?? 'Not Neutered/Spayed',
        'deworming_status': rescue['deworming_status'] ?? 'Not Dewormed',
        'created_at': DateTime.now().toIso8601String(),
      });

      final shelterObj = shelters.firstWhere(
        (s) => s['shelter_id'].toString() == shelterId.toString(),
        orElse: () => <String, dynamic>{},
      );
      final shelterName = shelterObj['name'] ?? 'Shelter $shelterId';

      await supabase.from('notifications').insert({
        'title': 'Pet Moved to Medication',
        'message':
            '${rescue['name'] ?? 'A pet'} has been moved to medication in $shelterName.',
        'pet_id': petId,
        'created_at': DateTime.now().toIso8601String(),
      });

      await logActivity(
        action: 'Moved Rescue to Medication',
        description:
            'Moved rescued pet ${rescue['name'] ?? ''} to medication in $shelterName',
        entityType: 'Pet Rescue',
        entityId: petId,
      );

      if (context.mounted) {
        _showSnackBar(
          '✅ Rescue moved to Medication in $shelterName successfully.',
          Colors.green,
        );
      }
    } catch (e) {
      _softRefreshRescues();
      if (context.mounted) {
        _showSnackBar('Failed to move rescue.', Colors.red);
      }
    }
  }

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _declineReport(Map<String, dynamic> report) async {
    try {
      setState(() {
        final idx = petReports.indexWhere(
          (r) => r['reportid'].toString() == report['reportid'].toString(),
        );
        if (idx != -1)
          petReports[idx] = {...petReports[idx], 'status': 'Declined'};
      });

      await supabase
          .from('reports')
          .update({'status': 'Declined'})
          .eq('reportid', report['reportid']);

      final rId = report['reportid'];
      await logActivity(
        action: 'Declined Report',
        description: 'Declined report "${report['name'] ?? 'Report'}"',
        entityType: 'Report',
        entityId: rId is int ? rId : int.tryParse(rId.toString()),
      );

      await _sendReportNotification(
        furparentId: report['reporter_id'] ?? 0,
        status: 'Declined',
        reportType: report['type'] ?? 'pet',
      );

      if (context.mounted) {
        Navigator.pop(context);

        _showSnackBar('Report declined.', Colors.red);
      }
    } catch (e) {
      _softRefreshReports();
      debugPrint('❌ Decline error: $e');
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
                _buildTopHeader(_isMobile),

                _buildWorkflowTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPendingReportsTab(),

                      _buildRescueTab(),

                      _buildLostPetsTab(),

                      _buildFoundPetsTab(),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowTabBar() {
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
              dropdownColor: const Color(0xFF2A2A2A),
              value: _tabController.index,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              items: [
                DropdownMenuItem<int>(
                  value: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Incident Reports'),
                      if (_regularReports.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_regularReports.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rescue'),
                      if (rescues.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${rescues.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lost'),
                      if (_lostReports.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_lostReports.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Found'),
                      if (_foundReports.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_foundReports.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _tabController.animateTo(val);
                  });
                }
              },
            ),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFF181818),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
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
            tabs: [
              _tabWithBadge(
                'Incident Reports',
                _regularReports.length,
                Colors.orange,
              ),
              _tabWithBadge('Rescue', rescues.length, Colors.orange),
              _tabWithBadge('Lost', _lostReports.length, Colors.orange),
              _tabWithBadge('Found', _foundReports.length, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pipelineStep(int index, IconData icon, String label, Color color) {
    final active = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? color : Colors.white38),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                color: active ? color : Colors.white38,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pipelineArrow() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Icon(Icons.chevron_right, color: Colors.white24, size: 16),
  );

  Tab _tabWithBadge(String label, int count, Color color) {
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
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingReportsTab() {
    final filtered =
        _numberOfPetsFilter == 'All'
            ? _regularReports
            : _regularReports
                .where(
                  (r) =>
                      (r['number_of_petreport'] ?? 'Individual').toString() ==
                      _numberOfPetsFilter,
                )
                .toList();

    return Column(
      children: [
        Container(
          color: const Color(0xFF181818),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Number of Pets:',
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _numberOfPetsFilter,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white54,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(
                        value: 'By Batch',
                        child: Text('By Batch'),
                      ),
                      DropdownMenuItem(
                        value: 'Individual',
                        child: Text('Individual'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _numberOfPetsFilter = v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildReportList(
            isLoading: isLoadingPetReports,
            reports: filtered,
            emptyLabel: 'No pending reports',
          ),
        ),
      ],
    );
  }

  Widget _buildRescueTab() {
    return Column(
      children: [
        _filterChipRow(
          selected: _rescueStatusFilter,
          options: const [
            'All',
            'Ongoing',
            'Found Pet',
            'Lost Pet',
            'Completed',
          ],
          colors: {
            'All': Colors.brown,
            'Ongoing': Colors.orange,
            'Found Pet': Colors.orange,
            'Lost & Found': Colors.orange,
            'Completed': Colors.green,
          },
          icons: {
            'All': Icons.list,
            'Ongoing': Icons.local_hospital,
            'Found Pet': Icons.pets,
            'Lost & Found': Icons.search,
            'Completed': Icons.check_circle_outline,
          },
          onSelected: (v) => setState(() => _rescueStatusFilter = v),
        ),

        _rescueSummaryStrip(),
        Expanded(
          child:
              isLoadingRescues
                  ? Center(
                      child: LoadingAnimationWidget.fallingDot(
                        color: Colors.orange,
                        size: 50,
                      ),
                    )
                  : _filteredRescues.isEmpty
                  ? _emptyState('No rescue records for "$_rescueStatusFilter"')
                  : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredRescues.length,
                    itemBuilder: (_, i) => rescueCard(_filteredRescues[i]),
                  ),
        ),
      ],
    );
  }

  Widget _rescueSummaryStrip() {
    final ongoing =
        rescues.where((r) => (r['rescue_status'] ?? '') == 'Ongoing').length;
    final lostFound =
        rescues
            .where((r) => (r['rescue_status'] ?? '') == 'Lost & Found')
            .length;
    final found =
        rescues.where((r) => (r['rescue_status'] ?? '') == 'Found Pet').length;
    final completed =
        rescues.where((r) => (r['rescue_status'] ?? '') == 'Completed').length;
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _summaryChip('Ongoing', ongoing, Colors.orange),
            const SizedBox(width: 8),
            _summaryChip('Lost & Found', lostFound, Colors.orange),
            const SizedBox(width: 8),
            _summaryChip('Found Pet', found, Colors.orange),
            const SizedBox(width: 8),
            _summaryChip('Completed', completed, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
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
          Text(
            '$label  ',
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontFamily: 'Montserrat',
              fontSize: 11,
            ),
          ),
          Text(
            '$count',
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

  Widget _markAsFoundButton(Map<String, dynamic> report) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.check_circle_outline, size: 15),
      label: const Text(
        'Mark as Found',
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () => _confirmAndMarkAsFound(report),
    );
  }

  Future<void> _confirmAndMarkAsFound(Map<String, dynamic> report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Mark as Found?',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'This will move "${report['name'] ?? 'this pet'}" to the Found tab '
              'and notify the reporter.',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
                fontSize: 13,
              ),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Yes, Mark as Found',
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    await _markAsFound(report);
  }

  Future<void> _markAsFound(Map<String, dynamic> report) async {
    final id = report['reportid'];
    if (id == null) return;

    setState(() {
      final idx = petReports.indexWhere(
        (r) => r['reportid'].toString() == id.toString(),
      );
      if (idx != -1) {
        petReports[idx] = {
          ...petReports[idx],
          'status': 'Found',
          'sub_type': 'found',
          'updated_at': DateTime.now().toIso8601String(),
        };
      }
    });

    try {
      await supabase
          .from('reports')
          .update({
            'status': 'Found',
            'sub_type': 'found',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('reportid', id);

      await logActivity(
        action: 'Marked Lost Pet as Found',
        description: 'Marked lost pet "${report['name'] ?? 'Pet'}" as Found',
        entityType: 'Lost Pet Report',
        entityId: id,
      );

      try {
        final int? fpId = report['furparent_id'] as int?;
        if (fpId != null) {
          await supabase.from('user_notifications').insert({
            'furparent_id': fpId,
            'type': 'lost_found_status',
            'screen': 'LostAndFoundPage',
            'title': '🎉 Your pet has been found!',
            'body':
                '"${report['name'] ?? 'Your pet'}" has been marked as found by the shelter. '
                'Please contact us to arrange pickup.',
            'read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('⚠️ Mark as Found notification error: $e');
      }

      if (mounted) {
        _showSnackBar(
          '${report['name'] ?? 'Pet'} marked as Found 🎉',
          Colors.green,
        );
      }
    } catch (e) {
      _softRefreshReports();
      debugPrint('Mark as Found error: $e');
      if (mounted) {
        _showSnackBar('Failed to mark lost pets as Found.', Colors.red);
      }
    }
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

  Widget _buildLostPetsTab() {
    return Column(
      children: [
        _filterChipRow(
          selected: _lostStatusFilter,
          options: const ['All', 'Pending', 'Approved', 'Declined'],
          colors: {
            'All': Colors.brown,
            'Pending': Colors.orange,
            'Approved': Colors.green,
            'Declined': Colors.red,
          },
          icons: {
            'All': Icons.list,
            'Pending': Icons.hourglass_top,
            'Approved': Icons.check_circle_outline,
            'Declined': Icons.cancel_outlined,
          },
          onSelected: (v) => setState(() => _lostStatusFilter = v),
        ),
        Expanded(
          child: _buildReportList(
            isLoading: isLoadingPetReports,
            reports: _lostReports,
            emptyLabel: 'No lost pet reports',
            accentColor: Colors.orange,

            extraAction:
                (report) =>
                    (report['status'] ?? '') == 'Approved'
                        ? _markAsFoundButton(report)
                        : null,
          ),
        ),
      ],
    );
  }

  Widget _buildFoundPetsTab() {
    return Column(
      children: [
        Expanded(
          child: _buildReportList(
            isLoading: isLoadingPetReports,
            reports: _foundReports,
            emptyLabel: 'No found pet reports',
            accentColor: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildReportList({
    required bool isLoading,
    required List<Map<String, dynamic>> reports,
    required String emptyLabel,
    Color accentColor = Colors.orange,
    Widget? Function(Map<String, dynamic>)? extraAction,
  }) {
    if (isLoading) {
      return Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 50,
        ),
      );
    }
    if (reports.isEmpty) return _emptyState(emptyLabel);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reports.length,
      itemBuilder:
          (_, i) => _reportCard(
            report: reports[i],
            accentColor: accentColor,
            onCheck: () => _showReportDetails(reports[i]),
            extraAction: extraAction?.call(reports[i]),
          ),
    );
  }

  Widget _emptyState(String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, color: Colors.white24, size: 52),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontFamily: 'Montserrat',
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChipRow({
    required String selected,
    required List<String> options,
    required Map<String, Color> colors,
    required Map<String, IconData> icons,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      color: const Color(0xFF181818),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              options.map((opt) {
                final isSelected = selected == opt;
                final color = colors[opt] ?? Colors.orange;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onSelected(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? color : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? color : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[opt] ?? Icons.list,
                            size: 13,
                            color: isSelected ? Colors.white : Colors.white54,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            opt,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _reportCard({
    required Map<String, dynamic> report,
    required VoidCallback onCheck,
    Color accentColor = Colors.orange,
    Widget? extraAction,
  }) {
    final type = (report['type'] ?? '').toString();
    final subType = (report['sub_type'] ?? '').toString();

    Color badgeColor = accentColor;
    String badgeLabel = type;
    if (type == 'Lost & Found') {
      if (subType.toLowerCase() == 'found') {
        badgeColor = Colors.orange;
        badgeLabel = 'Found Pet';
      } else {
        badgeColor = Colors.orange;
        badgeLabel = 'Lost Pet';
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withOpacity(0.2)),
          ),
          child:
              isMobile
                  ? _mobileReportCardContent(
                    report,
                    badgeLabel,
                    badgeColor,
                    onCheck,
                    extraAction: extraAction,
                  )
                  : _desktopReportCardContent(
                    report,
                    badgeLabel,
                    badgeColor,
                    onCheck,
                    extraAction: extraAction,
                  ),
        );
      },
    );
  }

  Widget _desktopReportCardContent(
    Map<String, dynamic> report,
    String badgeLabel,
    Color badgeColor,
    VoidCallback onCheck, {
    Widget? extraAction,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: badgeColor.withOpacity(0.2),
          child: Icon(
            badgeLabel == 'Lost Pet'
                ? Icons.search
                : badgeLabel == 'Found Pet'
                ? Icons.pets
                : Icons.report_outlined,
            color: badgeColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      report['reporter_name'] ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _badge(badgeLabel, badgeColor),
                  const SizedBox(width: 6),
                  _statusBadge(report['status'] ?? 'Pending'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${report['date_seen'] ?? report['created_at'] ?? 'N/A'}  •  ${report['venue'] ?? report['pickup_address'] ?? 'N/A'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: onCheck,
              style: ElevatedButton.styleFrom(
                backgroundColor: badgeColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Check',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
            if (extraAction != null) ...[
              const SizedBox(height: 6),
              extraAction,
            ],
          ],
        ),
      ],
    );
  }

  Widget _mobileReportCardContent(
    Map<String, dynamic> report,
    String badgeLabel,
    Color badgeColor,
    VoidCallback onCheck, {
    Widget? extraAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: badgeColor.withOpacity(0.2),
              child: Icon(
                badgeLabel == 'Lost Pet' ? Icons.search : Icons.pets,
                color: badgeColor,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report['reporter_name'] ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    children: [
                      _badge(badgeLabel, badgeColor),
                      _statusBadge(report['status'] ?? 'Pending'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onCheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: badgeColor,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Check',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ),

        if (extraAction != null) ...[
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, child: extraAction),
        ],
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;
      case 'declined':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> report) {
    final subType = (report['sub_type'] ?? '').toString();
    final isLost =
        subType.toLowerCase() == 'lost' ||
        (report['type'] == 'Lost & Found' && subType.isEmpty);
    final isFound = subType.toLowerCase() == 'found';
    final status = (report['status'] ?? 'Pending').toString();

    Color accent = Colors.orange;
    if (isLost) accent = Colors.orange;
    if (isFound) accent = Colors.orange;

    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: const Color(0xFF2A2A2A),
            insetPadding: EdgeInsets.symmetric(
              horizontal: _isMobile ? 12 : 20,
              vertical: _isMobile ? 24 : 40,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight:
                    _isMobile ? MediaQuery.of(context).size.height * 0.9 : 720,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(_isMobile ? 16 : 20),
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
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Report Details',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                    Text(
                                      report['reporter_name'] ?? 'Unknown',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _statusBadge(status),
                              if (subType.isNotEmpty)
                                _badge(subType, Colors.white38),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (status == 'Pending')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: accent.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: accent,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isLost
                                          ? 'Lost pet report — approve to move to Lost & Found rescue queue.'
                                          : isFound
                                          ? 'Found pet report — approve to move to Found Pet rescue queue.'
                                          : 'Approve this report to move it to the Rescue pipeline.',
                                      style: TextStyle(
                                        color: accent,
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),

                          _sectionHeader('Reporter Information'),
                          _infoRow('Name', report['reporter_name'] ?? 'N/A'),
                          _infoRow(
                            'Contact',
                            report['contact_number'] ?? 'N/A',
                          ),
                          _infoRow('Email', report['reporter_email'] ?? 'N/A'),
                          const SizedBox(height: 14),

                          _imageRow(
                            report['image_url_1']?.toString(),
                            report['image_url_2']?.toString(),
                          ),

                          ..._petFields(report, accent),
                        ],
                      ),
                    ),
                  ),

                  if (status == 'Pending')
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isMobile ? 14 : 20,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _declineReport(report),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Decline',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _approveReport(report);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Approve',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
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
          ),
    );
  }

  Future<void> _approveReport(Map<String, dynamic> report) async {
    try {
      final id = report['reportid'];

      await supabase
          .from('reports')
          .update({
            'status': 'Approved',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('reportid', id);

      await _loadPetReports();

      if (mounted) {
        // Replace success snackbar:
        _showSnackBar('Report approved successfully', Colors.green);
      }
    } catch (e) {
      debugPrint('Approve error: $e');
    }
  }

  Widget _imageRow(String? url1, String? url2) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child:
          _isMobile
              ? Column(
                children: [
                  if (url1 != null) _netImage(url1),
                  if (url2 != null) ...[
                    const SizedBox(height: 8),
                    _netImage(url2),
                  ],
                ],
              )
              : Row(
                children: [
                  if (url1 != null) Expanded(child: _netImage(url1)),
                  if (url2 != null) ...[
                    const SizedBox(width: 10),
                    Expanded(child: _netImage(url2)),
                  ],
                ],
              ),
    );
  }

  Widget _netImage(String url) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.network(
      url,
      height: 140,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) => Container(
            height: 140,
            color: Colors.grey[800],
            child: const Icon(Icons.broken_image, color: Colors.white54),
          ),
    ),
  );

  List<Widget> _petFields(Map<String, dynamic> r, Color accent) => [
    _sectionHeader('Report Information'),
    _infoRow('Type', r['type'] ?? 'N/A'),
    _infoRow('No. of Pets', r['number_of_petreport'] ?? 'N/A'),
    if (r['sub_type'] != null) _infoRow('Sub-type', r['sub_type']),
    if (r['pet_situation'] != null) _infoRow('Situation', r['pet_situation']),
    const SizedBox(height: 14),
    _sectionHeader('Pet Information'),
    _infoRow('Pet Type', r['pet_type'] ?? 'N/A'),
    _infoRow('Name', r['name'] ?? 'N/A'),
    _infoRow('Breed', r['breed'] ?? 'N/A'),
    _infoRow('Color', r['color'] ?? 'N/A'),
    _infoRow('Sex', r['sex'] ?? 'N/A'),
    _infoRow('Age', r['age'] ?? 'N/A'),
    _infoRow('Personality', r['personality'] ?? 'N/A'),
    _infoRow('Health', r['health_status'] ?? 'N/A'),
    _infoRow('Other Details', r['other_details'] ?? 'N/A'),
    const SizedBox(height: 14),
    _sectionHeader('Last Seen'),
    _infoRow('Date', r['date_seen'] ?? 'N/A'),
    _infoRow('Time', r['time_seen'] ?? 'N/A'),
    _infoRow('Venue', r['venue'] ?? 'N/A'),
    if (r['latitude'] != null && r['longitude'] != null) ...[
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _openInGoogleMaps(r['latitude'], r['longitude']),
          icon: const Icon(Icons.map, size: 16),
          label: const Text(
            'Open in Google Maps',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ],
  ];

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.orangeAccent,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'Montserrat',
      ),
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
      ],
    ),
  );

  Widget rescueCard(Map<String, dynamic> rescue) {
    final rStatus = (rescue['rescue_status'] ?? 'Ongoing').toString();
    Color statusColor = Colors.orange;
    if (rStatus == 'Found Pet') statusColor = Colors.orange;
    if (rStatus == 'Lost Pet') statusColor = Colors.orange;
    if (rStatus == 'Completed') statusColor = Colors.green;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Card(
          color: const Color(0xFF232323),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: statusColor.withOpacity(0.25)),
          ),
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child:
                isMobile
                    ? _mobileRescueLayout(rescue, statusColor)
                    : _desktopRescueLayout(rescue, statusColor),
          ),
        );
      },
    );
  }

  Widget _desktopRescueLayout(Map<String, dynamic> rescue, Color statusColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            rescue['image_url_1'] ?? '',
            width: 70,
            height: 70,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageFallback(70),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rescue['name'] ?? 'Unnamed Pet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${rescue['pet_type'] ?? '?'} • ${rescue['breed'] ?? '?'}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 4),
              _badge(rescue['rescue_status'] ?? 'Ongoing', statusColor),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _viewButton(rescue),
      ],
    );
  }

  Widget _mobileRescueLayout(Map<String, dynamic> rescue, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            rescue['image_url_1'] ?? '',
            width: double.infinity,
            height: 130,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageFallback(130),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          rescue['name'] ?? 'Unnamed',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
        const SizedBox(height: 4),
        _badge(rescue['rescue_status'] ?? 'Ongoing', statusColor),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: _viewButton(rescue)),
      ],
    );
  }

  Widget _viewButton(Map<String, dynamic> rescue) {
    return ElevatedButton(
      onPressed: () => _viewRescueDetails(rescue),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB74D),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'View Details',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamily: 'Montserrat',
        ),
      ),
    );
  }

  Widget _imageFallback(double size) => Container(
    width: size,
    height: size,
    color: Colors.grey[800],
    child: const Icon(Icons.pets, color: Colors.white38, size: 32),
  );

  void _viewRescueDetails(Map<String, dynamic> rescue) {
    selectedShelterId = null;
    String formattedTime = 'N/A';
    try {
      if (rescue['rescue_time'] != null &&
          rescue['rescue_time'].toString().isNotEmpty) {
        formattedTime = DateFormat(
          "hh:mm a",
        ).format(DateFormat("HH:mm:ss").parse(rescue['rescue_time']));
      }
    } catch (_) {
      formattedTime = rescue['rescue_time'] ?? 'N/A';
    }

    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: const Color(0xFF2A2A2A),
            insetPadding: EdgeInsets.symmetric(
              horizontal: _isMobile ? 12 : 20,
              vertical: _isMobile ? 24 : 40,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight:
                    _isMobile ? MediaQuery.of(context).size.height * 0.9 : 720,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(_isMobile ? 16 : 20),
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
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Rescue Details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if ((rescue['rescue_status'] ?? '').toString() == 'Ongoing') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.local_hospital,
                                    color: Colors.blue,
                                    size: 14,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Select a shelter to move to Medication.',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontFamily: 'Montserrat',
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _imageRow(
                            rescue['image_url_1'],
                            rescue['image_url_2'],
                          ),
                          _sectionHeader('Rescue Information'),
                          _infoRow('Status', rescue['rescue_status'] ?? 'N/A'),
                          _infoRow('Date', rescue['rescue_date'] ?? 'N/A'),
                          _infoRow('Time', formattedTime),
                          _infoRow(
                            'Location',
                            rescue['rescue_location'] ?? 'N/A',
                          ),
                          const SizedBox(height: 14),
                          _sectionHeader('Pet Information'),
                          _infoRow('Type', rescue['pet_type'] ?? 'N/A'),
                          _infoRow('Name', rescue['name'] ?? 'N/A'),
                          _infoRow('Breed', rescue['breed'] ?? 'N/A'),
                          _infoRow('Color', rescue['color'] ?? 'N/A'),
                          _infoRow('Sex', rescue['sex'] ?? 'N/A'),
                          _infoRow(
                            'Personality',
                            rescue['personality'] ?? 'N/A',
                          ),
                          _infoRow('Health', rescue['health_status'] ?? 'N/A'),
                          _infoRow(
                            'Situation',
                            rescue['pet_situation'] ?? 'N/A',
                          ),
                          _infoRow(
                            'Other Details',
                            rescue['other_details'] ?? 'N/A',
                          ),
                          _infoRow(
                            'Reporter',
                            rescue['reporter_name'] ?? 'N/A',
                          ),
                          _infoRow(
                            'Contact',
                            rescue['reporter_number'] ?? 'N/A',
                          ),
                          if (rescue['latitude'] != null &&
                              rescue['longitude'] != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    () => _openInGoogleMaps(
                                      rescue['latitude'],
                                      rescue['longitude'],
                                    ),
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text(
                                  'Open in Google Maps',
                                  style: TextStyle(fontFamily: 'Montserrat'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isMobile ? 14 : 20,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(14),
                      ),
                    ),
                    child: StatefulBuilder(
                      builder: (context, setLocal) {
                        final rescueStatus =
                            (rescue['rescue_status'] ?? '').toString();
                        if (rescueStatus != 'Ongoing') {
                          return const SizedBox.shrink();
                        }

                        final reportId = rescue['report_id'];
                        final sourceReport =
                            reportId != null
                                ? petReports.firstWhere(
                                  (r) =>
                                      r['reportid'].toString() ==
                                      reportId.toString(),
                                  orElse: () => {},
                                )
                                : <String, dynamic>{};
                        final isByBatch =
                            (sourceReport['number_of_petreport'] ?? '')
                                .toString() ==
                            'By Batch';

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isByBatch) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange,
                                      size: 15,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'This is a By Batch rescue — individual '
                                        'medication assignment is not available.',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              DropdownButtonFormField<int>(
                                value: selectedShelterId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Select Shelter to Proceed',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                dropdownColor: const Color(0xFF2A2A2A),
                                items: () {
                                  final petType =
                                      (rescue['pet_type'] ?? '')
                                          .toString()
                                          .trim()
                                          .toLowerCase();
                                  final filtered =
                                      shelters.where((s) {
                                        final shelterType =
                                            (s['type'] ?? '')
                                                .toString()
                                                .trim()
                                                .toLowerCase();
                                        if (petType.contains('dog'))
                                          return shelterType.contains('dog');
                                        if (petType.contains('cat'))
                                          return shelterType.contains('cat');
                                        return true;
                                      }).toList();

                                  if (selectedShelterId != null &&
                                      !filtered.any((s) => s['shelter_id'] == selectedShelterId)) {
                                    selectedShelterId = null;
                                  }

                                  return filtered
                                      .map(
                                        (s) => DropdownMenuItem<int>(
                                          value: s['shelter_id'],
                                          child: Text(
                                            '${s['name']}${s['type'] != null ? ' (${s['type']})' : ''}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Montserrat',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList();
                                }(),
                                onChanged:
                                    (v) =>
                                        setLocal(() => selectedShelterId = v),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.medication_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Move to Medication',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed:
                                      selectedShelterId == null
                                          ? null
                                          : () async {
                                            Navigator.pop(context);
                                            await _moveToMedication(
                                              rescue,
                                              selectedShelterId!,
                                            );
                                          },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
              'Reports',
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
                  if (context.mounted)
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnimatedAdminLoginPage(),
                      ),
                      (r) => false,
                    );
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
              callback: (p) {
                if (mounted)
                  setState(() => _notifications.insert(0, p.newRecord));
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'notifications',
              callback: (p) {
                final id = p.oldRecord['notification_id'];
                if (id != null && mounted)
                  setState(
                    () => _notifications.removeWhere(
                      (n) => n['notification_id'] == id,
                    ),
                  );
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
      final r = await supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      if (mounted)
        setState(() => _notifications = List<Map<String, dynamic>>.from(r));
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
    } catch (_) {
      await _loadNotifications();
    }
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

  void _openPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _NotificationPanel(
            notifications: List.from(_notifications),
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
  final Future<void> Function(int) onDelete;
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

  IconData _iconFor(String? t) {
    switch (t) {
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

  Color _colorFor(String? t) {
    switch (t) {
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
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
                        final n = _items[index];
                        final id = n['notification_id'] as int?;
                        final color = _colorFor(n['type'] as String?);
                        return Dismissible(
                          key: ValueKey('n_${id}_$index'),
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
                                _iconFor(n['type'] as String?),
                                color: color,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              n['title'] as String? ?? 'Notification',
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
                                if ((n['message'] as String? ?? '').isNotEmpty)
                                  Text(
                                    n['message'] as String,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontFamily: 'Montserrat',
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(
                                  widget.timeAgo(n['created_at'] as String?),
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
