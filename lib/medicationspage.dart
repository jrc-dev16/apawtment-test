import 'dart:convert';
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
import 'package:apawtmentweb_admin/notificationpage.dart';
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';
import 'package:apawtmentweb_admin/webnotifservice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

class MedicationListPage extends StatefulWidget {
  final int? shelterId;
  final String? shelterName;
  const MedicationListPage({super.key, this.shelterId, this.shelterName});
  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  final Set<int> _selectedPetIds = {};
  bool _isMultiSelectMode = false;
  String _selectedItem = 'Pet Management';
  List<Map<String, dynamic>> _pets = [];
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  String _filterStatus = 'All';
  List<Map<String, dynamic>> petsUnderMedication = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final ScrollController _petGridScrollController = ScrollController();
  final ScrollController _tableScrollController = ScrollController();
  List<Map<String, dynamic>> _allPets = [];

  final List<String> dewormingDetailsOptions = ["Dewormed", "Not Dewormed"];
  final List<String> vaccinationDetailsOptions = [
    "Vaccinated",
    "Partially Vaccinated",
    "Not Vaccinated",
  ];
  final List<String> neutredSpayedDetailsOptions = [
    "Neutered (Male)",
    "Spayed (Female)",
    "Not Neutered/Spayed",
  ];
  final Map<String, List<String>> surgeryDetailsOptions = {
    "No Surgery Type": ["No Surgery Details"],
    "Dental Surgery": ["Dental Cleaning", "Tooth Extraction"],
    "C-Section Surgery": ["Emergency C-Section", "Planned C-Section"],
    "Tumor Removal": ["Skin Tumor", "Internal Tumor"],
    "Fracture Repair": ["Leg Fracture", "Jaw Fracture"],
    "Eye Surgery": ["Cataract Removal", "Eye Injury Repair"],
    "Ear Surgery": ["Ear Canal Removal", "Ear Hematoma Repair"],
    "Hernia Repair": ["Umbilical Hernia", "Inguinal Hernia"],
    "Bladder Stone Removal": ["Small Stone", "Large Stone"],
    "Amputation": ["Leg Amputation", "Tail Amputation"],
  };

  final int _currentShelterIndex = 0;
  List<Map<String, dynamic>> _shelters = [];

  @override
  void initState() {
    super.initState();
    _loadShelters();
    _subscribeToMedicationChanges();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
          petsUnderMedication = _applyCurrentFilters(_pets);
        });
      }
    });
    _loadProfileImageForAvatar();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadProfileImageForAvatar(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _petGridScrollController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadShelters() async {
    try {
      final response = await supabase
          .from('shelters')
          .select('shelter_id, name')
          .order('shelter_id', ascending: true);
      setState(() {
        _shelters = List<Map<String, dynamic>>.from(response);
      });
      await _loadShelterPets();
    } catch (e) {
      debugPrint('Error loading shelters: $e');
      setState(() => isLoading = false);
    }
  }

  void _subscribeToMedicationChanges() {
    final channel = supabase.channel('public:pet_medications');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'pet_medications',
      callback: (payload) async => await _loadShelterPets(),
    );
    channel.subscribe();
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

  List<Map<String, dynamic>> _applyCurrentFilters(
    List<Map<String, dynamic>> source,
  ) {
    var result = List<Map<String, dynamic>>.from(source);
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result =
          result.where((p) {
            final name = p['name']?.toString().toLowerCase() ?? '';
            final age = p['age']?.toString().toLowerCase() ?? '';
            final status = p['status']?.toString().toLowerCase() ?? '';
            final breed = p['breed']?.toString().toLowerCase() ?? '';
            final color = p['color']?.toString().toLowerCase() ?? '';
            return name.contains(q) ||
                breed.contains(q) ||
                color.contains(q) ||
                age.contains(q) ||
                status.contains(q);
          }).toList();
    }
    if (_filterStatus != 'All') {
      result =
          result
              .where(
                (p) =>
                    (p['vaccination_status']?.toString() ?? '') ==
                    _filterStatus,
              )
              .toList();
    }
    return result;
  }

  void _filterSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      petsUnderMedication = _applyCurrentFilters(_pets);
    });
  }

  Widget _buildSearchBar() {
    return SizedBox(
      width: 360,
      child: TextField(
        controller: _searchController,
        onChanged: _filterSearch,
        decoration: InputDecoration(
          hintText: 'Search name, breed, color...',
          hintStyle: const TextStyle(
            color: Colors.white54,
            fontFamily: 'Montserrat',
          ),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF3C3C3E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
      ),
    );
  }

  Future<void> _loadShelterPets() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('pet_medications')
          .select('*, pets(has_disability)')
          .eq('status', 'Under Medication');

      final shelterMap = {
        for (final s in _shelters)
          s['shelter_id']: s['name'] ?? 'Unknown Shelter',
      };

      final fullData =
          (response as List).map<Map<String, dynamic>>((pet) {
            final sid = pet['shelter_id'];
            return {
              'pet_id': pet['pet_id'],
              'medication_id': pet['medication_id'],
              'shelter_id': sid,
              'shelter_name': shelterMap[sid] ?? 'Unknown Shelter',
              'name': pet['name'] ?? '',
              'type': pet['type'] ?? '',
              'status': pet['status'] ?? '',
              'image_url_1': _resolveImageUrl(pet['image_url_1'] ?? ''),
              'breed': pet['breed'] ?? '',
              'age': pet['age'] ?? '',
              'sex': pet['sex'] ?? '',
              'created_at': pet['created_at'] ?? '',
              'description': pet['description'] ?? '',
              'energy': pet['energy'] ?? '',
              'color': pet['color'] ?? '',
              'vaccination_status': pet['vaccination_status'] ?? '',
              'neutered_spayed_details': pet['neutered_spayed_details'] ?? '',
              'deworming_status': pet['deworming_status'] ?? '',
              'surgery_type': pet['surgery_type'] ?? '',
              'surgery_details': pet['surgery_details'] ?? '',
              'disease_type': pet['disease_type'],
              'disease_details': pet['disease_details'],
              'qr_code_url': pet['qr_code_url'],
              'has_disability': pet['pets']?['has_disability'] ?? 'No',
            };
          }).toList();

      if (!mounted) return;
      setState(() {
        _pets = List<Map<String, dynamic>>.from(fullData);
        _allPets = List<Map<String, dynamic>>.from(fullData);
        petsUnderMedication = _applyCurrentFilters(fullData);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading all medication pets: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _resolveImageUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return Supabase.instance.client.storage.from('pets').getPublicUrl(raw);
  }

  void _showPetQrDialog(BuildContext context, Map<String, dynamic> pet) {
    final petId = pet['pet_id'];
    final qrUrl = pet['qr_code_url'];
    final petName = pet['name'] ?? 'Unnamed';

    Future<void> downloadQr() async {
      try {
        Uint8List bytes;
        if (qrUrl != null && qrUrl.isNotEmpty) {
          final response = await http.get(Uri.parse(qrUrl));
          bytes = response.bodyBytes;
        } else {
          final qrValidationResult = QrValidator.validate(
            data: 'PET_ID:$petId',
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.L,
          );
          final qrCode = qrValidationResult.qrCode!;
          final painter = QrPainter.withQr(
            qr: qrCode,

            color: const Color(0xFF000000),

            emptyColor: const Color(0xFFFFFFFF),
            gapless: true,
          );
          final picData = await painter.toImageData(
            1024,
            format: ui.ImageByteFormat.png,
          );
          bytes = picData!.buffer.asUint8List();
        }
        final base64Data = base64Encode(bytes);
        final anchor =
            html.AnchorElement(href: 'data:image/png;base64,$base64Data')
              ..setAttribute('download', '${petName}_QR.png')
              ..click();
        anchor.remove();
        if (context.mounted) {
          _showSnackBar('QR code downloaded!', Colors.green);
        }
      } catch (e) {
        if (context.mounted) {
          _showSnackBar('Error downloading QR Code.', Colors.red);
        }
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
                              ? Image.network(
                                qrUrl,
                                fit: BoxFit.contain,
                                color: Colors.white,
                              )
                              : QrImageView(
                                foregroundColor: Colors.white,
                                data: 'PET_ID:$petId',
                                version: QrVersions.auto,
                              ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SelectableText(
                    'PET_ID:$petId',
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
    } catch (e, st) {
      debugPrint('Error loading avatar: $e\n$st');
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  Future<void> _movePet(
    Map<String, dynamic> pet,
    String destination, {
    int? newShelterId,
  }) async {
    final petId = pet['pet_id'];
    final currentShelterId = pet['shelter_id'];
    try {
      if (destination == 'shelter') {
        final targetShelterId = newShelterId ?? currentShelterId;
        await supabase
            .from('pets')
            .upsert({
              'pet_id': petId,
              'name': pet['name'],
              'status': 'In Shelter',
              'shelter_id': targetShelterId,
              'vaccination_status': pet['vaccination_status'],
              'neutered_spayed_details': pet['neutered_spayed_details'],
              'deworming_status': pet['deworming_status'],
              'surgery_type': pet['surgery_type'],
              'surgery_details': pet['surgery_details'],
              'disease_type': pet['disease_type'],
              'disease_details': pet['disease_details'],
              'updated_at': DateTime.now().toIso8601String(),
              'image_url_1': pet['image_url_1'],
              'sex': pet['sex'],
              'energy': pet['energy'],
              'description': pet['description'],
              'created_at': pet['created_at'],
              'has_disability': pet['has_disability'] ?? false,
            })
            .eq('pet_id', petId);
        await supabase.from('pet_medications').delete().eq('pet_id', petId);
        await logActivity(
          action: 'Moved to Shelter',
          description: '${pet['name']} moved back to shelter',
          entityType: 'pet',
          entityId: petId,
        );
        if (mounted) {
          setState(() {
            petsUnderMedication.removeWhere((p) => p['pet_id'] == petId);
            _selectedPetIds.remove(petId);
          });

          _showSnackBar(
            '✅ ${pet['name']} moved back to shelter.',
            Colors.green,
          );
        }
      } else if (destination == 'adoption') {
        await supabase.from('adoptable_pets').upsert({
          'pet_id': petId,
          'name': pet['name'],
          'status': 'Ready For Adoption',
          'color': pet['color'],
          'breed': pet['breed'],
          'type': pet['type'],
          'age': pet['age'],
          'image_url_1': pet['image_url_1'],
          'sex': pet['sex'],
          'energy': pet['energy'],
          'description': pet['description'],
          'created_at': pet['created_at'],
          'has_disability': pet['has_disability'] ?? false,
          'vaccination_status': pet['vaccination_status'],
          'neutered_spayed_details': pet['neutered_spayed_details'],
          'deworming_status': pet['deworming_status'],
          'surgery_type': pet['surgery_type'],
          'surgery_details': pet['surgery_details'],
          'disease_type': pet['disease_type'],
          'disease_details': pet['disease_details'],
          'shelter_id': pet['shelter_id'],
        });
        await supabase
            .from('pets')
            .update({
              'shelter_id': pet['shelter_id'],
              'status': 'Ready For Adoption',
              'vaccination_status': pet['vaccination_status'],
              'neutered_spayed_details': pet['neutered_spayed_details'],
              'deworming_status': pet['deworming_status'],
              'surgery_type': pet['surgery_type'],
              'surgery_details': pet['surgery_details'],
              'disease_type': pet['disease_type'],
              'disease_details': pet['disease_details'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('pet_id', petId);
        await supabase.from('pet_medications').delete().eq('pet_id', petId);
        await logActivity(
          action: 'Moved to Adoption',
          description: '${pet['name']} moved to Ready For Adoption',
          entityType: 'pet',
          entityId: petId,
        );
        if (mounted) {
          setState(() {
            petsUnderMedication.removeWhere((p) => p['pet_id'] == petId);
            _selectedPetIds.remove(petId);
          });
          _showSnackBar('${pet['name']} moved to adoption.', Colors.green);
        }
      }
    } catch (e, st) {
      debugPrint('Error moving pet: $e\n$st');
      if (mounted) {
        _showSnackBar('Failed to move ${pet['name']}.', Colors.red);
      }
    }
  }

  Future<void> _moveSelectedPets(String destination) async {
    if (_selectedPetIds.isEmpty) return;
    final petsToMove =
        petsUnderMedication.where((pet) {
          final id =
              pet['pet_id'] is int
                  ? pet['pet_id']
                  : int.tryParse(pet['pet_id'].toString()) ?? 0;
          return _selectedPetIds.contains(id);
        }).toList();
    if (petsToMove.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Move Pets',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            content: Text(
              'Move ${petsToMove.length} pet(s) to $destination?',
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
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Move',
                  style: TextStyle(
                    color: Colors.green,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    try {
      for (final pet in petsToMove) {
        final petId = pet['pet_id'];
        if (destination == 'shelter') {
          await supabase
              .from('pets')
              .update({
                'vaccination_status': pet['vaccination_status'],
                'neutered_spayed_details': pet['neutered_spayed_details'],
                'deworming_status': pet['deworming_status'],
                'surgery_type': pet['surgery_type'],
                'surgery_details': pet['surgery_details'],
                'disease_type': pet['disease_type'],
                'disease_details': pet['disease_details'],
                'status': 'In Shelter',
              })
              .eq('pet_id', petId);
          await supabase.from('pet_medications').delete().eq('pet_id', petId);
          await logActivity(
            action:
                'Bulk Move to ${destination == 'shelter' ? 'Shelter' : 'Adoption'}',
            description: '${pet['name']} moved to $destination',
            entityType: 'pet',
            entityId: pet['pet_id'],
          );
        } else if (destination == 'adoption') {
          await supabase.from('adoptable_pets').upsert({
            'pet_id': petId,
            'name': pet['name'],
            'status': 'Ready For Adoption',
            'color': pet['color'],
            'breed': pet['breed'],
            'type': pet['type'],
            'age': pet['age'],
            'image_url_1': pet['image_url_1'],
            'sex': pet['sex'],
            'energy': pet['energy'],
            'description': pet['description'],
            'created_at': pet['created_at'],
            'has_disability': pet['has_disability'],
            'vaccination_status': pet['vaccination_status'],
            'neutered_spayed_details': pet['neutered_spayed_details'],
            'deworming_status': pet['deworming_status'],
            'surgery_type': pet['surgery_type'],
            'surgery_details': pet['surgery_details'],
            'disease_type': pet['disease_type'],
            'disease_details': pet['disease_details'],
          });
          await supabase
              .from('pets')
              .update({'status': 'Ready For Adoption'})
              .eq('pet_id', petId);
        }
      }
      setState(() {
        petsUnderMedication.removeWhere(
          (p) => _selectedPetIds.contains(p['pet_id']),
        );
        _selectedPetIds.clear();
        _isMultiSelectMode = false;
      });
      _showSnackBar(
        '${petsToMove.length} pet(s) moved successfully.',
        Colors.green,
      );
    } catch (e) {
      debugPrint('Move error: $e');
      _showSnackBar('Failed to move pets.', Colors.red);
    }
  }

  Future<void> _updateMedicalInfo(
    BuildContext context,
    int petId,
    String vaccination,
    String neutered,
    String deworming,
    String surgeryType,
    String surgeryDetails,
    String diseaseType,
    String diseaseDetails, {
    required void Function(Map<String, dynamic>) onPetUpdated,
  }) async {
    try {
      final petsResponse =
          await supabase
              .from('pets')
              .update({
                'vaccination_status': vaccination,
                'neutered_spayed_details': neutered,
                'deworming_status': deworming,
                'surgery_type': surgeryType,
                'surgery_details': surgeryDetails,
                'disease_type': diseaseType,
                'disease_details': diseaseDetails,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('pet_id', petId)
              .select();
      if (petsResponse.isEmpty) throw Exception("Failed to update pets table.");
      await supabase
          .from('pet_medications')
          .update({
            'vaccination_status': vaccination,
            'neutered_spayed_details': neutered,
            'deworming_status': deworming,
            'surgery_type': surgeryType,
            'surgery_details': surgeryDetails,
            'disease_type': diseaseType,
            'disease_details': diseaseDetails,
          })
          .eq('pet_id', petId)
          .select();
      onPetUpdated({
        'vaccination_status': vaccination,
        'neutered_spayed_details': neutered,
        'deworming_status': deworming,
        'surgery_type': surgeryType,
        'surgery_details': surgeryDetails,
        'disease_type': diseaseType,
        'disease_details': diseaseDetails,
      });
      if (mounted) {
        _showSnackBar('Medical info updated successfully.', Colors.green);
      }
    } catch (e, st) {
      debugPrint('Error updating medical info: $e\n$st');
      if (mounted) {
        _showSnackBar('Failed to update medical info.', Colors.red);
      }
    }
  }

  Future<void> _markDeceased(Map<String, dynamic> pet) async {
    final petId = pet['pet_id'];
    if (petId == null) return;
    try {
      await supabase.from('deceased_pets').upsert({
        'pet_id': petId,
        'name': pet['name'],
        'type': pet['type'],
        'breed': pet['breed'],
        'age': pet['age'],
        'sex': pet['sex'],
        'color': pet['color'],
        'image_url_1': pet['image_url_1'],
        'shelter_id': pet['shelter_id'],
        'description': pet['description'],
        'energy': pet['energy'],
        'vaccination_status': pet['vaccination_status'],
        'neutered_spayed_details': pet['neutered_spayed_details'],
        'deworming_status': pet['deworming_status'],
        'surgery_type': pet['surgery_type'],
        'surgery_details': pet['surgery_details'],
        'disease_type': pet['disease_type'],
        'disease_details': pet['disease_details'],
        'has_disability': pet['has_disability'],
        'deceased_at': DateTime.now().toIso8601String(),
      });

      await supabase
          .from('pets')
          .update({
            'status': 'Deceased',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('pet_id', petId);

      await supabase.from('pet_medications').delete().eq('pet_id', petId);

      await logActivity(
        action: 'Marked Deceased',
        description: '${pet['name']} was marked as deceased',
        entityType: 'pet',
        entityId: petId,
      );

      if (mounted) {
        setState(
          () => petsUnderMedication.removeWhere((p) => p['pet_id'] == petId),
        );
        _showSnackBar(
          '${pet['name']} has been marked as deceased.',
          Colors.grey,
        );
      }
    } catch (e) {
      debugPrint('Error marking pet as deceased: $e');
      if (mounted) {
        _showSnackBar(
          '${pet['name']} has been marked as deceased.',
          Colors.grey,
        );
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    return Scaffold(
      key: _scaffoldKey,
      drawer: isDesktop ? null : Drawer(width: 200, child: _buildSidebar()),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(),
                _buildTopControls(),
                Expanded(child: _buildPetGrid()),
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 800;
    final bool isMobile = screenWidth < 600;

    return Container(
      height: isDesktop ? null : 56,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 10,
        vertical: isDesktop ? 15 : 8,
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),

          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed:
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PetPage()),
                  ),
            ),

          if (isDesktop)
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

          SizedBox(width: isMobile ? 8 : 12),

          Expanded(
            child: Text(
              'Medication',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 12 : 20,
                fontWeight: FontWeight.bold,
                fontFamily: "Montserrat",
              ),
            ),
          ),

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
                  width: 32,
                  height: 32,
                ),
              ),
              SizedBox(width: isMobile ? 6 : 16),
              _NotificationBell(
                iconSize: isMobile ? 22 : 24,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
              SizedBox(width: isMobile ? 6 : 16),
              buildProfileAvatar(context, radius: 16),
            ],
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

  void _showPetDetailDialog(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _MedPetDetailDialog(
          pets: petsUnderMedication,
          initialIndex: initialIndex,
          onEdit: (pet) {
            Navigator.pop(dialogContext);
            editPetDetailsModal(
              context,
              pet,
              onPetUpdated: (u) => setState(() => pet.addAll(u)),
            );
          },
          onDeceased: (pet) async {
            Navigator.pop(dialogContext);
            final confirm = await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF2D2D2D),
                    title: const Text(
                      'Mark as Deceased',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    content: Text(
                      'Mark ${pet['name']} as deceased? This will move the record to the Deceased Pets list.',
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
                          style: TextStyle(fontFamily: 'Montserrat'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                    ],
                  ),
            );
            if (confirm == true) await _markDeceased(pet);
          },

          onMoveToShelter: (pet) async {
            Navigator.pop(dialogContext);
            final confirm = await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF2D2D2D),
                    title: const Text(
                      'Move to Shelter',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    content: Text(
                      'Move ${pet['name']} back to shelter?',
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
                          style: TextStyle(fontFamily: 'Montserrat'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Move',
                          style: TextStyle(
                            color: Colors.green,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                    ],
                  ),
            );
            if (confirm == true) await _movePet(pet, 'shelter');
          },
          onMoveToAdoption: (pet) async {
            Navigator.pop(dialogContext);
            await _movePet(pet, 'adoption');
          },
        );
      },
    );
  }

  Widget _buildPetGrid() {
    if (isLoading) {
      return const SkeletonPetGrid();
    }
    if (petsUnderMedication.isEmpty) {
      return const Center(
        child: Text(
          'No pets under medication.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontFamily: 'Montserrat',
          ),
        ),
      );
    }
    return _buildMedicationTable();
  }

  Widget _buildMedicationTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.medical_services,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${petsUnderMedication.length} pet(s) under medication',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: constraints.maxWidth,
                child: Scrollbar(
                  controller: _tableScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth > 1100
                            ? constraints.maxWidth
                            : 1100,
                      ),
                      child: DataTable(
                      columnSpacing: 16,
                      headingRowHeight: 48,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 64,
                      horizontalMargin: 16,
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFF1C1C1E),
                      ),
                      dataRowColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.blue.withOpacity(0.1);
                        }
                        return const Color(0xFF2D2D30);
                      }),
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.white.withOpacity(0.06),
                          width: 1,
                        ),
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.06),
                          width: 1,
                        ),
                      ),
                      columns: const [
                        DataColumn(label: _TableHeader('Photo')),
                        DataColumn(label: _TableHeader('Name')),
                        DataColumn(label: _TableHeader('Shelter')),
                        DataColumn(label: _TableHeader('Type')),
                        DataColumn(label: _TableHeader('Breed')),
                        DataColumn(label: _TableHeader('Age')),
                        DataColumn(label: _TableHeader('Sex')),
                        DataColumn(label: _TableHeader('Disease')),
                        DataColumn(label: _TableHeader('Vaccination')),
                        DataColumn(label: _TableHeader('Surgery')),
                        DataColumn(label: _TableHeader('Actions')),
                      ],
                      rows:
                          petsUnderMedication.asMap().entries.map((entry) {
                            final index = entry.key;
                            final pet = entry.value;

                            final petId =
                                pet['pet_id'] is int
                                    ? pet['pet_id'] as int
                                    : int.tryParse(pet['pet_id'].toString()) ??
                                        0;

                            final name = pet['name'] ?? 'Unnamed';
                            final shelterName = pet['shelter_name'] ?? '—';
                            final type = pet['type'] ?? '—';
                            final breed = pet['breed'] ?? '—';
                            final age = pet['age']?.toString() ?? '—';
                            final sex = pet['sex'] ?? '—';
                            final imageUrl = pet['image_url_1'] ?? '';
                            final diseaseType =
                                pet['disease_type']?.toString() ?? '—';
                            final vaccination =
                                pet['vaccination_status'] ?? '—';
                            final surgeryType = pet['surgery_type'] ?? '—';
                            final isSelected = _selectedPetIds.contains(petId);

                            Color vacColor = Colors.white54;
                            if (vaccination.contains('Vaccinated') &&
                                !vaccination.contains('Partially')) {
                              vacColor = Colors.green;
                            } else if (vaccination.contains('Partially')) {
                              vacColor = Colors.orange;
                            } else if (vaccination.contains('Not')) {
                              vacColor = Colors.redAccent;
                            }

                            String shortenVac(String v) {
                              if (v.contains('Fully') || v == 'Vaccinated')
                                return 'Vaccinated';
                              if (v.contains('Partially')) return 'Partial';
                              if (v.contains('Not')) return 'Not Vacc.';
                              if (v == '—') return '—';
                              return v.length > 10
                                  ? '${v.substring(0, 9)}…'
                                  : v;
                            }

                            String shortenDisease(String v) {
                              if (v == '—' || v.isEmpty) return 'None';
                              return v.length > 12
                                  ? '${v.substring(0, 11)}…'
                                  : v;
                            }

                            String shortenSurgery(String v) {
                              if (v.isEmpty || v == 'No Surgery Type')
                                return 'None';
                              return v.length > 12
                                  ? '${v.substring(0, 11)}…'
                                  : v;
                            }

                            return DataRow(
                              selected: isSelected,
                              color: WidgetStateProperty.resolveWith<Color>((
                                states,
                              ) {
                                if (isSelected)
                                  return Colors.blue.withOpacity(0.1);
                                if (index.isEven)
                                  return const Color(0xFF2D2D30);
                                return const Color(0xFF262628);
                              }),
                              onSelectChanged:
                                  _isMultiSelectMode
                                      ? (selected) {
                                        setState(() {
                                          if (selected == true) {
                                            _selectedPetIds.add(petId);
                                          } else {
                                            _selectedPetIds.remove(petId);
                                            if (_selectedPetIds.isEmpty) {
                                              _isMultiSelectMode = false;
                                            }
                                          }
                                        });
                                      }
                                      : null,
                              cells: [
                                DataCell(
                                  GestureDetector(
                                    onTap:
                                        () => _showPetDetailDialog(
                                          context,
                                          index,
                                        ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child:
                                          imageUrl.isNotEmpty
                                              ? Image.network(
                                                imageUrl,
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                headers: const {
                                                  'Cache-Control': 'no-cache',
                                                },
                                                errorBuilder:
                                                    (_, __, ___) =>
                                                        _petPlaceholder(),
                                              )
                                              : _petPlaceholder(),
                                    ),
                                  ),
                                ),

                                DataCell(
                                  GestureDetector(
                                    onLongPress: () {
                                      setState(() {
                                        _isMultiSelectMode = true;
                                        _selectedPetIds.add(petId);
                                      });
                                    },
                                    onTap:
                                        () => _showPetDetailDialog(
                                          context,
                                          index,
                                        ),
                                    child: SizedBox(
                                      width: 90,
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                DataCell(
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      shelterName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontFamily: 'Montserrat',
                                        fontSize: 13,
                                      ),
                                    ),
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
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      breed,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontFamily: 'Montserrat',
                                        fontSize: 13,
                                      ),
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        sex == 'Female'
                                            ? Icons.female
                                            : Icons.male,
                                        color:
                                            sex == 'Female'
                                                ? Colors.pinkAccent
                                                : Colors.lightBlueAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        sex,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontFamily: 'Montserrat',
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                DataCell(
                                  Container(
                                    width: 80,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.redAccent.withOpacity(
                                          0.5,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      shortenDisease(diseaseType),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            diseaseType.isEmpty ||
                                                    diseaseType == '—'
                                                ? Colors.white38
                                                : Colors.redAccent,
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                DataCell(
                                  Container(
                                    width: 90,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: vacColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: vacColor.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      shortenVac(vaccination),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: vacColor,
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                DataCell(
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      shortenSurgery(surgeryType),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            surgeryType.isEmpty ||
                                                    surgeryType ==
                                                        'No Surgery Type'
                                                ? Colors.white38
                                                : Colors.white70,
                                        fontFamily: 'Montserrat',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),

                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: 'View QR',
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.qr_code,
                                            color: Colors.teal,
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => _showPetQrDialog(
                                                context,
                                                pet,
                                              ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'Edit Medical Info',
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.medical_services,
                                            color: Colors.orange,
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => editPetDetailsModal(
                                                context,
                                                pet,
                                                onPetUpdated:
                                                    (u) => setState(
                                                      () => pet.addAll(u),
                                                    ),
                                              ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'More',
                                        child: PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color: Colors.white54,
                                            size: 18,
                                          ),
                                          color: const Color(0xFF3C3C3E),
                                          padding: EdgeInsets.zero,
                                          onSelected: (value) async {
                                            if (value == 'shelter') {
                                              await _movePet(pet, 'shelter');
                                            } else if (value == 'adoption') {
                                              await _movePet(pet, 'adoption');
                                            } else if (value == 'deceased') {
                                              final confirm = await showDialog<
                                                bool
                                              >(
                                                context: context,
                                                builder:
                                                    (ctx) => AlertDialog(
                                                      backgroundColor:
                                                          const Color(
                                                            0xFF2D2D2D,
                                                          ),
                                                      title: const Text(
                                                        'Mark as Deceased',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontFamily:
                                                              'Montserrat',
                                                        ),
                                                      ),
                                                      content: Text(
                                                        'Mark ${pet['name']} as deceased? This will move the record to the Deceased Pets list.',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontFamily:
                                                              'Montserrat',
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    false,
                                                                  ),
                                                          child: const Text(
                                                            'Cancel',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    true,
                                                                  ),
                                                          child: const Text(
                                                            'Confirm',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                              );
                                              if (confirm == true)
                                                await _markDeceased(pet);
                                            }
                                          },
                                          itemBuilder:
                                              (_) => const [
                                                PopupMenuItem(
                                                  value: 'shelter',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.home,
                                                        color: Colors.green,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Move to Shelter',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'adoption',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.pets,
                                                        color: Colors.blue,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Move to Adoption',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuDivider(),
                                                PopupMenuItem(
                                                  value: 'deceased',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.heart_broken,
                                                        color: Colors.grey,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Mark as Deceased',
                                                        style: TextStyle(
                                                          color: Colors.grey,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  Widget _petPlaceholder() => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Colors.grey[800],
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.pets, color: Colors.white38, size: 22),
  );

  Widget _buildTopControls() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 800;

    Widget statusDropdown = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDesktop) ...[
          const Text(
            'Vaccination: ',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 0.5),
          ),
          child: DropdownButton<String>(
            value: _filterStatus,
            dropdownColor: const Color(0xFF1C1C1E),
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Vaccinated', child: Text('Vaccinated')),
              DropdownMenuItem(value: 'Not Vaccinated', child: Text('Not Vaccinated')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _filterStatus = v;
                  petsUnderMedication = _applyCurrentFilters(_pets);
                });
              }
            },
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSearchBar(),
            const SizedBox(width: 16),
            statusDropdown,
            const SizedBox(width: 16),
            if (_isMultiSelectMode && _selectedPetIds.isNotEmpty)
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.home),
                    label: const Text(
                      "Move to Shelter",
                      style: TextStyle(fontFamily: 'Montserrat'),
                    ),
                    onPressed: () => _moveSelectedPets('shelter'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pets),
                    label: const Text(
                      "Ready For Adoption",
                      style: TextStyle(fontFamily: 'Montserrat'),
                    ),
                    onPressed: () => _moveSelectedPets('adoption'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        () => setState(() {
                          _isMultiSelectMode = false;
                          _selectedPetIds.clear();
                        }),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontFamily: 'Montserrat'),
                    ),
                  ),
                ],
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

  Widget buildDetailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
                fontFamily: "Montserrat",
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value ?? "-",
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontFamily: "Montserrat",
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void editPetDetailsModal(
    BuildContext context,
    Map<String, dynamic> pet, {
    bool startInEdit = true,
    required Function(Map<String, dynamic>) onPetUpdated,
  }) {
    final vaccinationController = TextEditingController(
      text: pet['vaccination_status'] ?? '',
    );
    final neuteredController = TextEditingController(
      text: pet['neutered_spayed_details'] ?? '',
    );
    final dewormingController = TextEditingController(
      text: pet['deworming_status'] ?? '',
    );
    final surgeryTypeController = TextEditingController(
      text: pet['surgery_type'] ?? '',
    );
    final surgeryDetailsController = TextEditingController(
      text: pet['surgery_details'] ?? '',
    );
    final environmentalDiseaseController = TextEditingController(
      text: pet['disease_type'] ?? '',
    );
    final environmentalDiseaseDetailsController = TextEditingController(
      text: pet['disease_details'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        bool isEditing = startInEdit;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(
                  maxHeight: 600,
                  maxWidth: 400,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Pet Medical Details",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontFamily: "Montserrat",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(45, 45, 45, 1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Medical Information",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (!isEditing) ...[
                                buildDetailRow(
                                  "Vaccination",
                                  pet['vaccination_status'],
                                ),
                                buildDetailRow(
                                  "Neutered/Spayed",
                                  pet['neutered_spayed_details'],
                                ),
                                buildDetailRow(
                                  "Deworming",
                                  pet['deworming_status'],
                                ),
                                buildDetailRow(
                                  "Surgery Type",
                                  pet['surgery_type'],
                                ),
                                buildDetailRow(
                                  "Surgery Details",
                                  pet['surgery_details'],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        () => setModalState(
                                          () => isEditing = true,
                                        ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text(
                                      "Edit Medical Info",
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                _buildModalDropdown(
                                  "Vaccination Status",
                                  vaccinationController,
                                  vaccinationDetailsOptions,
                                  setModalState,
                                ),
                                const SizedBox(height: 12),
                                _buildModalDropdown(
                                  "Neutered/Spayed",
                                  neuteredController,
                                  neutredSpayedDetailsOptions,
                                  setModalState,
                                ),
                                const SizedBox(height: 12),
                                _buildModalDropdown(
                                  "Deworming Status",
                                  dewormingController,
                                  dewormingDetailsOptions,
                                  setModalState,
                                ),
                                const SizedBox(height: 12),
                                _buildModalDropdown(
                                  "Surgery Type",
                                  surgeryTypeController,
                                  surgeryDetailsOptions.keys.toList(),
                                  setModalState,
                                  onChanged: (v) {
                                    surgeryTypeController.text = v ?? '';
                                    surgeryDetailsController.text = '';
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildModalDropdown(
                                  "Surgery Details",
                                  surgeryDetailsController,
                                  surgeryDetailsOptions[surgeryTypeController
                                          .text] ??
                                      [],
                                  setModalState,
                                ),
                                const SizedBox(height: 12),
                                _buildModalDropdown(
                                  "Disease",
                                  environmentalDiseaseController,
                                  [
                                    'Allergies',
                                    'Fleas & Ticks',
                                    'Ear Infections',
                                    'Dermatitis',
                                    'Heatstroke',
                                    'Hypothermia',
                                    'Poisoning',
                                    'Respiratory Infections',
                                    'Parasitic Infections',
                                    'Eye Irritation',
                                    'Stress-related Disorders',
                                  ],
                                  setModalState,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller:
                                      environmentalDiseaseDetailsController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: "Specify Health Details",
                                    labelStyle: TextStyle(
                                      color: Colors.white70,
                                      fontFamily: 'Montserrat',
                                    ),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white38,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white38,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.orange,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Color(0xFF3C3C3E),
                                    hintText:
                                        "Describe symptoms, severity, or other notes",
                                    hintStyle: TextStyle(
                                      color: Colors.white54,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder:
                                            (ctx) => const Center(
                                              child: CircularProgressIndicator(
                                                color: Colors.orange,
                                              ),
                                            ),
                                      );
                                      try {
                                        await _updateMedicalInfo(
                                          context,
                                          pet['pet_id'],
                                          vaccinationController.text,
                                          neuteredController.text,
                                          dewormingController.text,
                                          surgeryTypeController.text,
                                          surgeryDetailsController.text,
                                          environmentalDiseaseController.text,
                                          environmentalDiseaseDetailsController
                                              .text,
                                          onPetUpdated:
                                              (u) =>
                                                  setState(() => pet.addAll(u)),
                                        );
                                        if (mounted) {
                                          Navigator.of(context).pop();
                                          Navigator.of(context).pop();
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          Navigator.of(context).pop();
                                          _showSnackBar(
                                            '${pet['name']} has been marked as deceased.',
                                            Colors.grey,
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text(
                                      "Save Medical Info",
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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

  Widget _buildModalDropdown(
    String label,
    TextEditingController controller,
    List<String> options,
    StateSetter setModalState, {
    void Function(String?)? onChanged,
  }) {
    final currentValue =
        controller.text.isNotEmpty && options.contains(controller.text)
            ? controller.text
            : null;
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white70,
          fontFamily: 'Montserrat',
        ),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orange),
        ),
        filled: true,
        fillColor: const Color(0xFF3C3C3E),
      ),
      dropdownColor: const Color(0xFF3C3C3E),
      style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
      value: currentValue,
      items:
          options
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(
                    v,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      color: Colors.white,
                    ),
                  ),
                ),
              )
              .toList(),
      onChanged:
          (value) => setModalState(() {
            if (onChanged != null) {
              onChanged(value);
            } else {
              controller.text = value ?? '';
            }
          }),
    );
  }
}

class _MedPetDetailDialog extends StatefulWidget {
  final List<Map<String, dynamic>> pets;
  final int initialIndex;
  final void Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onDeceased;
  final Future<void> Function(Map<String, dynamic>) onMoveToShelter;
  final Future<void> Function(Map<String, dynamic>) onMoveToAdoption;

  const _MedPetDetailDialog({
    required this.pets,
    required this.initialIndex,
    required this.onEdit,
    required this.onMoveToShelter,
    required this.onMoveToAdoption,
    required this.onDeceased,
  });

  @override
  State<_MedPetDetailDialog> createState() => _MedPetDetailDialogState();
}

class _MedPetDetailDialogState extends State<_MedPetDetailDialog> {
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

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    final name = pet['name'] ?? 'Unnamed';
    final breed = pet['breed'] ?? 'Unknown';
    final type = pet['type'] ?? 'Unknown';
    final age = pet['age']?.toString() ?? 'N/A';
    final color = pet['color'] ?? 'Unknown';
    final gender = pet['sex'] ?? 'Unknown';
    final energy = pet['energy'] ?? 'N/A';
    final desc = pet['description'] ?? '—';
    final imageUrl = pet['image_url_1'] ?? '';
    final createdAt = pet['created_at'] ?? 'N/A';
    final vaccination = pet['vaccination_status'] ?? '—';
    final neutered = pet['neutered_spayed_details'] ?? '—';
    final deworming = pet['deworming_status'] ?? '—';
    final surgeryType = pet['surgery_type'] ?? '—';
    final surgeryDet = pet['surgery_details'] ?? '—';
    final diseaseType = pet['disease_type'] ?? '—';
    final diseaseDet = pet['disease_details'] ?? '—';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: MediaQuery.of(context).size.width < 580
            ? MediaQuery.of(context).size.width * 0.95
            : 540,
        constraints: const BoxConstraints(maxWidth: 580),
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
                  _MedNavButton(
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
                  _MedNavButton(
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
                        _MedStatusBadge(
                          label: 'Under Medication',
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MedInfoGrid(
                      items: [
                        _MedInfoItem(label: 'Breed', value: breed),
                        _MedInfoItem(label: 'Type', value: type),
                        _MedInfoItem(label: 'Age', value: age),
                        _MedInfoItem(label: 'Color', value: color),
                        _MedInfoItem(label: 'Gender', value: gender),
                        _MedInfoItem(label: 'Energy', value: energy),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (desc.isNotEmpty && desc != '—') ...[
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
                        desc,
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
                    _MedInfoGrid(
                      items: [
                        _MedInfoItem(label: 'Vaccination', value: vaccination),
                        _MedInfoItem(label: 'Neutered', value: neutered),
                        _MedInfoItem(label: 'Deworming', value: deworming),
                        _MedInfoItem(label: 'Surgery Type', value: surgeryType),
                        _MedInfoItem(label: 'Surgery Info', value: surgeryDet),
                        _MedInfoItem(label: 'Disease', value: diseaseType),
                        _MedInfoItem(label: 'Disease Info', value: diseaseDet),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Added: $createdAt',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 16),
                    const Text(
                      'Actions',
                      style: TextStyle(
                        color: Colors.orange,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MedActionChip(
                          label: 'Edit Medical Info',
                          icon: Icons.medical_services,
                          color: Colors.orange,
                          onTap: () => widget.onEdit(pet),
                        ),
                        _MedActionChip(
                          label: 'Move to Shelter',
                          icon: Icons.home,
                          color: Colors.green,
                          onTap: () => widget.onMoveToShelter(pet),
                        ),
                        _MedActionChip(
                          label: 'Move to Adoption',
                          icon: Icons.pets,
                          color: Colors.blue,
                          onTap: () => widget.onMoveToAdoption(pet),
                        ),
                        _MedActionChip(
                          label: 'Mark as Deceased',
                          icon: Icons.delete,
                          color: Colors.red,
                          onTap: () => widget.onDeceased(pet),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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

class _MedNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool reversed;

  const _MedNavButton({
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

class _MedStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MedStatusBadge({required this.label, required this.color});

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

class _MedInfoGrid extends StatelessWidget {
  final List<_MedInfoItem> items;
  const _MedInfoGrid({required this.items});

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

class _MedInfoItem {
  final String label;
  final String value;
  const _MedInfoItem({required this.label, required this.value});
}

class _MedActionChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MedActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MedActionChip> createState() => _MedActionChipState();
}

class _MedActionChipState extends State<_MedActionChip> {
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

  static const _excludedTypes = ['system'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _channel =
        supabase
            .channel('notif_bell_med_${identityHashCode(this)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              callback: (payload) {
                final type = payload.newRecord['type'] ?? '';
                if (!_excludedTypes.contains(type) && mounted) {
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
          .select('*')
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
                        final notif = _items[index];
                        final id = notif['notification_id'] as int?;
                        final title =
                            notif['title'] as String? ?? 'Notification';
                        final message = notif['message'] as String? ?? '';
                        final type = notif['type'] as String? ?? 'general';
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

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.orange,
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.bold,
        fontSize: 13,
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
