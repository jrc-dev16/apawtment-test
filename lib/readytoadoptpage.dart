import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:apawtmentweb_admin/skeleton_loading.dart';
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
import 'package:apawtmentweb_admin/webnotifservice.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReadyToAdoptPage extends StatefulWidget {
  const ReadyToAdoptPage({super.key});

  @override
  State<ReadyToAdoptPage> createState() => _ReadyToAdoptPageState();
}

class _ReadyToAdoptPageState extends State<ReadyToAdoptPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> pets = [];
  List<Map<String, dynamic>> _filteredPets = [];
  String selectedItem = 'Pet Management';
  List<Map<String, dynamic>> adoptablePets = [];
  List<Map<String, dynamic>> medicationPets = [];

  RealtimeChannel? _realtimeChannel;
  bool _isFetching = false;

  final bool _isBulkMoving = false;
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  bool _isMultiSelectMode = false;
  final Set<int> _selectedPetIds = {};
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();
  List<String> _breeds = ['All'];
  String _selectedBreed = 'All';
  String _sortOrder = 'New';
  final List<Map<String, dynamic>> _shelters = [];

  @override
  void initState() {
    super.initState();
    _fetchShelters();
    _fetchPets();
    _subscribeRealtime();
    _loadProfileImageForAvatar();
    _searchController.addListener(() => setState(() => _applyFilters()));
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  void _subscribeRealtime() {
    _realtimeChannel = supabase
        .channel('ready_adopt_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'adoptable_pets',
          callback: (payload) {
            debugPrint('📡 adoptable_pets INSERT');
            _safeFetch();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'adoptable_pets',
          callback: (payload) {
            debugPrint('📡 adoptable_pets UPDATE ${payload.newRecord}');
            final newStatus = payload.newRecord['status']?.toString() ?? '';
            final petId = payload.newRecord['pet_id'];
            if (newStatus == 'Adopted' && petId != null && mounted) {
              setState(() {
                pets.removeWhere(
                  (p) => p['pet_id'].toString() == petId.toString(),
                );
                _applyFilters();
              });
            } else {
              _safeFetch();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'adoptable_pets',
          callback: (payload) {
            debugPrint('📡 adoptable_pets DELETE ${payload.oldRecord}');
            final petId = payload.oldRecord['pet_id'];
            if (petId != null && mounted) {
              setState(() {
                pets.removeWhere(
                  (p) => p['pet_id'].toString() == petId.toString(),
                );
                _applyFilters();
              });
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pets',
          callback: (payload) {
            debugPrint('📡 pets UPDATE');
            _safeFetch();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'adoptions',
          callback: (payload) {
            debugPrint('📡 adoptions INSERT ${payload.newRecord}');
            _safeFetch();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'adoptions',
          callback: (payload) {
            debugPrint('📡 adoptions UPDATE ${payload.newRecord}');
            final newStatus = payload.newRecord['status']?.toString() ?? '';
            final petId = payload.newRecord['pet_id'];
            if (newStatus == 'Adopted' && petId != null && mounted) {
              setState(() {
                pets.removeWhere(
                  (p) => p['pet_id'].toString() == petId.toString(),
                );
                _applyFilters();
              });
            } else {
              _safeFetch();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'adoptions',
          callback: (payload) {
            debugPrint('📡 adoptions DELETE');
            _safeFetch();
          },
        )
        .subscribe((status, [error]) {
          debugPrint('📡 Realtime: $status');
          if (error != null) debugPrint('❌ Realtime error: $error');
        });
  }

  void _safeFetch() {
    if (!mounted || _isFetching) return;
    _fetchPets();
  }

  Future<void> _assignPetToEvent(Map<String, dynamic> pet) async {
    final petId =
        pet['pet_id'] is int
            ? pet['pet_id'] as int
            : int.tryParse(pet['pet_id'].toString());
    if (petId == null) return;

    final events = await supabase
        .from('events')
        .select('eventid, title, date, location')
        .eq('category', 'Adoption')
        .inFilter('status', ['Upcoming', 'Ongoing'])
        .order('date', ascending: true);

    final eventList = List<Map<String, dynamic>>.from(events);

    if (!mounted) return;

    if (eventList.isEmpty) {
      _showSnackBar('No upcoming Adoption events found.', Colors.orange);
      return;
    }

    final alreadyAssigned = await supabase
        .from('event_pet_roster')
        .select('event_id')
        .eq('pet_id', petId);
    final assignedIds =
        (alreadyAssigned as List).map((r) => r['event_id']).toSet();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Row(
              children: [
                const Icon(Icons.event, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assign "${pet['name']}" to Event',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: eventList.length,
                separatorBuilder:
                    (_, __) => const Divider(color: Colors.white12, height: 1),
                itemBuilder: (context, i) {
                  final event = eventList[i];
                  final eid = event['eventid'];
                  final isAssigned = assignedIds.contains(eid);
                  return ListTile(
                    leading: Icon(
                      isAssigned
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isAssigned ? Colors.green : Colors.white38,
                      size: 20,
                    ),
                    title: Text(
                      event['title'] ?? 'Untitled',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${event['date'] ?? ''} · ${event['location'] ?? ''}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap:
                        isAssigned
                            ? null
                            : () async {
                              Navigator.pop(ctx);
                              try {
                                await supabase.from('event_pet_roster').insert({
                                  'event_id': eid,
                                  'pet_id': petId,
                                });
                                _showSnackBar(
                                  '${pet['name']} assigned to "${event['title']}"',
                                  Colors.green,
                                );
                              } catch (e) {
                                _showSnackBar(
                                  'Failed to assign pet to event.',
                                  Colors.red,
                                );
                                debugPrint('Assign error: $e');
                              }
                            },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _fetchPets() async {
    if (!mounted || _isFetching) return;
    setState(() {
      _isFetching = true;
      isLoading = pets.isEmpty;
    });

    try {
      final response = await supabase
          .from('adoptable_pets')
          .select('*')
          .eq('status', 'Ready For Adoption')
          .order('pet_id', ascending: _sortOrder == 'Old');

      final fetched = List<Map<String, dynamic>>.from(response);

      final adoptionsResponse = await supabase
          .from('adoptions')
          .select('pet_id, status')
          .inFilter('status', ['Pending', 'Approved', 'Adopted']);

      final adoptedPetIds =
          (adoptionsResponse as List)
              .map((a) => a['pet_id'])
              .whereType<int>()
              .toSet();

      final available =
          fetched.where((p) {
            final petId =
                p['pet_id'] is int
                    ? p['pet_id'] as int
                    : int.tryParse(p['pet_id'].toString());
            return petId != null && !adoptedPetIds.contains(petId);
          }).toList();

      final allAdoptionsResp = await supabase
          .from('adoptions')
          .select('pet_id, status')
          .order('created_at', ascending: false);

      final Map<String, String> adoptionStatusMap = {};
      for (final a in (allAdoptionsResp as List)) {
        final id = a['pet_id']?.toString();
        if (id != null && !adoptionStatusMap.containsKey(id)) {
          adoptionStatusMap[id] = a['status']?.toString() ?? '';
        }
      }

      final enriched =
          available.map((p) {
            final id = p['pet_id']?.toString() ?? '';
            return {
              ...p,
              'adoption_display_status':
                  adoptionStatusMap[id]?.isNotEmpty == true
                      ? adoptionStatusMap[id]!
                      : 'Available',
            };
          }).toList();

      if (!mounted) return;
      setState(() {
        pets = enriched;
        _applyFilters();
        _loadBreedsFromPets();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching pets: $e');
      if (mounted) setState(() => isLoading = false);
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(pets);

    if (_selectedBreed != 'All') {
      temp =
          temp.where((p) {
            final breed = p['breed']?.toString().trim() ?? '';
            return breed.toLowerCase() == _selectedBreed.toLowerCase();
          }).toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      temp =
          temp.where((p) {
            final name = p['name']?.toString().toLowerCase() ?? '';
            final breed = p['breed']?.toString().toLowerCase() ?? '';
            final color = p['color']?.toString().toLowerCase() ?? '';
            return name.contains(query) ||
                breed.contains(query) ||
                color.contains(query);
          }).toList();
    }

    _filteredPets = temp;
  }

  void _filterSearch(String query) => setState(() => _applyFilters());

  void _filterByBreed(String? selectedBreed) {
    setState(() {
      _selectedBreed = selectedBreed ?? 'All';
      _applyFilters();
    });
  }

  void _loadBreedsFromPets() {
    final uniqueBreeds =
        pets
            .map((pet) => pet['breed']?.toString() ?? '')
            .where((breed) => breed.isNotEmpty)
            .toSet()
            .toList();
    _breeds = ['All', ...uniqueBreeds];
  }

  Future<void> _fetchShelters() async {
    try {
      final response = await supabase
          .from('shelters')
          .select()
          .order('shelter_id', ascending: true);

      final data =
          (response as List)
              .map(
                (s) => {
                  'shelter_id': s['shelter_id'],
                  'name': s['name'] ?? 'Unnamed Shelter',
                },
              )
              .toList();

      if (mounted) setState(() => _shelters.addAll(data));
    } catch (e) {
      debugPrint('Error fetching shelters: $e');
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
      debugPrint('❌ Error loading profile image: $e');
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  Future<void> _deletePet(Map<String, dynamic> pet) async {
    final petId = pet['pet_id'];
    final petName = pet['name'] ?? 'this pet';
    if (petId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Confirm Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to permanently delete $petName?\n\nThis action cannot be undone.',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await supabase.from('notifications').delete().eq('pet_id', petId);
      await supabase.from('pet_medications').delete().eq('pet_id', petId);
      await supabase.from('adoptable_pets').delete().eq('pet_id', petId);
      await supabase.from('pets').delete().eq('pet_id', petId);

      if (mounted) {
        _showSnackBar('$petName has been permanently deleted.', Colors.green);
      }
    } catch (e) {
      debugPrint('Error deleting pet: $e');
      if (mounted) {
        _showSnackBar('Failed to delete $petName.', Colors.red);
      }
    }
  }

  Future<void> _movePet(Map<String, dynamic> pet, String destination) async {
    if (!mounted) return;

    final petStatus = pet['status']?.toString() ?? '';
    if (petStatus == 'Ready For Adoption') {
      _showSnackBar(
        'This pet is Ready For Adoption and cannot be moved.',
        Colors.orange,
      );
      return;
    }

    final int? petId =
        pet['pet_id'] is int
            ? pet['pet_id']
            : int.tryParse(pet['pet_id'].toString());
    if (petId == null) return;

    final petName = pet['name'] ?? 'Unnamed';
    setState(() {
      pets.removeWhere((p) => p['pet_id'] == petId);
      _applyFilters();
    });

    try {
      final notifier = WebNotificationService();

      Future<void> notify(String message) async {
        const title = 'Pet Moved';
        await supabase.from('notifications').insert({
          'pet_id': petId,
          'title': title,
          'message': message,
          'created_at': DateTime.now().toIso8601String(),
        });
        await notifier.requestPermission();
        notifier.showNotification(title: title, body: message);
      }

      if (destination == 'medication') {
        final petData =
            await supabase
                .from('pets')
                .select('shelter_id, has_disability')
                .eq('pet_id', petId)
                .maybeSingle();

        final shelterId = petData?['shelter_id'];
        if (shelterId == null) {
          _showSnackBar(
            'Cannot move: pet has no shelter assigned.',
            Colors.red,
          );
          await _fetchPets();
          return;
        }

        final hasDisability = petData?['has_disability'] ?? 'No';

        await supabase.from('pet_medications').upsert({
          'pet_id': petId,
          'name': petName,
          'shelter_id': shelterId,
          'type': pet['type'] ?? '',
          'breed': pet['breed'] ?? '',
          'age': pet['age']?.toString() ?? '',
          'sex': pet['sex'] ?? '',
          'color': pet['color'] ?? '',
          'has_disability': hasDisability,
          'description': pet['description'] ?? '',
          'energy': pet['energy'] ?? '',
          'status': 'Under Medication',
          'image_url_1': pet['image_url_1'] ?? '',
          'vaccination_status': pet['vaccination_status'] ?? 'N/A',
          'deworming_status': pet['deworming_status'] ?? 'N/A',
          'neutered_spayed_details': pet['neutered_spayed_details'] ?? 'N/A',
          'surgery_type': pet['surgery_type'] ?? '',
          'surgery_details': pet['surgery_details'] ?? '',
          'disease_type': pet['disease_type'] ?? '',
          'disease_details': pet['disease_details'] ?? '',
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'pet_id');

        await supabase
            .from('pets')
            .update({
              'status': 'Under Medication',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('pet_id', petId);

        await supabase.from('adoptable_pets').delete().eq('pet_id', petId);
        await notify('$petName moved to medication');
        await logActivity(
          action: 'Moved to Medication',
          description: '$petName was moved to medication',
          entityType: 'Pet',
          entityId: petId,
        );
        _showSnackBar('$petName is now under medication.', Colors.green);
      } else if (destination == 'shelter') {
        final shelterId = await _selectShelterDialog();
        if (shelterId == null) {
          await _fetchPets();
          return;
        }

        await supabase
            .from('pets')
            .update({
              'status': 'In Shelter',
              'shelter_id': shelterId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('pet_id', petId);

        await supabase.from('adoptable_pets').delete().eq('pet_id', petId);
        await notify('$petName moved back to shelter');
        await logActivity(
          action: 'Moved to Shelter',
          description: '$petName was moved back to shelter',
          entityType: 'Pet',
          entityId: petId,
        );
        _showSnackBar('$petName moved to shelter.', Colors.green);
      }
    } catch (e, stack) {
      debugPrint('❌ Move error: $e\n$stack');
      await _fetchPets();
      _showSnackBar('Failed to move pet.', Colors.red);
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

  Future<int?> _selectShelterDialog() async {
    return showDialog<int>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Select Shelter',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _shelters.length,
                itemBuilder: (context, i) {
                  final shelter = _shelters[i];
                  return ListTile(
                    title: Text(
                      shelter['name'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, shelter['shelter_id']),
                  );
                },
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

  void _showPetDetailDialog(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => _AdoptPetDetailDialog(
            pets: _filteredPets,
            initialIndex: initialIndex,
            onAssignToEvent: (pet) async {
              Navigator.pop(dialogContext);
              await _assignPetToEvent(pet);
            },
            onMoveToMedication: (pet) async {
              Navigator.pop(dialogContext);
              await _movePet(pet, 'medication');
            },
            onMoveToShelter: (pet) async {
              Navigator.pop(dialogContext);
              await _movePet(pet, 'shelter');
            },
            onDelete: (pet) async {
              Navigator.pop(dialogContext);
              await _deletePet(pet);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1000;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PetPage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2D2D30),
        drawer:
            !isDesktop
                ? Drawer(
                  width: 200,
                  backgroundColor: const Color(0xFF1F1F22),
                  child: SafeArea(child: _buildSidebar()),
                )
                : null,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) _buildSidebar(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopHeader(isDesktop),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopControls(screenWidth),
                        if (_isMultiSelectMode) _buildMultiSelectToolbar(),
                      ],
                    ),
                  ),
                  if (_isFetching && pets.isNotEmpty)
                    LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: Colors.orange.withOpacity(0.6),
                    ),
                  if (!isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        '${_filteredPets.length} pet${_filteredPets.length == 1 ? '' : 's'} found',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Expanded(child: _buildPetTable()),
                  _buildFooter(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectToolbar() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_selectedPetIds.length} selected — Ready For Adoption pets cannot be bulk-moved.',
              style: const TextStyle(
                color: Colors.orange,
                fontFamily: 'Montserrat',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Cancel selection',
            onPressed:
                () => setState(() {
                  _isMultiSelectMode = false;
                  _selectedPetIds.clear();
                }),
          ),
        ],
      ),
    );
  }

  Widget _buildPetTable() {
    const kTablePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    const columns = [
      _ColDef(label: 'Pet', flex: 6),
      _ColDef(label: 'Type', flex: 4),
      _ColDef(label: 'Breed', flex: 4),
      _ColDef(label: 'Age', flex: 4),
      _ColDef(label: 'Sex', flex: 3),
      _ColDef(label: 'Color', flex: 4),
      _ColDef(label: 'Energy', flex: 3),
      _ColDef(label: 'Status', flex: 6),
      _ColDef(label: 'Actions', flex: 4),
    ];

    if (isLoading) {
      return const SkeletonPetTable();
    }

    if (_filteredPets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, color: Colors.white24, size: 56),
            const SizedBox(height: 12),
            const Text(
              'No pets ready to adopt.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1000;

    Widget tableContent = Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          padding: kTablePadding,
          child: Row(
            children:
                columns
                    .map(
                      (col) => Expanded(
                        flex: col.flex,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: col.label == 'Pet'
                                ? 40
                                : (col.label == 'Actions' ? 4 : 0),
                            right: 12,
                          ),
                          child: Text(
                            col.label,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredPets.length,
          separatorBuilder:
              (_, __) => const Divider(height: 1, color: Colors.white10),
          itemBuilder:
              (context, index) => _buildTableRow(_filteredPets[index], index),
        ),
        Container(
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth = constraints.maxWidth > 1250 ? constraints.maxWidth : 1250;
        return Scrollbar(
          controller: _tableScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _tableScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: tableContent,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableRow(Map<String, dynamic> pet, int index) {
    const kTablePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    final petId =
        pet['pet_id'] is int
            ? pet['pet_id'] as int
            : int.tryParse(pet['pet_id'].toString()) ?? 0;

    final name = pet['name']?.toString() ?? 'Unnamed';
    final type = pet['type']?.toString() ?? '—';
    final breed = pet['breed']?.toString() ?? '—';
    final age = pet['age']?.toString() ?? '—';
    final sex = pet['sex']?.toString() ?? '—';
    final color = pet['color']?.toString() ?? '—';
    final energy = pet['energy']?.toString() ?? '—';
    final imageUrl = pet['image_url_1']?.toString() ?? '';
    final adoptionStatus = pet['status']?.toString() ?? 'Ready For Adoption';

    final isSelected = _selectedPetIds.contains(petId);
    final isEven = index % 2 == 0;

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _isMultiSelectMode = true;
          _selectedPetIds.add(petId);
        });
      },
      onTap: () {
        if (_isMultiSelectMode) {
          setState(() {
            if (isSelected) {
              _selectedPetIds.remove(petId);
            } else {
              _selectedPetIds.add(petId);
            }
            if (_selectedPetIds.isEmpty) _isMultiSelectMode = false;
          });
        } else {
          _showPetDetailDialog(context, index);
        }
      },
      child: Container(
        color:
            isSelected
                ? Colors.orange.withOpacity(0.12)
                : isEven
                ? const Color(0xFF2D2D30)
                : const Color(0xFF272729),
        padding: kTablePadding,
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child:
                            imageUrl.isNotEmpty
                                ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => _avatarFallback(name),
                                )
                                : _avatarFallback(name),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(flex: 4, child: _tableCell(type)),
            Expanded(flex: 4, child: _tableCell(breed)),
            Expanded(flex: 4, child: _tableCell(age)),
            Expanded(flex: 3, child: _genderBadge(sex)),
            Expanded(flex: 4, child: _tableCell(color)),
            Expanded(flex: 3, child: _energyBadge(energy)),
            Expanded(flex: 6, child: _adoptionStatusBadge(adoptionStatus)),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconAction(
                      icon: Icons.info_outline,
                      color: Colors.orange,
                      tooltip: 'View Details',
                      onTap: () => _showPetDetailDialog(context, index),
                    ),
                    const SizedBox(width: 6),
                    _iconAction(
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      tooltip: 'Delete',
                      onTap: () => _deletePet(pet),
                    ),
                    const SizedBox(width: 6),
                    _iconAction(
                      icon: Icons.event_available,
                      color: Colors.teal,
                      tooltip: 'Assign to Adoption Event',
                      onTap: () => _assignPetToEvent(pet),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableCell(String value) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Text(
      value,
      style: const TextStyle(
        color: Colors.white70,
        fontFamily: 'Montserrat',
        fontSize: 12,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _genderBadge(String sex) {
    final isMale = sex.toLowerCase() == 'male';
    final color = isMale ? Colors.lightBlue : Colors.pinkAccent;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            sex,
            style: TextStyle(
              color: color,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _energyBadge(String energy) {
    Color color;
    switch (energy.toLowerCase()) {
      case 'high':
        color = Colors.orangeAccent;
        break;
      case 'medium':
        color = Colors.amber;
        break;
      case 'low':
        color = Colors.lightGreenAccent;
        break;
      default:
        color = Colors.white38;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            energy,
            style: TextStyle(
              color: color,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _adoptionStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.amber;
        break;
      case 'approved':
        color = Colors.lightBlue;
        break;
      case 'adopted':
        color = Colors.green;
        break;
      case 'available':
        color = Colors.tealAccent;
        break;
      default:
        color = Colors.white38;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: const Color(0xFF3C3C3E),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildBreedDropdown() {
    return DropdownButton<String>(
      value: _selectedBreed,
      dropdownColor: const Color(0xFF3C3C3E),
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Montserrat',
      ),
      underline: Container(height: 1, color: Colors.orange),
      items: _breeds
          .map(
            (breed) => DropdownMenuItem(
              value: breed,
              child: Text(
                breed,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          )
          .toList(),
      onChanged: _filterByBreed,
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButton<String>(
      value: _sortOrder,
      dropdownColor: const Color(0xFF3C3C3E),
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Montserrat',
      ),
      underline: Container(height: 1, color: Colors.orange),
      items: const [
        DropdownMenuItem(
          value: 'New',
          child: Text('New', style: TextStyle(fontFamily: 'Montserrat')),
        ),
        DropdownMenuItem(
          value: 'Old',
          child: Text('Old', style: TextStyle(fontFamily: 'Montserrat')),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _sortOrder = value);
          _fetchPets();
        }
      },
    );
  }

  Widget _buildTopControls(double screenWidth) {
    final bool isMobile = screenWidth < 800;

    final searchBar = TextField(
      controller: _searchController,
      onChanged: _filterSearch,
      decoration: InputDecoration(
        hintText: 'Search pets...',
        hintStyle: const TextStyle(
          color: Colors.white54,
          fontFamily: 'Montserrat',
          fontSize: 12,
        ),
        prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 16),
        filled: true,
        fillColor: const Color(0xFF3C3C3E),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isMobile ? 6 : 10,
        ),
        isDense: isMobile,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Montserrat',
        fontSize: 13,
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchBar,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBreedDropdown(),
                const SizedBox(width: 12),
                _buildSortDropdown(),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 250,
          child: searchBar,
        ),
        const SizedBox(width: 16),
        const Text(
          'Breed: ',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        _buildBreedDropdown(),
        const SizedBox(width: 16),
        const Text(
          'Sort By: ',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        _buildSortDropdown(),
      ],
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

  Widget _buildTopHeader(bool isDesktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder:
                  (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
            ),
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed:
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => PetPage()),
                  ),
            ),
          if (isDesktop)
            ElevatedButton.icon(
              onPressed:
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => PetPage()),
                  ),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text(
                'Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Montserrat',
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF666666),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ready to Adopt Pets',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 12 : 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
              maxLines: 2,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ShelterProjectsPage()),
                    ),
                child: Image.asset(
                  'assets/icons/shelterprojects.png',
                  width: isMobile ? 28 : 32,
                  height: isMobile ? 28 : 32,
                ),
              ),
              _NotificationBell(
                iconSize: isMobile ? 22 : 24,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
              const SizedBox(width: 8),
              buildProfileAvatar(context, radius: isDesktop ? 16 : 14),
              const SizedBox(width: 8),
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
}

class _ColDef {
  final String label;
  final int flex;
  const _ColDef({required this.label, required this.flex});
}

class _AdoptPetDetailDialog extends StatefulWidget {
  final List<Map<String, dynamic>> pets;
  final int initialIndex;
  final Future<void> Function(Map<String, dynamic>) onMoveToMedication;
  final Future<void> Function(Map<String, dynamic>) onMoveToShelter;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final Future<void> Function(Map<String, dynamic>) onAssignToEvent;

  const _AdoptPetDetailDialog({
    required this.pets,
    required this.initialIndex,
    required this.onMoveToMedication,
    required this.onMoveToShelter,
    required this.onDelete,
    required this.onAssignToEvent,
  });

  @override
  State<_AdoptPetDetailDialog> createState() => _AdoptPetDetailDialogState();
}

class _AdoptPetDetailDialogState extends State<_AdoptPetDetailDialog> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  Map<String, dynamic> get _pet => widget.pets[_currentIndex];
  bool get _hasPrev => _currentIndex > 0;
  bool get _hasNext => _currentIndex < widget.pets.length - 1;

  void _prev() {
    if (_hasPrev) setState(() => _currentIndex--);
  }

  void _next() {
    if (_hasNext) setState(() => _currentIndex++);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber;
      case 'approved':
        return Colors.lightBlue;
      case 'adopted':
        return Colors.green;
      case 'available':
        return Colors.tealAccent;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    final name = pet['name'] ?? 'Unnamed';
    final breed = pet['breed'] ?? 'Unknown';
    final type = pet['type'] ?? 'Unknown';
    final age = pet['age']?.toString() ?? 'N/A';
    final color = pet['color'] ?? 'Unknown';
    final gender = pet['sex'] ?? pet['gender'] ?? 'Unknown';
    final energy = pet['energy'] ?? 'N/A';
    final status = pet['status'] ?? 'N/A';
    final description = pet['description'] ?? '—';
    final imageUrl = pet['image_url_1'] ?? '';
    final vaccinationStatus = pet['vaccination_status'] ?? 'N/A';
    final dewormingStatus = pet['deworming_status'] ?? 'N/A';
    final neuteredSpayed = pet['neutered_spayed_details'] ?? 'N/A';
    final surgeryType = pet['surgery_type'] ?? 'N/A';
    final surgeryDetails = pet['surgery_details'] ?? 'N/A';
    final adoptionStatus =
        pet['adoption_display_status']?.toString() ?? 'Available';

    final rawDisability = pet['has_disability'];
    final hasDisability =
        (rawDisability == true ||
                rawDisability?.toString().toLowerCase() == 'true' ||
                rawDisability?.toString().toLowerCase() == 'yes')
            ? 'Yes'
            : (rawDisability == null ? 'Unknown' : 'No');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: MediaQuery.of(context).size.width < 560
            ? MediaQuery.of(context).size.width * 0.95
            : 520,
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF2D2D2D),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  _NavButton(
                    icon: Icons.chevron_left,
                    label: 'Prev',
                    enabled: _hasPrev,
                    onTap: _prev,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_currentIndex + 1} / ${widget.pets.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _NavButton(
                    icon: Icons.chevron_right,
                    label: 'Next',
                    enabled: _hasNext,
                    onTap: _next,
                    reversed: true,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child:
                          imageUrl.isNotEmpty
                              ? Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => _imagePlaceholder(),
                              )
                              : _imagePlaceholder(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                        _StatusBadge(
                          label: adoptionStatus,
                          color: _statusColor(adoptionStatus),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InfoGrid(
                      items: [
                        _InfoItem(label: 'Breed', value: breed),
                        _InfoItem(label: 'Type', value: type),
                        _InfoItem(label: 'Age', value: age),
                        _InfoItem(label: 'Color', value: color),
                        _InfoItem(label: 'Gender', value: gender),
                        _InfoItem(label: 'Energy', value: energy),
                        _InfoItem(label: 'Disability', value: hasDisability),
                        _InfoItem(label: 'Status', value: status),
                        _InfoItem(
                          label: 'Adoption Status',
                          value: adoptionStatus,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (description.isNotEmpty && description != '—') ...[
                      const Text(
                        'Description',
                        style: TextStyle(
                          color: Colors.orange,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text(
                      'Medical Information',
                      style: TextStyle(
                        color: Colors.orange,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoGrid(
                      items: [
                        _InfoItem(
                          label: 'Vaccination',
                          value: vaccinationStatus,
                        ),
                        _InfoItem(label: 'Deworming', value: dewormingStatus),
                        _InfoItem(
                          label: 'Neutered/Spayed',
                          value: neuteredSpayed,
                        ),
                        _InfoItem(label: 'Surgery Type', value: surgeryType),
                        _InfoItem(
                          label: 'Surgery Details',
                          value: surgeryDetails,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 16),
                    _ActionChip(
                      label: 'Delete',
                      icon: Icons.delete,
                      color: Colors.red,
                      onTap: () => widget.onDelete(pet),
                    ),
                    const SizedBox(height: 8),
                    _ActionChip(
                      label: 'Assign to Adoption Event',
                      icon: Icons.event_available,
                      color: Colors.teal,
                      onTap: () => widget.onAssignToEvent(pet),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    width: double.infinity,
    height: 220,
    color: Colors.grey[800],
    child: const Icon(Icons.pets, color: Colors.white38, size: 60),
  );
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool reversed;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.orange : Colors.white24;
    final children = [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ];
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reversed ? children.reversed.toList() : children,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Montserrat',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isOneCol = constraints.maxWidth < 450;
          final itemWidth = isOneCol
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;

          return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: items.map((item) {
              return SizedBox(
                width: itemWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontFamily: 'Montserrat',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});
}

class _ActionChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? widget.color : widget.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.color, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: _hovered ? Colors.white : widget.color,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? Colors.white : widget.color,
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                if (mounted)
                  setState(() => _notifications.insert(0, payload.newRecord));
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'notifications',
              callback: (payload) {
                final deletedId = payload.oldRecord['id'];
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
