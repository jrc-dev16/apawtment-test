import 'dart:convert';

import 'dart:typed_data';

import 'dart:ui' as ui;



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



import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:universal_html/html.dart' as html;



class PetsWithDisabilitiesPage extends StatefulWidget {

  const PetsWithDisabilitiesPage({super.key});



  @override

  State<PetsWithDisabilitiesPage> createState() =>

      _PetsWithDisabilitiesPageState();

}



class _PetsWithDisabilitiesPageState extends State<PetsWithDisabilitiesPage> {

  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  bool _isLoadingAvatar = false;

  String? _cachedProfileImage;

  String _selectedItem = 'Pet Management';

  List<Map<String, dynamic>> _allPets = [];

  List<String> _breeds = ['All'];

  int? _expandedPetId;

  final List<Map<String, dynamic>> _shelters = [];

  String _filterStatus = 'All';

  String _filterAge = 'All';

  final String _searchQuery = '';

  List<Map<String, dynamic>> _pets = [];

  List<Map<String, dynamic>> pets = [];

  final int _currentShelterIndex = 0;

  List<Map<String, dynamic>> petsUnderMedication = [];



  List<Map<String, dynamic>> _disabledPets = [];

  List<Map<String, dynamic>> _filteredPets = [];

  RealtimeChannel? _petsChannel;

  final ScrollController _tableScrollController = ScrollController();



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      loadProfileImageForAvatar();

    });

    loadDisabledPets();

  }



  @override

  void dispose() {

    _petsChannel?.unsubscribe();

    _tableScrollController.dispose();

    super.dispose();

  }



  void onStatusChanged(String? status) {

    if (status == null) return;

    _filterStatus = status;

    applyFilters();

  }



  void onAgeChanged(String? age) {

    if (age == null) return;

    _filterAge = age;

    applyFilters();

  }



  Future<void> deletePet(Map<String, dynamic> pet) async {

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

                    fontSize: 14,

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

                  padding: const EdgeInsets.symmetric(

                    horizontal: 20,

                    vertical: 12,

                  ),

                ),

                child: const Text(

                  'Delete',

                  style: TextStyle(

                    color: Colors.white,

                    fontWeight: FontWeight.bold,

                    fontFamily: 'Montserrat',

                    fontSize: 14,

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

        setState(() {

          petsUnderMedication.removeWhere((p) => p['pet_id'] == petId);

        });

        _showSnackBar('$petName has been permanently deleted.', Colors.green);

      }

    } catch (e) {

      debugPrint('❌ Error deleting pet: $e');

      if (mounted) {

        _showSnackBar('Failed to delete $petName.', Colors.red);

        debugPrint('❌ Failed to delete $petName: $e');

      }

    }

  }



  Future<void> movePet(Map<String, dynamic> pet, String destination) async {

    try {

      final petId =

          pet['pet_id'] is int

              ? pet['pet_id']

              : int.tryParse(pet['pet_id'].toString());



      if (petId == null) {

        debugPrint('❌ Invalid pet ID');

        return;

      }



      final petName = pet['name'] ?? 'Unnamed';



      Future<void> notify(String message) async {

        await supabase.from('notifications').insert({

          'title': 'Pet Moved',

          'message': message,

          'pet_id': petId,

          'created_at': DateTime.now().toIso8601String(),

        });

      }



      void updateLocal(String newStatus) {

        setState(() {

          final i = _filteredPets.indexWhere((p) => p['pet_id'] == petId);

          if (i != -1) _filteredPets[i]['status'] = newStatus;



          final ii = pets.indexWhere((p) => p['pet_id'] == petId);

          if (ii != -1) pets[ii]['status'] = newStatus;

        });

      }



      await supabase.from('pet_medications').delete().eq('pet_id', petId);

      await supabase.from('adoptable_pets').delete().eq('pet_id', petId);



      if (destination == 'medication') {

        await supabase.from('pet_medications').insert({

          'medication_id': pet['medication_id'],

          'name': petName,

          'pet_id': petId,

          'shelter_id': pet['shelter_id'],

          'color': pet['color'] ?? 'Unknown',

          'sex': pet['sex'] ?? 'Unknown',

          'breed': pet['breed'] ?? '',

          'type': pet['type'] ?? '',

          'age': pet['age'] ?? 'Unknown',

          'energy': pet['energy'] ?? 'Low',

          'description': pet['description'] ?? '',

          'image_url_1': pet['image_url_1'] ?? '',

          'status': 'Under Medication',

          'created_at': DateTime.now().toIso8601String(),

          'vaccination_status': pet['vaccination_status'] ?? 'Not Vaccinated',

          'neutered_spayed_details':

              pet['neutered_spayed_details'] ?? 'Not Neutered/Spayed',

          'deworming_status': pet['deworming_status'] ?? 'Not Dewormed',

          'disease_type': pet['disease_type'] ?? 'N/A',

          'disease_details': pet['disease_details'],

          'has_disability': pet['has_disability'] ?? 'No',

        });



        await supabase

            .from('pets')

            .update({'status': 'Under Medication'})

            .eq('pet_id', petId);

        await notify("$petName moved to Medication.");

        updateLocal("Under Medication");

      } else if (destination == 'adoption') {

        await supabase.from('adoptable_pets').upsert({

          'pet_id': petId,

          'name': petName,

          'status': 'Ready For Adoption',

          'color': pet['color'] ?? 'Unknown',

          'sex': pet['sex'] ?? 'Unknown',

          'breed': pet['breed'] ?? '',

          'type': pet['type'] ?? '',

          'age': pet['age'] ?? 'Unknown',

          'energy': pet['energy'] ?? 'Low',

          'description': pet['description'] ?? '',

          'image_url_1': pet['image_url_1'] ?? '',

          'shelter_id': pet['shelter_id'],

          'created_at': pet['created_at'],

          'has_disability': pet['has_disability'] ?? 'No',

          'vaccination_status': pet['vaccination_status'],

          'neutered_spayed_details': pet['neutered_spayed_details'],

          'deworming_status': pet['deworming_status'],

          'surgery_type': pet['surgery_type'],

          'subadmin_id': pet['subadmin_id'],

        }, onConflict: 'pet_id');



        await supabase

            .from('pets')

            .update({'status': 'Ready For Adoption'})

            .eq('pet_id', petId);

        await notify("$petName moved to Adoption.");

        updateLocal("Ready For Adoption");

      }



      _showSnackBar('$petName moved to $destination.', Colors.green);

    } catch (e) {

      debugPrint("❌ Error: $e");



      _showSnackBar('Failed to move pet.', Colors.red);

      debugPrint('❌ Failed to move pet: $e');

    }

  }



  void subscribeToRealtimeUpdates() {

    _petsChannel = supabase

        .channel('public:pets:disabled')

        .onPostgresChanges(

          event: PostgresChangeEvent.insert,

          schema: 'public',

          table: 'pets',

          callback: (payload) {

            debugPrint('🟢 Realtime INSERT: ${payload.newRecord}');

            handleRealtimeInsert(payload.newRecord);

          },

        )

        .onPostgresChanges(

          event: PostgresChangeEvent.update,

          schema: 'public',

          table: 'pets',

          callback: (payload) {

            debugPrint('🟡 Realtime UPDATE: ${payload.newRecord}');

            handleRealtimeUpdate(payload.newRecord);

          },

        )

        .onPostgresChanges(

          event: PostgresChangeEvent.delete,

          schema: 'public',

          table: 'pets',

          callback: (payload) {

            debugPrint('🔴 Realtime DELETE: ${payload.oldRecord}');

            handleRealtimeDelete(payload.oldRecord);

          },

        )

        .subscribe((status, [error]) {

          debugPrint('📡 Realtime pets status: $status');

        });

  }



  bool isDisabledPet(Map<String, dynamic> pet) {

    final val = pet['has_disability'];

    if (val == null) return false;

    final s = val.toString().toLowerCase().trim();

    return s == 'true' || s == 'yes' || s == '1';

  }



  void handleRealtimeInsert(Map<String, dynamic> newRecord) {

    if (!mounted) return;

    if (isDisabledPet(newRecord)) {

      setState(() {

        _disabledPets.insert(0, newRecord);

        applyFilters();

      });

    }

  }



  void handleRealtimeUpdate(Map<String, dynamic> updatedRecord) {

    if (!mounted) return;

    final petId = updatedRecord['pet_id'];

    setState(() {

      final index = _disabledPets.indexWhere((p) => p['pet_id'] == petId);

      if (isDisabledPet(updatedRecord)) {

        if (index != -1) {

          _disabledPets[index] = updatedRecord;

        } else {

          _disabledPets.insert(0, updatedRecord);

        }

      } else {

        if (index != -1) _disabledPets.removeAt(index);

      }

      applyFilters();

    });

  }



  void handleRealtimeDelete(Map<String, dynamic> oldRecord) {

    if (!mounted) return;

    final petId = oldRecord['pet_id'];

    setState(() {

      _disabledPets.removeWhere((p) => p['pet_id'] == petId);

      applyFilters();

    });

  }



  Future<void> moveToShelter(Map<String, dynamic> pet) async {

    try {

      final petId =

          pet['pet_id'] is int

              ? pet['pet_id']

              : int.tryParse(pet['pet_id'].toString());

      if (petId == null) {

        debugPrint('❌ Invalid pet ID');

        return;

      }



      final shelters = await supabase

          .from('shelters')

          .select('shelter_id, name')

          .order('shelter_id', ascending: true);



      // AFTER:

      if (shelters.isEmpty) {

        if (mounted) {

          _showSnackBar('No shelters available.', Colors.red); // ✅ accurate

        }

        return;

      }



      String? selectedShelterId;



      await showDialog(

        context: context,

        builder: (ctx) {

          return AlertDialog(

            backgroundColor: const Color(0xFF2D2D2D),

            title: const Text(

              'Move to Shelter',

              style: TextStyle(

                color: Colors.white,

                fontWeight: FontWeight.bold,

                fontFamily: 'Montserrat',

              ),

            ),

            content: StatefulBuilder(

              builder: (context, setState) {

                return DropdownButtonFormField<String>(

                  dropdownColor: const Color(0xFF3C3C3E),

                  decoration: const InputDecoration(

                    labelText: 'Select Shelter',

                    labelStyle: TextStyle(

                      color: Colors.white70,

                      fontFamily: 'Montserrat',

                    ),

                    enabledBorder: OutlineInputBorder(

                      borderSide: BorderSide(color: Colors.white38),

                    ),

                    focusedBorder: OutlineInputBorder(

                      borderSide: BorderSide(color: Colors.blueAccent),

                    ),

                  ),

                  value: selectedShelterId,

                  items:

                      shelters.map<DropdownMenuItem<String>>((shelter) {

                        final name = shelter['name'] ?? 'Unnamed Shelter';

                        final id = shelter['shelter_id'].toString();

                        return DropdownMenuItem<String>(

                          value: id,

                          child: Text(

                            name,

                            style: const TextStyle(

                              color: Colors.white,

                              fontFamily: 'Montserrat',

                            ),

                          ),

                        );

                      }).toList(),

                  onChanged:

                      (value) => setState(() => selectedShelterId = value),

                );

              },

            ),

            actions: [

              TextButton(

                onPressed: () => Navigator.pop(ctx),

                child: const Text(

                  'Cancel',

                  style: TextStyle(

                    color: Colors.white70,

                    fontFamily: 'Montserrat',

                  ),

                ),

              ),

              TextButton(

                onPressed: () {

                  if (selectedShelterId != null) {

                    Navigator.pop(ctx, selectedShelterId);

                  } else {

                    _showSnackBar('Failed to move pet.', Colors.red);

                  }

                },

                child: const Text(

                  'Confirm',

                  style: TextStyle(

                    color: Colors.greenAccent,

                    fontFamily: 'Montserrat',

                  ),

                ),

              ),

            ],

          );

        },

      ).then((value) => selectedShelterId = value);



      if (selectedShelterId == null) return;



      await supabase

          .from('pets')

          .update({

            'shelter_id': int.parse(selectedShelterId!),

            'status': 'In Shelter',

          })

          .eq('pet_id', petId);



      setState(() {

        final index = _filteredPets.indexWhere((p) => p['pet_id'] == petId);

        if (index != -1) {

          _filteredPets[index]['shelter_id'] = int.parse(selectedShelterId!);

          _filteredPets[index]['status'] = 'In Shelter';

        }

      });



      if (mounted) {

        _showSnackBar(

          '${pet['name']} has been moved to the selected shelter.',

          Colors.green,

        );

      }

    } catch (e, stack) {

      debugPrint('❌ Error moving to shelter: $e');

      debugPrint(stack.toString());

      if (mounted) {

        _showSnackBar(

          'Failed to move ${pet['name']} to shelter.',

          Colors.red,

        ); // ✅ pet IS defined here

        setState(

          () => _isLoading = false,

        ); // remove the loadShelterPets() call in catch

      }

    }

  }



  Future<void> loadDisabledPets() async {

    try {

      final response = await supabase

          .from('pets')

          .select('*, shelters(shelter_id, name)')

          .order('created_at', ascending: false);



      final allPets = List<Map<String, dynamic>>.from(response);



      _disabledPets =

          allPets.where((pet) {

            final val = pet['has_disability'];

            if (val == null) return false;

            final s = val.toString().toLowerCase().trim();

            return s == 'true' || s == 'yes' || s == '1';

          }).toList();



      debugPrint('✅ Loaded ${_disabledPets.length} pets with disabilities');



      applyFilters();

      setState(() => _isLoading = false);

    } catch (e) {

      debugPrint("❌ Error loading disabled pets: $e");

      if (mounted) {

        setState(() => _isLoading = false);

        _showSnackBar(

          'Failed to load pets with disabilities.',

          Colors.red,

        ); // ✅ fixed

      }

    }

  }



  void applyFilters() {

    List<Map<String, dynamic>> tempList = List.from(_disabledPets);



    if (_filterStatus != 'All') {

      tempList =

          tempList

              .where((pet) => (pet['status'] ?? '') == _filterStatus)

              .toList();

    }



    if (_filterAge != 'All') {

      tempList =

          tempList.where((pet) {

            final petAge = int.tryParse(pet['age']?.toString() ?? '0') ?? 0;

            switch (_filterAge) {

              case 'Young':

                return petAge <= 2;

              case 'Adult':

                return petAge > 2 && petAge <= 8;

              case 'Senior':

                return petAge > 8;

              default:

                return true;

            }

          }).toList();

    }



    if (_searchQuery.isNotEmpty) {

      final query = _searchQuery.toLowerCase();

      tempList =

          tempList

              .where(

                (pet) => (pet['name']?.toString().toLowerCase() ?? '').contains(

                  query,

                ),

              )

              .toList();

    }



    setState(() {

      _filteredPets = tempList;

    });

  }



  Future<void> fetchPetsFromDatabase() async {

    final supabase = Supabase.instance.client;

    try {

      final response = await supabase

          .from('pets')

          .select('*')

          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> allPets =

          (response as List).map((e) => Map<String, dynamic>.from(e)).toList();

      List<Map<String, dynamic>> filteredPets = List.from(allPets);

      if (_filterStatus != 'All') {

        filteredPets =

            filteredPets

                .where(

                  (pet) =>

                      (pet['status'] ?? '').toString().toLowerCase() ==

                      _filterStatus.toLowerCase(),

                )

                .toList();

      }

      if (_filterAge != 'All') {

        filteredPets =

            filteredPets.where((pet) {

              final petAge = int.tryParse(pet['age']?.toString() ?? '0') ?? 0;

              switch (_filterAge) {

                case 'Young':

                  return petAge <= 2;

                case 'Adult':

                  return petAge > 2 && petAge <= 8;

                case 'Senior':

                  return petAge > 8;

                default:

                  return true;

              }

            }).toList();

      }

      setState(() {

        _pets = filteredPets;

      });

    } catch (error) {

      debugPrint('❌ Error fetching pets: $error');

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text(

            'Failed to load pets. Please try again later.',

            style: TextStyle(fontFamily: 'Montserrat'),

          ),

          backgroundColor: Colors.redAccent,

        ),

      );

    }

  }



  Future<void> loadProfileImageForAvatar() async {

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

        final finalUrl =

            '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

        publicUrl = finalUrl;

      }



      if (mounted) {

        setState(() {

          _cachedProfileImage = publicUrl;

          _isLoadingAvatar = false;

        });

      }

    } catch (e, stackTrace) {

      debugPrint('❌ Error loading profile image: $e');

      if (mounted) setState(() => _isLoadingAvatar = false);

    }

  }



  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();



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

        key: scaffoldKey,

        backgroundColor: const Color(0xFF2D2D30),

        drawer:

            isDesktop

                ? null

                : Drawer(
                  width: 200,
                  backgroundColor: const Color(0xFF1F1F22),
                  child: SafeArea(child: _buildSidebar()),
                ),

        body: Row(

          children: [

            if (isDesktop) _buildSidebar(),

            Expanded(

              child: Column(

                children: [

                  buildTopHeader(),

                  buildTopControls(),

                  Expanded(

                    child:
                        _isLoading
                            ? const SkeletonPetGrid()
                            : _filteredPets.isEmpty

                            ? const Center(

                              child: Text(

                                "No pets with disabilities found.",

                                style: TextStyle(

                                  color: Colors.white70,

                                  fontSize: 18,

                                  fontFamily: "Montserrat",

                                ),

                              ),

                            )

                            : Align(

                              alignment: Alignment.topLeft,

                              child: buildPetGrid(),

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



  Widget buildPetGrid() {

    return SingleChildScrollView(

      padding: const EdgeInsets.all(16),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [buildPetTable()],

      ),

    );

  }



  Widget buildPetTable() {

    return Container(

      width: double.infinity,

      decoration: BoxDecoration(

        color: const Color(0xFF3C3C3E),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.white12),

      ),

      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _tableScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _tableScrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth > 900 ? constraints.maxWidth : 900,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF2A2A2D)),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xFF4A4A4D);
                    }
                    return const Color(0xFF3C3C3E);
                  }),
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  headingTextStyle: const TextStyle(
                    color: Colors.white60,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  dividerThickness: 0.5,
                  columns: const [
                    DataColumn(label: Expanded(child: Text('Pet'))),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Age')),
                    DataColumn(label: Text('Sex')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _filteredPets.map((pet) => buildPetRow(pet)).toList(),
                ),
              ),
            ),
          );
        },
      ),

    );

  }



  DataRow buildPetRow(Map<String, dynamic> pet) {

    final name = pet['name'] ?? 'Unnamed';

    final breed = pet['breed'] ?? 'Unknown';

    final type = pet['type'] ?? '—';

    final age = pet['age']?.toString() ?? '—';

    final gender = pet['sex'] ?? '—';

    final status = pet['status'] ?? '—';

    final imageUrl = pet['image_url_1'] ?? '';

    final isUnderMedication = status.contains('Under Medication');



    Color statusColor() {

      switch (status) {

        case 'In Shelter':

          return Colors.blue;

        case 'Under Medication':

          return Colors.orange;

        case 'Ready For Adoption':

          return Colors.green;

        default:

          return Colors.grey;

      }

    }



    return DataRow(

      cells: [

        DataCell(

          Row(

            children: [

              ClipRRect(

                borderRadius: BorderRadius.circular(8),

                child:

                    imageUrl.isNotEmpty

                        ? Image.network(

                          imageUrl,

                          width: 38,

                          height: 38,

                          fit: BoxFit.cover,

                          errorBuilder:

                              (_, __, ___) => Container(

                                width: 38,

                                height: 38,

                                color: Colors.grey[800],

                                child: const Icon(

                                  Icons.pets,

                                  color: Colors.white38,

                                  size: 18,

                                ),

                              ),

                        )

                        : Container(

                          width: 38,

                          height: 38,

                          color: Colors.grey[800],

                          child: const Icon(

                            Icons.pets,

                            color: Colors.white38,

                            size: 18,

                          ),

                        ),

              ),

              const SizedBox(width: 10),

              Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  Text(

                    name,

                    style: const TextStyle(

                      color: Colors.white,

                      fontFamily: 'Montserrat',

                      fontWeight: FontWeight.w600,

                      fontSize: 13,

                    ),

                  ),

                  Text(

                    breed,

                    style: const TextStyle(

                      color: Colors.white54,

                      fontFamily: 'Montserrat',

                      fontSize: 11,

                    ),

                  ),

                ],

              ),

            ],

          ),

        ),



        DataCell(

          Text(

            type,

            style: const TextStyle(

              color: Colors.white70,

              fontFamily: 'Montserrat',

              fontSize: 13,

            ),

          ),

        ),



        DataCell(

          Text(

            age,

            style: const TextStyle(

              color: Colors.white70,

              fontFamily: 'Montserrat',

              fontSize: 13,

            ),

          ),

        ),



        DataCell(

          Text(

            gender,

            style: const TextStyle(

              color: Colors.white70,

              fontFamily: 'Montserrat',

              fontSize: 13,

            ),

          ),

        ),



        DataCell(

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

            decoration: BoxDecoration(

              color: statusColor().withOpacity(0.15),

              borderRadius: BorderRadius.circular(20),

              border: Border.all(color: statusColor().withOpacity(0.4)),

            ),

            child: Text(

              status,

              style: TextStyle(

                color: statusColor(),

                fontFamily: 'Montserrat',

                fontSize: 11,

                fontWeight: FontWeight.w600,

              ),

            ),

          ),

        ),



        DataCell(

          PopupMenuButton<String>(

            icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),

            color: const Color(0xFF2A2A2D),

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(10),

            ),

            onSelected: (value) {

              switch (value) {

                case 'view':

                  _showPetDetailDialog(context, pet);

                  break;

                case 'edit':

                  showEditPetDialog(context, pet);

                  break;

                case 'adoption':

                  movePet(pet, 'adoption');

                  break;

                case 'medication':

                  movePet(pet, 'medication');

                  break;

                case 'shelter':

                  moveToShelter(pet);

                  break;

                case 'delete':

                  deletePet(pet);

                  break;

              }

            },

            itemBuilder:

                (_) => [

                  _menuItem(

                    'view',

                    Icons.info_outline,

                    'View Details',

                    Colors.teal,

                  ),

                  _menuItem('edit', Icons.edit, 'Edit', Colors.orange),

                  if (!isUnderMedication) ...[

                    _menuItem(

                      'adoption',

                      Icons.pets,

                      'Move to Adoption',

                      Colors.blue,

                    ),

                    _menuItem(

                      'medication',

                      Icons.medical_services,

                      'Move to Medication',

                      Colors.green,

                    ),

                    _menuItem(

                      'shelter',

                      Icons.home_work,

                      'Move to Shelter',

                      Colors.deepPurple,

                    ),

                  ],

                  const PopupMenuDivider(),

                  _menuItem('delete', Icons.delete, 'Delete', Colors.red),

                ],

          ),

        ),

      ],

    );

  }



  PopupMenuItem<String> _menuItem(

    String value,

    IconData icon,

    String label,

    Color color,

  ) {

    return PopupMenuItem<String>(

      value: value,

      child: Row(

        children: [

          Icon(icon, color: color, size: 16),

          const SizedBox(width: 10),

          Text(

            label,

            style: TextStyle(

              color: color,

              fontFamily: 'Montserrat',

              fontSize: 13,

              fontWeight: FontWeight.w500,

            ),

          ),

        ],

      ),

    );

  }



  Widget buildFullWidthButton({

    required String label,

    required IconData icon,

    required Color color,

    required VoidCallback onPressed,

  }) {

    return SizedBox(

      width: double.infinity,

      height: 44,

      child: ElevatedButton.icon(

        onPressed: onPressed,

        icon: Icon(icon, color: Colors.white, size: 18),

        label: Text(

          label,

          style: const TextStyle(

            color: Colors.white,

            fontFamily: 'Montserrat',

            fontWeight: FontWeight.w600,

            fontSize: 13,

          ),

        ),

        style: ElevatedButton.styleFrom(

          backgroundColor: color,

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(10),

          ),

          padding: const EdgeInsets.symmetric(horizontal: 8),

        ),

      ),

    );

  }



  Future<void> showEditPetDialog(

    BuildContext context,

    Map<String, dynamic> pet,

  ) async {

    final nameController = TextEditingController(text: pet['name'] ?? '');

    final colorController = TextEditingController(text: pet['color'] ?? '');

    final breedController = TextEditingController(text: pet['breed'] ?? '');

    final ageController = TextEditingController(

      text: pet['age']?.toString() ?? '',

    );

    final parsedAge = _parseAge(pet['age']?.toString());

    final mainAgeNumberCtrl = TextEditingController(text: parsedAge['number']);

    String mainAgeUnit = parsedAge['unit'] ?? 'month(s) old';

    final descriptionController = TextEditingController(

      text: pet['description'] ?? '',

    );



    Uint8List? imageBytes;

    String? imageName;

    final rawDisability = pet['has_disability'];

    String hasDisability =

        (rawDisability == true ||

                rawDisability.toString().toLowerCase() == 'Yes')

            ? 'Yes'

            : 'No';



    String selectedType = pet['type'] ?? 'Cat';

    String selectedEnergy = pet['energy'] ?? 'Low';

    String selectedGender = pet['sex'] ?? 'Male';



    await showDialog(

      context: context,

      barrierDismissible: false,

      builder: (BuildContext context) {

        return StatefulBuilder(

          builder: (context, setDialogState) {

            return AlertDialog(

              backgroundColor: const Color(0xFF1E1E1E),

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(20),

              ),

              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),

              contentPadding: const EdgeInsets.symmetric(

                horizontal: 24,

                vertical: 10,

              ),

              title: Row(

                children: const [

                  Icon(Icons.pets, color: Colors.orange, size: 26),

                  SizedBox(width: 10),

                  Text(

                    "Edit Pet",

                    style: TextStyle(

                      color: Colors.white,

                      fontFamily: "Montserrat",

                      fontWeight: FontWeight.bold,

                      fontSize: 20,

                    ),

                  ),

                ],

              ),

              content: SingleChildScrollView(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Center(

                      child: Column(

                        children: [

                          GestureDetector(

                            onTap: () async {

                              final pickedFile = await ImagePicker().pickImage(

                                source: ImageSource.gallery,

                              );

                              if (pickedFile != null) {

                                final bytes = await pickedFile.readAsBytes();

                                setDialogState(() {

                                  imageBytes = bytes;

                                  imageName = pickedFile.name;

                                });

                              }

                            },

                            child: CircleAvatar(

                              radius: 55,

                              backgroundColor: Colors.grey[850],

                              backgroundImage:

                                  imageBytes != null

                                      ? MemoryImage(imageBytes!)

                                      : (pet['image_url_1'] != null

                                              ? NetworkImage(pet['image_url_1'])

                                              : null)

                                          as ImageProvider<Object>?,

                              child:

                                  (imageBytes == null &&

                                          pet['image_url_1'] == null)

                                      ? const Icon(

                                        Icons.add_a_photo,

                                        color: Colors.white70,

                                        size: 35,

                                      )

                                      : null,

                            ),

                          ),

                          const SizedBox(height: 10),

                          const Text(

                            "Tap to change photo",

                            style: TextStyle(

                              color: Colors.white60,

                              fontFamily: "Montserrat",

                              fontSize: 13,

                            ),

                          ),

                        ],

                      ),

                    ),

                    const SizedBox(height: 25),

                    const Text(

                      "Basic Details",

                      style: TextStyle(

                        color: Colors.orange,

                        fontWeight: FontWeight.bold,

                        fontSize: 15,

                        fontFamily: "Montserrat",

                      ),

                    ),

                    const Divider(

                      color: Colors.orange,

                      thickness: 0.5,

                      endIndent: 150,

                    ),

                    const SizedBox(height: 10),

                    buildTextField("Name", nameController),

                    const SizedBox(height: 12),

                    buildTextField("Color", colorController),

                    const SizedBox(height: 12),

                    buildDropdownField(

                      label: "Type",

                      value: selectedType,

                      options: ['Cat', 'Dog'],

                      onChanged:

                          (value) =>

                              setDialogState(() => selectedType = value!),

                    ),

                    const SizedBox(height: 12),

                    buildDropdownField(

                      label: "Energy Level",

                      value: selectedEnergy,

                      options: ['Low', 'Medium', 'High'],

                      onChanged:

                          (value) =>

                              setDialogState(() => selectedEnergy = value!),

                    ),

                    const SizedBox(height: 12),

                    buildTextField("Breed", breedController),

                    const SizedBox(height: 12),

                    _buildAgeFieldRow(

                      "Age",

                      mainAgeNumberCtrl,

                      mainAgeUnit,

                      (v) => setDialogState(() => mainAgeUnit = v!),

                      onChangedValue: () {

                        ageController.text = _formatAgeText(mainAgeNumberCtrl.text, mainAgeUnit);

                      },

                    ),

                    const SizedBox(height: 12),

                    const Text(

                      "Additional Info",

                      style: TextStyle(

                        color: Colors.orange,

                        fontWeight: FontWeight.bold,

                        fontSize: 15,

                        fontFamily: "Montserrat",

                      ),

                    ),

                    const Divider(

                      color: Colors.orange,

                      thickness: 0.5,

                      endIndent: 150,

                    ),

                    const SizedBox(height: 10),

                    buildTextField("Description", descriptionController),

                    const SizedBox(height: 12),

                    buildDropdownField(

                      label: "Sex",

                      value: selectedGender,

                      options: ['Male', 'Female'],

                      onChanged:

                          (value) =>

                              setDialogState(() => selectedGender = value!),

                    ),

                    const SizedBox(height: 12),

                    buildDropdownField(

                      label: "Has Disability?",

                      value: hasDisability,

                      options: ['Yes', 'No'],

                      onChanged:

                          (value) => setDialogState(

                            () => hasDisability = value ?? 'No',

                          ),

                    ),

                  ],

                ),

              ),

              actionsPadding: const EdgeInsets.symmetric(

                horizontal: 20,

                vertical: 15,

              ),

              actions: [

                TextButton(

                  onPressed: () => Navigator.pop(context),

                  style: TextButton.styleFrom(

                    foregroundColor: Colors.white70,

                    textStyle: const TextStyle(fontFamily: "Montserrat"),

                  ),

                  child: const Text(

                    "Cancel",

                    style: TextStyle(fontFamily: 'Montserrat'),

                  ),

                ),

                ElevatedButton.icon(

                  icon: const Icon(Icons.check, color: Colors.white, size: 18),

                  label: const Text(

                    "Save Changes",

                    style: TextStyle(

                      color: Colors.white,

                      fontFamily: "Montserrat",

                      fontWeight: FontWeight.w600,

                    ),

                  ),

                  style: ElevatedButton.styleFrom(

                    backgroundColor: Colors.orange,

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(10),

                    ),

                    padding: const EdgeInsets.symmetric(

                      horizontal: 20,

                      vertical: 12,

                    ),

                  ),

                  onPressed: () async {

                    if (nameController.text.trim().isEmpty ||

                        colorController.text.trim().isEmpty ||

                        breedController.text.trim().isEmpty ||

                        ageController.text.trim().isEmpty ||

                        descriptionController.text.trim().isEmpty) {

                      ScaffoldMessenger.of(context).showSnackBar(

                        const SnackBar(

                          content: Text(

                            "Please fill out all fields.",

                            style: TextStyle(fontFamily: 'Montserrat'),

                          ),

                          backgroundColor: Colors.red,

                        ),

                      );

                      return;

                    }



                    try {

                      String? imageUrl = pet['image_url_1'];



                      if (imageBytes != null && imageName != null) {

                        final filePath =

                            'pets/images/${DateTime.now().millisecondsSinceEpoch}_$imageName';

                        await supabase.storage

                            .from('pets')

                            .uploadBinary(filePath, imageBytes!);

                        imageUrl = supabase.storage

                            .from('pets')

                            .getPublicUrl(filePath);

                      }



                      await supabase

                          .from('pets')

                          .update({

                            'name': nameController.text.trim(),

                            'color': colorController.text.trim(),

                            'breed': breedController.text.trim(),

                            'age': ageController.text.trim(),

                            'type': selectedType,

                            'energy': selectedEnergy,

                            'sex': selectedGender,

                            'description': descriptionController.text.trim(),

                            'has_disability': hasDisability == 'Yes',

                            'image_url_1': imageUrl,

                          })

                          .eq('pet_id', pet['pet_id']);



                      onPetAdded();

                      Navigator.pop(context);



                      ScaffoldMessenger.of(context).showSnackBar(

                        const SnackBar(

                          content: Text("✅ Pet successfully updated!"),

                          backgroundColor: Colors.green,

                        ),

                      );

                    } catch (e) {

                      ScaffoldMessenger.of(context).showSnackBar(

                        SnackBar(

                          content: Text("❌ Error updating pet."),

                          backgroundColor: Colors.red,

                        ),

                      );

                      debugPrint('❌ Error updating pet: $e');

                    }

                  },

                ),

              ],

            );

          },

        );

      },

    );

  }



  void onPetAdded() {

    loadDisabledPets();

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



  Widget _buildAgeFieldRow(

    String label,

    TextEditingController numCtrl,

    String selectedUnit,

    ValueChanged<String?> onUnitChanged, {

    required VoidCallback onChangedValue,

  }) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 10),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            label,

            style: const TextStyle(

              color: Colors.orange,

              fontFamily: 'Montserrat',

              fontWeight: FontWeight.bold,

              fontSize: 13,

            ),

          ),

          const SizedBox(height: 5),

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



  Widget buildDropdownField({

    required String label,

    required String? value,

    required List<String> options,

    required ValueChanged<String?> onChanged,

  }) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          label,

          style: const TextStyle(

            color: Colors.white70,

            fontFamily: "Montserrat",

            fontSize: 13,

            fontWeight: FontWeight.w600,

          ),

        ),

        const SizedBox(height: 5),

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

              isExpanded: true,

              value: value,

              dropdownColor: const Color(0xFF252526),

              style: const TextStyle(

                color: Colors.white,

                fontFamily: 'Montserrat',

                fontSize: 14,

              ),

              hint: Text(

                'Select $label',

                style: const TextStyle(

                  color: Colors.white30,

                  fontFamily: 'Montserrat',

                  fontSize: 14,

                ),

              ),

              items:

                  options

                      .map(

                        (opt) => DropdownMenuItem(

                          value: opt,

                          child: Text(

                            opt,

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

    );

  }



  Widget buildTextField(

    String label,

    TextEditingController controller, {

    TextInputType keyboardType = TextInputType.text,

    List<TextInputFormatter>? inputFormatters,

  }) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 10),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            label,

            style: const TextStyle(

              color: Colors.orange,

              fontFamily: 'Montserrat',

              fontWeight: FontWeight.bold,

              fontSize: 13,

            ),

          ),

          const SizedBox(height: 5),

          TextField(

            controller: controller,

            keyboardType: keyboardType,

            inputFormatters: inputFormatters,

            style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 14),

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



  Future<void> loadShelterPets() async {

    if (_shelters.isEmpty) return;



    final shelterId = _shelters[_currentShelterIndex]['shelter_id'];

    setState(() => _isLoading = true);



    try {

      final response = await supabase

          .from('pets')

          .select()

          .eq('shelter_id', shelterId);



      final data =

          (response as List)

              .map<Map<String, dynamic>>(

                (pet) => {

                  'pet_id': pet['pet_id'],

                  'name': pet['name'] ?? '',

                  'type': pet['type'] ?? '',

                  'status': pet['status'] ?? '',

                  'image_url_1': pet['image_url_1'] ?? '',

                  'breed': pet['breed'] ?? '',

                  'age': pet['age'] ?? '',

                  'sex': pet['sex'] ?? '',

                  'created_at': pet['created_at'] ?? '',

                  'shelter_id': pet['shelter_id'],

                  'description': pet['description'],

                  'energy': pet['energy'],

                  'color': pet['color'] ?? '',

                },

              )

              .toList();



      setState(() {

        _allPets = data;

        _pets = List<Map<String, dynamic>>.from(data);

        _filteredPets = List<Map<String, dynamic>>.from(data);

        loadBreedsFromPets();

        _isLoading = false;

      });

    } catch (e) {

      debugPrint("❌ Error loading pets: $e");

      if (mounted) {

        setState(() => _isLoading = false);

        _showSnackBar(

          'Failed to load shelter pets.',

          Colors.red,

        ); // ✅ optional but consistent

      }

    }

  }



  void loadBreedsFromPets() {

    final uniqueBreeds =

        _pets

            .map((pet) => pet['breed']?.toString() ?? '')

            .where((breed) => breed.isNotEmpty)

            .toSet()

            .toList();



    setState(() {

      _breeds = ['All', ...uniqueBreeds];

    });

  }



  void showPetQrDialog(BuildContext context, Map<String, dynamic> pet) {

    final petId = pet['pet_id'];

    final qrUrl = pet['qr_code_url'];

    final petName = pet['name'] ?? 'Unnamed';

    final webLink = pet['web_link'] ?? 'https://apawtmentpets.com/pet/$petId';



    Future<void> downloadQr() async {

      try {

        Uint8List bytes;



        if (qrUrl != null && qrUrl.isNotEmpty) {

          final response = await http.get(Uri.parse(qrUrl));

          bytes = response.bodyBytes;

        } else {

          final qrValidationResult = QrValidator.validate(

            data: webLink,

            version: QrVersions.auto,

            errorCorrectionLevel: QrErrorCorrectLevel.L,

          );

          final qrCode = qrValidationResult.qrCode!;

          final painter = QrPainter.withQr(

            qr: qrCode,



            color: Colors.black,



            emptyColor: Colors.white,

            gapless: true,

          );

          final picData = await painter.toImageData(

            1024,

            format: ui.ImageByteFormat.png,

          );

          bytes = picData!.buffer.asUint8List();

        }



        final base64 = base64Encode(bytes);

        final anchor =

            html.AnchorElement(href: 'data:image/png;base64,$base64')

              ..download = '$petName-QR.png'

              ..click();

      } catch (e) {

        ScaffoldMessenger.of(

          context,

        ).showSnackBar(SnackBar(content: Text('Error downloading QR Code.')));

        debugPrint('Error downloading QR Code: $e');

      }

    }



    showDialog(

      context: context,

      builder:

          (context) => AlertDialog(

            backgroundColor: const Color(0xFF1E1E1E),

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(20),

            ),

            title: Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Row(

                  children: [

                    const Icon(Icons.qr_code_2, color: Colors.orangeAccent),

                    const SizedBox(width: 8),

                    Text(

                      "$petName QR Code",

                      style: const TextStyle(

                        color: Colors.white,

                        fontFamily: "Montserrat",

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ],

                ),

                IconButton(

                  icon: const Icon(Icons.close, color: Colors.white),

                  onPressed: () => Navigator.pop(context),

                ),

              ],

            ),

            content: SizedBox(

              width: 260,

              child: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  Center(

                    child: SizedBox(

                      width: 200,

                      height: 200,

                      child:

                          qrUrl != null && qrUrl.isNotEmpty

                              ? Image.network(qrUrl, fit: BoxFit.contain)

                              : QrImageView(

                                data: webLink,

                                version: QrVersions.auto,

                              ),

                    ),

                  ),

                  const SizedBox(height: 15),

                  SelectableText(

                    webLink,

                    textAlign: TextAlign.center,

                    style: const TextStyle(

                      color: Colors.orangeAccent,

                      fontSize: 13,

                      fontFamily: "Montserrat",

                    ),

                  ),

                ],

              ),

            ),

            actions: [

              TextButton(

                onPressed: () => Navigator.pop(context),

                child: const Text(

                  "Close",

                  style: TextStyle(

                    color: Colors.white70,

                    fontFamily: "Montserrat",

                  ),

                ),

              ),

              TextButton(

                onPressed: downloadQr,

                child: const Text(

                  "Download QR",

                  style: TextStyle(

                    color: Colors.orangeAccent,

                    fontFamily: "Montserrat",

                  ),

                ),

              ),

            ],

          ),

    );

  }



  Widget buildHoverButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool wide = false,
  }) {
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return MouseRegion(
          onEnter: (_) {
            if (mounted) setLocalState(() => isHovered = true);
          },
          onExit: (_) {
            if (mounted) setLocalState(() => isHovered = false);
          },
          child: GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              height: wide ? 65 : 60,
              width: wide ? 250 : 120,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slideAnimation,
                        child: child,
                      ),
                    );
                  },
                  child:
                      isHovered
                          ? Icon(
                            icon,
                            color: Colors.white,
                            size: 26,
                            key: ValueKey('icon_$label'),
                          )
                          : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                key: ValueKey('text_$label'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Montserrat',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }



  Widget buildFooter(BuildContext context) {

    return Container(

      height: 40,

      color: const Color(0xFF181818),

      padding: const EdgeInsets.symmetric(horizontal: 24),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: const [

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



  Widget buildTopHeader() {

    final screenWidth = MediaQuery.of(context).size.width;

    final bool isDesktop = screenWidth >= 1000;

    final bool isMobile = screenWidth < 600;



    return Container(

      padding: EdgeInsets.symmetric(

        horizontal: isDesktop ? 16 : 8,

        vertical: 12,

      ),

      child: Row(

        children: [

          if (isMobile) ...[

            IconButton(

              icon: const Icon(Icons.menu, color: Colors.white),

              padding: EdgeInsets.zero,

              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),

              onPressed: () => scaffoldKey.currentState?.openDrawer(),

            ),

            const SizedBox(width: 4),

          ],



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



          const SizedBox(width: 8),



          Expanded(

            child: Text(

              'Pets with Disabilities',

              textAlign: isMobile ? TextAlign.center : TextAlign.start,

              style: TextStyle(

                color: Colors.white,

                fontSize: isMobile ? 14 : 20,

                fontWeight: FontWeight.bold,

                fontFamily: "Montserrat",

              ),

            ),

          ),



          const SizedBox(width: 8),



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

                  width: isMobile ? 28 : 32,

                  height: isMobile ? 28 : 32,

                ),

              ),

              _NotificationBell(

                iconSize: isMobile ? 22 : 24,

                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),

              ),

              const SizedBox(width: 4),

              buildProfileAvatar(context, radius: isMobile ? 14 : 16),

            ],

          ),

        ],

      ),

    );

  }



  Widget buildProfileAvatar(BuildContext context, {double radius = 16}) {

    return GestureDetector(

      onTap: () {

        Navigator.push(

          context,

          MaterialPageRoute(builder: (_) => ProfilePage()),

        ).then((_) => loadProfileImageForAvatar());

      },

      child: CircleAvatar(

        radius: radius,

        backgroundColor: Colors.white,

        child:

            _isLoadingAvatar

                ? SizedBox(

                  width: radius * 1.2,

                  height: radius * 1.2,

                  child: CircularProgressIndicator(

                    strokeWidth: 2,

                    valueColor: const AlwaysStoppedAnimation<Color>(

                      Colors.orange,

                    ),

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

                        (context, error, stackTrace) => Icon(

                          Icons.person,

                          color: Colors.black,

                          size: radius,

                        ),

                    loadingBuilder: (context, child, loadingProgress) {

                      if (loadingProgress == null) return child;

                      return Center(

                        child: CircularProgressIndicator(

                          strokeWidth: 2,

                          value:

                              loadingProgress.expectedTotalBytes != null

                                  ? loadingProgress.cumulativeBytesLoaded /

                                      loadingProgress.expectedTotalBytes!

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



  Widget buildTopControls() {

    final screenWidth = MediaQuery.of(context).size.width;

    final bool isMobile = screenWidth < 700;



    final searchField = SizedBox(

      width: isMobile ? double.infinity : 200,

      height: 40,

      child: TextField(

        onChanged: onStatusChanged,

        style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),

        decoration: InputDecoration(

          hintText: 'Search pets...',

          hintStyle: const TextStyle(

            color: Colors.white54,

            fontFamily: 'Montserrat',

          ),

          filled: true,

          fillColor: const Color(0xFF3C3C3E),

          contentPadding: const EdgeInsets.symmetric(

            horizontal: 12,

            vertical: 8,

          ),

          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),

          border: OutlineInputBorder(

            borderRadius: BorderRadius.circular(12),

            borderSide: BorderSide.none,

          ),

        ),

      ),

    );



    Widget statusDropdown = Container(

      padding: const EdgeInsets.symmetric(horizontal: 12),

      decoration: BoxDecoration(

        color: const Color(0xFF3C3C3E),

        borderRadius: BorderRadius.circular(12),

      ),

      child: DropdownButton<String>(

        isExpanded: true,

        value: _filterStatus,

        dropdownColor: const Color(0xFF3C3C3E),

        underline: const SizedBox(),

        style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),

        items: const [

          DropdownMenuItem(value: 'All', child: Text('All')),

          DropdownMenuItem(value: 'In Shelter', child: Text('In Shelter')),

          DropdownMenuItem(

            value: 'Under Medication',

            child: Text('Under Medication'),

          ),

          DropdownMenuItem(

            value: 'Ready For Adoption',

            child: Text('Ready For Adoption'),

          ),

        ],

        onChanged: onStatusChanged,

      ),

    );



    Widget ageDropdown = Container(

      padding: const EdgeInsets.symmetric(horizontal: 12),

      decoration: BoxDecoration(

        color: const Color(0xFF3C3C3E),

        borderRadius: BorderRadius.circular(12),

      ),

      child: DropdownButton<String>(

        isExpanded: true,

        value: _filterAge,

        dropdownColor: const Color(0xFF3C3C3E),

        underline: const SizedBox(),

        style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),

        items:

            ['All', 'Young', 'Adult', 'Senior']

                .map((age) => DropdownMenuItem(value: age, child: Text(age)))

                .toList(),

        onChanged: onAgeChanged,

      ),

    );



    if (isMobile) {

      return Padding(

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(

              "Disabled Pets",

              style: TextStyle(

                color: Colors.white,

                fontSize: 18,

                fontWeight: FontWeight.bold,

                fontFamily: 'Montserrat',

              ),

            ),

            const SizedBox(height: 8),

            searchField,

            const SizedBox(height: 8),

            Row(

              children: [

                Expanded(child: statusDropdown),

                const SizedBox(width: 8),

                Expanded(child: ageDropdown),

              ],

            ),

          ],

        ),

      );

    }



    Widget desktopStatusDropdown = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Status: ',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(width: 180, child: statusDropdown),
      ],
    );

    Widget desktopAgeDropdown = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Age: ',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(width: 120, child: ageDropdown),
      ],
    );

    return Padding(

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          const Text(

            "Disabled Pets",

            style: TextStyle(

              color: Colors.white,

              fontSize: 22,

              fontWeight: FontWeight.bold,

              fontFamily: 'Montserrat',

            ),

          ),

          Row(

            children: [

              searchField,

              const SizedBox(width: 12),

              desktopStatusDropdown,

              const SizedBox(width: 12),

              desktopAgeDropdown,

            ],

          ),

        ],

      ),

    );

  }



  void alertDialog() {

    showDialog(

      context: context,

      builder:

          (context) => AlertDialog(

            title: const Text(

              'LOG OUT',

              style: TextStyle(fontFamily: "Montserrat"),

            ),

            content: const Text(

              'Are you sure want to log out?',

              style: TextStyle(fontFamily: 'Montserrat'),

            ),

            actions: [

              TextButton(

                onPressed: () => Navigator.pop(context),

                child: const Text(

                  'Back',

                  style: TextStyle(

                    fontFamily: 'Montserrat',

                    fontWeight: FontWeight.bold,

                  ),

                ),

              ),

              TextButton(

                onPressed: () {

                  Navigator.pushAndRemoveUntil(

                    context,

                    MaterialPageRoute(

                      builder: (context) => AnimatedAdminLoginPage(),

                    ),

                    (route) => false,

                  );

                },

                child: const Text(

                  'LOG OUT',

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



  void _showPetDetailDialog(BuildContext context, Map<String, dynamic> pet) {

    final name = pet['name'] ?? 'Unnamed';

    final type = pet['type'] ?? '—';

    final breed = pet['breed'] ?? '—';

    final age = pet['age']?.toString() ?? '—';

    final sex = pet['sex'] ?? '—';

    final color = pet['color'] ?? '—';

    final energy = pet['energy'] ?? '—';

    final status = pet['status'] ?? '—';

    final description = pet['description'] ?? '—';

    final imageUrl = pet['image_url_1'] ?? '';

    final origin = pet['origin'] ?? '—';

    final dateOfBirth = pet['date_of_birth'];

    final createdAt = pet['created_at'] ?? '—';

    final isOffspring = pet['is_offspring'] == true;

    final rescueAge = pet['rescue_age'];



    final healthStatus = pet['health_status'] ?? '—';

    final vacStatus = pet['vaccination_status'] ?? '—';

    final deworm = pet['deworming_status'] ?? '—';

    final neutered = pet['neutered_spayed_details'] ?? '—';

    final diseaseType = pet['disease_type'] ?? '—';

    final diseaseDetails = pet['disease_details'] ?? '';

    final surgeryType = pet['surgery_type'] ?? '—';

    final surgeryDetails = pet['surgery_details'] ?? '';

    final hasDisability = pet['has_disability'];

    final disabilityDisplay =

        (hasDisability == true ||

                hasDisability.toString().toLowerCase() == 'true' ||

                hasDisability.toString().toLowerCase() == 'yes')

            ? 'Yes'

            : 'No';



    final shelterData = pet['shelters'];

    final shelterName =

        shelterData is Map ? shelterData['name']?.toString() ?? '—' : '—';



    Widget sectionHeader(String title, IconData icon, Color color) {

      return Padding(

        padding: const EdgeInsets.only(top: 20, bottom: 10),

        child: Row(

          children: [

            Container(

              padding: const EdgeInsets.all(6),

              decoration: BoxDecoration(

                color: color.withOpacity(0.15),

                borderRadius: BorderRadius.circular(8),

              ),

              child: Icon(icon, color: color, size: 14),

            ),

            const SizedBox(width: 8),

            Text(

              title,

              style: TextStyle(

                color: color,

                fontFamily: 'Montserrat',

                fontWeight: FontWeight.bold,

                fontSize: 13,

                letterSpacing: 0.5,

              ),

            ),

            const SizedBox(width: 8),

            Expanded(child: Divider(color: color.withOpacity(0.3))),

          ],

        ),

      );

    }



    Widget infoRow(String label, String value, {Color? valueColor}) {

      return Padding(

        padding: const EdgeInsets.only(bottom: 8),

        child: Row(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            SizedBox(

              width: 140,

              child: Text(

                label,

                style: const TextStyle(

                  color: Colors.white38,

                  fontFamily: 'Montserrat',

                  fontSize: 12,

                  fontWeight: FontWeight.w600,

                ),

              ),

            ),

            Expanded(

              child: Text(

                value.isEmpty ? '—' : value,

                style: TextStyle(

                  color: valueColor ?? Colors.white70,

                  fontFamily: 'Montserrat',

                  fontSize: 12,

                ),

              ),

            ),

          ],

        ),

      );

    }



    Widget statusBadge(String label, Color color) => Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

      decoration: BoxDecoration(

        color: color.withOpacity(0.15),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: color.withOpacity(0.4)),

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



    Color statusColor(String s) {

      switch (s) {

        case 'In Shelter':

          return Colors.blue;

        case 'Under Medication':

          return Colors.orange;

        case 'Ready For Adoption':

          return Colors.green;

        default:

          return Colors.white54;

      }

    }



    showDialog(

      context: context,

      builder:

          (ctx) => Dialog(

            backgroundColor: Colors.transparent,

            insetPadding: const EdgeInsets.symmetric(

              horizontal: 24,

              vertical: 32,

            ),

            child: Container(

              width: MediaQuery.of(ctx).size.width < 580

                  ? MediaQuery.of(ctx).size.width * 0.95

                  : 560,

              constraints: BoxConstraints(

                maxHeight: MediaQuery.of(ctx).size.height * 0.88,

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

                        Container(

                          padding: const EdgeInsets.all(8),

                          decoration: BoxDecoration(

                            color: Colors.teal.withOpacity(0.15),

                            borderRadius: BorderRadius.circular(10),

                          ),

                          child: const Icon(

                            Icons.info_outline,

                            color: Colors.teal,

                            size: 18,

                          ),

                        ),

                        const SizedBox(width: 12),

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

                              const SizedBox(height: 2),

                              statusBadge(status, statusColor(status)),

                            ],

                          ),

                        ),

                        GestureDetector(

                          onTap: () => Navigator.pop(ctx),

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

                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            if (imageUrl.isNotEmpty) ...[

                              const SizedBox(height: 12),

                              ClipRRect(

                                borderRadius: BorderRadius.circular(12),

                                child: Image.network(

                                  imageUrl,

                                  width: double.infinity,

                                  height: 180,

                                  fit: BoxFit.cover,

                                  errorBuilder:

                                      (_, __, ___) => Container(

                                        height: 180,

                                        color: Colors.grey[800],

                                        child: const Icon(

                                          Icons.pets,

                                          color: Colors.white38,

                                          size: 48,

                                        ),

                                      ),

                                ),

                              ),

                            ],



                            sectionHeader(

                              'Basic Information',

                              Icons.info_outline,

                              Colors.orange,

                            ),

                            infoRow('Type', type),

                            infoRow('Breed', breed),

                            infoRow('Age', age),

                            infoRow('Sex', sex),

                            infoRow('Color', color),

                            infoRow('Energy', energy),

                            infoRow('Shelter', shelterName),

                            if (description != '—' && description.isNotEmpty)

                              infoRow('Description', description),



                            sectionHeader(

                              'Background',

                              Icons.history,

                              Colors.blue,

                            ),

                            infoRow('Origin', origin),

                            if (isOffspring)

                              infoRow('Shelter Born', 'Yes (offspring)'),

                            if (rescueAge != null &&

                                rescueAge.toString().isNotEmpty)

                              infoRow('Age at Rescue', rescueAge.toString()),

                            if (dateOfBirth != null)

                              infoRow(

                                'Date of Birth',

                                dateOfBirth.toString().substring(0, 10),

                              ),

                            infoRow(

                              'Added On',

                              createdAt.toString().length >= 10

                                  ? createdAt.toString().substring(0, 10)

                                  : createdAt.toString(),

                            ),



                            sectionHeader(

                              'Medical Information',

                              Icons.health_and_safety,

                              Colors.teal,

                            ),

                            infoRow('Health Status', healthStatus),

                            infoRow(

                              'Vaccination',

                              vacStatus,

                              valueColor:

                                  vacStatus.contains('Fully')

                                      ? Colors.green

                                      : vacStatus.contains('Not')

                                      ? Colors.redAccent

                                      : Colors.orange,

                            ),

                            infoRow(

                              'Deworming',

                              deworm,

                              valueColor:

                                  deworm.contains('Not')

                                      ? Colors.redAccent

                                      : Colors.green,

                            ),

                            infoRow('Neutered / Spayed', neutered),

                            infoRow(

                              'Has Disability',

                              disabilityDisplay,

                              valueColor:

                                  disabilityDisplay == 'Yes'

                                      ? Colors.redAccent

                                      : Colors.green,

                            ),



                            if (diseaseType != '—' &&

                                diseaseType.isNotEmpty &&

                                diseaseType != 'No Disease') ...[

                              const SizedBox(height: 4),

                              Container(

                                padding: const EdgeInsets.all(12),

                                decoration: BoxDecoration(

                                  color: Colors.redAccent.withOpacity(0.08),

                                  borderRadius: BorderRadius.circular(10),

                                  border: Border.all(

                                    color: Colors.redAccent.withOpacity(0.25),

                                  ),

                                ),

                                child: Column(

                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [

                                    Row(

                                      children: [

                                        const Icon(

                                          Icons.sick_outlined,

                                          color: Colors.redAccent,

                                          size: 14,

                                        ),

                                        const SizedBox(width: 6),

                                        Text(

                                          diseaseType,

                                          style: const TextStyle(

                                            color: Colors.redAccent,

                                            fontFamily: 'Montserrat',

                                            fontWeight: FontWeight.bold,

                                            fontSize: 13,

                                          ),

                                        ),

                                      ],

                                    ),

                                    if (diseaseDetails.isNotEmpty) ...[

                                      const SizedBox(height: 6),

                                      Text(

                                        diseaseDetails,

                                        style: const TextStyle(

                                          color: Colors.white54,

                                          fontFamily: 'Montserrat',

                                          fontSize: 12,

                                        ),

                                      ),

                                    ],

                                  ],

                                ),

                              ),

                            ],



                            if (surgeryType != '—' &&

                                surgeryType.isNotEmpty &&

                                surgeryType != 'No Surgery Type') ...[

                              const SizedBox(height: 10),

                              Container(

                                padding: const EdgeInsets.all(12),

                                decoration: BoxDecoration(

                                  color: Colors.purple.withOpacity(0.08),

                                  borderRadius: BorderRadius.circular(10),

                                  border: Border.all(

                                    color: Colors.purple.withOpacity(0.25),

                                  ),

                                ),

                                child: Column(

                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [

                                    Row(

                                      children: [

                                        const Icon(

                                          Icons.cut_outlined,

                                          color: Colors.purple,

                                          size: 14,

                                        ),

                                        const SizedBox(width: 6),

                                        Text(

                                          surgeryType,

                                          style: const TextStyle(

                                            color: Colors.purple,

                                            fontFamily: 'Montserrat',

                                            fontWeight: FontWeight.bold,

                                            fontSize: 13,

                                          ),

                                        ),

                                      ],

                                    ),

                                    if (surgeryDetails.isNotEmpty) ...[

                                      const SizedBox(height: 6),

                                      Text(

                                        surgeryDetails,

                                        style: const TextStyle(

                                          color: Colors.white54,

                                          fontFamily: 'Montserrat',

                                          fontSize: 12,

                                        ),

                                      ),

                                    ],

                                  ],

                                ),

                              ),

                            ],

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

                    child: LayoutBuilder(

                      builder: (ctx, constraints) {

                        final useStack = constraints.maxWidth < 360;

                        final buttons = [

                          OutlinedButton.icon(

                            onPressed: () {

                              Navigator.pop(ctx);

                              showEditPetDialog(context, pet);

                            },

                            icon: const Icon(

                              Icons.edit,

                              color: Colors.orange,

                              size: 16,

                            ),

                            label: const Text(

                              'Edit Pet',

                              style: TextStyle(

                                color: Colors.orange,

                                fontFamily: 'Montserrat',

                              ),

                            ),

                            style: OutlinedButton.styleFrom(

                              side: const BorderSide(color: Colors.orange),

                              padding: const EdgeInsets.symmetric(vertical: 12),

                              shape: RoundedRectangleBorder(

                                borderRadius: BorderRadius.circular(10),

                              ),

                            ),

                          ),

                          if (useStack)

                            const SizedBox(height: 8)

                          else

                            const SizedBox(width: 12),

                          ElevatedButton.icon(

                            onPressed: () => Navigator.pop(ctx),

                            icon: const Icon(

                              Icons.close,

                              color: Colors.white,

                              size: 16,

                            ),

                            label: const Text(

                              'Close',

                              style: TextStyle(

                                color: Colors.white,

                                fontFamily: 'Montserrat',

                              ),

                            ),

                            style: ElevatedButton.styleFrom(

                              backgroundColor: const Color(0xFF3C3C3E),

                              padding: const EdgeInsets.symmetric(vertical: 12),

                              shape: RoundedRectangleBorder(

                                borderRadius: BorderRadius.circular(10),

                              ),

                            ),

                          ),

                        ];



                        if (useStack) {

                          return Column(

                            crossAxisAlignment: CrossAxisAlignment.stretch,

                            children: [

                              buttons[0],

                              buttons[1], // SizedBox(height: 8)

                              buttons[2],

                            ],

                          );

                        }



                        return Row(

                          children: [

                            Expanded(child: buttons[0]),

                            buttons[1], // SizedBox(width: 12)

                            Expanded(child: buttons[2]),

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

                      .eq('notification_idd', id);

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

