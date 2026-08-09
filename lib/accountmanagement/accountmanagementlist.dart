import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:apawtmentweb_admin/accountmanagement/accountmanagementpage.dart';
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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountManagementListPage extends StatefulWidget {
  const AccountManagementListPage({super.key});

  @override
  State<AccountManagementListPage> createState() =>
      _AccountManagementListPageState();
}

class _AccountManagementListPageState extends State<AccountManagementListPage> {
  final supabase = Supabase.instance.client;
  String selectedSuffix = '';
  final _formKey = GlobalKey<FormState>();
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  bool isRealtimeConnected = false;
  late final int vetId;
  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;
  List<Map<String, dynamic>> _vetApplications = [];
  bool _isLoadingVetApps = false;
  int _activeTab = 0;
  String _selectedItem = 'Account Management';
  List<Map<String, dynamic>> _archivedAccounts = [];
  bool _isLoadingArchived = false;

  late final String _subadminChannelName;
  late final String _profileChannelName;
  int _archivedSubTab = 0;
  RealtimeChannel? _subadminChannel;
  RealtimeChannel? _profileChannel;
  List<Map<String, dynamic>> _archivedVetApplications = [];
  bool _isLoadingArchivedVets = false;
  Timer? _reconnectTimer;
  List<Map<String, dynamic>> _veterinarians = [];
  final bool _isLoadingVets = false;
  Timer? _pollTimer;
  RealtimeChannel? _veterinariansChannel;
  RealtimeChannel? _vetApplicationsChannel;

  @override
  void initState() {
    super.initState();
    saveLastVisitedPage('Account Management');

    final ts = DateTime.now().millisecondsSinceEpoch;
    _subadminChannelName = 'subadmin_status_$ts';
    _profileChannelName = 'admin_profile_$ts';

    _loadProfileImageForAvatar();
    _fetchData();
    _fetchVetApplications();

    _setupSubadminChannel();
    _setupProfileChannel();
    _setupVeterinariansChannel();
    _setupVetApplicationsChannel();

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) _softRefresh();
    });

    _pollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _softRefresh(),
    );
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    if (_subadminChannel != null) supabase.removeChannel(_subadminChannel!);
    if (_profileChannel != null) supabase.removeChannel(_profileChannel!);
    if (_veterinariansChannel != null)
      supabase.removeChannel(_veterinariansChannel!);
    if (_vetApplicationsChannel != null)
      supabase.removeChannel(_vetApplicationsChannel!);
    super.dispose();
  }

  void _setupVeterinariansChannel() {
    if (_veterinariansChannel != null) {
      supabase.removeChannel(_veterinariansChannel!);
      _veterinariansChannel = null;
    }

    _veterinariansChannel = supabase
        .channel('veterinarians_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          schema: 'public',
          table: 'veterinarians',
          event: PostgresChangeEvent.all,
          callback: (payload) {
            if (!mounted) return;

            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                final newVet = Map<String, dynamic>.from(payload.newRecord);
                final id = newVet['vet_id'];
                setState(() {
                  if (!_veterinarians.any(
                    (v) => v['vet_id'].toString() == id.toString(),
                  )) {
                    _veterinarians.insert(0, newVet);
                  }
                });
                break;

              case PostgresChangeEvent.update:
                final updated = Map<String, dynamic>.from(payload.newRecord);
                final id = updated['vet_id'];
                setState(() {
                  final idx = _veterinarians.indexWhere(
                    (v) => v['vet_id'].toString() == id.toString(),
                  );
                  if (idx != -1) {
                    _veterinarians[idx] = {..._veterinarians[idx], ...updated};
                  } else {
                    _veterinarians.insert(0, updated);
                  }
                });
                break;

              case PostgresChangeEvent.delete:
                final deletedId = payload.oldRecord['vet_id'];
                if (deletedId != null) {
                  setState(
                    () => _veterinarians.removeWhere(
                      (v) => v['vet_id'].toString() == deletedId.toString(),
                    ),
                  );
                }
                break;

              default:
                break;
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) debugPrint('❌ Vets channel error: $error');
        });
  }

  void _setupVetApplicationsChannel() {
    if (_vetApplicationsChannel != null) {
      supabase.removeChannel(_vetApplicationsChannel!);
      _vetApplicationsChannel = null;
    }

    _vetApplicationsChannel = supabase
        .channel('vet_applications_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          schema: 'public',
          table: 'vet_applications',
          event: PostgresChangeEvent.all,
          callback: (payload) {
            if (!mounted) return;

            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                _handleVetAppInsert(payload.newRecord);
                break;
              case PostgresChangeEvent.update:
                _handleVetAppUpdate(payload.newRecord);
                break;
              case PostgresChangeEvent.delete:
                _handleVetAppDelete(payload.oldRecord);
                break;
              default:
                break;
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) debugPrint('❌ Vet apps channel error: $error');
        });
  }

  void _handleVetAppInsert(Map<String, dynamic> record) {
    if (record.isEmpty) return;
    final id = record['application_id'];
    if (id == null) return;
    final idStr = id.toString();

    setState(() {
      if (record['is_archived'] == true) {
        if (!_archivedVetApplications.any(
          (a) => a['application_id'].toString() == idStr,
        )) {
          _archivedVetApplications.insert(0, Map<String, dynamic>.from(record));
        }
      } else {
        if (!_vetApplications.any(
          (a) => a['application_id'].toString() == idStr,
        )) {
          _vetApplications.insert(0, Map<String, dynamic>.from(record));
        }
      }
    });
  }

  void _handleVetAppUpdate(Map<String, dynamic> updated) {
    if (updated.isEmpty) return;
    final id = updated['application_id'];
    if (id == null) return;
    final idStr = id.toString();
    final isArchived = updated['is_archived'] == true;

    setState(() {
      if (isArchived) {
        _vetApplications.removeWhere(
          (a) => a['application_id'].toString() == idStr,
        );
        final archivedIdx = _archivedVetApplications.indexWhere(
          (a) => a['application_id'].toString() == idStr,
        );
        if (archivedIdx == -1) {
          _archivedVetApplications.insert(
            0,
            Map<String, dynamic>.from(updated),
          );
        } else {
          _archivedVetApplications[archivedIdx] = {
            ..._archivedVetApplications[archivedIdx],
            ...updated,
          };
        }
      } else {
        _archivedVetApplications.removeWhere(
          (a) => a['application_id'].toString() == idStr,
        );
        final activeIdx = _vetApplications.indexWhere(
          (a) => a['application_id'].toString() == idStr,
        );
        if (activeIdx == -1) {
          _vetApplications.insert(0, Map<String, dynamic>.from(updated));
        } else {
          _vetApplications[activeIdx] = {
            ..._vetApplications[activeIdx],
            ...updated,
          };
        }
      }
    });
  }

  void _handleVetAppDelete(Map<String, dynamic> oldRecord) {
    if (oldRecord.isEmpty) return;
    final id = oldRecord['application_id'];
    if (id == null) return;
    final idStr = id.toString();

    setState(() {
      _vetApplications.removeWhere(
        (a) => a['application_id'].toString() == idStr,
      );
      _archivedVetApplications.removeWhere(
        (a) => a['application_id'].toString() == idStr,
      );
    });
  }

  void _setupSubadminChannel() {
    if (_subadminChannel != null) {
      supabase.removeChannel(_subadminChannel!);
      _subadminChannel = null;
    }

    _subadminChannel = supabase
        .channel(_subadminChannelName)
        .onPostgresChanges(
          schema: 'public',
          table: 'subadmin_profiles',
          event: PostgresChangeEvent.all,
          callback: (payload) {
            if (!mounted) return;
            debugPrint(
              '📡 subadmin ${payload.eventType} | new: ${payload.newRecord}',
            );

            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                _handleSubadminInsert(payload.newRecord);
              case PostgresChangeEvent.update:
                _handleSubadminUpdate(payload.newRecord);
              case PostgresChangeEvent.delete:
                _handleSubadminDelete(payload.oldRecord);
              case PostgresChangeEvent.all:
                break;
            }
          },
        )
        .subscribe((status, error) {
          if (!mounted) return;
          debugPrint('📡 Subadmin channel: $status | error: $error');

          final connected = status == RealtimeSubscribeStatus.subscribed;
          if (isRealtimeConnected != connected)
            setState(() => isRealtimeConnected = connected);
          if (connected) _softRefresh();
          if (error != null || status == RealtimeSubscribeStatus.closed)
            _scheduleReconnect();
        });
  }

  void _handleSubadminInsert(Map<String, dynamic> record) {
    if (record.isEmpty) return;
    final id = record['subadmin_id'];
    if (id == null) return;

    setState(() {
      if (record['is_archived'] == true) {
        if (!_archivedAccounts.any(
          (r) => r['subadmin_id'].toString() == id.toString(),
        )) {
          _archivedAccounts.insert(0, Map<String, dynamic>.from(record));
        }
      } else {
        if (!requests.any(
          (r) => r['subadmin_id'].toString() == id.toString(),
        )) {
          requests.insert(0, Map<String, dynamic>.from(record));
        }
      }
    });
  }

  void _handleSubadminUpdate(Map<String, dynamic> updated) {
    if (updated.isEmpty) return;
    final id = updated['subadmin_id'];
    if (id == null) return;
    final idStr = id.toString();
    final isArchived = updated['is_archived'] == true;

    setState(() {
      if (isArchived) {
        requests.removeWhere((r) => r['subadmin_id'].toString() == idStr);
        final archivedIdx = _archivedAccounts.indexWhere(
          (r) => r['subadmin_id'].toString() == idStr,
        );
        if (archivedIdx == -1) {
          _archivedAccounts.insert(0, Map<String, dynamic>.from(updated));
        } else {
          _archivedAccounts[archivedIdx] = {
            ..._archivedAccounts[archivedIdx],
            ...updated,
          };
        }
      } else {
        _archivedAccounts.removeWhere(
          (r) => r['subadmin_id'].toString() == idStr,
        );
        final activeIdx = requests.indexWhere(
          (r) => r['subadmin_id'].toString() == idStr,
        );
        if (activeIdx == -1) {
          requests.insert(0, Map<String, dynamic>.from(updated));
        } else {
          final oldStatus = requests[activeIdx]['status'];
          final newStatus = updated['status'];
          requests[activeIdx] = {...requests[activeIdx], ...updated};
          if (oldStatus != null &&
              newStatus != null &&
              oldStatus != newStatus) {
            final username = updated['username'] ?? 'Subadmin';
            _showSnackBar(
              '$username is now $newStatus',
              newStatus == 'Online' ? Colors.green : Colors.grey[700]!,
            );
          }
        }
      }
    });
  }

  void _handleSubadminDelete(Map<String, dynamic> oldRecord) {
    if (oldRecord.isEmpty) return;
    final id = oldRecord['subadmin_id'];
    if (id == null) return;
    final idStr = id.toString();

    setState(() {
      requests.removeWhere((r) => r['subadmin_id'].toString() == idStr);
      _archivedAccounts.removeWhere(
        (r) => r['subadmin_id'].toString() == idStr,
      );
    });
  }

  void _setupProfileChannel() {
    if (_profileChannel != null) {
      supabase.removeChannel(_profileChannel!);
      _profileChannel = null;
    }

    _profileChannel =
        supabase
            .channel(_profileChannelName)
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'admin',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: 1,
              ),
              callback: (payload) {
                if (!mounted) return;
                debugPrint('🔔 Admin profile updated');
                _loadProfileImageForAvatar();
              },
            )
            .subscribe();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      debugPrint('🔄 Reconnecting subadmin channel...');
      _setupSubadminChannel();
    });
  }

  Future<void> _confirmUnarchiveSubadmin(Map<String, dynamic> subadmin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: const Text(
              'Restore Account',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            content: Text(
              'Restore ${subadmin['username'] ?? 'this account'}?\n\n'
              'The account will be reactivated.',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
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
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Restore',
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() {
        final record = _archivedAccounts.firstWhere(
          (r) => r['subadmin_id'] == subadmin['subadmin_id'],
          orElse: () => {},
        );
        if (record.isNotEmpty) {
          _archivedAccounts.removeWhere(
            (r) => r['subadmin_id'] == subadmin['subadmin_id'],
          );
          final restored = {
            ...record,
            'is_archived': false,
            'archived_at': null,
            'status': 'Offline',
          };
          requests.insert(0, restored);
        }
      });

      await supabase
          .from('subadmin_profiles')
          .update({
            'is_archived': false,
            'archived_at': null,
            'status': 'Offline',
          })
          .eq('subadmin_id', subadmin['subadmin_id']);

      if (mounted) _showSnackBar('Account restored.', Colors.green);
    } catch (e) {
      debugPrint('Unarchive error: $e');
      if (mounted) {
        _showSnackBar('Error restoring account.', Colors.red);
        _softRefresh();
      }
    }
  }

  Widget _buildVetApplicationsList(bool isMobile) {
    if (_isLoadingVetApps) {
      return Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 50,
        ),
      );
    }
    final active =
        _vetApplications.where((a) => a['is_archived'] != true).toList();
    if (active.isEmpty) {
      return const Center(
        child: Text(
          'No vet applications yet.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Montserrat'),
        ),
      );
    }
    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _fetchVetApplications,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: active.length,
        itemBuilder:
            (_, i) => Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 10 : 14),
              child: _buildVetApplicationCard(active[i]),
            ),
      ),
    );
  }

  Future<void> _fetchVetApplications() async {
    if (!mounted) return;
    setState(() => _isLoadingVetApps = true);
    try {
      final res = await supabase
          .from('vet_applications')
          .select('*')
          .eq('is_archived', false)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _vetApplications = List<Map<String, dynamic>>.from(res);
        _isLoadingVetApps = false;
      });
    } catch (e) {
      debugPrint('Vet app fetch error: $e');
      if (mounted) setState(() => _isLoadingVetApps = false);
    }
  }

  Future<void> _notifyVetApproved({required int vetId}) async {
    try {
      await supabase.from('vet_notifications').insert({
        'vet_id': vetId,
        'title': '🎉 Application Approved!',
        'message':
            'Congratulations! Your veterinarian account has been approved. '
            'You can now log in and start using the Apawtment vet portal.',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('❌ Error sending approval notification: $e');
    }
  }

  Future<void> _sendVetCredentialEmail({
    required Map<String, dynamic> app,
    required String password,
    required String role,
    required String payType,
  }) async {
    try {
      final serviceId = dotenv.env['EMAILJS_SERVICE_ID_VET']!;
      final templateId = dotenv.env['EMAILJS_TEMPLATE_ID_VET']!;
      final publicKey = dotenv.env['EMAILJS_PUBLIC_KEY_VET']!;

      final email = (app['email'] ?? '').toString();
      if (email.isEmpty) {
        debugPrint('⚠️ No email found for vet applicant, skipping email send.');
        return;
      }

      final emailResponse = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'to_email': email,
            'username': email,
            'password': password,
            'first_name': app['first_name'] ?? '',
            'middle_name': app['middle_name'] ?? '',
            'last_name': app['last_name'] ?? '',
            'suffix_name': app['suffix_name'] ?? '',
            'role': role,
            'pay_type': payType,
            'clinic_name': app['clinic_name'] ?? '',
            'license_number': app['license_number'] ?? '',
          },
        }),
      );

      if (emailResponse.statusCode == 200) {
        debugPrint('✅ Vet credential email sent to $email');
        if (mounted) {
          _showSnackBar('Credentials emailed to $email', Colors.green);
        }
      } else {
        throw Exception('EmailJS vet email failed: ${emailResponse.body}');
      }
    } catch (e) {
      debugPrint('❌ _sendVetCredentialEmail error: $e');

      if (mounted) {
        _showSnackBar(
          'Account approved but email failed. Check logs.',
          Colors.orange,
        );
      }
    }
  }

  Future<void> _reviewVetApplication(
    Map<String, dynamic> app,
    String newStatus, {
    String? notes,
    String? password,
    String role = 'Veterinarian',
    String payType = 'Unpaid',
  }) async {
    try {
      if (newStatus == 'Approved') {
        if (password == null || password.isEmpty) {
          _showSnackBar('Password is required to approve.', Colors.red);
          return;
        }
      }

      await supabase
          .from('vet_applications')
          .update({
            'status': newStatus,
            'notes': notes,
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': 1,
            if (password != null) 'password': password,
          })
          .eq('application_id', app['application_id']);

      if (newStatus == 'Approved') {
        final newVetId = await _insertVeterinarian(
          app,
          password!,
          role,
          payType,
        );

        if (newVetId != null) {
          await _notifyVetApproved(vetId: newVetId);
        }

        await _sendVetCredentialEmail(
          app: app,
          password: password,
          role: role,
          payType: payType,
        );
      }

      await _fetchVetApplications();

      if (mounted) {
        _showSnackBar(
          'Application $newStatus',
          newStatus == 'Approved' ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      debugPrint('Review error: $e');
      if (mounted) _showSnackBar('Error updating application.', Colors.red);
    }
  }

  Future<int?> _insertVeterinarian(
    Map<String, dynamic> app,
    String password,
    String role,
    String payType,
  ) async {
    final inserted =
        await supabase
            .from('veterinarians')
            .insert({
              'first_name': app['first_name'] ?? '',
              'middle_name': app['middle_name'] ?? '',
              'last_name': app['last_name'] ?? '',
              'suffix_name': app['suffix_name'] ?? '',
              'email': app['email'] ?? '',
              'password': password,
              'license_number': app['license_number'],
              'clinic_name': app['clinic_name'],
              'years_exp': app['years_exp'],
              'account_status': 'Active',
              'status': 'Offline',
              'role': role,
              'pay_type': payType,
            })
            .select()
            .single();

    final int? vetId = inserted['vet_id'] as int?;
    await logActivity(
      action: 'Created Vet Account',
      description:
          'Created veterinarian account for Dr. ${app['last_name'] ?? ''} (${app['email'] ?? ''})',
      entityType: 'Vet Account',
      entityId: vetId,
    );

    return vetId;
  }

  void _showApproveWithPasswordDialog(Map<String, dynamic> app) {
    String localPayType = 'Unpaid';

    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz123456789@#%&!';
    final random = Random.secure();
    final generatedPassword =
        List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialog) => Dialog(
                  backgroundColor: const Color(0xFF2C2C2C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Approve Veterinarian',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Approving Dr. ${app['last_name'] ?? 'this applicant'}. '
                            'A secure password will be generated and emailed automatically.',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Generated Password',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontFamily: 'Montserrat',
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        generatedPassword,
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.green,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '  This password will be sent to the applicant\'s email.',
                            style: TextStyle(
                              color: Colors.white24,
                              fontFamily: 'Montserrat',
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            value: localPayType,
                            decoration: _inputDecoration('Pay Type'),
                            dropdownColor: const Color(0xFF3A3A3A),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                            ),
                            items:
                                ['Paid', 'Unpaid']
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(
                                          p,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Montserrat',
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (v) => setDialog(
                                  () => localPayType = v ?? 'Unpaid',
                                ),
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _reviewVetApplication(
                                      app,
                                      'Approved',
                                      password: generatedPassword,
                                      role: 'Veterinarian',
                                      payType: localPayType,
                                    );
                                  },
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text(
                                    'Approve & Send',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        supabase
            .from('subadmin_profiles')
            .select()
            .eq('is_archived', false)
            .order('created_at', ascending: false),
        supabase
            .from('veterinarians')
            .select()
            .order('created_at', ascending: false),
      ]);

      if (!mounted) return;
      setState(() {
        requests = List<Map<String, dynamic>>.from(results[0]);
        _veterinarians = List<Map<String, dynamic>>.from(results[1]);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Fetch error: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Error loading accounts.', Colors.red);
      }
    }
  }

  Future<void> _softRefresh() async {
    if (!mounted) return;
    try {
      final results = await Future.wait([
        supabase
            .from('subadmin_profiles')
            .select()
            .eq('is_archived', false)
            .order('created_at', ascending: false),
        supabase
            .from('veterinarians')
            .select()
            .order('created_at', ascending: false),
        supabase
            .from('vet_applications')
            .select('*')
            .eq('is_archived', false)
            .order('created_at', ascending: false),
      ]);

      if (!mounted) return;

      final freshSubadmins = List<Map<String, dynamic>>.from(results[0]);
      final freshVets = List<Map<String, dynamic>>.from(results[1]);
      final freshVetApps = List<Map<String, dynamic>>.from(results[2]);
      _mergeList(list: requests, fresh: freshSubadmins, idKey: 'subadmin_id');
      _mergeList(list: _veterinarians, fresh: freshVets, idKey: 'vet_id');
      _mergeList(
        list: _vetApplications,
        fresh: freshVetApps,
        idKey: 'application_id',
      );

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('⚠️ Soft refresh error: $e');
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

  Future<void> _loadProfileImageForAvatar() async {
    if (_isLoadingAvatar || !mounted) return;
    setState(() => _isLoadingAvatar = true);

    try {
      final response =
          await supabase
              .from('admin')
              .select('admin_profile')
              .eq('admin_id', 1)
              .maybeSingle();

      if (!mounted) return;
      if (response == null) {
        setState(() => _isLoadingAvatar = false);
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

      setState(() {
        _cachedProfileImage = publicUrl;
        _isLoadingAvatar = false;
      });
    } catch (e) {
      debugPrint('❌ Avatar load error: $e');
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  Future<void> _confirmArchiveSubadmin(Map<String, dynamic> subadmin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: const Text(
              'Archive Account',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            content: Text(
              'Archive ${subadmin['username'] ?? 'this account'}?\n\n'
              'The account will be deactivated but data will be preserved.',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
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
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Archive',
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() {
        final record = requests.firstWhere(
          (r) => r['subadmin_id'] == subadmin['subadmin_id'],
          orElse: () => {},
        );
        if (record.isNotEmpty) {
          requests.removeWhere(
            (r) => r['subadmin_id'] == subadmin['subadmin_id'],
          );
          final archived = {
            ...record,
            'is_archived': true,
            'archived_at': DateTime.now().toIso8601String(),
            'status': 'Offline',
          };
          _archivedAccounts.insert(0, archived);
        }
      });

      await supabase
          .from('subadmin_profiles')
          .update({
            'is_archived': true,
            'archived_at': DateTime.now().toIso8601String(),
            'status': 'Offline',
          })
          .eq('subadmin_id', subadmin['subadmin_id']);

      final subId = subadmin['subadmin_id'];
      await logActivity(
        action: 'Archived Staff Account',
        description: 'Archived subadmin account ${subadmin['username'] ?? ''}',
        entityType: 'Staff Account',
        entityId: subId is int ? subId : int.tryParse(subId.toString()),
      );

      if (mounted) _showSnackBar('Account archived.', Colors.orange);
    } catch (e) {
      debugPrint('Archive error: $e');
      if (mounted) {
        _showSnackBar('Error archiving account.', Colors.red);
        _softRefresh();
      }
    }
  }

  void showAddAccountDialog() {
    final firstNameController = TextEditingController();
    final middleNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final suffixController = TextEditingController();
    final emailController = TextEditingController();
    String localSelectedSuffix = '';
    String localPayType = 'Unpaid';
    String localRole = 'Staff';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFF2C2C2C),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Add Subadmin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStyledTextField(
                                    controller: firstNameController,
                                    label: 'First Name',
                                    validatorMsg: 'First name is required',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStyledTextField(
                                    controller: middleNameController,
                                    label: 'Middle Name (Optional)',
                                    isOptional: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStyledTextField(
                                    controller: lastNameController,
                                    label: 'Last Name',
                                    validatorMsg: 'Last name is required',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value:
                                        localSelectedSuffix.isEmpty
                                            ? null
                                            : localSelectedSuffix,
                                    decoration: _inputDecoration('Suffix'),
                                    items:
                                        [
                                              'None',
                                              'Jr.',
                                              'Sr.',
                                              'II',
                                              'III',
                                              'IV',
                                              'V',
                                            ]
                                            .map(
                                              (s) => DropdownMenuItem<String>(
                                                value: s,
                                                child: Text(
                                                  s,
                                                  style: const TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setDialogState(() {
                                        localSelectedSuffix =
                                            (value == 'None')
                                                ? ''
                                                : (value ?? '');
                                        suffixController.text =
                                            (value == 'None')
                                                ? ''
                                                : (value ?? '');
                                      });
                                    },
                                    dropdownColor: const Color(0xFF3A3A3A),
                                    validator: (value) {
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: localRole,
                              decoration: _inputDecoration('Role'),
                              items:
                                  ['Staff', 'Veterinarian']
                                      .map(
                                        (r) => DropdownMenuItem(
                                          value: r,
                                          child: Text(
                                            r,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Montserrat',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (v) => setDialogState(
                                    () => localRole = v ?? 'Staff',
                                  ),
                              dropdownColor: const Color(0xFF3A3A3A),
                              validator:
                                  (v) =>
                                      v == null ? 'Please select a role' : null,
                            ),
                            const SizedBox(height: 12),
                            _buildStyledTextField(
                              controller: emailController,
                              label: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              validatorMsg: 'Enter a valid email address',
                              emailValidation: true,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: localPayType,
                              decoration: _inputDecoration('Pay Type'),
                              items:
                                  ['Paid', 'Unpaid']
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(
                                            p,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Montserrat',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (v) => setDialogState(
                                    () => localPayType = v ?? 'Unpaid',
                                  ),
                              dropdownColor: const Color(0xFF3A3A3A),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (_formKey.currentState!.validate()) {
                                      Navigator.pop(context);
                                      await createSubAdminAccount(
                                        firstNameController.text,
                                        middleNameController.text,
                                        lastNameController.text,
                                        emailController.text,
                                        suffixController.text,
                                        localRole,
                                        localPayType,
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> createSubAdminAccount(
    String firstName,
    String middleName,
    String lastName,
    String email,
    String suffix,
    String role,
    String payType,
  ) async {
    try {
      final response = await supabase
          .from('subadmin_profiles')
          .select('username')
          .order('created_at', ascending: false)
          .limit(1);

      int nextNumber = 1;
      if (response.isNotEmpty) {
        final lastUsername = response.first['username'] as String;
        final numberPart = lastUsername.replaceAll(RegExp(r'[^0-9]'), '');
        if (numberPart.isNotEmpty) {
          nextNumber = int.parse(numberPart) + 1;
        }
      }

      final username = 'SUBAD${nextNumber.toString().padLeft(3, '0')}';
      final random = Random.secure();
      const chars =
          'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz123456789@#%&!';
      final password =
          List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();

      await supabase.from('subadmin_profiles').insert({
        'to_email': email,
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'suffix_name': suffix,
        'username': username,
        'password': password,
        'status': 'Offline',
        'role': role,
        'pay_type': payType,
        'is_archived': false,
      });

      await logActivity(
        action: 'Created Staff Account',
        description: 'Created subadmin account for $username ($email)',
        entityType: 'Staff Account',
      );

      final serviceId = dotenv.env['EMAILJS_SERVICE_ID']!;
      final templateId = dotenv.env['EMAILJS_TEMPLATE_ID_SUB']!;
      final publicKey = dotenv.env['EMAILJS_PUBLIC_KEY']!;

      final emailResponse = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'to_email': email,
            'username': username,
            'password': password,
            'first_name': firstName,
            'middle_name': middleName,
            'last_name': lastName,
            'suffix_name': suffix,
          },
        }),
      );

      if (emailResponse.statusCode == 200) {
        if (mounted) {
          _showSnackBar(
            'Subadmin account created & email sent to $email',
            Colors.green,
          );
        }
      } else {
        throw Exception('EmailJS failed: ${emailResponse.body}');
      }
    } catch (e) {
      debugPrint('❌ Error creating subadmin: $e');
      if (mounted) _showSnackBar('Error creating subadmin.', Colors.red);
      debugPrint('Error creating subamin: $e');
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

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return '';
    try {
      final dt = DateTime.parse(lastSeen.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    String? validatorMsg,
    bool isOptional = false,
    TextInputType keyboardType = TextInputType.text,
    bool emailValidation = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
      keyboardType: keyboardType,
      decoration: _inputDecoration(label),
      validator: (value) {
        if (isOptional) return null;
        if (value == null || value.trim().isEmpty) return validatorMsg;
        if (emailValidation) {
          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
            return validatorMsg;
          }
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      hintStyle: const TextStyle(fontFamily: 'Montserrat'),
      labelStyle: const TextStyle(
        color: Colors.white70,
        fontFamily: 'Montserrat',
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white54),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      errorStyle: const TextStyle(
        color: Colors.redAccent,
        fontFamily: 'Montserrat',
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white54),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget buildRequestItem(Map<String, dynamic> subadmin) {
    final status = subadmin['status'] ?? 'Offline';
    final isOnline = status == 'Online';

    final firstName = subadmin['first_name'] ?? '';
    final middleName = subadmin['middle_name'] ?? '';
    final lastName = subadmin['last_name'] ?? '';
    final email = subadmin['to_email'] ?? '';
    final fullName = [
      firstName,
      middleName,
      lastName,
    ].where((n) => n.isNotEmpty).join(' ');
    final name = fullName.isNotEmpty ? fullName : 'Unnamed Subadmin';

    final lastSeenStr = _formatLastSeen(subadmin['last_seen']);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? Colors.green.withOpacity(0.35) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 30,
                backgroundImage:
                    subadmin['avatar_url'] != null
                        ? NetworkImage(subadmin['avatar_url'] as String)
                        : const AssetImage('assets/images/profile.png')
                            as ImageProvider,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow:
                        isOnline
                            ? [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                            : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isNotEmpty ? email : 'No email found',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isOnline ? Colors.greenAccent : Colors.white60,
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      child: Text('$status'),
                    ),
                    if (!isOnline && lastSeenStr.isNotEmpty)
                      Flexible(
                        child: Text(
                          ' • Last seen • $lastSeenStr',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _payTypeBadge(subadmin['pay_type'] ?? 'Unpaid'),
                    const SizedBox(width: 8),
                    _roleBadge(subadmin['role'] ?? 'Staff'),
                  ],
                ),
              ],
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Archive',
                icon: const Icon(
                  Icons.move_to_inbox_outlined,
                  color: Colors.orange,
                ),
                onPressed: () => _confirmArchiveSubadmin(subadmin),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => AccountManagementPage(subadmin: subadmin),
                      ),
                    ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) =>
      status == 'Online' ? Colors.green : Colors.grey;

  Widget _roleBadge(String role) {
    final isVet = role == 'Veterinarian';
    final color = isVet ? Colors.purple : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVet ? Icons.medical_services_outlined : Icons.badge_outlined,
            color: color,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            role,
            style: TextStyle(
              color: color,
              fontFamily: 'Montserrat',
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _payTypeBadge(String payType) {
    final isPaid = payType == 'Paid';
    final color = isPaid ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.payments_outlined : Icons.money_off_outlined,
            color: color,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            payType,
            style: TextStyle(
              color: color,
              fontFamily: 'Montserrat',
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAccountsSection() {
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (isLoading) {
      return Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 50,
        ),
      );
    }

    final pendingVets =
        _vetApplications.where((a) => a['status'] == 'Pending').length;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 20,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _activeTab == 0
                    ? '${requests.where((r) => r['is_archived'] != true).length} staff · ${_veterinarians.where((v) => v['account_status'] != 'Archived').length} veterinarian(s)'
                    : _activeTab == 1
                    ? '${_vetApplications.where((a) => a['is_archived'] != true).length} application(s)'
                    : '${_archivedAccounts.length + _archivedVetApplications.length} archived',
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_activeTab == 0) ...[
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: showAddAccountDialog,
                      icon: const Icon(Icons.person_add_outlined, size: 16),
                      label: const Text(
                        'Add Account',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          isMobile
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      dropdownColor: const Color(0xFF2A2A2A),
                      value: _activeTab,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: 0,
                          child: Text('Staff & Veterinarian'),
                        ),
                        DropdownMenuItem<int>(
                          value: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Vet Applications'),
                              if (pendingVets > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$pendingVets',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const DropdownMenuItem<int>(
                          value: 2,
                          child: Text('Archived'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _activeTab = val;
                          });
                        }
                      },
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _tabButton('Staff & Veterinarian', 0),
                      const SizedBox(width: 8),
                      _tabButton('Vet Applications', 1, badgeCount: pendingVets),
                      const SizedBox(width: 8),
                      _tabButton('Archived', 2),
                    ],
                  ),
                ),
          const SizedBox(height: 14),

          Expanded(
            child:
                _activeTab == 0
                    ? _buildStaffList(isMobile)
                    : _activeTab == 1
                    ? _buildVetApplicationsList(isMobile)
                    : _buildArchivedList(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedList(bool isMobile) {
    return Column(
      children: [
        isMobile
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    dropdownColor: const Color(0xFF2A2A2A),
                    value: _archivedSubTab,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    items: const [
                      DropdownMenuItem<int>(
                        value: 0,
                        child: Text('Archived Subadmins'),
                      ),
                      DropdownMenuItem<int>(
                        value: 1,
                        child: Text('Archived Veterinarians'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _archivedSubTab = val;
                        });
                      }
                    },
                  ),
                ),
              )
            : Row(
                children: [
                  _archivedSubTabButton('Subadmin', 0),
                  const SizedBox(width: 8),
                  _archivedSubTabButton('Veterinarian', 1),
                ],
              ),
        const SizedBox(height: 12),
        Expanded(
          child:
              _archivedSubTab == 0
                  ? _buildArchivedSubadminList(isMobile)
                  : _buildArchivedVetList(isMobile),
        ),
      ],
    );
  }

  Widget _buildArchivedVetList(bool isMobile) {
    if (_isLoadingArchivedVets) {
      return Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 50,
        ),
      );
    }
    if (_archivedVetApplications.isEmpty) {
      return const Center(
        child: Text(
          'No archived vet applications.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Montserrat'),
        ),
      );
    }
    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _fetchArchivedVetApplications,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _archivedVetApplications.length,
        itemBuilder:
            (_, i) => Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 10 : 14),
              child: _buildArchivedVetCard(_archivedVetApplications[i]),
            ),
      ),
    );
  }

  Future<void> _fetchArchivedVetApplications() async {
    if (!mounted) return;
    setState(() => _isLoadingArchivedVets = true);
    try {
      final response = await supabase
          .from('vet_applications')
          .select('*')
          .eq('is_archived', true)
          .order('archived_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _archivedVetApplications = List<Map<String, dynamic>>.from(response);
        _isLoadingArchivedVets = false;
      });
    } catch (e) {
      debugPrint('Archived vet fetch error: $e');
      if (mounted) setState(() => _isLoadingArchivedVets = false);
    }
  }

  Future<void> _fetchArchivedAccounts() async {
    if (!mounted) return;
    setState(() => _isLoadingArchived = true);
    try {
      final response = await supabase
          .from('subadmin_profiles')
          .select()
          .eq('is_archived', true)
          .order('archived_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _archivedAccounts = List<Map<String, dynamic>>.from(response);
        _isLoadingArchived = false;
      });
    } catch (e) {
      debugPrint('Archived fetch error: $e');
      if (mounted) setState(() => _isLoadingArchived = false);
    }
  }

  Widget _buildArchivedVetCard(Map<String, dynamic> app) {
    final status = app['status'] ?? 'Pending';
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_empty;
    }

    final fullName = [
      app['first_name'] ?? '',
      app['middle_name'] ?? '',
      app['last_name'] ?? '',
      app['suffix_name'] ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    String archivedLabel = '';
    if (app['archived_at'] != null) {
      try {
        final dt = DateTime.parse(app['archived_at'].toString()).toLocal();
        archivedLabel = 'Archived ${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Opacity(
      opacity: 0.75,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'Unnamed Applicant' : fullName,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        app['email'] ?? '',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                        ),
                      ),
                      if (archivedLabel.isNotEmpty)
                        Text(
                          archivedLabel,
                          style: const TextStyle(
                            color: Colors.white24,
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                IconButton(
                  tooltip: 'Restore',
                  icon: const Icon(
                    Icons.unarchive_outlined,
                    color: Colors.green,
                  ),
                  onPressed: () => _confirmUnarchiveVetApplication(app),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),

            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _vetDetailChip(
                  Icons.badge,
                  'License',
                  app['license_number'] ?? '—',
                ),
                _vetDetailChip(
                  Icons.local_hospital,
                  'Clinic',
                  app['clinic_name'] ?? '—',
                ),
                _vetDetailChip(
                  Icons.timer,
                  'Experience',
                  '${app['years_exp'] ?? '—'} yrs',
                ),
              ],
            ),
            if (app['notes'] != null && app['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notes, color: Colors.white38, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        app['notes'].toString(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmArchiveVetApplication(Map<String, dynamic> app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: const Text(
              'Archive Application',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            content: Text(
              'Archive the application of ${app['first_name'] ?? 'this applicant'}?\n\n'
              'It will be hidden from the active list but preserved.',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
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
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Archive',
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() {
        final record = _vetApplications.firstWhere(
          (a) => a['application_id'] == app['application_id'],
          orElse: () => {},
        );
        if (record.isNotEmpty) {
          _vetApplications.removeWhere(
            (a) => a['application_id'] == app['application_id'],
          );
          final archived = {
            ...record,
            'is_archived': true,
            'archived_at': DateTime.now().toIso8601String(),
          };
          _archivedVetApplications.insert(0, archived);
        }
      });

      await supabase
          .from('vet_applications')
          .update({
            'is_archived': true,
            'archived_at': DateTime.now().toIso8601String(),
          })
          .eq('application_id', app['application_id']);

      final appId = app['application_id'];
      await logActivity(
        action: 'Archived Vet Application',
        description:
            'Archived vet application of ${app['first_name'] ?? ''} ${app['last_name'] ?? ''}',
        entityType: 'Vet Application',
        entityId: appId is int ? appId : int.tryParse(appId.toString()),
      );

      if (mounted) _showSnackBar('Application archived.', Colors.orange);
    } catch (e) {
      debugPrint('Archive vet error: $e');
      if (mounted) {
        _showSnackBar('Error archiving application.', Colors.red);
        _softRefresh();
      }
    }
  }

  Future<void> _confirmUnarchiveVetApplication(Map<String, dynamic> app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: const Text(
              'Restore Application',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            content: Text(
              'Restore the application of ${app['first_name'] ?? 'this applicant'}?\n\n'
              'It will reappear in the active list.',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
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
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Restore',
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() {
        final record = _archivedVetApplications.firstWhere(
          (a) => a['application_id'] == app['application_id'],
          orElse: () => {},
        );
        if (record.isNotEmpty) {
          _archivedVetApplications.removeWhere(
            (a) => a['application_id'] == app['application_id'],
          );
          final restored = {
            ...record,
            'is_archived': false,
            'archived_at': null,
          };
          _vetApplications.insert(0, restored);
        }
      });

      await supabase
          .from('vet_applications')
          .update({'is_archived': false, 'archived_at': null})
          .eq('application_id', app['application_id']);

      if (mounted) _showSnackBar('Application restored.', Colors.green);
    } catch (e) {
      debugPrint('Unarchive vet error: $e');
      if (mounted) {
        _showSnackBar('Error restoring application.', Colors.red);
        _softRefresh();
      }
    }
  }

  Widget _buildArchivedSubadminList(bool isMobile) {
    if (_isLoadingArchived) {
      return Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 50,
        ),
      );
    }
    if (_archivedAccounts.isEmpty) {
      return const Center(
        child: Text(
          'No archived accounts.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Montserrat'),
        ),
      );
    }
    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _fetchArchivedAccounts,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _archivedAccounts.length,
        itemBuilder:
            (_, i) => Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
              child: _buildArchivedSubadminCard(_archivedAccounts[i]),
            ),
      ),
    );
  }

  Widget _buildArchivedSubadminCard(Map<String, dynamic> subadmin) {
    final firstName = subadmin['first_name'] ?? '';
    final middleName = subadmin['middle_name'] ?? '';
    final lastName = subadmin['last_name'] ?? '';
    final fullName = [
      firstName,
      middleName,
      lastName,
    ].where((n) => n.isNotEmpty).join(' ');
    final name = fullName.isNotEmpty ? fullName : 'Unnamed Subadmin';
    final email = subadmin['to_email'] ?? '';

    String archivedLabel = '';
    if (subadmin['archived_at'] != null) {
      try {
        final dt = DateTime.parse(subadmin['archived_at'].toString()).toLocal();
        archivedLabel = 'Archived ${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Opacity(
      opacity: 0.75,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 28,
              backgroundImage:
                  subadmin['avatar_url'] != null
                      ? NetworkImage(subadmin['avatar_url'] as String)
                      : const AssetImage('assets/images/profile.png')
                          as ImageProvider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email.isNotEmpty ? email : 'No email found',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                    ),
                  ),
                  if (archivedLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      archivedLabel,
                      style: const TextStyle(
                        color: Colors.white24,
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _payTypeBadge(subadmin['pay_type'] ?? 'Unpaid'),
                      const SizedBox(width: 8),
                      _roleBadge(subadmin['role'] ?? 'Staff'),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Restore',
              icon: const Icon(Icons.unarchive_outlined, color: Colors.green),
              onPressed: () => _confirmUnarchiveSubadmin(subadmin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _archivedSubTabButton(String label, int index) {
    final isActive = _archivedSubTab == index;
    final color = index == 1 ? Colors.purple : Colors.orange;
    return GestureDetector(
      onTap: () {
        setState(() => _archivedSubTab = index);
        if (index == 1 && _archivedVetApplications.isEmpty) {
          _fetchArchivedVetApplications();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isActive
                  ? color.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : Colors.white38,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index, {int badgeCount = 0}) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = index);
        if (index == 1 && _vetApplications.isEmpty) _fetchVetApplications();
        if (index == 2) _fetchArchivedAccounts();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.orange : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withOpacity(0.3) : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white,
                    fontFamily: 'Montserrat',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList(bool isMobile) {
    final activeSubadmins =
        requests.where((r) => r['is_archived'] != true).toList();
    final activeVets =
        _veterinarians.where((v) => v['account_status'] != 'Archived').toList();

    final combined = [
      ...activeSubadmins.map((s) => {...s, '_type': 'subadmin'}),
      ...activeVets.map((v) => {...v, '_type': 'vet'}),
    ];

    if (combined.isEmpty) {
      return const Center(
        child: Text(
          'No active accounts.',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Montserrat',
            fontSize: 16,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _fetchData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: combined.length,
        itemBuilder: (_, i) {
          final item = combined[i];
          return Padding(
            padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
            child:
                item['_type'] == 'vet'
                    ? _buildVetStaffCard(item)
                    : buildRequestItem(item),
          );
        },
      ),
    );
  }

  Widget _buildVetStaffCard(Map<String, dynamic> vet) {
    final status = vet['status'] ?? 'Offline';
    final lastLogin = vet['last_login'];
    final bool isOnline = () {
      if (status != 'Online') return false;
      if (lastLogin == null) return false;
      try {
        final dt = DateTime.parse(lastLogin.toString()).toLocal();
        return DateTime.now().difference(dt).inSeconds < 45;
      } catch (_) {
        return false;
      }
    }();

    final firstName = vet['first_name'] ?? '';
    final middleName = vet['middle_name'] ?? '';
    final lastName = vet['last_name'] ?? '';
    final suffix = vet['suffix_name'] ?? '';
    final fullName = [
      firstName,
      middleName,
      lastName,
      suffix,
    ].where((n) => n.isNotEmpty).join(' ');
    final name = fullName.isNotEmpty ? fullName : 'Unnamed Veterinarian';
    final email = vet['email'] ?? '';
    final lastSeenStr = _formatLastSeen(vet['last_login']);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isOnline
                  ? Colors.green.withOpacity(0.35)
                  : Colors.purple.withOpacity(0.20),
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 30,
                backgroundImage:
                    vet['avatar_url'] != null
                        ? NetworkImage(vet['avatar_url'] as String)
                        : const AssetImage('assets/images/profile.png')
                            as ImageProvider,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow:
                        isOnline
                            ? [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                            : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isNotEmpty ? email : 'No email found',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isOnline ? Colors.greenAccent : Colors.white60,
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      child: Text(status),
                    ),
                    if (!isOnline && lastSeenStr.isNotEmpty)
                      Text(
                        ' • Last seen • $lastSeenStr',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                        ),
                      ),
                    if (isOnline)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.4),
                            ),
                          ),
                          child: const Text(
                            'Active now',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'Montserrat',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    _payTypeBadge(vet['pay_type'] ?? 'Unpaid'),
                    const SizedBox(width: 8),
                    _roleBadge(vet['role'] ?? 'Veterinarian'),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Archive Vet',
                icon: const Icon(
                  Icons.move_to_inbox_outlined,
                  color: Colors.orange,
                ),
                onPressed: () => _confirmArchiveVet(vet),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountManagementPage(subadmin: vet),
                      ),
                    ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArchiveVet(Map<String, dynamic> vet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: const Text(
              'Archive Veterinarian',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            content: Text(
              'Archive Dr. ${vet['last_name'] ?? 'this veterinarian'}?\n\n'
              'The account will be deactivated but data will be preserved.',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
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
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Archive',
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    final vetId = vet['vet_id'];
    if (vetId == null) {
      _showSnackBar('Cannot archive: vet_id is missing.', Colors.red);
      return;
    }
    try {
      setState(() {
        _veterinarians.removeWhere(
          (v) => v['vet_id'].toString() == vetId.toString(),
        );
      });

      await supabase
          .from('veterinarians')
          .update({'account_status': 'Archived', 'status': 'Offline'})
          .eq('vet_id', vetId);

      if (mounted) _showSnackBar('Veterinarian archived.', Colors.orange);
    } catch (e) {
      debugPrint('Archive vet error: $e');
      if (mounted) {
        _showSnackBar('Error archiving veterinarian.', Colors.red);
        _softRefresh();
      }
    }
  }

  Widget _buildVetApplicationCard(Map<String, dynamic> app) {
    final status = app['status'] ?? 'Pending';
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_empty;
    }

    final fullName = [
      app['first_name'] ?? '',
      app['middle_name'] ?? '',
      app['last_name'] ?? '',
      app['suffix_name'] ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.medical_services,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Unnamed Applicant' : fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      app['email'] ?? '',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),

          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _vetDetailChip(
                Icons.badge,
                'License',
                app['license_number'] ?? '—',
              ),
              _vetDetailChip(
                Icons.local_hospital,
                'Clinic',
                app['clinic_name'] ?? '—',
              ),
              _vetDetailChip(
                Icons.timer,
                'Experience',
                '${app['years_exp'] ?? '—'} yrs',
              ),
            ],
          ),

          if (app['notes'] != null && app['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes, color: Colors.white38, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app['notes'],
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'Pending') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApproveWithPasswordDialog(app),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'Approve',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectReasonDialog(app),
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text(
                      'Reject',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _vetDetailChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 13),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white38,
              fontFamily: 'Montserrat',
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectReasonDialog(Map<String, dynamic> app) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reject Application',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                    decoration: _inputDecoration('Reason (optional)'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white54,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _reviewVetApplication(
                              app,
                              'Rejected',
                              notes:
                                  notesController.text.trim().isEmpty
                                      ? null
                                      : notesController.text.trim(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF101510),
        drawer: isMobile ? Drawer(width: 200, child: _buildSidebar()) : null,
        appBar:
            isMobile
                ? AppBar(
                  backgroundColor: const Color(0xFF101510),
                  elevation: 0,
                  leading: Builder(
                    builder:
                        (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                  ),
                  title: Text(
                    'Account Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 13 : 20,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
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
                        width: 32,
                        height: 32,
                      ),
                    ),
                    _NotificationBell(
                      iconSize: isMobile ? 22 : 24,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 4 : 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildProfileAvatar(radius: isMobile ? 14 : 16),
                    const SizedBox(width: 10),
                  ],
                )
                : null,
        body:
            isMobile
                ? Column(
                  children: [
                    Expanded(child: buildAccountsSection()),
                    _buildFooter(context),
                  ],
                )
                : Row(
                  children: [
                    _buildSidebar(),
                    Expanded(
                      child: Column(
                        children: [
                          _buildTopHeader(isMobile),
                          Expanded(child: buildAccountsSection()),
                          _buildFooter(context),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      height: 40,
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

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isMobile ? 4 : 0),
              child: Text(
                'Account Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
