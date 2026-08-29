import 'dart:convert';
import 'package:apawtmentweb_admin/skeleton_loading.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';



import 'dart:typed_data';



import 'dart:ui' as ui;



import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';

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

import 'package:flutter/services.dart';



import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart';

import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'package:image/image.dart' as img;

import 'package:universal_html/html.dart' as html;



import 'dart:math' as math;



class ShelterCard extends StatefulWidget {

  final Map<String, dynamic> shelter;

  final VoidCallback onViewPressed;

  final VoidCallback onDeletePressed;

  final VoidCallback onEditPressed;



  const ShelterCard({

    super.key,

    required this.shelter,

    required this.onViewPressed,

    required this.onDeletePressed,

    required this.onEditPressed,

  });



  @override

  State<ShelterCard> createState() => _ShelterCardState();

}



class _ShelterCardState extends State<ShelterCard> {
  bool isHovered = false;
  bool get isMobile => MediaQuery.of(context).size.width < 900;



  static const _themes = {

    'dog': (

      primary: Color(0xFF8B5E3C),

      roof: Color(0xFF7B5231),

      light: Color(0xFFF5EBE0),

      label: 'Dog Shelter',

    ),

    'cat': (

      primary: Color(0xFFC96B1A),

      roof: Color(0xFFB85C10),

      light: Color(0xFFFAEAD7),

      label: 'Cat Shelter',

    ),

    'mixed': (

      primary: Color(0xFF2E86AB),

      roof: Color(0xFF1A6080),

      light: Color(0xFFE3F2F9),

      label: 'Mixed Shelter',

    ),

  };



  String get _typeKey {

    final t = (widget.shelter['type'] ?? '').toString().toLowerCase();

    if (t.contains('dog')) return 'dog';

    if (t.contains('cat')) return 'cat';

    return 'mixed';

  }



  ({Color primary, Color roof, Color light, String label}) get _theme =>

      _themes[_typeKey]!;



  Color get _barColor {

    final pct = _capacityPct;

    if (pct >= 1.0) return const Color(0xFFE24B4A);

    if (pct > 0.7) return const Color(0xFFEF9F27);

    return const Color(0xFF1D9E75);

  }



  double get _capacityPct {

    final current = widget.shelter['current_pets'] ?? 0;

    final cap = widget.shelter['capacity'] ?? 100;

    return cap > 0 ? (current / cap).clamp(0.0, 1.0) : 0.0;

  }



  @override

  Widget build(BuildContext context) {

    final shelter = widget.shelter;

    final currentPets = shelter['current_pets'] ?? 0;

    final capacity = shelter['capacity'] ?? 100;

    final adopted = shelter['status'] ?? 0;

    final name = shelter['name'] ?? 'Unknown Shelter';

    final theme = _theme;



    return MouseRegion(

      onEnter: (_) => setState(() => isHovered = true),

      onExit: (_) => setState(() => isHovered = false),

      child: GestureDetector(

        onTap: widget.onViewPressed,
        child: AnimatedScale(
          scale: isHovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: isMobile ? 100 : 180,
                  width: double.infinity,

                  child: Stack(

                    children: [

                      Positioned.fill(

                        child: ClipRRect(

                          borderRadius: const BorderRadius.only(

                            topLeft: Radius.circular(16),

                            topRight: Radius.circular(16),

                          ),

                          child:

                              _typeKey == 'mixed'

                                  ? Row(

                                    children: [

                                      Expanded(

                                        child: Image.asset(

                                          'assets/images/dogs.png',

                                          fit: BoxFit.cover,

                                        ),

                                      ),

                                      Expanded(

                                        child: Image.asset(

                                          'assets/images/cats.png',

                                          fit: BoxFit.cover,

                                        ),

                                      ),

                                    ],

                                  )

                                  : Image.asset(

                                    _typeKey == 'dog'

                                        ? 'assets/images/dogs.png'

                                        : 'assets/images/cats.png',

                                    fit: BoxFit.cover,

                                    width: double.infinity,

                                  ),

                        ),

                      ),



                      Positioned.fill(

                        child: ClipRRect(

                          borderRadius: const BorderRadius.only(

                            topLeft: Radius.circular(16),

                            topRight: Radius.circular(16),

                          ),

                          child: Container(decoration: BoxDecoration()),

                        ),

                      ),



                      Positioned(

                        top: 8,

                        left: 8,

                        child: GestureDetector(

                          onTap: widget.onEditPressed,

                          child: Tooltip(

                            message: 'Edit shelter',

                            child: Container(
                              padding: EdgeInsets.all(isMobile ? 3 : 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: isMobile ? 11 : 13,
                              ),
                            ),

                          ),

                        ),

                      ),



                      Positioned(

                        top: 8,

                        right: 8,

                        child: GestureDetector(

                          onTap: widget.onDeletePressed,

                          child: Tooltip(

                            message:

                                (widget.shelter['current_pets'] ?? 0) > 0
                                    ? 'Cannot delete — shelter has pets'
                                    : 'Delete shelter',
                            child: Container(
                              padding: EdgeInsets.all(isMobile ? 3 : 4),
                              decoration: BoxDecoration(
                                color:
                                    (widget.shelter['current_pets'] ?? 0) > 0
                                        ? Colors.grey.withOpacity(0.5)
                                        : Colors.black.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                (widget.shelter['current_pets'] ?? 0) > 0
                                    ? Icons.lock_rounded
                                    : Icons.close_rounded,
                                color:
                                    (widget.shelter['current_pets'] ?? 0) > 0
                                        ? Colors.white54
                                        : Colors.white,
                                size: isMobile ? 11 : 13,
                              ),
                            ),
                          ),
                        ),
                      ),

                    ],

                  ),

                ),



                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: theme.primary.withOpacity(0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withOpacity(
                          isHovered ? 0.16 : 0.07,
                        ),
                        blurRadius: isHovered ? 16 : 6,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: isMobile
                      ? const EdgeInsets.fromLTRB(10, 8, 10, 10)
                      : const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.bold,
                          color: theme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 6 : 8,
                          vertical: isMobile ? 2 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.light,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          theme.label,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: isMobile ? 8 : 10,
                            fontWeight: FontWeight.w600,
                            color: theme.roof,
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 6 : 10),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      SizedBox(height: isMobile ? 6 : 10),
                      _detailRow(
                        'Capacity',
                        '$currentPets / $capacity',
                        theme.primary,
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _capacityPct,
                                minHeight: isMobile ? 5 : 7,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _barColor,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 4 : 8),
                          Text(
                            '${(_capacityPct * 100).round()}%',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: isMobile ? 9 : 11,
                              fontWeight: FontWeight.bold,
                              color: _barColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 6 : 8),
                      _detailRow('Released', '$adopted pets', theme.primary),
                      SizedBox(height: isMobile ? 8 : 12),
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color:
                                isHovered
                                    ? theme.primary
                                    : theme.primary.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'View Pets',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  color: Colors.white,
                                  fontSize: isMobile ? 10 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: isMobile ? 11 : 13,
                                color: Colors.white,
                              ),
                            ],
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

      ),

    );

  }



  Widget _detailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: isMobile ? 9 : 11,
            color: Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: isMobile ? 10 : 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

}



class ShelterProfilesPage extends StatefulWidget {

  final int? petId;

  final String? type;

  final String? hasDisability;



  const ShelterProfilesPage({

    super.key,

    this.petId,

    this.type,

    this.hasDisability,

  });



  @override

  State<ShelterProfilesPage> createState() => _ShelterProfilesPageState();

}



class _ShelterProfilesPageState extends State<ShelterProfilesPage> {

  final supabase = Supabase.instance.client;

  late String _selectedItem = 'Pet Management';

  List<Map<String, dynamic>> _shelters = [];

  bool _isLoading = true;

  final capacityController = TextEditingController();

  String selectedType = 'Cats';

  bool hasDisability = false;

  String? _cachedProfileImage;

  bool _isLoadingAvatar = false;

  String _selectedShelterType = 'All';



  @override

  void initState() {

    super.initState();

    _loadProfileImageForAvatar();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      debugPrint('🚀 Loading profile image after frame...');

      _loadProfileImageForAvatar();

    });

    _loadShelterData();

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



  Future<void> addShelterToDatabase(

    BuildContext context,

    String name,

    String type,

    int capacity,

    bool hasDisability,

  ) async {

    try {

      await supabase.from('shelters').insert({

        'name': name,

        'type': type,

        'capacity': capacity,

        'has_disability': 'Yes',

      });

      if (context.mounted) {

        _showSnackBar('$name added successfully!', Colors.green);

        Navigator.pop(context);

      }

      await _loadShelterData();

    } catch (error) {

      debugPrint('Error adding shelter: $error');

      if (context.mounted) {

        _showSnackBar('Unable to add shelter. Please try again.', Colors.red);

      }

    }

  }



  Future<void> updateShelterInDatabase(

    BuildContext context,

    int shelterId,

    String name,

    String type,

    int capacity,

    bool hasDisability,

  ) async {

    try {

      await supabase.from('shelters').update({

        'name': name,

        'type': type,

        'capacity': capacity,

        'has_disability': hasDisability ? 'Yes' : 'No',

      }).eq('shelter_id', shelterId);



      if (context.mounted) {

        _showSnackBar('$name updated successfully!', Colors.green);

        Navigator.pop(context);

      }

      await _loadShelterData();

    } catch (error) {

      debugPrint('Error updating shelter: $error');

      if (context.mounted) {

        _showSnackBar('Unable to update shelter. Please try again.', Colors.red);

      }

    }

  }



  Future<void> deleteShelterFromDatabase(

    BuildContext context,

    int shelterId,

  ) async {

    try {

      try {

        await supabase

            .from('pet_medications')

            .delete()

            .eq('shelter_id', shelterId);

      } catch (_) {}



      try {

        await supabase

            .from('adoptable_pets')

            .delete()

            .eq('shelter_id', shelterId);

      } catch (_) {}



      try {

        await supabase

            .from('pet_health_records')

            .delete()

            .eq('shelter_id', shelterId);

      } catch (_) {}



      try {

        await supabase.from('vet_vials').delete().eq('shelter_id', shelterId);

      } catch (_) {}



      try {

        await supabase

            .from('pets')

            .update({'shelter_id': null, 'status': 'In Shelter'})

            .eq('shelter_id', shelterId);

      } catch (_) {

        await supabase.from('pets').delete().eq('shelter_id', shelterId);

      }



      await supabase.from('shelters').delete().eq('shelter_id', shelterId);



      // Re-number remaining default-named shelters sequentially

      final remainingData = await supabase

          .from('shelters')

          .select('shelter_id, name')

          .order('shelter_id', ascending: true);



      final defaultShelterRegex = RegExp(r'^Shelter \d+$');

      for (int i = 0; i < remainingData.length; i++) {

        final remaining = remainingData[i];

        final currentName = remaining['name']?.toString() ?? '';

        if (currentName.isEmpty || defaultShelterRegex.hasMatch(currentName)) {

          final newName = 'Shelter ${i + 1}';

          if (currentName != newName) {

            await supabase

                .from('shelters')

                .update({'name': newName})

                .eq('shelter_id', remaining['shelter_id']);

          }

        }

      }



      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text(

              'Shelter deleted successfully.',

              style: TextStyle(fontFamily: 'Montserrat'),

            ),

            backgroundColor: Colors.green,

          ),

        );

      }

      await _loadShelterData();

    } catch (error) {

      debugPrint('Error deleting shelter: $error');

      if (context.mounted) {

        _showSnackBar(

          'Unable to delete shelter. Please try again.',

          Colors.red,

        );

      }

    }

  }



  Future<void> _loadShelterData() async {

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {

      final shelterData = await supabase

          .from('shelters')

          .select('*')

          .order('shelter_id', ascending: true);

      List<Map<String, dynamic>> sheltersWithCounts = [];

      for (var shelter in shelterData) {

        final shelterId = shelter['shelter_id'];

        if (shelterId == null) continue;

        final availablePets = await supabase

            .from('pets')

            .select('pet_id')

            .eq('shelter_id', shelterId)

            .eq('status', 'In Shelter');

        final adoptedPets = await supabase

            .from('adoptable_pets')

            .select('pet_id')

            .eq('shelter_id', shelterId)

            .eq('status', 'Ready For Adoption');

        sheltersWithCounts.add({

          ...shelter,

          'current_pets': availablePets.length,

          'status': adoptedPets.length,

        });

      }

      if (!mounted) return;

      setState(() {

        _shelters = sheltersWithCounts;

        _isLoading = false;

      });

    } catch (e) {

      debugPrint('Error loading shelter data: $e');

      if (!mounted) return;
      setState(() => _isLoading = false);

    }

  }



  void _viewShelter(BuildContext context, int shelterId, String shelterName) {

    final shelter = _shelters.firstWhere(

      (s) => s['shelter_id'] == shelterId,

      orElse: () => {},

    );

    final shelterType = shelter['type']?.toString() ?? '';

    Navigator.push(

      context,

      MaterialPageRoute(

        builder:

            (_) => ShelterPetsDetailPage(

              petId: widget.petId,

              shelterId: shelterId,

              shelterName: shelterName,

              type: shelterType,

              hasDisability: widget.hasDisability,

            ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(

      backgroundColor: const Color(0xFF2D2D30),

      drawer: isMobile ? Drawer(width: 200, child: _buildSidebar()) : null,

      body: Row(

        children: [

          if (!isMobile) _buildSidebar(),

          Expanded(

            child: Column(

              children: [

                _buildTopHeader(isMobile),

                Expanded(

                  child: SingleChildScrollView(

                    padding: EdgeInsets.symmetric(

                      horizontal: isMobile ? 16 : 30,

                    ),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        const SizedBox(height: 20),

                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddShelterDialog(context),
                            icon: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: isMobile ? 18 : 24,
                            ),
                            label: Text(
                              "Add Shelter",
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8C6A2F),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 14 : 22,
                                vertical: isMobile ? 8 : 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Center(

                          child: Wrap(

                            spacing: 12,

                            children: [

                              _buildFilterButton('Cats'),

                              _buildFilterButton('Dogs'),

                            ],

                          ),

                        ),

                        const SizedBox(height: 30),

                        if (_isLoading)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: LoadingAnimationWidget.fallingDot(
                                color: Colors.orange,
                                size: 50,
                              ),
                            ),
                          )

                        else if (_filteredShelters.isEmpty)

                          const Center(

                            child: Padding(

                              padding: EdgeInsets.all(40),

                              child: Text(

                                'No shelters found for this filter',

                                style: TextStyle(

                                  color: Colors.white70,

                                  fontFamily: 'Montserrat',

                                  fontSize: 16,

                                ),

                              ),

                            ),

                          )

                        else

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = constraints.maxWidth < 600 ? 2 : (constraints.maxWidth < 900 ? 2 : 3);
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredShelters.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: isMobile ? 12 : 24,
                                      mainAxisSpacing: isMobile ? 12 : 24,
                                      childAspectRatio: isMobile ? 0.65 : 0.78,
                                    ),

                                itemBuilder: (context, index) {

                                  final shelter = _filteredShelters[index];

                                  final shelterId = int.tryParse(

                                    shelter['shelter_id'].toString(),

                                  );

                                  return ShelterCard(

                                    shelter: shelter,

                                    onViewPressed:

                                        shelterId == null

                                            ? () {}

                                            : () => _viewShelter(

                                              context,

                                              shelterId,

                                              shelter['name'] ??

                                                  'Unknown Shelter',

                                            ),

                                    onEditPressed: () => _showEditShelterDialog(context, shelter),

                                    onDeletePressed: () async {

                                      final currentPets =

                                          shelter['current_pets'] ?? 0;



                                      if (currentPets > 0) {

                                        showDialog(

                                          context: context,

                                          builder:

                                              (ctx) => AlertDialog(

                                                backgroundColor: const Color(

                                                  0xFF2D2D2D,

                                                ),

                                                shape: RoundedRectangleBorder(

                                                  borderRadius:

                                                      BorderRadius.circular(12),

                                                ),

                                                title: const Row(

                                                  children: [

                                                    Icon(

                                                      Icons.lock,

                                                      color: Colors.orange,

                                                      size: 24,

                                                    ),

                                                    SizedBox(width: 10),

                                                    Text(

                                                      'Cannot Delete',

                                                      style: TextStyle(

                                                        fontFamily:

                                                            'Montserrat',

                                                        color: Colors.white,

                                                        fontWeight:

                                                            FontWeight.bold,

                                                      ),

                                                    ),

                                                  ],

                                                ),

                                                content: Text(

                                                  'This shelter still has $currentPets pet(s) inside. Please move or remove all pets before deleting this shelter.',

                                                  style: const TextStyle(

                                                    fontFamily: 'Montserrat',

                                                    color: Colors.white70,

                                                  ),

                                                ),

                                                actions: [

                                                  ElevatedButton(

                                                    style: ElevatedButton.styleFrom(

                                                      backgroundColor:

                                                          const Color(

                                                            0xFF8C6A2F,

                                                          ),

                                                      shape: RoundedRectangleBorder(

                                                        borderRadius:

                                                            BorderRadius.circular(

                                                              8,

                                                            ),

                                                      ),

                                                    ),

                                                    onPressed:

                                                        () =>

                                                            Navigator.pop(ctx),

                                                    child: const Text(

                                                      'OK',

                                                      style: TextStyle(

                                                        fontFamily:

                                                            'Montserrat',

                                                        color: Colors.white,

                                                        fontWeight:

                                                            FontWeight.bold,

                                                      ),

                                                    ),

                                                  ),

                                                ],

                                              ),

                                        );

                                        return;

                                      }



                                      final confirm = await showDialog<bool>(

                                        context: context,

                                        builder:

                                            (ctx) => AlertDialog(

                                              backgroundColor: const Color(

                                                0xFF2D2D2D,

                                              ),

                                              title: const Text(

                                                'Delete Shelter',

                                                style: TextStyle(

                                                  fontFamily: 'Montserrat',

                                                  color: Colors.white,

                                                ),

                                              ),

                                              content: const Text(

                                                'Are you sure you want to delete this shelter? This action cannot be undone.',

                                                style: TextStyle(

                                                  fontFamily: 'Montserrat',

                                                  color: Colors.white70,

                                                ),

                                              ),

                                              actions: [

                                                TextButton(

                                                  onPressed:

                                                      () => Navigator.pop(

                                                        ctx,

                                                        false,

                                                      ),

                                                  child: const Text(

                                                    'Cancel',

                                                    style: TextStyle(

                                                      fontFamily: 'Montserrat',

                                                    ),

                                                  ),

                                                ),

                                                TextButton(

                                                  onPressed:

                                                      () => Navigator.pop(

                                                        ctx,

                                                        true,

                                                      ),

                                                  child: const Text(

                                                    'Delete',

                                                    style: TextStyle(

                                                      fontFamily: 'Montserrat',

                                                      color: Colors.red,

                                                    ),

                                                  ),

                                                ),

                                              ],

                                            ),

                                      );

                                      if (confirm == true && context.mounted) {

                                        await deleteShelterFromDatabase(

                                          context,

                                          shelter['shelter_id'],

                                        );

                                      }

                                    },

                                  );

                                },

                              );

                            },

                          ),

                        const SizedBox(height: 40),

                      ],

                    ),

                  ),

                ),

                _buildFooter(context),

              ],

            ),

          ),

        ],

      ),

    );

  }



  List<Map<String, dynamic>> get _filteredShelters {

    if (_selectedShelterType == 'All') return _shelters;

    return _shelters

        .where(

          (s) =>

              s['type']?.toString().toLowerCase() ==

              _selectedShelterType.toLowerCase(),

        )

        .toList();

  }



  Widget _buildFilterButton(String type) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final isActive = _selectedShelterType == type;

    return ElevatedButton(
      onPressed: () => setState(() => _selectedShelterType = type),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.orange : const Color(0xFF444444),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 20,
          vertical: isMobile ? 8 : 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isActive ? 3 : 0,
      ),
      child: Text(
        type,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 12 : 14,
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

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

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



  Widget _buildTopHeader(bool isMobile) {

    return Container(
      height: isMobile ? 56 : null,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 20,
        vertical: isMobile ? 8 : 15,
      ),

      child: Row(

        children: [



          if (isMobile)

            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed:
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => PetPage()),
                  ),
            )

          else

            ElevatedButton.icon(

              onPressed:

                  () => Navigator.pushReplacement(

                    context,

                    MaterialPageRoute(builder: (_) => PetPage()),

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

              'Shelter Profiles',

              style: TextStyle(

                color: Colors.white,

                fontSize: isMobile ? 16 : 24,

                fontWeight: FontWeight.bold,

                fontFamily: "Montserrat",

                overflow: TextOverflow.ellipsis,

              ),

              textAlign: TextAlign.center,

            ),

          ),

          if (!isMobile) ...[
            const SizedBox(width: 8),
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
          ],

          _NotificationBell(

            iconSize: isMobile ? 22 : 24,

            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),

          ),

          SizedBox(width: isMobile ? 6 : 20),

          buildProfileAvatar(context, radius: isMobile ? 14 : 16),

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

        ).then((_) => _loadProfileImageForAvatar());

      },

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



  void _showAddShelterDialog(BuildContext context) {

    String selectedType = widget.type?.toString() == 'Dogs' ? 'Dogs' : 'Cats';

    bool hasDisability = false;

    final nameController = TextEditingController();

    final capacityController = TextEditingController();



    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) {

        return AlertDialog(

          backgroundColor: const Color(0xFF2D2D2D),

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(16),

          ),

          title: const Center(

            child: Text(

              'Add Shelter',

              style: TextStyle(

                color: Colors.white,

                fontFamily: 'Montserrat',

                fontWeight: FontWeight.bold,

                fontSize: 22,

              ),

            ),

          ),

          content: StatefulBuilder(

            builder: (context, setState) {

              return Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  const SizedBox(height: 12),

                  const Align(

                    alignment: Alignment.centerLeft,

                    child: Text(

                      'Shelter Name (Optional)',

                      style: TextStyle(

                        color: Colors.white70,

                        fontFamily: 'Montserrat',

                        fontSize: 16,

                      ),

                    ),

                  ),

                  const SizedBox(height: 8),

                  TextField(

                    controller: nameController,

                    style: const TextStyle(

                      color: Colors.white,

                      fontFamily: 'Montserrat',

                    ),

                    decoration: InputDecoration(

                      hintText: 'Enter shelter name',

                      hintStyle: const TextStyle(

                        color: Colors.white54,

                        fontFamily: 'Montserrat',

                      ),

                      filled: true,

                      fillColor: const Color(0xFF3C3C3C),

                      border: OutlineInputBorder(

                        borderRadius: BorderRadius.circular(8),

                        borderSide: BorderSide.none,

                      ),

                    ),

                  ),

                  const SizedBox(height: 20),

                  const Align(

                    alignment: Alignment.centerLeft,

                    child: Text(

                      'Type',

                      style: TextStyle(

                        color: Colors.white70,

                        fontFamily: 'Montserrat',

                        fontSize: 16,

                      ),

                    ),

                  ),

                  const SizedBox(height: 8),

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 12),

                    decoration: BoxDecoration(

                      color: const Color(0xFF3C3C3C),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: DropdownButtonHideUnderline(

                      child: DropdownButton<String>(

                        value: selectedType,

                        dropdownColor: const Color(0xFF3C3C3C),

                        style: const TextStyle(

                          color: Colors.white,

                          fontFamily: 'Montserrat',

                        ),

                        items: const [

                          DropdownMenuItem(

                            value: 'Cats',

                            child: Text(

                              'Cats',

                              style: TextStyle(fontFamily: 'Montserrat'),

                            ),

                          ),

                          DropdownMenuItem(

                            value: 'Dogs',

                            child: Text(

                              'Dogs',

                              style: TextStyle(fontFamily: 'Montserrat'),

                            ),

                          ),

                        ],

                        onChanged:

                            (value) => setState(() => selectedType = value!),

                      ),

                    ),

                  ),

                  const SizedBox(height: 20),

                  const Align(

                    alignment: Alignment.centerLeft,

                    child: Text(

                      'Capacity',

                      style: TextStyle(

                        color: Colors.white70,

                        fontFamily: 'Montserrat',

                        fontSize: 16,

                      ),

                    ),

                  ),

                  const SizedBox(height: 8),

                  TextField(

                    controller: capacityController,

                    keyboardType: TextInputType.number,

                    style: const TextStyle(

                      color: Colors.white,

                      fontFamily: 'Montserrat',

                    ),

                    decoration: InputDecoration(

                      hintText: 'Enter capacity',

                      hintStyle: const TextStyle(

                        color: Colors.white54,

                        fontFamily: 'Montserrat',

                      ),

                      filled: true,

                      fillColor: const Color(0xFF3C3C3C),

                      border: OutlineInputBorder(

                        borderRadius: BorderRadius.circular(8),

                        borderSide: BorderSide.none,

                      ),

                    ),

                  ),

                  const SizedBox(height: 20),

                  const Align(

                    alignment: Alignment.centerLeft,

                    child: Text(

                      'Has Disability?',

                      style: TextStyle(

                        color: Colors.white70,

                        fontFamily: 'Montserrat',

                        fontSize: 16,

                      ),

                    ),

                  ),

                  const SizedBox(height: 8),

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 12),

                    decoration: BoxDecoration(

                      color: const Color(0xFF3C3C3C),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: DropdownButtonHideUnderline(

                      child: DropdownButton<String>(

                        value: hasDisability ? 'Yes' : 'No',

                        dropdownColor: const Color(0xFF3C3C3C),

                        style: const TextStyle(

                          color: Colors.white,

                          fontFamily: 'Montserrat',

                        ),

                        items: const [

                          DropdownMenuItem(

                            value: 'Yes',

                            child: Text(

                              'Yes',

                              style: TextStyle(fontFamily: 'Montserrat'),

                            ),

                          ),

                          DropdownMenuItem(

                            value: 'No',

                            child: Text(

                              'No',

                              style: TextStyle(fontFamily: 'Montserrat'),

                            ),

                          ),

                        ],

                        onChanged:

                            (value) =>

                                setState(() => hasDisability = value == 'Yes'),

                      ),

                    ),

                  ),

                ],

              );

            },

          ),

          actionsAlignment: MainAxisAlignment.center,

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(context),

              child: const Text(

                'Cancel',

                style: TextStyle(

                  color: Colors.white70,

                  fontFamily: 'Montserrat',

                  fontSize: 16,

                ),

              ),

            ),

            ElevatedButton(

              style: ElevatedButton.styleFrom(

                backgroundColor: const Color(0xFF8C6A2F),

                padding: const EdgeInsets.symmetric(

                  horizontal: 24,

                  vertical: 14,

                ),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(10),

                ),

              ),

              onPressed: () async {

                final capacity =

                    int.tryParse(capacityController.text.trim()) ?? 0;

                if (capacity <= 0) {

                  _showSnackBar('Please enter a valid capacity.', Colors.red);

                  return;

                }

                String name = nameController.text.trim();

                if (name.isEmpty) {

                  final shelterCount = _shelters.length + 1;

                  name = 'Shelter $shelterCount';

                }

                await addShelterToDatabase(

                  context,

                  name,

                  selectedType,

                  capacity,

                  hasDisability,

                );

              },

              child: const Text(

                'Add Shelter',

                style: TextStyle(

                  color: Colors.white,

                  fontFamily: 'Montserrat',

                  fontWeight: FontWeight.bold,

                  fontSize: 16,

                ),

              ),

            ),

          ],

        );

      },

    );

  }



  void _showEditShelterDialog(BuildContext context, Map<String, dynamic> shelter) {

    final shelterId = int.tryParse(shelter['shelter_id'].toString()) ?? 0;

    final nameController = TextEditingController(text: shelter['name'] ?? '');

    final capacityController = TextEditingController(text: (shelter['capacity'] ?? '').toString());

    String selectedType = shelter['type']?.toString() == 'Dogs' ? 'Dogs' : 'Cats';

    bool hasDisability = shelter['has_disability']?.toString() == 'Yes';



    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) {

        return AlertDialog(

          backgroundColor: const Color(0xFF2D2D2D),

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(16),

          ),

          title: const Center(

            child: Text(

              'Edit Shelter',

              style: TextStyle(

                color: Colors.white,

                fontFamily: 'Montserrat',

                fontWeight: FontWeight.bold,

                fontSize: 22,

              ),

            ),

          ),

          content: StatefulBuilder(

            builder: (context, setState) {

              return Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  const SizedBox(height: 12),

                  const Align(

                    alignment: Alignment.centerLeft,

                    child: Text(

                      'Shelter Name (Optional)',

                      style: TextStyle(

                        color: Colors.white70,

                        fontFamily: 'Montserrat',

                        fontSize: 16,

                      ),

                    ),

                  ),

                  const SizedBox(height: 8),

                  TextField(

                    controller: nameController,

                    style: const TextStyle(

                      color: Colors.white,

                      fontFamily: 'Montserrat',

                    ),

                    decoration: InputDecoration(

                      hintText: 'Enter shelter name',

                      hintStyle: const TextStyle(

                        color: Colors.white54,

                        fontFamily: 'Montserrat',

                      ),

                      filled: true,

                      fillColor: const Color(0xFF3C3C3C),

                      border: OutlineInputBorder(

                        borderRadius: BorderRadius.circular(8),

                        borderSide: BorderSide.none,

                      ),

                    ),

                  ),

                  const SizedBox(height: 20),

                  const Align(

                    alignment: Alignment.centerLeft,

                    child: Text(

                      'Type',

                      style: TextStyle(

                        color: Colors.white70,

                        fontFamily: 'Montserrat',

                        fontSize: 16,

                      ),

                    ),

                  ),

                  const SizedBox(height: 8),

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 12),

                    decoration: BoxDecoration(

                      color: const Color(0xFF3C3C3C),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: DropdownButtonHideUnderline(

                      child: DropdownButton<String>(

                        value: selectedType,

                        dropdownColor: const Color(0xFF3C3C3C),

                        style: const TextStyle(

                          color: Colors.white,

                          fontFamily: 'Montserrat',

                        ),

                        items: const [

                          DropdownMenuItem(

                            value: 'Cats',

                            child: Text(

                              'Cats',

                              style: TextStyle(fontFamily: 'Montserrat'),

                            ),

                          ),

                          DropdownMenuItem(

                            value: 'Dogs',

                            child: Text(

                              'Dogs',

                              style: TextStyle(fontFamily: 'Montserrat'),

                            ),

                          ),

                        ],

                        onChanged:

                            (value) => setState(() => selectedType = value!),

                      ),

                    ),

                  ),

                  const SizedBox(height: 20),

                  const Align(

                    alignment: Alignment.centerLeft,

                    child: Text(

                      'Capacity',

                      style: TextStyle(

                        color: Colors.white70,

                        fontFamily: 'Montserrat',

                        fontSize: 16,

                      ),

                    ),

                  ),

                  const SizedBox(height: 8),

                  TextField(

                    controller: capacityController,

                    keyboardType: TextInputType.number,

                    style: const TextStyle(

                      color: Colors.white,

                      fontFamily: 'Montserrat',

                    ),

                    decoration: InputDecoration(

                      hintText: 'Enter capacity',

                      hintStyle: const TextStyle(

                        color: Colors.white54,

                        fontFamily: 'Montserrat',

                      ),

                      filled: true,

                      fillColor: const Color(0xFF3C3C3C),

                      border: OutlineInputBorder(

                        borderRadius: BorderRadius.circular(8),

                        borderSide: BorderSide.none,

                      ),

                    ),

                  ),

                  const SizedBox(height: 20),

                  const Align(

                    alignment: Alignment.centerLeft,

                    child: Text(

                      'Has Disability?',

                      style: TextStyle(

                        color: Colors.white70,

                        fontFamily: 'Montserrat',

                        fontSize: 16,

                      ),

                    ),

                  ),

                  const SizedBox(height: 8),

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 12),

                    decoration: BoxDecoration(

                      color: const Color(0xFF3C3C3C),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: DropdownButtonHideUnderline(

                      child: DropdownButton<String>(

                        value: hasDisability ? 'Yes' : 'No',

                        dropdownColor: const Color(0xFF3C3C3C),

                        style: const TextStyle(

                          color: Colors.white,

                          fontFamily: 'Montserrat',

                        ),

                        items: const [

                          DropdownMenuItem(

                            value: 'Yes',

                            child: Text(

                              'Yes',

                              style: TextStyle(fontFamily: 'Montserrat'),

                            ),

                          ),

                          DropdownMenuItem(

                            value: 'No',

                            child: Text(

                              'No',

                              style: TextStyle(fontFamily: 'Montserrat'),

                            ),

                          ),

                        ],

                        onChanged:

                            (value) =>

                                setState(() => hasDisability = value == 'Yes'),

                      ),

                    ),

                  ),

                ],

              );

            },

          ),

          actionsAlignment: MainAxisAlignment.center,

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(context),

              child: const Text(

                'Cancel',

                style: TextStyle(

                  color: Colors.white70,

                  fontFamily: 'Montserrat',

                  fontSize: 16,

                ),

              ),

            ),

            ElevatedButton(

              style: ElevatedButton.styleFrom(

                backgroundColor: const Color(0xFF8C6A2F),

                padding: const EdgeInsets.symmetric(

                  horizontal: 24,

                  vertical: 14,

                ),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(10),

                ),

              ),

              onPressed: () async {

                final capacity =

                    int.tryParse(capacityController.text.trim()) ?? 0;

                if (capacity <= 0) {

                  _showSnackBar('Please enter a valid capacity.', Colors.red);

                  return;

                }

                String name = nameController.text.trim();

                if (name.isEmpty) {

                  name = shelter['name'] ?? 'Shelter $shelterId';

                }

                await updateShelterInDatabase(

                  context,

                  shelterId,

                  name,

                  selectedType,

                  capacity,

                  hasDisability,

                );

              },

              child: const Text(

                'Save',

                style: TextStyle(

                  color: Colors.white,

                  fontFamily: 'Montserrat',

                  fontWeight: FontWeight.bold,

                  fontSize: 16,

                ),

              ),

            ),

          ],

        );

      },

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



class ShelterPetsDetailPage extends StatefulWidget {

  final int shelterId;

  final int? petId;

  final String? type;

  final String? hasDisability;

  final Map<String, dynamic>? pet;

  final bool showMedicationOverlay;

  final String? shelterName;



  const ShelterPetsDetailPage({

    super.key,

    this.showMedicationOverlay = true,

    required this.shelterId,

    this.shelterName,

    this.petId,

    this.pet,

    this.type,

    this.hasDisability,

  });



  @override

  State<ShelterPetsDetailPage> createState() => _ShelterPetsDetailPageState();

}



class _ShelterPetsDetailPageState extends State<ShelterPetsDetailPage>

    with TickerProviderStateMixin {

  final supabase = Supabase.instance.client;



  String selectedHealthStatus = 'Healthy';

  final List<Map<String, dynamic>> offspringList = [];

  bool isLoading = true;

  List<Map<String, dynamic>> _allPets = [];

  List<Map<String, dynamic>> _pets = [];

  List<Map<String, dynamic>> _shelters = [];

  List<Map<String, dynamic>> _filteredPets = [];

  List<Map<String, dynamic>> pets = [];

  List<Map<String, dynamic>> petsUnderMedication = [];



  bool _isSelectionMode = false;

  bool _isLoadingAvatar = false;

  final Set<int> _selectedPetIds = {};

  final String _petRecordsFilter = 'All';

  String _selectedAgeFilter = 'All Ages';

  String _selectedItem = 'Pet Management';

  int _currentShelterIndex = 0;



  String? _cachedProfileImage;



  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();



  final TextEditingController _searchController = TextEditingController();

  final ScrollController _tableScrollController = ScrollController();



  late AnimationController _controller;

  late Animation<double> _animation;



  RealtimeChannel? _medicationChannel;

  RealtimeChannel? _petsChannel;



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



  void _onPetAdded() {

    _loadShelterPets();

    _loadProfileImageForAvatar();

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



  void _showBulkMoveDialog() {

    showDialog(

      context: context,

      builder: (context) {

        return Dialog(

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(16),

          ),

          backgroundColor: const Color(0xFF2D2D30),

          child: Padding(

            padding: const EdgeInsets.all(24),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Row(

                  children: const [

                    Icon(Icons.drive_file_move, color: Colors.orange),

                    SizedBox(width: 12),

                    Text(

                      'Move Selected Pets',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 20,

                        fontWeight: FontWeight.bold,

                        fontFamily: 'Montserrat',

                      ),

                    ),

                  ],

                ),

                const SizedBox(height: 24),

                _buildMoveOption(

                  label: 'To Adoption',

                  icon: Icons.medical_services,

                  color: Colors.green,

                  onTap: () async {

                    await _bulkMove(value: 'Ready For Adoption');

                    Navigator.pop(context);

                  },

                ),

                const SizedBox(height: 12),

                _buildMoveOption(

                  label: 'To Medication',

                  icon: Icons.medical_services,

                  color: Colors.green,

                  onTap: () async {

                    await _bulkMove(value: 'Under Medication');

                    Navigator.pop(context);

                  },

                ),

                const SizedBox(height: 24),

                Align(

                  alignment: Alignment.centerRight,

                  child: TextButton(

                    onPressed: () => Navigator.pop(context),

                    child: const Text(

                      'Cancel',

                      style: TextStyle(

                        color: Colors.white70,

                        fontFamily: 'Montserrat',

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

  }



  bool _isTooYoung(dynamic age) {

    if (age == null) return false;

    final ageStr = age.toString().toLowerCase().trim();

    if (ageStr.isEmpty) return false;



    // If it contains "year", never too young

    if (ageStr.contains('year')) return false;



    // Match months - under 3 months is too young

    final monthMatch = RegExp(r'(\d+)\s*month').firstMatch(ageStr);

    if (monthMatch != null) {

      return (int.tryParse(monthMatch.group(1) ?? '') ?? 99) < 3;

    }



    // Match weeks - under 12 weeks is too young

    final weekMatch = RegExp(r'(\d+)\s*week').firstMatch(ageStr);

    if (weekMatch != null) {

      return (int.tryParse(weekMatch.group(1) ?? '') ?? 99) < 12;

    }



    // Days always too young

    if (ageStr.contains('day')) return true;



    // Pure number with no unit — treat as months if < 3

    final numOnly = RegExp(r'^\d+$').firstMatch(ageStr);

    if (numOnly != null) {

      return (int.tryParse(ageStr) ?? 99) < 3;

    }



    return false;

  }

  bool _matchesAgeFilter(dynamic age, String filter) {
    if (filter == 'All Ages') return true;
    if (age == null) return false;

    final ageStr = age.toString().toLowerCase().trim();
    if (ageStr.isEmpty) return false;

    if (filter == 'Too Young (< 3 mos)') {
      return _isTooYoung(ageStr);
    }

    double months = 0;
    final yearMatch = RegExp(r'(\d+(?:\.\d+)?)\s*year').firstMatch(ageStr);
    final monthMatch = RegExp(r'(\d+(?:\.\d+)?)\s*month').firstMatch(ageStr);
    final weekMatch = RegExp(r'(\d+(?:\.\d+)?)\s*week').firstMatch(ageStr);
    final dayMatch = RegExp(r'(\d+(?:\.\d+)?)\s*day').firstMatch(ageStr);

    if (yearMatch != null) {
      months += (double.tryParse(yearMatch.group(1) ?? '') ?? 0) * 12;
    }
    if (monthMatch != null) {
      months += double.tryParse(monthMatch.group(1) ?? '') ?? 0;
    }
    if (weekMatch != null) {
      months += (double.tryParse(weekMatch.group(1) ?? '') ?? 0) / 4.33;
    }
    if (dayMatch != null) {
      months += (double.tryParse(dayMatch.group(1) ?? '') ?? 0) / 30.0;
    }

    if (yearMatch == null && monthMatch == null && weekMatch == null && dayMatch == null) {
      final numVal = double.tryParse(ageStr);
      if (numVal != null) months = numVal;
    }

    if (filter == 'Baby (< 1 yr)') {
      return months < 12;
    } else if (filter == 'Young (1 - 3 yrs)') {
      return months >= 12 && months < 36;
    } else if (filter == 'Adult (3 - 7 yrs)') {
      return months >= 36 && months < 84;
    } else if (filter == 'Senior (7+ yrs)') {
      return months >= 84;
    }

    return true;
  }

  Widget _buildAgeFilterDropdown({bool isMobile = false}) {
    final options = [
      'All Ages',
      'Too Young (< 3 mos)',
      'Baby (< 1 yr)',
      'Young (1 - 3 yrs)',
      'Adult (3 - 7 yrs)',
      'Senior (7+ yrs)',
    ];

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3C3C3E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAgeFilter,
          dropdownColor: const Color(0xFF3C3C3E),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w600,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedAgeFilter = newValue;
              });
              _filterSearch();
            }
          },
          items: options.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }



  Future<void> _showAddOffspringDialog(

    BuildContext context,

    Map<String, dynamic> motherPet,

  ) async {

    final motherId = motherPet['pet_id'];

    final motherName = motherPet['name'] ?? 'Unknown';

    final motherType = motherPet['type'] ?? 'Cat';



    final String initialBreed = motherPet['breed'] ?? '';
    final String defaultBreedOption = (initialBreed == 'Puspin' || initialBreed == 'Aspin')
        ? initialBreed
        : (initialBreed.isEmpty ? 'Puspin' : 'Others');

    String selectedBreed = defaultBreedOption;
    String selectedColor = 'BLACK';

    final nameController = TextEditingController();

    final colorController = TextEditingController(text: 'BLACK');

    final breedController = TextEditingController(

      text: initialBreed.isEmpty ? 'Puspin' : initialBreed,

    );

    final ageController = TextEditingController(text: '0 months');

    final mainAgeNumberCtrl = TextEditingController(text: '0');

    String mainAgeUnit = 'month(s) old';

    final descriptionController = TextEditingController();

    final rescueAgeController = TextEditingController();

    final mainRescueAgeNumberCtrl = TextEditingController();

    String mainRescueAgeUnit = 'month(s) old';

    final originController = TextEditingController();

    final diseaseDetailsController = TextEditingController();



    String selectedGender = 'Male';

    String selectedEnergy = 'Low';

    String selectedOrigin = 'Shelter Born';

    String selectedStatus = 'In Shelter';

    String selectedHealthStatus = 'Healthy';

    String selectedVaccinationStatus = 'Not Vaccinated';

    String selectedDewormingStatus = 'Not Dewormed';

    String selectedNeuteredStatus = 'Not Neutered/Spayed';

    String selectedDiseaseType = 'No Disease';

    String selectedSurgeryType = 'No Surgery Type';

    String selectedSurgeryDetails = 'No Surgery Details';

    String hasDisability = 'No';

    DateTime? selectedDob;

    bool isRescued = false;

    Uint8List? imageBytes;

    bool saveAttempted = false;



    final originOptions = [

      'Shelter Born',

      'Rescued',

      'Surrendered by Owner',

      'Transfer from Another Shelter',

      'Found Stray',

      'Other',

    ];



    final List<String> diseaseOptions = [

      'No Disease',

      'Parvovirus',

      'Distemper',

      'Heartworm',

      'Rabies',

      'Kennel Cough',

      'Ringworm',

      'Mange',

      'Feline Leukemia',

      'Upper Respiratory Infection',

      'Other',

    ];



    final Map<String, List<String>> surgeryDetailsOptions = {

      'No Surgery Type': ['No Surgery Details'],

      'Dental Surgery': ['Dental Cleaning', 'Tooth Extraction'],

      'C-Section Surgery': ['Emergency C-Section', 'Planned C-Section'],

      'Tumor Removal': ['Skin Tumor', 'Internal Tumor'],

      'Fracture Repair': ['Leg Fracture', 'Jaw Fracture'],

      'Eye Surgery': ['Cataract Removal', 'Eye Injury Repair'],

      'Ear Surgery': ['Ear Canal Removal', 'Ear Hematoma Repair'],

      'Hernia Repair': ['Umbilical Hernia', 'Inguinal Hernia'],

      'Bladder Stone Removal': ['Small Stone', 'Large Stone'],

      'Amputation': ['Leg Amputation', 'Tail Amputation'],

    };



    await showDialog(

      context: context,

      barrierDismissible: false,

      builder: (dialogContext) {

        return StatefulBuilder(

          builder: (dialogContext, setDialogState) {

            final bool imageError = saveAttempted && imageBytes == null;



            Widget buildSection(String title) => Padding(

              padding: const EdgeInsets.only(top: 20, bottom: 10),

              child: Row(

                children: [

                  Expanded(child: Divider(color: Colors.pink.withOpacity(0.3))),

                  const SizedBox(width: 8),

                  Text(

                    title,

                    style: const TextStyle(

                      color: Colors.pinkAccent,

                      fontFamily: 'Montserrat',

                      fontWeight: FontWeight.bold,

                      fontSize: 12,

                      letterSpacing: 0.8,

                    ),

                  ),

                  const SizedBox(width: 8),

                  Expanded(child: Divider(color: Colors.pink.withOpacity(0.3))),

                ],

              ),

            );



            Widget buildField(

              String label,

              TextEditingController ctrl, {

              int maxLines = 1,

              TextInputType keyboardType = TextInputType.text,

            }) => Padding(

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



            Widget buildDropdown(

              String label,

              String value,

              List<String> options,

              ValueChanged<String?> onChanged,

            ) => Padding(

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

                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,

                ),

                decoration: BoxDecoration(

                  color: const Color(0xFF1E1E1E),

                  borderRadius: BorderRadius.circular(20),

                ),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    // ── Header ──────────────────────────────────────────

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

                          const Icon(Icons.child_care, color: Colors.pink),

                          const SizedBox(width: 10),

                          Expanded(

                            child: Column(

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

                                const Text(

                                  'Add Offspring',

                                  style: TextStyle(

                                    color: Colors.white,

                                    fontFamily: 'Montserrat',

                                    fontWeight: FontWeight.bold,

                                    fontSize: 16,

                                  ),

                                ),

                                Text(

                                  'Mother: $motherName',

                                  style: const TextStyle(

                                    color: Colors.white54,

                                    fontFamily: 'Montserrat',

                                    fontSize: 12,

                                  ),

                                ),

                              ],

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



                    // ── Scrollable content ───────────────────────────────

                    Flexible(

                      child: Scrollbar(

                        thumbVisibility: true,

                        child: SingleChildScrollView(

                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),

                          child: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              // ── Photo ──────────────────────────────────

                              Center(

                                child: GestureDetector(

                                  onTap: () async {

                                    final picked = await ImagePicker()

                                        .pickImage(source: ImageSource.gallery);

                                    if (picked == null) return;

                                    final bytes = await picked.readAsBytes();

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

                                      imageBytes = Uint8List.fromList(jpgBytes);

                                    });

                                  },

                                  child: Column(

                                    children: [

                                      CircleAvatar(

                                        radius: 48,

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

                              const SizedBox(height: 16),



                              // ── Mother info banner ─────────────────────

                              Container(

                                padding: const EdgeInsets.all(12),

                                decoration: BoxDecoration(

                                  color: Colors.pink.withOpacity(0.07),

                                  borderRadius: BorderRadius.circular(10),

                                  border: Border.all(

                                    color: Colors.pink.withOpacity(0.3),

                                  ),

                                ),

                                child: Row(

                                  children: [

                                    const Icon(

                                      Icons.favorite,

                                      color: Colors.pinkAccent,

                                      size: 16,

                                    ),

                                    const SizedBox(width: 8),

                                    Expanded(

                                      child: Text(

                                        'Offspring of $motherName · '

                                        'Species: $motherType · '

                                        'Breed: ${motherPet['breed'] ?? '—'}',

                                        style: const TextStyle(

                                          color: Colors.pinkAccent,

                                          fontFamily: 'Montserrat',

                                          fontSize: 12,

                                        ),

                                      ),

                                    ),

                                  ],

                                ),

                              ),



                              // ── Basic Info ─────────────────────────────

                              buildSection('Basic Information'),

                              buildField('Name *', nameController),

                              buildDropdown(
                                'Color',
                                selectedColor,
                                motherType.toLowerCase() == 'cat'
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

                                maxLines: 3,

                              ),



                              // ── Details ────────────────────────────────

                              buildSection('Details'),

                              buildDropdown(

                                'Sex',

                                selectedGender,

                                ['Male', 'Female'],

                                (v) =>

                                    setDialogState(() => selectedGender = v!),

                              ),

                              buildDropdown(

                                'Energy Level',

                                selectedEnergy,

                                ['Low', 'Medium', 'High'],

                                (v) =>

                                    setDialogState(() => selectedEnergy = v!),

                              ),

                              buildDropdown(

                                'Has Disability?',

                                hasDisability,

                                ['Yes', 'No'],

                                (v) => setDialogState(() => hasDisability = v!),

                              ),

                              buildDropdown(

                                'Initial Status',

                                selectedStatus,

                                ['In Shelter', 'Under Medication'],

                                (v) =>

                                    setDialogState(() => selectedStatus = v!),

                              ),



                              // ── Origin ─────────────────────────────────

                              buildSection('Origin & Background'),

                              buildDropdown(

                                'Origin',

                                selectedOrigin,

                                originOptions,

                                (v) {

                                  setDialogState(() {

                                    selectedOrigin = v!;

                                    isRescued =

                                        v == 'Rescued' || v == 'Found Stray';

                                    if (!isRescued) rescueAgeController.clear();

                                    if (v != 'Other') originController.clear();

                                  });

                                },

                              ),

                              if (selectedOrigin == 'Other')

                                buildField('Specify Origin', originController),

                              if (isRescued)

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



                              // ── Date of Birth ──────────────────────────

                              buildSection('Date of Birth'),

                              GestureDetector(

                                onTap: () async {

                                  final picked = await showDatePicker(

                                    context: dialogContext,

                                    initialDate:

                                        selectedDob ??

                                        DateTime.now().subtract(

                                          const Duration(days: 30),

                                        ),

                                    firstDate: DateTime(2000),

                                    lastDate: DateTime.now(),

                                    builder:

                                        (ctx, child) => Theme(

                                          data: ThemeData.dark().copyWith(

                                            colorScheme: const ColorScheme.dark(

                                              primary: Colors.pink,

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

                                      color: Colors.pink.withOpacity(0.4),

                                    ),

                                  ),

                                  child: Row(

                                    children: [

                                      const Icon(

                                        Icons.calendar_today,

                                        color: Colors.pink,

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



                              // ── Health & Medical ───────────────────────

                              buildSection('Health & Medical'),

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

                              buildDropdown(

                                'Vaccination Status',

                                selectedVaccinationStatus,

                                [

                                  'Not Vaccinated',

                                  'Partially Vaccinated',

                                  'Fully Vaccinated',

                                  'Vaccination Due',

                                  'Vaccination Overdue',

                                ],

                                (v) => setDialogState(

                                  () => selectedVaccinationStatus = v!,

                                ),

                              ),

                              buildDropdown(

                                'Deworming Status',

                                selectedDewormingStatus,

                                [

                                  'Not Dewormed',

                                  'Dewormed',

                                  'Deworming Due',

                                  'Deworming Overdue',

                                ],

                                (v) => setDialogState(

                                  () => selectedDewormingStatus = v!,

                                ),

                              ),

                              buildDropdown(

                                'Neutered / Spayed',

                                selectedNeuteredStatus,

                                [

                                  'Not Neutered/Spayed',

                                  'Neutered',

                                  'Spayed',

                                  'Scheduled',

                                ],

                                (v) => setDialogState(

                                  () => selectedNeuteredStatus = v!,

                                ),

                              ),

                              buildDropdown(

                                'Disease Type',

                                selectedDiseaseType,

                                diseaseOptions,

                                (v) => setDialogState(

                                  () => selectedDiseaseType = v!,

                                ),

                              ),

                              if (selectedDiseaseType != 'No Disease')

                                buildField(

                                  'Disease Details',

                                  diseaseDetailsController,

                                ),

                              buildDropdown(

                                'Surgery Type',

                                selectedSurgeryType,

                                surgeryDetailsOptions.keys.toList(),

                                (v) {

                                  setDialogState(() {

                                    selectedSurgeryType = v!;

                                    selectedSurgeryDetails =

                                        surgeryDetailsOptions[v]!.first;

                                  });

                                },

                              ),

                              if (selectedSurgeryType != 'No Surgery Type')

                                buildDropdown(

                                  'Surgery Details',

                                  selectedSurgeryDetails,

                                  surgeryDetailsOptions[selectedSurgeryType]!,

                                  (v) => setDialogState(

                                    () => selectedSurgeryDetails = v!,

                                  ),

                                ),

                            ],

                          ),

                        ),

                      ),

                    ),



                    // ── Footer buttons ───────────────────────────────────

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

                            child: ElevatedButton.icon(

                              icon: const Icon(

                                Icons.child_care,

                                color: Colors.white,

                                size: 16,

                              ),

                              label: const Text(

                                'Save Offspring',

                                style: TextStyle(

                                  color: Colors.white,

                                  fontFamily: 'Montserrat',

                                  fontWeight: FontWeight.bold,

                                ),

                              ),

                              style: ElevatedButton.styleFrom(

                                backgroundColor: Colors.pink,

                                padding: const EdgeInsets.symmetric(

                                  vertical: 14,

                                ),

                                shape: RoundedRectangleBorder(

                                  borderRadius: BorderRadius.circular(10),

                                ),

                              ),

                              onPressed: () async {

                                setDialogState(() => saveAttempted = true);



                                // ── Validation ─────────────────────────

                                if (imageBytes == null) return;



                                if (nameController.text.trim().isEmpty) {

                                  _showSnackBar(

                                    'Please enter a name for the offspring.',

                                    Colors.red,

                                  );

                                  return;

                                }



                                if (selectedOrigin == 'Other' &&

                                    originController.text.trim().isEmpty) {

                                  _showSnackBar(

                                    'Please specify the origin.',

                                    Colors.red,

                                  );

                                  return;

                                }



                                try {

                                  // ── Upload image ───────────────────────

                                  final filePath =

                                      'pets/images/${DateTime.now().millisecondsSinceEpoch}.jpg';

                                  await supabase.storage

                                      .from('pets')

                                      .uploadBinary(filePath, imageBytes!);

                                  final imageUrl = supabase.storage

                                      .from('pets')

                                      .getPublicUrl(filePath);



                                  final shelterId =

                                      motherPet['shelter_id'] ??

                                      (_shelters.isNotEmpty

                                          ? _shelters[_currentShelterIndex]['shelter_id']

                                          : widget.shelterId);



                                  // ── Insert pet ─────────────────────────

                                  await supabase.from('pets').insert({

                                    'name': nameController.text.trim(),

                                    'color':

                                        colorController.text.trim().isEmpty

                                            ? 'Unknown'

                                            : colorController.text.trim(),

                                    'breed':

                                        breedController.text.trim().isEmpty

                                            ? (motherPet['breed'] ?? '')

                                            : breedController.text.trim(),

                                    'age':

                                        ageController.text.trim().isEmpty

                                            ? '0 months'

                                            : ageController.text.trim(),

                                    'type': motherType,

                                    'energy': selectedEnergy,

                                    'sex': selectedGender,

                                    'status': selectedStatus,

                                    'description':

                                        descriptionController.text

                                                .trim()

                                                .isEmpty

                                            ? 'Offspring of $motherName.'

                                            : descriptionController.text.trim(),

                                    'image_url_1': imageUrl,

                                    'shelter_id': shelterId,

                                    'origin':

                                        selectedOrigin == 'Other'

                                            ? originController.text.trim()

                                            : selectedOrigin,

                                    'is_offspring': true,

                                    'motherpet_id': motherId,

                                    'rescue_age':

                                        isRescued

                                            ? rescueAgeController.text.trim()

                                            : null,

                                    'date_of_birth':

                                        selectedDob?.toIso8601String(),

                                    'has_disability': hasDisability == 'Yes',

                                    'health_status': selectedHealthStatus,

                                    'vaccination_status':

                                        selectedVaccinationStatus,

                                    'deworming_status': selectedDewormingStatus,

                                    'neutered_spayed_details':

                                        selectedNeuteredStatus,

                                    'disease_type': selectedDiseaseType,

                                    'disease_details':

                                        selectedDiseaseType != 'No Disease'

                                            ? diseaseDetailsController.text

                                                .trim()

                                            : '',

                                    'surgery_type': selectedSurgeryType,

                                    'surgery_details':

                                        selectedSurgeryType != 'No Surgery Type'

                                            ? selectedSurgeryDetails

                                            : '',

                                    'created_at':

                                        DateTime.now().toIso8601String(),

                                  });

                                  await logActivity(
                                    action: 'Created Pet Record',
                                    description:
                                        'Created pet record for ${nameController.text.trim()}',
                                    entityType: 'Pet',
                                  );

                                  // ── If Under Medication, also insert to pet_medications ──

                                  if (selectedStatus == 'Under Medication') {

                                    await supabase

                                        .from('pet_medications')

                                        .insert({

                                          'shelter_id': shelterId,

                                          'name': nameController.text.trim(),

                                          'color':

                                              colorController.text

                                                      .trim()

                                                      .isEmpty

                                                  ? 'Unknown'

                                                  : colorController.text.trim(),

                                          'breed':

                                              breedController.text

                                                      .trim()

                                                      .isEmpty

                                                  ? (motherPet['breed'] ?? '')

                                                  : breedController.text.trim(),

                                          'age':

                                              ageController.text.trim().isEmpty

                                                  ? '0 months'

                                                  : ageController.text.trim(),

                                          'type': motherType,

                                          'energy': selectedEnergy,

                                          'sex': selectedGender,

                                          'status': 'Under Medication',

                                          'description':

                                              descriptionController.text

                                                      .trim()

                                                      .isEmpty

                                                  ? 'Offspring of $motherName.'

                                                  : descriptionController.text

                                                      .trim(),

                                          'image_url_1': imageUrl,

                                          'vaccination_status':

                                              selectedVaccinationStatus,

                                          'neutered_spayed_details':

                                              selectedNeuteredStatus,

                                          'deworming_status':

                                              selectedDewormingStatus,

                                          'disease_type': selectedDiseaseType,

                                          'disease_details':

                                              selectedDiseaseType !=

                                                      'No Disease'

                                                  ? diseaseDetailsController

                                                      .text

                                                      .trim()

                                                  : '',

                                          'has_disability': hasDisability,

                                          'created_at':

                                              DateTime.now().toIso8601String(),

                                        });

                                  }



                                  await logActivity(

                                    action: 'Added Offspring',

                                    description:

                                        '${nameController.text.trim()} added as offspring of $motherName',

                                    entityType: 'pet',

                                    entityId: motherId,

                                  );



                                  if (dialogContext.mounted) {

                                    Navigator.pop(dialogContext);

                                  }



                                  _onPetAdded();



                                  if (mounted) {

                                    _showSnackBar(

                                      '${nameController.text.trim()} added as offspring of $motherName.',

                                      Colors.green,

                                    );

                                  }

                                } catch (e) {

                                  debugPrint('❌ Error adding offspring: $e');

                                  if (dialogContext.mounted) {

                                    _showSnackBar(

                                      'Failed to add offspring.',

                                      Colors.red,

                                    );

                                  }

                                }

                              },

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



  Widget _buildMoveOption({

    required String label,

    required IconData icon,

    required Color color,

    required VoidCallback onTap,

  }) {

    return GestureDetector(

      onTap: onTap,

      child: Container(

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        decoration: BoxDecoration(

          color: const Color(0xFF3C3C3E),

          borderRadius: BorderRadius.circular(12),

          border: Border.all(color: color, width: 2),

        ),

        child: Row(

          children: [

            Icon(icon, color: color),

            const SizedBox(width: 12),

            Text(

              label,

              style: TextStyle(

                color: color,

                fontSize: 16,

                fontWeight: FontWeight.bold,

                fontFamily: 'Montserrat',

              ),

            ),

          ],

        ),

      ),

    );

  }



  Future<void> _bulkMove({required String value}) async {

    if (_selectedPetIds.isEmpty) return;

    try {

      final response = await supabase

          .from('pets')

          .select()

          .inFilter('pet_id', _selectedPetIds.toList());

      final petsToMove = (response as List).cast<Map<String, dynamic>>();

      if (petsToMove.isEmpty) return;



      for (final pet in petsToMove) {

        final petId = pet['pet_id'];

        final petName = pet['name'] ?? 'Unnamed';

        await logActivity(

          action: 'Moved Pet',

          description: '$petName moved to Medication',

          entityType: 'pet',

          entityId: petId,

        );



        await logActivity(

          action: 'Moved Pet',

          description: '$petName moved to Adoption',

          entityType: 'pet',

          entityId: petId,

        );

        await logActivity(

          action: 'Bulk Move',

          description: '$petName moved to $value',

          entityType: 'pet',

          entityId: petId,

        );

        void updateLocal(String newStatus) {

          setState(() {

            final i = _filteredPets.indexWhere((p) => p['pet_id'] == petId);

            if (i != -1) _filteredPets[i]['status'] = newStatus;

            final ii = pets.indexWhere((p) => p['pet_id'] == petId);

            if (ii != -1) pets[ii]['status'] = newStatus;

          });

        }



        if (value == 'Ready For Adoption') {

          await supabase.from('adoptable_pets').upsert({

            'pet_id': petId,

            'name': petName,

            'status': value,

            'color': pet['color'] ?? 'Unknown',

            'sex': pet['sex'] ?? 'Unknown',

            'breed': pet['breed'] ?? '',

            'type': pet['type'] ?? '',

            'age': pet['age'] ?? 'Unknown',

            'energy': pet['energy'] ?? 'Low',

            'description': pet['description'] ?? '',

            'image_url_1': pet['image_url_1'] ?? '',

            'vaccination_status': pet['vaccination_status'] ?? 'Not Vaccinated',

            'neutered_spayed_details':

                pet['neutered_spayed_details'] ?? 'Not Neutered/Spayed',

            'deworming_status': pet['deworming_status'] ?? 'Not Dewormed',

            'disease_type': pet['disease_type'],

            'disease_details': pet['disease_details'],

            'has_disability': pet['has_disability'] ?? 'No',

          }, onConflict: 'pet_id');

          await supabase.from('pets').delete().eq('pet_id', petId);

          updateLocal(value);

        } else if (value == 'Under Medication') {

          await supabase.from('pet_medications').insert({

            'shelter_id':

                _shelters.isNotEmpty

                    ? _shelters[_currentShelterIndex]['shelter_id']

                    : widget.shelterId,

            'pet_id': petId,

            'name': petName,

            'status': value,

            'color': pet['color'] ?? 'Unknown',

            'sex': pet['sex'] ?? 'Unknown',

            'breed': pet['breed'] ?? '',

            'type': pet['type'] ?? '',

            'age': pet['age'] ?? 'Unknown',

            'energy': pet['energy'] ?? 'Low',

            'description': pet['description'] ?? '',

            'image_url_1': pet['image_url_1'] ?? '',

            'vaccination_status': pet['vaccination_status'] ?? 'Not Vaccinated',

            'neutered_spayed_details':

                pet['neutered_spayed_details'] ?? 'Not Neutered/Spayed',

            'deworming_status': pet['deworming_status'] ?? 'Not Dewormed',

            'disease_type': pet['disease_type'] ?? '',

            'disease_details': pet['disease_details'] ?? '',

            'created_at': DateTime.now().toIso8601String(),

          });

          await supabase

              .from('pets')

              .update({'status': value})

              .eq('pet_id', petId);



          updateLocal(value);

          await logActivity(

            action: 'Moved Pet',

            description: '$petName moved to Medication',

            entityType: 'pet',

            entityId: petId,

          );

        }

      }



      _clearSelection();

      _loadShelterPets();



      _showSnackBar('${petsToMove.length} pets moved to $value.', Colors.green);

    } catch (e) {

      debugPrint("❌ Bulk move error: $e");

      _showSnackBar('Failed to move pets.', Colors.red);

      debugPrint('Failed to move pets: $e');

    }

  }



  Future<void> _deleteSelectedPets() async {

    if (_selectedPetIds.isEmpty) return;

    await Supabase.instance.client

        .from('pets')

        .delete()

        .inFilter('pet_id', _selectedPetIds.toList());

    _clearSelection();

    _loadShelterPets();

  }



  void _previousShelter() {

    if (_currentShelterIndex > 0) {

      setState(() => _currentShelterIndex--);

      _loadShelterPets();

    }

  }



  void _nextShelter() {

    if (_currentShelterIndex < _shelters.length - 1) {

      setState(() => _currentShelterIndex++);

      _loadShelterPets();

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



  Widget buildProfileAvatar(BuildContext context, {double radius = 16}) {

    return GestureDetector(

      onTap: () {

        Navigator.push(

          context,

          MaterialPageRoute(builder: (_) => ProfilePage()),

        ).then((_) => _loadProfileImageForAvatar());

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

      try {

        await supabase.from('pet_health_records').delete().eq('pet_id', petId);

      } catch (_) {}

      try {

        await supabase.from('notifications').delete().eq('pet_id', petId);

      } catch (_) {}

      try {

        await supabase.from('pet_medications').delete().eq('pet_id', petId);

      } catch (_) {}

      try {

        await supabase.from('adoptable_pets').delete().eq('pet_id', petId);

      } catch (_) {}

      try {

        await supabase

            .from('adoption_appointments')

            .delete()

            .eq('pet_id', petId);

      } catch (_) {}

      try {

        await supabase.from('adoptions').delete().eq('pet_id', petId);

      } catch (_) {}



      await supabase.from('pets').delete().eq('pet_id', petId);



      await logActivity(

        action: 'Deleted Pet',

        description: '${pet['name']} was permanently deleted',

        entityType: 'pet',

        entityId: petId,

      );



      if (mounted) {

        setState(() {

          _pets.removeWhere((p) => p['pet_id'] == petId);

          _filteredPets.removeWhere((p) => p['pet_id'] == petId);

          _allPets.removeWhere((p) => p['pet_id'] == petId);

          petsUnderMedication.removeWhere((p) => p['pet_id'] == petId);

        });

        _showSnackBar('$petName has been permanently deleted.', Colors.green);

      }

    } catch (e) {

      debugPrint('❌ Error deleting pet: $e');

      if (mounted) {

        _showSnackBar('Failed to delete $petName.', Colors.red);

      }

    }

  }



  void _filterSearch([String? query]) {
    final q = (query ?? _searchController.text).trim().toLowerCase();
    setState(() {
      _filteredPets = _pets.where((pet) {
        final name = pet['name']?.toString().toLowerCase() ?? '';
        final age = pet['age']?.toString().toLowerCase() ?? '';
        final breed = pet['breed']?.toString().toLowerCase() ?? '';
        final energy = pet['energy']?.toString().toLowerCase() ?? '';
        final color = pet['color']?.toString().toLowerCase() ?? '';
        final status = pet['status']?.toString().toLowerCase() ?? '';

        final matchesQuery = q.isEmpty ||
            name.contains(q) ||
            breed.contains(q) ||
            age.contains(q) ||
            energy.contains(q) ||
            color.contains(q) ||
            status.contains(q);

        final matchesAge = _matchesAgeFilter(pet['age'], _selectedAgeFilter);

        return matchesQuery && matchesAge;
      }).toList();
    });
  }



  Widget _buildSearchBar() {

    return SizedBox(

      width: 250,

      child: TextField(

        controller: _searchController,

        onChanged: _filterSearch,

        decoration: InputDecoration(

          hintText: 'Search name, breed, energy, color...',

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



  Future<void> _movePet(Map<String, dynamic> pet, String destination) async {

    try {

      final petId =

          pet['pet_id'] is int

              ? pet['pet_id']

              : int.tryParse(pet['pet_id'].toString());

      if (petId == null) return;



      final petName = pet['name'] ?? 'Unnamed';

      await logActivity(

        action: 'Moved Pet',

        description: '$petName moved to Medication',

        entityType: 'pet',

        entityId: petId,

      );



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

        final shelterId = pet['shelter_id'] ?? widget.shelterId;

        await supabase.from('pet_medications').upsert({

          'pet_id': petId,

          'shelter_id': shelterId,

          'name': petName,

          'image_url_1': pet['image_url_1'],

          'type': pet['type'] ?? '',

          'breed': pet['breed'] ?? '',

          'age': pet['age'] ?? '',

          'sex': pet['sex'] ?? pet['gender'] ?? '',

          'color': pet['color'] ?? '',

          'status': 'Under Medication',

          'energy': pet['energy'],

          'description': pet['description'] ?? '',

          'has_disability': pet['has_disability'] ?? '',

          'vaccination_status': pet['vaccination_status'] ?? 'Not Vaccinated',

          'neutered_spayed_details':

              pet['neutered_spayed_details'] ?? 'Not Neutered/Spayed',

          'deworming_status': pet['deworming_status'] ?? 'Not Dewormed',

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

        await logActivity(

          action: 'Moved Pet',

          description: '$petName moved to Medication',

          entityType: 'pet',

          entityId: petId,

        );

        Future<void> notifyVetsPetMedicationChanged({

          required String petName,

          required String newStatus,

        }) async {

          try {

            final vets = await Supabase.instance.client

                .from('veterinarians')

                .select('vet_id')

                .eq('is_active', true);



            final bool isUnder = newStatus == 'Under Medication';



            for (final vet in vets) {

              await Supabase.instance.client.from('vet_notifications').insert({

                'vet_id': vet['vet_id'],

                'title':

                    isUnder

                        ? '🐾 Pet Added to Medication'

                        : '✅ Pet Removed from Medication',

                'message':

                    isUnder

                        ? '"$petName" has been placed under medication and requires your attention.'

                        : '"$petName" has been moved out of medication (status: $newStatus).',

                'type': 'medication',

                'is_read': false,

              });

            }

          } catch (e) {

            debugPrint('❌ Error notifying vets of pet medication change: $e');

          }

        }



        updateLocal('Under Medication');

      } else if (destination == 'adoption') {

        await supabase.from('adoptable_pets').upsert({

          'pet_id': petId,

          'name': petName,

          'status': 'Ready For Adoption',

          'shelter_id': pet['shelter_id'],

          'color': pet['color'] ?? 'Unknown',

          'sex': pet['sex'] ?? 'Unknown',

          'breed': pet['breed'] ?? '',

          'type': pet['type'] ?? '',

          'age': pet['age'] ?? 'Unknown',

          'energy': pet['energy'] ?? 'Low',

          'description': pet['description'] ?? '',

          'image_url_1': pet['image_url_1'] ?? '',

          'vaccination_status': pet['vaccination_status'] ?? 'Not Vaccinated',

          'neutered_spayed_details':

              pet['neutered_spayed_details'] ?? 'Not Neutered/Spayed',

          'deworming_status': pet['deworming_status'] ?? 'Not Dewormed',

          'disease_type': pet['disease_type'],

          'disease_details': pet['disease_details'],

          'has_disability': pet['has_disability'] ?? 'No',

          'created_at': pet['created_at'],

          'admin_id': pet['admin_id'],

        }, onConflict: 'pet_id');

        await supabase

            .from('pets')

            .update({'status': 'Ready For Adoption'})

            .eq('pet_id', petId);

        updateLocal("Ready For Adoption");

      }



      _showSnackBar('$petName moved to $destination.', Colors.green);

    } catch (e) {

      debugPrint("❌ Error: $e");

      _showSnackBar('Failed to move pet.', Colors.red);

    }

  }



  void _listenToShelterPets() {

    final shelterId = widget.shelterId;

    supabase

        .from('pets')

        .stream(primaryKey: ['pet_id'])

        .eq('shelter_id', shelterId) // ← correct way to filter a stream

        .listen((data) {

          final petsData =

              data

                  .where((pet) => pet['status']?.toString() == 'In Shelter')

                  .map<Map<String, dynamic>>(

                    (pet) => {

                      'pet_id': pet['pet_id'],

                      'name': pet['name'] ?? '',

                      'type': pet['type'] ?? '',

                      'status': 'In Shelter',

                      'image_url_1': pet['image_url_1'] ?? '',

                      'breed': pet['breed'] ?? '',

                      'age': pet['age'] ?? '',

                      'sex': pet['sex'] ?? '',

                      'color': pet['color'] ?? '',

                      'energy': pet['energy'] ?? '',

                      'created_at': pet['created_at'] ?? '',

                      'shelter_id': pet['shelter_id'],

                    },

                  )

                  .toList();

          if (mounted) {

            setState(() {

              _allPets = petsData;

              _pets = List<Map<String, dynamic>>.from(petsData);

              _filteredPets = List<Map<String, dynamic>>.from(petsData);

              isLoading = false;

            });

          }

        });

  }



  @override

  void initState() {

    super.initState();

    _initializeShelters();

    _listenToShelterPets();

    _loadProfileImageForAvatar();

    _filteredPets = List.from(_pets);



    // Replace these two channel registrations:

    _medicationChannel =

        supabase

            .channel(

              'pets_changes_${widget.shelterId}_${DateTime.now().millisecondsSinceEpoch}',

            )

            .onPostgresChanges(

              event: PostgresChangeEvent.all,

              schema: 'public',

              table: 'pets',

              callback: (payload) async {

                if (mounted) await _loadShelterPets();

              },

            )

            .subscribe();



    _petsChannel =

        supabase

            .channel(

              'pets_deletes_${widget.shelterId}_${DateTime.now().millisecondsSinceEpoch}',

            )

            .onPostgresChanges(

              event: PostgresChangeEvent.delete,

              schema: 'public',

              table: 'pets',

              callback: (payload) {

                final deletedPetId = payload.oldRecord['pet_id'];

                if (mounted) {

                  setState(() {

                    pets.removeWhere((p) => p['pet_id'] == deletedPetId);

                    _filteredPets.removeWhere(

                      (p) => p['pet_id'] == deletedPetId,

                    );

                  });

                }

              },

            )

            .subscribe();



    _controller = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 300),

    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  }



  Future<void> _initializeShelters() async {

    await _loadShelters();

    if (_shelters.isNotEmpty) {

      final idx = _shelters.indexWhere(

        (s) => s['shelter_id'] == widget.shelterId,

      );

      setState(() => _currentShelterIndex = idx >= 0 ? idx : 0);

      await _loadShelterPets();

    }

    if (widget.petId != null) {

      WidgetsBinding.instance.addPostFrameCallback((_) async {

        final pet = await _fetchPetProfileData(context, widget.petId!);

        if (pet != null) _loadShelters();

      });

    }

  }



  Future<void> _loadShelterPets() async {

    final shelterId =

        _shelters.isNotEmpty

            ? _shelters[_currentShelterIndex]['shelter_id']

            : widget.shelterId;

    if (!mounted) return;

    setState(() => isLoading = true);

    try {

      final response = await supabase

          .from('pets')

          .select()

          .eq('shelter_id', shelterId)

          .eq('status', 'In Shelter');



      final data =

          (response as List)

              .map<Map<String, dynamic>>(

                (pet) => {

                  'pet_id': pet['pet_id'],

                  'name': pet['name'] ?? '',

                  'type': pet['type'] ?? '',

                  'status': 'In Shelter',

                  'image_url_1': pet['image_url_1'] ?? '',

                  'breed': pet['breed'] ?? '',

                  'age': pet['age'] ?? '',

                  'sex': pet['sex'] ?? '',

                  'created_at': pet['created_at'] ?? '',

                  'shelter_id': pet['shelter_id'],

                  'description': pet['description'],

                  'energy': pet['energy'],

                  'color': pet['color'] ?? '',

                  'has_disability': pet['has_disability'],

                  'is_offspring': pet['is_offspring'] ?? false, // ← ADD THIS

                },

              )

              .toList();

      if (!mounted) return;

      setState(() {

        _allPets = data;

        _pets = List<Map<String, dynamic>>.from(data);

        _filteredPets = List<Map<String, dynamic>>.from(data);

        isLoading = false;

      });

    } catch (e) {

      debugPrint("❌ Error loading pets: $e");

      if (!mounted) return;

      setState(() => isLoading = false);

    }

  }



  Future<Map<String, dynamic>?> _fetchPetProfileData(

    BuildContext context,

    int petId,

  ) async {

    try {

      final response =

          await supabase

              .from('pets')

              .select()

              .eq('pet_id', petId)

              .eq('status', 'In Shelter')

              .maybeSingle();

      if (response == null) throw Exception("Pet with ID $petId not found.");

      return response;

    } catch (e, stackTrace) {

      debugPrint("❌ Error fetching pet profile: $e");

      if (mounted) {

        _showSnackBar('Failed to fetch pet profile.', Colors.red);

        debugPrint('Failed to fetch pet profile: $e');

      }

      return null;

    }

  }



  Future<List<Map<String, dynamic>>> fetchSheltersFromDatabase() async {

    try {

      final response = await supabase

          .from('shelters')

          .select('*')

          .order('shelter_id', ascending: true);

      return List<Map<String, dynamic>>.from(response);

    } catch (error) {

      debugPrint("Error fetching shelters: $error");

      return [];

    }

  }



  Future<void> _loadShelters() async {

    final data = await fetchSheltersFromDatabase();

    setState(() {

      _shelters = data;

      if (_shelters.isNotEmpty && _currentShelterIndex >= _shelters.length) {

        _currentShelterIndex = _shelters.length - 1;

      }

    });

  }



  @override

  void dispose() {

    _medicationChannel?.unsubscribe();

    _petsChannel?.unsubscribe();

    _controller.dispose();

    _searchController.dispose();

    _tableScrollController.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final isMobile = !isDesktop;



    return WillPopScope(

      onWillPop: () async {

        Navigator.pushReplacement(

          context,

          MaterialPageRoute(builder: (_) => ShelterProfilesPage()),

        );

        return false;

      },

      child: Scaffold(

        key: _scaffoldKey,

        backgroundColor: const Color(0xFF2D2D30),

        drawer: !isDesktop ? Drawer(width: 200, child: _buildSidebar()) : null,

        body: Row(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            if (isDesktop) _buildSidebar(),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  _buildTopHeader(isMobile),

                  _buildTopControls(),

                  Expanded(child: _buildPetGrid()),

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

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

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



  Widget _buildTopHeader(bool isMobile) {

    return Container(
      height: isMobile ? 56 : null,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 20,
        vertical: isMobile ? 8 : 15,
      ),

      child: Row(

        children: [





          if (isMobile)

            IconButton(

              icon: const Icon(Icons.arrow_back, color: Colors.white),

              padding: EdgeInsets.zero,

              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),

              onPressed:

                  () => Navigator.pushReplacement(

                    context,

                    MaterialPageRoute(builder: (_) => ShelterProfilesPage()),

                  ),

            )

          else

            ElevatedButton.icon(

              onPressed:

                  () => Navigator.pushReplacement(

                    context,

                    MaterialPageRoute(builder: (_) => ShelterProfilesPage()),

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

              'Pet Profiles',

              style: TextStyle(

                color: Colors.white,

                fontSize: isMobile ? 16 : 24,

                fontWeight: FontWeight.bold,

                fontFamily: "Montserrat",

                overflow: TextOverflow.ellipsis,

              ),

              textAlign: TextAlign.center,

            ),

          ),



          if (!isMobile) ...[
            const SizedBox(width: 8),
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
          ],

          _NotificationBell(

            iconSize: isMobile ? 22 : 24,

            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),

          ),

          SizedBox(width: isMobile ? 6 : 20),

          buildProfileAvatar(context, radius: isMobile ? 14 : 16),

        ],

      ),

    );

  }



  Widget _buildTopControls() {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      width: double.infinity,
      color: const Color(0xFF2D2D30),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isMobile ? 8 : 12,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSelectionMode)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${_selectedPetIds.length} Selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: _showBulkMoveDialog,
                            icon: const Icon(Icons.drive_file_move, color: Colors.white, size: 14),
                            label: const Text(
                              'Move',
                              style: TextStyle(fontFamily: 'Montserrat', color: Colors.white, fontSize: 11),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: _deleteSelectedPets,
                            icon: const Icon(Icons.delete, color: Colors.white, size: 14),
                            label: const Text(
                              'Delete',
                              style: TextStyle(fontFamily: 'Montserrat', color: Colors.white, fontSize: 11),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: _clearSelection,
                            icon: const Icon(Icons.close, color: Colors.white, size: 14),
                            label: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildShelterNavigation(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _searchController,
                            onChanged: _filterSearch,
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              hintStyle: const TextStyle(
                                color: Colors.white54,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                              prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 16),
                              filled: true,
                              fillColor: const Color(0xFF3C3C3E),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildAgeFilterDropdown(isMobile: true),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 38,
                        width: 38,
                        child: ElevatedButton(
                          onPressed: () => _showPetRecordsDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C5C8A),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.folder_special,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            )
          : Row(
              children: [
                if (_isSelectionMode) ...[
                  Text(
                    '${_selectedPetIds.length} Selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: _showBulkMoveDialog,
                    icon: const Icon(Icons.drive_file_move, color: Colors.white),
                    label: const Text(
                      'Move',
                      style: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _deleteSelectedPets,
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text(
                      'Delete',
                      style: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
                    ),
                  ),
                ] else ...[
                  _buildShelterNavigation(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterSearch,
                      decoration: InputDecoration(
                        hintText: 'Search name, breed, energy, color...',
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildAgeFilterDropdown(isMobile: false),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showPetRecordsDialog(context),
                    icon: const Icon(
                      Icons.folder_special,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Pet Records',
                      style: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C5C8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }



  void _clearSelection() {

    setState(() {

      _isSelectionMode = false;

      _selectedPetIds.clear();

    });

  }



  Widget _buildShelterNavigation() {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          color: _currentShelterIndex > 0 ? Colors.orange : Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: _currentShelterIndex > 0 ? _previousShelter : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 6 : 8,
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: isMobile ? 16 : 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? 120 : 300),
          child: Text(
            _shelters.isNotEmpty
                ? _shelters[_currentShelterIndex]['name']
                : 'No Shelters',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontFamily: "Montserrat",
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Card(
          color:
              _currentShelterIndex < _shelters.length - 1
                  ? Colors.orange
                  : Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap:
                _currentShelterIndex < _shelters.length - 1
                    ? _nextShelter
                    : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 6 : 8,
              ),
              child: Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: isMobile ? 16 : 24,
              ),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildPetGrid() {

    if (isLoading) {
      return const SkeletonPetTable();
    }

    if (_filteredPets.isEmpty) {

      return const Center(

        child: Text(

          "No pets stored",

          style: TextStyle(

            color: Colors.white70,

            fontSize: 16,

            fontFamily: "Montserrat",

          ),

        ),

      );

    }

    return _buildPetTable();

  }



  Widget _buildPetTable() {

    return LayoutBuilder(

      builder: (context, constraints) {

        return SingleChildScrollView(

          padding: const EdgeInsets.all(16),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Padding(

                padding: const EdgeInsets.only(bottom: 10),

                child: Text(

                  '${_filteredPets.length} pet(s) found',

                  style: const TextStyle(

                    color: Colors.white54,

                    fontFamily: 'Montserrat',

                    fontSize: 13,

                  ),

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
                        minWidth: constraints.maxWidth > 1000
                            ? constraints.maxWidth
                            : 1000,
                      ),

                      child: DataTable(

                      columnSpacing: 20,

                      headingRowHeight: 48,

                      dataRowMinHeight: 64,

                      dataRowMaxHeight: 72,

                      horizontalMargin: 16,

                      headingRowColor: WidgetStateProperty.all(

                        const Color(0xFF1C1C1E),

                      ),

                      dataRowColor: WidgetStateProperty.resolveWith<Color>((

                        states,

                      ) {

                        if (states.contains(WidgetState.selected)) {

                          return Colors.orange.withOpacity(0.08);

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

                        DataColumn(

                          label: Text(

                            'Photo',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                        DataColumn(

                          label: Text(

                            'Name',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                        DataColumn(

                          label: Text(

                            'Type',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                        DataColumn(

                          label: Text(

                            'Breed',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                        DataColumn(

                          label: Text(

                            'Age',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                        DataColumn(

                          label: Text(

                            'Sex',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                        DataColumn(

                          label: Text(

                            'Color',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                        DataColumn(

                          label: Text(

                            'Energy',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                        DataColumn(

                          label: Text(

                            'Status',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                        DataColumn(

                          label: Text(

                            'Actions',

                            style: TextStyle(

                              color: Colors.orange,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                        ),

                      ],

                      rows:

                          _filteredPets.asMap().entries.map((entry) {

                            final index = entry.key;

                            final pet = entry.value;



                            final petId =

                                pet['pet_id'] is int

                                    ? pet['pet_id'] as int

                                    : int.tryParse(pet['pet_id'].toString()) ??

                                        0;

                            final name = pet['name'] ?? 'Unnamed';

                            final type = pet['type'] ?? '—';

                            final breed = pet['breed'] ?? '—';

                            final age = pet['age']?.toString() ?? '—';

                            final sex = pet['sex'] ?? '—';

                            final color = pet['color'] ?? '—';

                            final energy = pet['energy'] ?? '—';

                            final status = pet['status'] ?? '—';

                            final imageUrl = pet['image_url_1'] ?? '';



                            final isUnderMedication = status.contains(

                              'Under Medication',

                            );

                            final isReadyForAdoption = status.contains(

                              'Ready For Adoption',

                            );

                            final isSelected = _selectedPetIds.contains(petId);



                            Color statusColor = Colors.white54;

                            if (isUnderMedication)

                              statusColor = Colors.redAccent;

                            if (isReadyForAdoption) statusColor = Colors.green;



                            Color energyColor = Colors.white70;

                            if (energy == 'High') energyColor = Colors.orange;

                            if (energy == 'Medium') energyColor = Colors.yellow;

                            if (energy == 'Low')

                              energyColor = Colors.lightBlueAccent;



                            return DataRow(

                              selected: isSelected,

                              color: WidgetStateProperty.resolveWith<Color>((

                                states,

                              ) {

                                if (isSelected) {

                                  return Colors.blue.withOpacity(0.1);

                                }

                                if (index.isEven)

                                  return const Color(0xFF2D2D30);

                                return const Color(0xFF262628);

                              }),

                              onSelectChanged:

                                  _isSelectionMode

                                      ? (selected) {

                                        setState(() {

                                          if (selected == true) {

                                            _selectedPetIds.add(petId);

                                          } else {

                                            _selectedPetIds.remove(petId);

                                            if (_selectedPetIds.isEmpty) {

                                              _isSelectionMode = false;

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

                                    child: Padding(

                                      padding: const EdgeInsets.symmetric(

                                        vertical: 8,

                                      ),

                                      child: ClipRRect(

                                        borderRadius: BorderRadius.circular(8),

                                        child:

                                            imageUrl.isNotEmpty

                                                ? Image.network(

                                                  imageUrl,

                                                  width: 52,

                                                  height: 52,

                                                  fit: BoxFit.cover,

                                                  errorBuilder:

                                                      (_, __, ___) => Container(

                                                        width: 52,

                                                        height: 52,

                                                        color: Colors.grey[800],

                                                        child: const Icon(

                                                          Icons.pets,

                                                          color: Colors.white38,

                                                          size: 24,

                                                        ),

                                                      ),

                                                )

                                                : Container(

                                                  width: 52,

                                                  height: 52,

                                                  color: Colors.grey[800],

                                                  child: const Icon(

                                                    Icons.pets,

                                                    color: Colors.white38,

                                                    size: 24,

                                                  ),

                                                ),

                                      ),

                                    ),

                                  ),

                                ),



                                DataCell(

                                  GestureDetector(

                                    onLongPress: () {

                                      setState(() {

                                        _isSelectionMode = true;

                                        _selectedPetIds.add(petId);

                                      });

                                    },

                                    onTap:

                                        () => _showPetDetailDialog(

                                          context,

                                          index,

                                        ),

                                    child: Row(

                                      mainAxisSize: MainAxisSize.min,

                                      children: [

                                        if (pet['is_offspring'] == true)

                                          const Tooltip(

                                            message: 'Shelter-born offspring',

                                            child: Padding(

                                              padding: EdgeInsets.only(

                                                right: 6,

                                              ),

                                              child: Icon(

                                                Icons.child_care,

                                                color: Colors.pinkAccent,

                                                size: 14,

                                              ),

                                            ),

                                          ),

                                        Text(

                                          name,

                                          style: const TextStyle(

                                            color: Colors.white,

                                            fontFamily: 'Montserrat',

                                            fontWeight: FontWeight.w600,

                                            fontSize: 14,

                                          ),

                                        ),

                                      ],

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

                                  Text(

                                    breed,

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

                                      const SizedBox(width: 4),

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

                                  Text(

                                    color,

                                    style: const TextStyle(

                                      color: Colors.white70,

                                      fontFamily: 'Montserrat',

                                      fontSize: 13,

                                    ),

                                  ),

                                ),



                                DataCell(

                                  Container(

                                    padding: const EdgeInsets.symmetric(

                                      horizontal: 8,

                                      vertical: 3,

                                    ),

                                    decoration: BoxDecoration(

                                      color: energyColor.withOpacity(0.12),

                                      borderRadius: BorderRadius.circular(6),

                                      border: Border.all(

                                        color: energyColor.withOpacity(0.5),

                                        width: 1,

                                      ),

                                    ),

                                    child: Text(

                                      energy,

                                      style: TextStyle(

                                        color: energyColor,

                                        fontFamily: 'Montserrat',

                                        fontSize: 11,

                                        fontWeight: FontWeight.w600,

                                      ),

                                    ),

                                  ),

                                ),



                                DataCell(

                                  Container(

                                    padding: const EdgeInsets.symmetric(

                                      horizontal: 8,

                                      vertical: 3,

                                    ),

                                    decoration: BoxDecoration(

                                      color: statusColor.withOpacity(0.12),

                                      borderRadius: BorderRadius.circular(6),

                                      border: Border.all(

                                        color: statusColor.withOpacity(0.5),

                                        width: 1,

                                      ),

                                    ),

                                    child: Text(

                                      isUnderMedication

                                          ? 'Medication'

                                          : isReadyForAdoption

                                          ? 'For Adoption'

                                          : 'In Shelter',

                                      style: TextStyle(

                                        color: statusColor,

                                        fontFamily: 'Montserrat',

                                        fontSize: 11,

                                        fontWeight: FontWeight.w600,

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

                                            size: 20,

                                          ),

                                          onPressed:

                                              () => _showPetQrDialog(

                                                context,

                                                pet,

                                              ),

                                          padding: EdgeInsets.zero,

                                          constraints: const BoxConstraints(

                                            minWidth: 32,

                                            minHeight: 32,

                                          ),

                                        ),

                                      ),

                                      if (!isUnderMedication &&

                                          !isReadyForAdoption) ...[

                                        Tooltip(

                                          message: 'Edit',

                                          child: IconButton(

                                            icon: const Icon(

                                              Icons.edit,

                                              color: Colors.orange,

                                              size: 20,

                                            ),

                                            onPressed:

                                                () => _showEditPetDialog(

                                                  context,

                                                  pet,

                                                ),

                                            padding: EdgeInsets.zero,

                                            constraints: const BoxConstraints(

                                              minWidth: 32,

                                              minHeight: 32,

                                            ),

                                          ),

                                        ),

                                        Tooltip(

                                          message: 'More',

                                          child: PopupMenuButton<String>(

                                            icon: const Icon(

                                              Icons.more_vert,

                                              color: Colors.white54,

                                              size: 20,

                                            ),

                                            color: const Color(0xFF3C3C3E),

                                            padding: EdgeInsets.zero,

                                            onSelected: (value) async {

                                              if (value == 'adoption') {

                                                await _movePet(pet, 'adoption');

                                              } else if (value ==

                                                  'medication') {

                                                await _movePet(

                                                  pet,

                                                  'medication',

                                                );

                                              } else if (value == 'shelter') {

                                                _moveToShelter(context, pet);

                                              } else if (value == 'delete') {

                                                await _deletePet(pet);

                                              }

                                            },

                                            itemBuilder:

                                                (_) => const [

                                                  PopupMenuItem(

                                                    value: 'medication',

                                                    child: Row(

                                                      children: [

                                                        Icon(

                                                          Icons

                                                              .medical_services,

                                                          color: Colors.green,

                                                          size: 16,

                                                        ),

                                                        SizedBox(width: 8),

                                                        Text(

                                                          'Move to Medication',

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

                                                    value: 'shelter',

                                                    child: Row(

                                                      children: [

                                                        Icon(

                                                          Icons.location_city,

                                                          color: Colors.purple,

                                                          size: 16,

                                                        ),

                                                        SizedBox(width: 8),

                                                        Text(

                                                          'Assign to Shelter',

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

                                                    value: 'delete',

                                                    child: Row(

                                                      children: [

                                                        Icon(

                                                          Icons.delete,

                                                          color: Colors.red,

                                                          size: 16,

                                                        ),

                                                        SizedBox(width: 8),

                                                        Text(

                                                          'Delete',

                                                          style: TextStyle(

                                                            color: Colors.red,

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



  void _showPetDetailDialog(BuildContext context, int initialIndex) {

    final dialogKey = GlobalKey<_PetDetailDialogState>();

    showDialog(

      context: context,

      builder: (dialogContext) {

        return _PetDetailDialog(

          key: dialogKey,

          pets: _filteredPets,

          initialIndex: initialIndex,

          onEdit: (pet) async {

            await _showEditPetDialog(context, pet);

            await Future.delayed(const Duration(milliseconds: 400));

            dialogKey.currentState?.refreshCurrentPet();

          },

          onDelete: (pet) async {

            Navigator.pop(dialogContext);

            await _deletePet(pet);

          },

          onMoveToAdoption: (pet) async {

            Navigator.pop(dialogContext);

            await _movePet(pet, 'adoption');

          },

          onMoveToMedication: (pet) async {

            Navigator.pop(dialogContext);

            await _movePet(pet, 'medication');

          },

          onMoveToShelter: (pet) {

            Navigator.pop(dialogContext);

            _moveToShelter(context, pet);

          },

          onShowQr: (pet) => _showPetQrDialog(context, pet),

          onAddOffspring: (pet) async {

            await _showAddOffspringDialog(context, pet);

            await Future.delayed(const Duration(milliseconds: 400));

            dialogKey.currentState?.refreshCurrentPet();

          },

        );

      },

    );

  }



  void _moveToShelter(BuildContext context, Map<String, dynamic> pet) async {

    final petType = pet['type']?.toString() ?? '';

    final currentShelterId = pet['shelter_id'];



    final availableShelters =

        _shelters.where((shelter) {

          final sameType =

              shelter['type']?.toString().toLowerCase().contains(

                petType.toLowerCase(),

              ) ??

              false;

          final isDifferentShelter = shelter['shelter_id'] != currentShelterId;

          return sameType && isDifferentShelter;

        }).toList();



    if (availableShelters.isEmpty) {

      _showSnackBar(

        'No other shelters available for this pet type.',

        Colors.orange,

      );

      return;

    }



    final selectedShelter = await showDialog<Map<String, dynamic>>(

      context: context,

      builder: (context) {

        return AlertDialog(

          backgroundColor: const Color(0xFF2D2D2D),

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(12),

          ),

          title: const Text(

            'Move to Another Shelter',

            style: TextStyle(

              color: Colors.white,

              fontFamily: 'Montserrat',

              fontWeight: FontWeight.bold,

            ),

          ),

          content: SizedBox(

            width: double.maxFinite,

            child: ListView.builder(

              shrinkWrap: true,

              itemCount: availableShelters.length,

              itemBuilder: (context, index) {

                final shelter = availableShelters[index];

                return ListTile(

                  leading: const Icon(Icons.home, color: Colors.orange),

                  title: Text(

                    shelter['name'] ?? 'Unnamed Shelter',

                    style: const TextStyle(

                      color: Colors.white,

                      fontFamily: 'Montserrat',

                    ),

                  ),

                  onTap: () => Navigator.pop(context, shelter),

                );

              },

            ),

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

          ],

        );

      },

    );



    if (selectedShelter == null) return;



    final targetShelterId = selectedShelter['shelter_id'];

    final targetShelterName = selectedShelter['name'] ?? 'the selected shelter';

    final petName = pet['name'] ?? 'This pet';

    final petId = pet['pet_id'];



    try {

      await supabase

          .from('pets')

          .update({

            'shelter_id': targetShelterId,

            'updated_at': DateTime.now().toIso8601String(),

          })

          .eq('pet_id', petId);



      await logActivity(

        action: 'Assigned to Shelter',

        description: '$petName moved to $targetShelterName',

        entityType: 'pet',

        entityId: petId,

      );



      _loadShelterPets();



      if (mounted) {

        _showSnackBar('$petName moved to $targetShelterName.', Colors.green);

      }

    } catch (e) {

      debugPrint('❌ Error moving pet to shelter: $e');

      if (mounted) {

        _showSnackBar('Failed to move $petName. Please try again.', Colors.red);

      }

    }

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

          _showSnackBar(

            'QR code downloaded.',

            Colors.green,

          );

        }

      } catch (e) {

        if (context.mounted) {

          _showSnackBar('Failed to download QR.', Colors.red);

          debugPrint('Failed to download QR code: $e');

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



  Widget buildDropdown(

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

              fontSize: 13,

            ),

          ),

          const SizedBox(height: 5),

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 12),

            decoration: BoxDecoration(

              color: const Color(0xFF3C3C3E),

              borderRadius: BorderRadius.circular(8),

            ),

            child: DropdownButtonHideUnderline(

              child: DropdownButton<String>(

                value: value,

                isExpanded: true,

                dropdownColor: const Color(0xFF3C3C3E),

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



  void _showPetRecordsDialog(BuildContext context) {

    List<Map<String, dynamic>> managedPets = [];

    bool isLoadingRecords = true;

    String petRecordsFilter = 'All';



    Future<void> loadManagedPets(StateSetter setDialogState) async {

      setDialogState(() => isLoadingRecords = true);

      try {

        final shelterId =

            _shelters.isNotEmpty

                ? _shelters[_currentShelterIndex]['shelter_id']

                : widget.shelterId;



        final medPets = await supabase

            .from('pet_medications')

            .select()

            .eq('shelter_id', shelterId);



        final adoptPets = await supabase

            .from('adoptable_pets')

            .select()

            .eq('shelter_id', shelterId)

            .eq('status', 'Ready For Adoption');



        final shelterPets = await supabase

            .from('pets')

            .select()

            .eq('shelter_id', shelterId);

        // After building combined list, add deduplication:

        final seen = <dynamic>{};

        final combined =

            [

              ...List<Map<String, dynamic>>.from(

                medPets,

              ).map((p) => {...p, 'status': 'Under Medication'}),

              ...List<Map<String, dynamic>>.from(

                adoptPets,

              ).map((p) => {...p, 'status': 'Ready For Adoption'}),

              ...List<Map<String, dynamic>>.from(

                shelterPets,

              ).map((p) => {...p, 'status': p['status'] ?? 'In Shelter'}),

            ].where((p) => seen.add(p['pet_id'])).toList(); // ← deduplicate



        setDialogState(() {

          managedPets = combined;

          isLoadingRecords = false;

        });

      } catch (e) {

        debugPrint('❌ Error loading pet records: $e');

        setDialogState(() => isLoadingRecords = false);

      }

    }



    showDialog(

      context: context,

      builder: (ctx) {

        return StatefulBuilder(

          builder: (ctx, setDialogState) {

            if (isLoadingRecords && managedPets.isEmpty) {

              loadManagedPets(setDialogState);

            }



            final filteredPets =

                managedPets.where((pet) {

                  final status = pet['status']?.toString() ?? '';

                  if (petRecordsFilter == 'All') return true;

                  if (petRecordsFilter == 'Too Young') {

                    return _isTooYoung(pet['age']);

                  }

                  return status == petRecordsFilter;

                }).toList();



            return Dialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width > 668 ? 620 : double.infinity,

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

                          const Icon(

                            Icons.folder_special,

                            color: Colors.orange,

                          ),

                          const SizedBox(width: 10),

                          const Expanded(

                            child: Text(

                              'Pet Records — Under Management',

                              style: TextStyle(

                                color: Colors.white,

                                fontFamily: 'Montserrat',

                                fontWeight: FontWeight.bold,

                                fontSize: 16,

                              ),

                            ),

                          ),

                          IconButton(

                            icon: const Icon(

                              Icons.refresh,

                              color: Colors.white54,

                              size: 18,

                            ),

                            onPressed: () => loadManagedPets(setDialogState),

                            padding: EdgeInsets.zero,

                            constraints: const BoxConstraints(),

                          ),

                          const SizedBox(width: 8),

                          GestureDetector(

                            onTap: () => Navigator.pop(ctx),

                            child: const Icon(

                              Icons.close,

                              color: Colors.white54,

                            ),

                          ),

                        ],

                      ),

                    ),



                    Padding(

                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),

                      child: SingleChildScrollView(

                        scrollDirection: Axis.horizontal,

                        child: Row(

                          children: [

                            for (final filter in [

                              'All',

                              'In Shelter',

                              'Under Medication',

                              'Ready For Adoption',

                              'Too Young',

                            ])

                              Padding(

                                padding: const EdgeInsets.only(right: 8),

                                child: GestureDetector(

                                  onTap:

                                      () => setDialogState(

                                        () => petRecordsFilter = filter,

                                      ),

                                  child: AnimatedContainer(

                                    duration: const Duration(milliseconds: 180),

                                    padding: const EdgeInsets.symmetric(

                                      horizontal: 14,

                                      vertical: 7,

                                    ),

                                    decoration: BoxDecoration(

                                      color:

                                          petRecordsFilter == filter

                                              ? Colors.orange

                                              : const Color(0xFF3C3C3E),

                                      borderRadius: BorderRadius.circular(20),

                                      border: Border.all(

                                        color:

                                            petRecordsFilter == filter

                                                ? Colors.orange

                                                : Colors.white24,

                                      ),

                                    ),

                                    child: Text(

                                      filter,

                                      style: TextStyle(

                                        color:

                                            petRecordsFilter == filter

                                                ? Colors.white

                                                : Colors.white60,

                                        fontFamily: 'Montserrat',

                                        fontSize: 12,

                                        fontWeight: FontWeight.w600,

                                      ),

                                    ),

                                  ),

                                ),

                              ),

                          ],

                        ),

                      ),

                    ),



                    const Divider(color: Colors.white12, height: 1),



                    Flexible(

                      child:

                          isLoadingRecords
                              ? Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Center(
                                    child: LoadingAnimationWidget.fallingDot(
                                      color: Colors.orange,
                                      size: 50,
                                    ),
                                  ),
                                )

                              : filteredPets.isEmpty

                              ? Padding(

                                padding: const EdgeInsets.all(40),

                                child: Column(

                                  mainAxisSize: MainAxisSize.min,

                                  children: [

                                    const Icon(

                                      Icons.pets,

                                      color: Colors.white24,

                                      size: 48,

                                    ),

                                    const SizedBox(height: 12),

                                    Text(

                                      petRecordsFilter == 'All'

                                          ? 'No pets under management'

                                          : 'No "$petRecordsFilter" pets ',

                                      style: const TextStyle(

                                        color: Colors.white38,

                                        fontFamily: 'Montserrat',

                                        fontSize: 15,

                                      ),

                                      textAlign: TextAlign.center,

                                    ),

                                  ],

                                ),

                              )

                              : ListView.separated(

                                padding: const EdgeInsets.all(16),

                                itemCount: filteredPets.length,

                                separatorBuilder:

                                    (_, __) => const Divider(

                                      color: Colors.white10,

                                      height: 1,

                                    ),

                                itemBuilder: (context, index) {

                                  final pet = filteredPets[index];

                                  final status =

                                      pet['status']?.toString() ?? '';

                                  final isUnderMed =

                                      status == 'Under Medication';

                                  final statusColor =

                                      isUnderMed

                                          ? Colors.redAccent

                                          : Colors.amber;

                                  final imageUrl = pet['image_url_1'] ?? '';



                                  return ListTile(

                                    contentPadding: const EdgeInsets.symmetric(

                                      horizontal: 8,

                                      vertical: 4,

                                    ),

                                    leading: ClipRRect(

                                      borderRadius: BorderRadius.circular(8),

                                      child:

                                          imageUrl.isNotEmpty

                                              ? Image.network(

                                                imageUrl,

                                                width: 56,

                                                height: 56,

                                                fit: BoxFit.cover,

                                                errorBuilder:

                                                    (_, __, ___) => Container(

                                                      width: 56,

                                                      height: 56,

                                                      color: Colors.grey[800],

                                                      child: const Icon(

                                                        Icons.pets,

                                                        color: Colors.white38,

                                                      ),

                                                    ),

                                              )

                                              : Container(

                                                width: 56,

                                                height: 56,

                                                color: Colors.grey[800],

                                                child: const Icon(

                                                  Icons.pets,

                                                  color: Colors.white38,

                                                ),

                                              ),

                                    ),

                                    title: Text(

                                      pet['name'] ?? 'Unnamed',

                                      style: const TextStyle(

                                        color: Colors.white,

                                        fontFamily: 'Montserrat',

                                        fontWeight: FontWeight.w600,

                                        fontSize: 14,

                                      ),

                                    ),

                                    subtitle: Column(

                                      crossAxisAlignment:

                                          CrossAxisAlignment.start,

                                      children: [

                                        Text(

                                          '${pet['breed'] ?? '—'}  •  ${pet['age'] ?? '—'}  •  ${pet['type'] ?? '—'}',

                                          style: const TextStyle(

                                            color: Colors.white54,

                                            fontFamily: 'Montserrat',

                                            fontSize: 12,

                                          ),

                                        ),

                                        const SizedBox(height: 4),

                                        Row(

                                          children: [

                                            Container(

                                              padding:

                                                  const EdgeInsets.symmetric(

                                                    horizontal: 8,

                                                    vertical: 2,

                                                  ),

                                              decoration: BoxDecoration(

                                                color: statusColor.withOpacity(

                                                  0.15,

                                                ),

                                                borderRadius:

                                                    BorderRadius.circular(10),

                                                border: Border.all(

                                                  color: statusColor,

                                                  width: 1,

                                                ),

                                              ),

                                              child: Text(

                                                status,

                                                style: TextStyle(

                                                  color: statusColor,

                                                  fontFamily: 'Montserrat',

                                                  fontSize: 11,

                                                  fontWeight: FontWeight.bold,

                                                ),

                                              ),

                                            ),

                                            if (_isTooYoung(pet['age'])) ...[

                                              const SizedBox(width: 6),

                                              Container(

                                                padding:

                                                    const EdgeInsets.symmetric(

                                                      horizontal: 8,

                                                      vertical: 2,

                                                    ),

                                                decoration: BoxDecoration(

                                                  color: Colors.pink

                                                      .withOpacity(0.15),

                                                  borderRadius:

                                                      BorderRadius.circular(10),

                                                  border: Border.all(

                                                    color: Colors.pinkAccent,

                                                    width: 1,

                                                  ),

                                                ),

                                                child: const Row(

                                                  mainAxisSize:

                                                      MainAxisSize.min,

                                                  children: [

                                                    Icon(

                                                      Icons.child_care,

                                                      color: Colors.pinkAccent,

                                                      size: 11,

                                                    ),

                                                    SizedBox(width: 4),

                                                    Text(

                                                      'Too Young',

                                                      style: TextStyle(

                                                        color:

                                                            Colors.pinkAccent,

                                                        fontFamily:

                                                            'Montserrat',

                                                        fontSize: 11,

                                                        fontWeight:

                                                            FontWeight.bold,

                                                      ),

                                                    ),

                                                  ],

                                                ),

                                              ),

                                            ],

                                          ],

                                        ),

                                      ],

                                    ),

                                    trailing: PopupMenuButton<String>(

                                      icon: const Icon(

                                        Icons.more_vert,

                                        color: Colors.white54,

                                      ),

                                      color: const Color(0xFF3C3C3E),

                                      onSelected: (value) async {

                                        Navigator.pop(ctx);

                                        if (value == 'adoption') {

                                          await _movePet(pet, 'adoption');

                                        } else if (value == 'shelter') {

                                          _moveToShelter(context, pet);

                                        } else if (value == 'delete') {

                                          await _deletePet(pet);

                                        }

                                      },

                                      itemBuilder:

                                          (_) => const [

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

                                                    'Mark Ready for Adoption',

                                                    style: TextStyle(

                                                      color: Colors.white,

                                                      fontFamily: 'Montserrat',

                                                      fontSize: 13,

                                                    ),

                                                  ),

                                                ],

                                              ),

                                            ),

                                            PopupMenuItem(

                                              value: 'shelter',

                                              child: Row(

                                                children: [

                                                  Icon(

                                                    Icons.home,

                                                    color: Colors.purple,

                                                    size: 16,

                                                  ),

                                                  SizedBox(width: 8),

                                                  Text(

                                                    'Assign to Shelter',

                                                    style: TextStyle(

                                                      color: Colors.white,

                                                      fontFamily: 'Montserrat',

                                                      fontSize: 13,

                                                    ),

                                                  ),

                                                ],

                                              ),

                                            ),

                                            PopupMenuDivider(),

                                            PopupMenuItem(

                                              value: 'delete',

                                              child: Row(

                                                children: [

                                                  Icon(

                                                    Icons.delete,

                                                    color: Colors.red,

                                                    size: 16,

                                                  ),

                                                  SizedBox(width: 8),

                                                  Text(

                                                    'Delete',

                                                    style: TextStyle(

                                                      color: Colors.red,

                                                      fontFamily: 'Montserrat',

                                                      fontSize: 13,

                                                    ),

                                                  ),

                                                ],

                                              ),

                                            ),

                                          ],

                                    ),

                                  );

                                },

                              ),

                    ),



                    const SizedBox(height: 8),

                  ],

                ),

              ),

            );

          },

        );

      },

    );

  }



  Widget _buildOffspringInlineDropdown(

    String label,

    String value,

    List<String> options,

    ValueChanged<String?> onChanged,

  ) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          label,

          style: const TextStyle(

            color: Colors.white54,

            fontFamily: 'Montserrat',

            fontSize: 11,

          ),

        ),

        const SizedBox(height: 3),

        Container(

          padding: const EdgeInsets.symmetric(horizontal: 10),

          decoration: BoxDecoration(

            color: const Color(0xFF3C3C3E),

            borderRadius: BorderRadius.circular(8),

          ),

          child: DropdownButtonHideUnderline(

            child: DropdownButton<String>(

              value: value,

              isExpanded: true,

              dropdownColor: const Color(0xFF3C3C3E),

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

    );

  }



  Future<void> _showEditPetDialog(

    BuildContext context,

    Map<String, dynamic> pet,

  ) async {

    final List<Map<String, dynamic>> offspringList = [];

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

    final originController = TextEditingController(

      text:

          (pet['origin'] == 'Shelter Born' ||

                  pet['origin'] == 'Rescued' ||

                  pet['origin'] == 'Surrendered by Owner' ||

                  pet['origin'] == 'Transfer from Another Shelter' ||

                  pet['origin'] == 'Found Stray' ||

                  pet['origin'] == null)

              ? ''

              : (pet['origin'] ?? ''),

    );

    final rescueAgeController = TextEditingController(

      text: pet['rescue_age'] ?? '',

    );

    final parsedRescueAge = _parseAge(pet['rescue_age']?.toString());

    final mainRescueAgeNumberCtrl = TextEditingController(text: parsedRescueAge['number']);

    String mainRescueAgeUnit = parsedRescueAge['unit'] ?? 'month(s) old';

    final diseaseDetailsController = TextEditingController(

      text: pet['disease_details'] ?? '',

    );



    final editScrollCtrl = ScrollController();



    Uint8List? imageBytes;



    final editRawType = (widget.type ?? '').toString();

    String selectedType = editRawType.contains('Dog') ? 'Dog' : 'Cat';



    String selectedEnergy = pet['energy'] ?? 'Low';

    String selectedGender = pet['sex'] ?? 'Male';



    final originOptions = [

      'Shelter Born',

      'Rescued',

      'Surrendered by Owner',

      'Transfer from Another Shelter',

      'Found Stray',

      'Other',

    ];



    String selectedOrigin =

        originOptions.contains(pet['origin'])

            ? pet['origin']!

            : (pet['origin'] != null && pet['origin'].toString().isNotEmpty

                ? 'Other'

                : 'Shelter Born');



    bool isRescued =

        selectedOrigin == 'Rescued' || selectedOrigin == 'Found Stray';

    bool isOffspring = selectedOrigin == 'Shelter Born';



    String selectedStatus = pet['status'] ?? 'In Shelter';

    String selectedVaccinationStatus =

        pet['vaccination_status'] ?? 'Not Vaccinated';

    String selectedDewormingStatus = pet['deworming_status'] ?? 'Not Dewormed';

    String selectedNeuteredStatus =

        pet['neutered_spayed_details'] ?? 'Not Neutered/Spayed';

    String selectedHealthStatus = pet['health_status'] ?? 'Healthy';

    String hasDisability =

        (pet['has_disability'] == true || pet['has_disability'] == 'Yes')

            ? 'Yes'

            : 'No';



    DateTime? selectedDob =

        pet['date_of_birth'] != null

            ? DateTime.tryParse(pet['date_of_birth'].toString())

            : null;



    String selectedDiseaseType = pet['disease_type'] ?? 'No Disease';

    String selectedSurgeryType = pet['surgery_type'] ?? 'No Surgery Type';

    String selectedSurgeryDetails =

        pet['surgery_details'] ?? 'No Surgery Details';



    final List<String> diseaseOptions = [

      'No Disease',

      'Parvovirus',

      'Distemper',

      'Heartworm',

      'Rabies',

      'Kennel Cough',

      'Ringworm',

      'Mange',

      'Feline Leukemia',

      'Upper Respiratory Infection',

      'Other',

    ];



    await showDialog(

      context: context,

      barrierDismissible: false,

      builder: (BuildContext dialogContext) {

        return StatefulBuilder(

          builder: (dialogContext, setDialogState) {

            return AlertDialog(

              backgroundColor: const Color(0xFF1E1E1E),

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(20),

              ),

              title: const Row(

                children: [

                  Icon(Icons.edit, color: Colors.orange),

                  SizedBox(width: 10),

                  Text(

                    'Edit Pet',

                    style: TextStyle(

                      color: Colors.white,

                      fontFamily: 'Montserrat',

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ],

              ),

              content: SizedBox(

                width: double.maxFinite,

                height: 600,

                child: Scrollbar(

                  controller: editScrollCtrl,

                  thumbVisibility: true,

                  child: SingleChildScrollView(

                    controller: editScrollCtrl,

                    padding: const EdgeInsets.only(right: 8),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Center(

                          child: GestureDetector(

                            onTap: () async {

                              final pickedFile = await ImagePicker().pickImage(

                                source: ImageSource.gallery,

                              );

                              if (pickedFile != null) {

                                final bytes = await pickedFile.readAsBytes();

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

                                  imageBytes = Uint8List.fromList(jpgBytes);

                                });

                              }

                            },

                            child: CircleAvatar(

                              radius: 55,

                              backgroundColor: Colors.grey[850],

                              backgroundImage:

                                  imageBytes != null

                                      ? MemoryImage(imageBytes!)

                                      : (pet['image_url_1'] != null &&

                                                  pet['image_url_1']

                                                      .toString()

                                                      .isNotEmpty

                                              ? NetworkImage(pet['image_url_1'])

                                              : null)

                                          as ImageProvider<Object>?,

                              child:

                                  imageBytes == null &&

                                          (pet['image_url_1'] == null ||

                                              pet['image_url_1'].isEmpty)

                                      ? const Icon(

                                        Icons.add_a_photo,

                                        color: Colors.white70,

                                      )

                                      : null,

                            ),

                          ),

                        ),

                        const SizedBox(height: 20),



                        _sectionLabel('Basic Information'),

                        _buildFixedField('Name', nameController),

                        _buildFixedField('Color', colorController),

                        _buildFixedField('Breed', breedController),

                        _buildAgeFieldRow(

                          'Age',

                          mainAgeNumberCtrl,

                          mainAgeUnit,

                          (v) => setDialogState(() => mainAgeUnit = v!),

                          onChangedValue: () {

                            ageController.text = _formatAgeText(mainAgeNumberCtrl.text, mainAgeUnit);

                          },

                        ),

                        const SizedBox(height: 8),

                        _buildDropdownField(

                          label: 'Energy Level',

                          value: selectedEnergy,

                          options: const ['Low', 'Medium', 'High'],

                          onChanged:

                              (v) => setDialogState(() => selectedEnergy = v!),

                        ),

                        const SizedBox(height: 8),

                        _buildDropdownField(

                          label: 'Sex',

                          value: selectedGender,

                          options: const ['Male', 'Female'],

                          onChanged:

                              (v) => setDialogState(() => selectedGender = v!),

                        ),

                        const SizedBox(height: 8),



                        const Text(

                          'Description',

                          style: TextStyle(

                            color: Colors.orange,

                            fontFamily: 'Montserrat',

                            fontWeight: FontWeight.bold,

                            fontSize: 13,

                          ),

                        ),

                        const SizedBox(height: 5),

                        TextField(

                          controller: descriptionController,

                          maxLines: 3,

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

                        const SizedBox(height: 16),



                        _sectionLabel('Origin & Background'),

                        _buildDropdownField(

                          label: 'Origin',

                          value: selectedOrigin,

                          options: originOptions,

                          onChanged: (value) {

                            setDialogState(() {

                              selectedOrigin = value!;

                              isRescued =

                                  value == 'Rescued' || value == 'Found Stray';

                              isOffspring = value == 'Shelter Born';

                              if (!isRescued) rescueAgeController.clear();

                              if (value != 'Other') originController.clear();

                            });

                          },

                        ),

                        const SizedBox(height: 8),



                        if (selectedOrigin == 'Other') ...[

                          _buildFixedField('Specify Origin', originController),

                          const SizedBox(height: 8),

                        ],



                        if (isOffspring) ...[

                          _infoChip(

                            Icons.child_care,

                            'This pet was born inside the shelter (offspring).',

                            Colors.lightBlueAccent,

                          ),

                          const SizedBox(height: 8),

                        ],



                        if (isRescued) ...[

                          _buildAgeFieldRow(

                            'Age at Rescue',

                            mainRescueAgeNumberCtrl,

                            mainRescueAgeUnit,

                            (v) => setDialogState(() => mainRescueAgeUnit = v!),

                            onChangedValue: () {

                              rescueAgeController.text = _formatAgeText(mainRescueAgeNumberCtrl.text, mainRescueAgeUnit);

                            },

                          ),

                          const SizedBox(height: 8),

                        ],



                        const Text(

                          'Date of Birth',

                          style: TextStyle(

                            color: Colors.orange,

                            fontFamily: 'Montserrat',

                            fontWeight: FontWeight.bold,

                          ),

                        ),

                        const SizedBox(height: 5),

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

                        const SizedBox(height: 16),



                        _sectionLabel('Health & Medical'),

                        if (selectedGender == 'Female') ...[

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

                            (v) =>

                                setDialogState(() => selectedHealthStatus = v!),

                          ),

                        ],



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

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

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

                                            'name': '',

                                            'sex': 'Male',

                                            'energy': 'Low',

                                            'color': '',

                                            'origin': 'Shelter Born',

                                            'status': 'In Shelter',

                                            'hasDisability': 'No',

                                            'healthStatus': 'Healthy',

                                            'isRescued': false,

                                            'nameCtrl': TextEditingController(),

                                            'colorCtrl':

                                                TextEditingController(),

                                            'breedCtrl':

                                                TextEditingController(),

                                            'ageCtrl': TextEditingController(),

                                            'descCtrl': TextEditingController(),

                                            'originCtrl':

                                                TextEditingController(),

                                            'rescueAgeCtrl':

                                                TextEditingController(),

                                          });

                                        });

                                      },

                                      child: Container(

                                        padding: const EdgeInsets.symmetric(

                                          horizontal: 10,

                                          vertical: 5,

                                        ),

                                        decoration: BoxDecoration(

                                          color: Colors.pink.withOpacity(0.15),

                                          borderRadius: BorderRadius.circular(

                                            20,

                                          ),

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

                                                fontWeight: FontWeight.w600,

                                              ),

                                            ),

                                          ],

                                        ),

                                      ),

                                    ),

                                  ],

                                ),



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



                                ...offspringList.asMap().entries.map((entry) {

                                  final i = entry.key;

                                  final o = entry.value;

                                  return Container(

                                    margin: const EdgeInsets.only(top: 10),

                                    padding: const EdgeInsets.all(12),

                                    decoration: BoxDecoration(

                                      color: const Color(0xFF2D2D2D),

                                      borderRadius: BorderRadius.circular(10),

                                      border: Border.all(

                                        color: Colors.pink.withOpacity(0.2),

                                      ),

                                    ),

                                    child: Column(

                                      crossAxisAlignment:

                                          CrossAxisAlignment.start,

                                      children: [

                                        // ── Header ──────────────────────────────────────

                                        Row(

                                          children: [

                                            Text(

                                              'Offspring #${i + 1}',

                                              style: const TextStyle(

                                                color: Colors.pinkAccent,

                                                fontFamily: 'Montserrat',

                                                fontWeight: FontWeight.bold,

                                                fontSize: 12,

                                              ),

                                            ),

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

                                        const SizedBox(height: 8),



                                        // ── Name ────────────────────────────────────────

                                        TextField(

                                          controller:

                                              o['nameCtrl']

                                                  as TextEditingController,

                                          style: const TextStyle(

                                            color: Colors.white,

                                            fontFamily: 'Montserrat',

                                            fontSize: 13,

                                          ),

                                          decoration: InputDecoration(

                                            hintText: 'Name *',

                                            hintStyle: const TextStyle(

                                              color: Colors.white38,

                                              fontFamily: 'Montserrat',

                                              fontSize: 13,

                                            ),

                                            filled: true,

                                            fillColor: const Color(0xFF3C3C3E),

                                            border: OutlineInputBorder(

                                              borderRadius:

                                                  BorderRadius.circular(8),

                                              borderSide: BorderSide.none,

                                            ),

                                            contentPadding:

                                                const EdgeInsets.symmetric(

                                                  horizontal: 12,

                                                  vertical: 10,

                                                ),

                                          ),

                                        ),

                                        const SizedBox(height: 6),



                                        // ── Color ───────────────────────────────────────

                                        TextField(

                                          controller:

                                              o['colorCtrl']

                                                  as TextEditingController,

                                          style: const TextStyle(

                                            color: Colors.white,

                                            fontFamily: 'Montserrat',

                                            fontSize: 13,

                                          ),

                                          decoration: InputDecoration(

                                            hintText: 'Color',

                                            hintStyle: const TextStyle(

                                              color: Colors.white38,

                                              fontFamily: 'Montserrat',

                                              fontSize: 13,

                                            ),

                                            filled: true,

                                            fillColor: const Color(0xFF3C3C3E),

                                            border: OutlineInputBorder(

                                              borderRadius:

                                                  BorderRadius.circular(8),

                                              borderSide: BorderSide.none,

                                            ),

                                            contentPadding:

                                                const EdgeInsets.symmetric(

                                                  horizontal: 12,

                                                  vertical: 10,

                                                ),

                                          ),

                                        ),

                                        const SizedBox(height: 6),



                                        // ── Breed ───────────────────────────────────────

                                        TextField(

                                          controller:

                                              o['breedCtrl']

                                                  as TextEditingController,

                                          style: const TextStyle(

                                            color: Colors.white,

                                            fontFamily: 'Montserrat',

                                            fontSize: 13,

                                          ),

                                          decoration: InputDecoration(

                                            hintText:

                                                'Breed (leave blank to inherit)',

                                            hintStyle: const TextStyle(

                                              color: Colors.white38,

                                              fontFamily: 'Montserrat',

                                              fontSize: 13,

                                            ),

                                            filled: true,

                                            fillColor: const Color(0xFF3C3C3E),

                                            border: OutlineInputBorder(

                                              borderRadius:

                                                  BorderRadius.circular(8),

                                              borderSide: BorderSide.none,

                                            ),

                                            contentPadding:

                                                const EdgeInsets.symmetric(

                                                  horizontal: 12,

                                                  vertical: 10,

                                                ),

                                          ),

                                        ),

                                        const SizedBox(height: 6),



                                        // ── Age ─────────────────────────────────────────

                                        TextField(

                                          controller:

                                              o['ageCtrl']

                                                  as TextEditingController,

                                          style: const TextStyle(

                                            color: Colors.white,

                                            fontFamily: 'Montserrat',

                                            fontSize: 13,

                                          ),

                                          onChanged:

                                              (_) => setDialogState(() {}),

                                          decoration: InputDecoration(

                                            hintText:

                                                'Age (e.g. "3 months", "1 year")',

                                            hintStyle: const TextStyle(

                                              color: Colors.white38,

                                              fontFamily: 'Montserrat',

                                              fontSize: 13,

                                            ),

                                            filled: true,

                                            fillColor: const Color(0xFF3C3C3E),

                                            border: OutlineInputBorder(

                                              borderRadius:

                                                  BorderRadius.circular(8),

                                              borderSide: BorderSide.none,

                                            ),

                                            contentPadding:

                                                const EdgeInsets.symmetric(

                                                  horizontal: 12,

                                                  vertical: 10,

                                                ),

                                          ),

                                        ),

                                        const SizedBox(height: 6),



                                        // ── Description ──────────────────────────────────

                                        TextField(

                                          controller:

                                              o['descCtrl']

                                                  as TextEditingController,

                                          maxLines: 3,

                                          style: const TextStyle(

                                            color: Colors.white,

                                            fontFamily: 'Montserrat',

                                            fontSize: 13,

                                          ),

                                          decoration: InputDecoration(

                                            hintText: 'Description',

                                            hintStyle: const TextStyle(

                                              color: Colors.white38,

                                              fontFamily: 'Montserrat',

                                              fontSize: 13,

                                            ),

                                            filled: true,

                                            fillColor: const Color(0xFF3C3C3E),

                                            border: OutlineInputBorder(

                                              borderRadius:

                                                  BorderRadius.circular(8),

                                              borderSide: BorderSide.none,

                                            ),

                                            contentPadding:

                                                const EdgeInsets.symmetric(

                                                  horizontal: 12,

                                                  vertical: 10,

                                                ),

                                          ),

                                        ),

                                        const SizedBox(height: 6),



                                        // ── Sex & Energy ─────────────────────────────────

                                        Row(

                                          children: [

                                            Expanded(

                                              child:

                                                  _buildOffspringInlineDropdown(

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

                                                  _buildOffspringInlineDropdown(

                                                    'Energy',

                                                    o['energy'] as String,

                                                    ['Low', 'Medium', 'High'],

                                                    (v) => setDialogState(

                                                      () => o['energy'] = v!,

                                                    ),

                                                  ),

                                            ),

                                          ],

                                        ),

                                        const SizedBox(height: 6),



                                        // ── Origin ──────────────────────────────────────

                                        _buildOffspringInlineDropdown(

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

                                          (v) => setDialogState(() {

                                            o['origin'] = v!;

                                            o['isRescued'] =

                                                v == 'Rescued' ||

                                                v == 'Found Stray';

                                          }),

                                        ),

                                        const SizedBox(height: 6),



                                        // ── Specify origin if Other ──────────────────────

                                        if (o['origin'] == 'Other') ...[

                                          TextField(

                                            controller:

                                                o['originCtrl']

                                                    as TextEditingController,

                                            style: const TextStyle(

                                              color: Colors.white,

                                              fontFamily: 'Montserrat',

                                              fontSize: 13,

                                            ),

                                            decoration: InputDecoration(

                                              hintText: 'Specify origin',

                                              hintStyle: const TextStyle(

                                                color: Colors.white38,

                                                fontFamily: 'Montserrat',

                                                fontSize: 13,

                                              ),

                                              filled: true,

                                              fillColor: const Color(

                                                0xFF3C3C3E,

                                              ),

                                              border: OutlineInputBorder(

                                                borderRadius:

                                                    BorderRadius.circular(8),

                                                borderSide: BorderSide.none,

                                              ),

                                              contentPadding:

                                                  const EdgeInsets.symmetric(

                                                    horizontal: 12,

                                                    vertical: 10,

                                                  ),

                                            ),

                                          ),

                                          const SizedBox(height: 6),

                                        ],



                                        // ── Rescue age if rescued ────────────────────────

                                        if (o['isRescued'] == true) ...[

                                          TextField(

                                            controller:

                                                o['rescueAgeCtrl']

                                                    as TextEditingController,

                                            style: const TextStyle(

                                              color: Colors.white,

                                              fontFamily: 'Montserrat',

                                              fontSize: 13,

                                            ),

                                            decoration: InputDecoration(

                                              hintText:

                                                  'Age at rescue (e.g. 3 months)',

                                              hintStyle: const TextStyle(

                                                color: Colors.white38,

                                                fontFamily: 'Montserrat',

                                                fontSize: 13,

                                              ),

                                              filled: true,

                                              fillColor: const Color(

                                                0xFF3C3C3E,

                                              ),

                                              border: OutlineInputBorder(

                                                borderRadius:

                                                    BorderRadius.circular(8),

                                                borderSide: BorderSide.none,

                                              ),

                                              contentPadding:

                                                  const EdgeInsets.symmetric(

                                                    horizontal: 12,

                                                    vertical: 10,

                                                  ),

                                            ),

                                          ),

                                          const SizedBox(height: 6),

                                        ],



                                        // ── Has Disability ───────────────────────────────

                                        _buildOffspringInlineDropdown(

                                          'Has Disability?',

                                          o['hasDisability'] as String,

                                          ['Yes', 'No'],

                                          (v) => setDialogState(

                                            () => o['hasDisability'] = v!,

                                          ),

                                        ),

                                        const SizedBox(height: 6),



                                        // ── Health Status (female only) ──────────────────

                                        if ((o['sex'] as String) ==

                                            'Female') ...[

                                          _buildOffspringInlineDropdown(

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

                                              () => o['healthStatus'] = v!,

                                            ),

                                          ),

                                          const SizedBox(height: 6),

                                        ],



                                        // ── Initial Status ───────────────────────────────

                                        _buildOffspringInlineDropdown(

                                          'Initial Status',

                                          o['status'] as String,

                                          ['In Shelter', 'Under Medication'],

                                          (v) => setDialogState(

                                            () => o['status'] = v!,

                                          ),

                                        ),

                                      ],

                                    ),

                                  );

                                }),

                              ],

                            ),

                          ),

                          const SizedBox(height: 8),

                        ],

                        const SizedBox(height: 8),

                        _buildDropdownField(

                          label: 'Vaccination Status',

                          value: selectedVaccinationStatus,

                          options: const [

                            'Not Vaccinated',

                            'Partially Vaccinated',

                            'Fully Vaccinated',

                            'Vaccination Due',

                            'Vaccination Overdue',

                          ],

                          onChanged:

                              (v) => setDialogState(

                                () => selectedVaccinationStatus = v!,

                              ),

                        ),

                        const SizedBox(height: 8),

                        _buildDropdownField(

                          label: 'Deworming Status',

                          value: selectedDewormingStatus,

                          options: const [

                            'Not Dewormed',

                            'Dewormed',

                            'Deworming Due',

                            'Deworming Overdue',

                          ],

                          onChanged:

                              (v) => setDialogState(

                                () => selectedDewormingStatus = v!,

                              ),

                        ),

                        const SizedBox(height: 8),

                        _buildDropdownField(

                          label: 'Neutered / Spayed',

                          value: selectedNeuteredStatus,

                          options: const [

                            'Not Neutered/Spayed',

                            'Neutered',

                            'Spayed',

                            'Scheduled',

                          ],

                          onChanged:

                              (v) => setDialogState(

                                () => selectedNeuteredStatus = v!,

                              ),

                        ),

                        const SizedBox(height: 8),



                        _buildDropdownField(

                          label: 'Disease Type',

                          value:

                              diseaseOptions.contains(selectedDiseaseType)

                                  ? selectedDiseaseType

                                  : 'No Disease',

                          options: diseaseOptions,

                          onChanged:

                              (v) => setDialogState(

                                () => selectedDiseaseType = v!,

                              ),

                        ),

                        const SizedBox(height: 8),

                        if (selectedDiseaseType != 'No Disease') ...[

                          _buildFixedField(

                            'Disease Details',

                            diseaseDetailsController,

                          ),

                          const SizedBox(height: 8),

                        ],



                        _buildDropdownField(

                          label: 'Surgery Type',

                          value:

                              surgeryDetailsOptions.keys.contains(

                                    selectedSurgeryType,

                                  )

                                  ? selectedSurgeryType

                                  : 'No Surgery Type',

                          options: surgeryDetailsOptions.keys.toList(),

                          onChanged: (v) {

                            setDialogState(() {

                              selectedSurgeryType = v!;

                              selectedSurgeryDetails =

                                  surgeryDetailsOptions[v]!.first;

                            });

                          },

                        ),

                        const SizedBox(height: 8),

                        if (selectedSurgeryType != 'No Surgery Type') ...[

                          _buildDropdownField(

                            label: 'Surgery Details',

                            value:

                                (surgeryDetailsOptions[selectedSurgeryType]

                                            ?.contains(

                                              selectedSurgeryDetails,

                                            ) ??

                                        false)

                                    ? selectedSurgeryDetails

                                    : surgeryDetailsOptions[selectedSurgeryType]!

                                        .first,

                            options:

                                surgeryDetailsOptions[selectedSurgeryType]!,

                            onChanged:

                                (v) => setDialogState(

                                  () => selectedSurgeryDetails = v!,

                                ),

                          ),

                          const SizedBox(height: 8),

                        ],



                        const SizedBox(height: 12),

                        const Text(

                          'Has Disability?',

                          style: TextStyle(

                            color: Colors.orange,

                            fontFamily: 'Montserrat',

                            fontWeight: FontWeight.bold,

                          ),

                        ),

                        Row(

                          children:

                              ['Yes', 'No'].map((option) {

                                return Expanded(

                                  child: RadioListTile<String>(

                                    value: option,

                                    groupValue: hasDisability,

                                    onChanged:

                                        (v) => setDialogState(

                                          () => hasDisability = v!,

                                        ),

                                    title: Text(

                                      option,

                                      style: const TextStyle(

                                        color: Colors.white,

                                        fontFamily: 'Montserrat',

                                      ),

                                    ),

                                    activeColor: Colors.orange,

                                    dense: true,

                                  ),

                                );

                              }).toList(),

                        ),

                        const SizedBox(height: 8),

                      ],

                    ),

                  ),

                ),

              ),

              actions: [

                TextButton(

                  onPressed: () => Navigator.pop(dialogContext),

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

                    backgroundColor: Colors.orange,

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(10),

                    ),

                  ),

                  onPressed: () async {

                    final messenger = ScaffoldMessenger.of(context);

                    final dialogMessenger = ScaffoldMessenger.of(dialogContext);

                    try {

                      // 1. Handle image upload

                      String? imageUrl = pet['image_url_1'];

                      if (imageBytes != null) {

                        final filePath =

                            'pets/images/${DateTime.now().millisecondsSinceEpoch}.jpg';

                        await supabase.storage

                            .from('pets')

                            .uploadBinary(

                              filePath,

                              imageBytes!,

                              fileOptions: const FileOptions(

                                contentType: 'image/jpeg',

                                upsert: true,

                              ),

                            );

                        imageUrl = supabase.storage

                            .from('pets')

                            .getPublicUrl(filePath);

                      }



                      // 2. Build the update payload

                      final updatePayload = {

                        'name': nameController.text.trim(),

                        'color': colorController.text.trim(),

                        'breed': breedController.text.trim(),

                        'age': ageController.text.trim(),

                        'energy': selectedEnergy,

                        'sex': selectedGender,

                        'description': descriptionController.text.trim(),

                        'status': selectedStatus,

                        'has_disability': hasDisability == 'Yes',

                        'origin':

                            selectedOrigin == 'Other'

                                ? originController.text.trim()

                                : selectedOrigin,

                        'is_offspring': isOffspring,

                        'rescue_age':

                            isRescued ? rescueAgeController.text.trim() : null,

                        'date_of_birth': selectedDob?.toIso8601String(),

                        'health_status': selectedHealthStatus,

                        'vaccination_status': selectedVaccinationStatus,

                        'deworming_status': selectedDewormingStatus,

                        'neutered_spayed_details': selectedNeuteredStatus,

                        'disease_type': selectedDiseaseType,

                        'disease_details':

                            selectedDiseaseType != 'No Disease'

                                ? diseaseDetailsController.text.trim()

                                : '',

                        'surgery_type': selectedSurgeryType,

                        'surgery_details':

                            selectedSurgeryType != 'No Surgery Type'

                                ? selectedSurgeryDetails

                                : '',

                        'updated_at': DateTime.now().toIso8601String(),

                        if (imageUrl != null) 'image_url_1': imageUrl,

                      };



                      // 3. Update pets table

                      await supabase

                          .from('pets')

                          .update(updatePayload)

                          .eq('pet_id', pet['pet_id']);



                      // 4. Sync to adoptable_pets if exists there

                      final adoptCheck =

                          await supabase

                              .from('adoptable_pets')

                              .select('pet_id')

                              .eq('pet_id', pet['pet_id'])

                              .maybeSingle();



                      if (adoptCheck != null) {

                        await supabase

                            .from('adoptable_pets')

                            .update({

                              'name': nameController.text.trim(),

                              'color': colorController.text.trim(),

                              'breed': breedController.text.trim(),

                              'age': ageController.text.trim(),

                              'energy': selectedEnergy,

                              'sex': selectedGender,

                              'description': descriptionController.text.trim(),

                              'has_disability':

                                  hasDisability == 'Yes' ? 'Yes' : 'No',

                              'vaccination_status': selectedVaccinationStatus,

                              'deworming_status': selectedDewormingStatus,

                              'neutered_spayed_details': selectedNeuteredStatus,

                              'disease_type': selectedDiseaseType,

                              'disease_details':

                                  selectedDiseaseType != 'No Disease'

                                      ? diseaseDetailsController.text.trim()

                                      : '',

                              if (imageUrl != null) 'image_url_1': imageUrl,

                            })

                            .eq('pet_id', pet['pet_id']);

                      }



                      // 5. Sync to pet_medications if exists there

                      final medCheck =

                          await supabase

                              .from('pet_medications')

                              .select('pet_id')

                              .eq('pet_id', pet['pet_id'])

                              .maybeSingle();



                      if (medCheck != null) {

                        await supabase

                            .from('pet_medications')

                            .update({

                              'name': nameController.text.trim(),

                              'color': colorController.text.trim(),

                              'breed': breedController.text.trim(),

                              'age': ageController.text.trim(),

                              'energy': selectedEnergy,

                              'sex': selectedGender,

                              'description': descriptionController.text.trim(),

                              'has_disability':

                                  hasDisability == 'Yes' ? 'Yes' : 'No',

                              'vaccination_status': selectedVaccinationStatus,

                              'deworming_status': selectedDewormingStatus,

                              'neutered_spayed_details': selectedNeuteredStatus,

                              'disease_type': selectedDiseaseType,

                              'disease_details':

                                  selectedDiseaseType != 'No Disease'

                                      ? diseaseDetailsController.text.trim()

                                      : '',

                              if (imageUrl != null) 'image_url_1': imageUrl,

                            })

                            .eq('pet_id', pet['pet_id']);

                      }



                      // 6. Save offspring from offspringList to database

                      if (offspringList.isNotEmpty) {

                        final shelterId =

                            pet['shelter_id'] ??

                            (_shelters.isNotEmpty

                                ? _shelters[_currentShelterIndex]['shelter_id']

                                : widget.shelterId);



                        for (final o in offspringList) {

                          final oName =

                              (o['nameCtrl'] as TextEditingController).text

                                  .trim();

                          if (oName.isEmpty) continue; // skip unnamed offspring



                          final oColor =

                              (o['colorCtrl'] as TextEditingController).text

                                  .trim();

                          final oBreed =

                              (o['breedCtrl'] as TextEditingController).text

                                  .trim();

                          final oAge =

                              (o['ageCtrl'] as TextEditingController).text

                                  .trim();

                          final oDesc =

                              (o['descCtrl'] as TextEditingController).text

                                  .trim();

                          final oOriginCustom =

                              (o['originCtrl'] as TextEditingController).text

                                  .trim();

                          final oRescueAge =

                              (o['rescueAgeCtrl'] as TextEditingController).text

                                  .trim();



                          final oOrigin =

                              o['origin'] == 'Other'

                                  ? oOriginCustom

                                  : o['origin'] as String;



                          await supabase.from('pets').insert({

                            'name': oName,

                            'color': oColor.isNotEmpty ? oColor : 'Unknown',

                            'breed':

                                oBreed.isNotEmpty

                                    ? oBreed

                                    : (pet['breed'] ?? ''),

                            'age': oAge.isNotEmpty ? oAge : '0 months',

                            'type': pet['type'] ?? '',

                            'energy': o['energy'] as String,

                            'sex': o['sex'] as String,

                            'status': o['status'] as String,

                            'description':

                                oDesc.isNotEmpty

                                    ? oDesc

                                    : 'Offspring of ${nameController.text.trim()}.',

                            'image_url_1': imageUrl ?? pet['image_url_1'] ?? '',

                            'shelter_id': shelterId,

                            'origin': oOrigin,

                            'is_offspring': true,

                            'motherpet_id': pet['pet_id'],

                            'has_disability':

                                o['hasDisability'] == 'Yes' ? true : false,

                            'health_status': o['healthStatus'] as String,

                            'rescue_age':

                                o['isRescued'] == true ? oRescueAge : null,

                            'created_at': DateTime.now().toIso8601String(),

                          });



                          await logActivity(

                            action: 'Added Offspring',

                            description:

                                '$oName added as offspring of ${nameController.text.trim()}',

                            entityType: 'pet',

                            entityId: pet['pet_id'],

                          );

                        }

                      }



                      // 7. Log the edit

                      await logActivity(

                        action: 'Edited Pet',

                        description:

                            '${nameController.text.trim()} was updated',

                        entityType: 'pet',

                        entityId: pet['pet_id'],

                      );



                      // 8. Pop dialog first

                      if (dialogContext.mounted) {

                        Navigator.pop(dialogContext);

                      }



                      // 9. Reload shelter pets and clear offspring cache

                      //    so the detail dialog re-fetches fresh offspring

                      _onPetAdded();



                      if (mounted) {

                        _showSnackBar('${nameController.text.trim()} updated successfully!', Colors.green);

                      }

                    } catch (e) {

                      debugPrint('❌ Error saving pet: $e');

                      if (dialogContext.mounted) {

                        _showSnackBar('Failed to save pet.', Colors.red);

                      }

                    }

                  },

                  child: const Text(

                    'Save Changes',

                    style: TextStyle(

                      color: Colors.white,

                      fontFamily: 'Montserrat',

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ),

              ],

            );

          },

        );

      },

    );



    editScrollCtrl.dispose();

  }



  Widget _sectionLabel(String title) => Padding(

    padding: const EdgeInsets.only(bottom: 10),

    child: Row(

      children: [

        Expanded(child: Divider(color: Colors.orange.withOpacity(0.3))),

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

        Expanded(child: Divider(color: Colors.orange.withOpacity(0.3))),

      ],

    ),

  );



  Widget _infoChip(IconData icon, String message, Color color) => Container(

    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

    decoration: BoxDecoration(

      color: color.withOpacity(0.07),

      borderRadius: BorderRadius.circular(10),

      border: Border.all(color: color.withOpacity(0.3)),

    ),

    child: Row(

      children: [

        Icon(icon, color: color, size: 16),

        const SizedBox(width: 8),

        Expanded(

          child: Text(

            message,

            style: TextStyle(

              color: color,

              fontFamily: 'Montserrat',

              fontSize: 12,

            ),

          ),

        ),

      ],

    ),

  );



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

              Expanded(

                flex: 3,

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

                      horizontal: 14,

                      vertical: 14,

                    ),

                  ),

                ),

              ),

              const SizedBox(width: 8),

              Expanded(

                flex: 2,

                child: Container(

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

                      value: selectedUnit,

                      isExpanded: true,

                      dropdownColor: const Color(0xFF252526),

                      style: const TextStyle(

                        color: Colors.white,

                        fontFamily: 'Montserrat',

                        fontSize: 14,

                      ),

                      items: const ['day(s) old', 'week(s) old', 'month(s) old', 'year(s) old']

                          .map(

                            (unit) => DropdownMenuItem(

                              value: unit,

                              child: Text(

                                unit,

                                style: const TextStyle(

                                  fontFamily: 'Montserrat',

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



  Widget _buildFixedField(

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

            maxLines: 1,

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



  Widget _buildDropdownField({

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

              isExpanded: true,

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



  Widget _buildTextField(

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

}



class _PetDetailDialog extends StatefulWidget {

  final List<Map<String, dynamic>> pets;

  final int initialIndex;

  final Future<void> Function(Map<String, dynamic>) onEdit;

  final Future<void> Function(Map<String, dynamic>) onDelete;

  final Future<void> Function(Map<String, dynamic>) onMoveToAdoption;

  final Future<void> Function(Map<String, dynamic>) onMoveToMedication;

  final void Function(Map<String, dynamic>) onMoveToShelter;

  final void Function(Map<String, dynamic>) onShowQr;

  final void Function(Map<String, dynamic>) onAddOffspring;

  const _PetDetailDialog({

    required this.pets,

    required this.initialIndex,

    required this.onEdit,

    required this.onDelete,

    required this.onMoveToAdoption,

    required this.onMoveToMedication,

    required this.onMoveToShelter,

    required this.onShowQr,

    required this.onAddOffspring,

    super.key,

  });



  @override

  State<_PetDetailDialog> createState() => _PetDetailDialogState();

}



class _PetDetailDialogState extends State<_PetDetailDialog>

    with SingleTickerProviderStateMixin {

  final supabase = Supabase.instance.client;

  late int _currentIndex;

  late TabController _tabController;

  final Map<int, List<Map<String, dynamic>>> _offspringCache = {};



  final Map<int, Map<String, dynamic>> _livePetCache = {};



  final Map<int, List<Map<String, dynamic>>> _healthRecordsCache = {};



  final Map<int, List<Map<String, dynamic>>> _vialCache = {};



  bool _loadingDetails = false;



  @override

  void initState() {

    super.initState();

    _currentIndex = widget.initialIndex;

    _tabController = TabController(length: 3, vsync: this);

    _fetchDetailsForCurrentPet(forceRefresh: false);

  }



  @override

  void dispose() {

    _tabController.dispose();

    super.dispose();

  }



  Map<String, dynamic> get _pet => widget.pets[_currentIndex];



  bool get _hasPrev => _currentIndex > 0;

  bool get _hasNext => _currentIndex < widget.pets.length - 1;



  void _prev() {

    if (_hasPrev) {

      setState(() {

        _currentIndex--;

        _tabController.index = 0;

      });

      _fetchDetailsForCurrentPet(forceRefresh: false);

    }

  }



  void _next() {

    if (_hasNext) {

      setState(() {

        _currentIndex++;

        _tabController.index = 0;

      });

      _fetchDetailsForCurrentPet(forceRefresh: false);

    }

  }



  void refreshCurrentPet() {

    final petId = _parsePetId(_pet);

    if (petId != null) {

      _livePetCache.remove(petId);

      _healthRecordsCache.remove(petId);

      _offspringCache.remove(petId);

      _vialCache.remove(petId);

    }

    _fetchDetailsForCurrentPet(forceRefresh: true);

  }



  Future<void> _fetchDetailsForCurrentPet({bool forceRefresh = false}) async {

    final pet = _pet;

    final petId = _parsePetId(pet);

    if (petId == null) return;



    // Only skip if cache is populated AND we're not forcing a refresh

    if (!forceRefresh &&

        _livePetCache.containsKey(petId) &&

        _healthRecordsCache.containsKey(petId) &&

        _offspringCache.containsKey(petId))

      return;



    setState(() => _loadingDetails = true);

    try {

      final livePet =

          await supabase

              .from('pets')

              .select('*')

              .eq('pet_id', petId)

              .maybeSingle();



      final offspring = await supabase

          .from('pets')

          .select(

            'pet_id, name, sex, type, breed, color, age, image_url_1, status',

          )

          .eq('motherpet_id', petId)

          .order('created_at', ascending: true);



      _offspringCache[petId] = List<Map<String, dynamic>>.from(offspring);



      final records = await supabase

          .from('pet_health_records')

          .select(

            '*, vaccination_cms(vaccine_name, target_species, interval_days)',

          )

          .eq('pet_id', petId)

          .order('date_administered', ascending: false);



      final vials = await supabase

          .from('vet_vials')

          .select(

            '*, vaccination_cms(vaccine_name, target_species), veterinarians(first_name, last_name)',

          )

          .order('donation_date', ascending: false);



      if (mounted) {

        setState(() {

          if (livePet != null) {

            _livePetCache[petId] = {...pet, ...livePet};

          } else {

            _livePetCache[petId] = pet;

          }

          _healthRecordsCache[petId] = List<Map<String, dynamic>>.from(records);

          _vialCache[petId] = List<Map<String, dynamic>>.from(vials);

          _loadingDetails = false;

        });

      }

    } catch (e) {

      debugPrint('❌ Admin pet detail fetch error: $e');

      if (mounted) setState(() => _loadingDetails = false);

    }

  }



  int? _parsePetId(Map<String, dynamic> pet) {

    final raw = pet['pet_id'];

    if (raw is int) return raw;

    return int.tryParse(raw?.toString() ?? '');

  }



  String _formatDate(dynamic raw) {

    if (raw == null || raw.toString().isEmpty) return 'N/A';

    try {

      return DateFormat('MMM dd, yyyy').format(DateTime.parse(raw.toString()));

    } catch (_) {

      return raw.toString();

    }

  }



  Color _recordTypeColor(String type) {

    switch (type) {

      case 'vaccination':

        return Colors.blue;

      case 'procedure':

        return Colors.orange;

      case 'checkup':

        return Colors.green;

      default:

        return Colors.grey;

    }

  }



  IconData _recordTypeIcon(String type) {

    switch (type) {

      case 'vaccination':

        return Icons.vaccines;

      case 'procedure':

        return Icons.medical_services;

      case 'checkup':

        return Icons.health_and_safety;

      default:

        return Icons.note;

    }

  }



  String _capitalize(String s) =>

      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);



  @override

  Widget build(BuildContext context) {

    final petId = _parsePetId(_pet);



    final pet =

        (petId != null && _livePetCache.containsKey(petId))

            ? _livePetCache[petId]!

            : _pet;



    final name = pet['name'] ?? 'Unnamed';

    final status = pet['status'] ?? 'N/A';

    final imageUrl = pet['image_url_1'] ?? '';

    final isUnderMed = status.toString().contains('Under Medication');

    final isForAdopt = status.toString().contains('Ready For Adoption');

    final isLocked = isUnderMed || isForAdopt;



    final healthRecords =

        petId != null

            ? (_healthRecordsCache[petId] ?? <Map<String, dynamic>>[])

            : <Map<String, dynamic>>[];

    final vials =

        petId != null

            ? (_vialCache[petId] ?? <Map<String, dynamic>>[])

            : <Map<String, dynamic>>[];



    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: MediaQuery.of(context).size.width > 600 ? 560 : double.infinity,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 780),

        decoration: BoxDecoration(

          color: const Color(0xFF1E1E1E),

          borderRadius: BorderRadius.circular(20),

        ),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            _buildNavBar(name),



            Container(

              color: const Color(0xFF2A2A2A),

              child: TabBar(

                controller: _tabController,

                indicatorColor: Colors.orange,

                labelColor: Colors.orange,

                unselectedLabelColor: Colors.white54,

                labelStyle: const TextStyle(

                  fontFamily: 'Montserrat',

                  fontSize: 12,

                  fontWeight: FontWeight.w600,

                ),

                tabs: [

                  const Tab(

                    icon: Icon(Icons.info_outline, size: 16),

                    text: 'Details',

                  ),

                  Tab(

                    icon: Stack(

                      clipBehavior: Clip.none,

                      children: [

                        const Icon(Icons.history, size: 16),

                        if (healthRecords.isNotEmpty)

                          Positioned(

                            top: -4,

                            right: -6,

                            child: Container(

                              width: 14,

                              height: 14,

                              decoration: const BoxDecoration(

                                color: Colors.teal,

                                shape: BoxShape.circle,

                              ),

                              child: Center(

                                child: Text(

                                  '${healthRecords.length}',

                                  style: const TextStyle(

                                    color: Colors.white,

                                    fontSize: 9,

                                    fontWeight: FontWeight.bold,

                                  ),

                                ),

                              ),

                            ),

                          ),

                      ],

                    ),

                    text: 'Health Records',

                  ),

                  Tab(

                    icon: Stack(

                      clipBehavior: Clip.none,

                      children: [

                        const Icon(Icons.vaccines, size: 16),

                        if (vials.isNotEmpty)

                          Positioned(

                            top: -4,

                            right: -6,

                            child: Container(

                              width: 14,

                              height: 14,

                              decoration: const BoxDecoration(

                                color: Colors.purple,

                                shape: BoxShape.circle,

                              ),

                              child: Center(

                                child: Text(

                                  '${vials.length}',

                                  style: const TextStyle(

                                    color: Colors.white,

                                    fontSize: 9,

                                    fontWeight: FontWeight.bold,

                                  ),

                                ),

                              ),

                            ),

                          ),

                      ],

                    ),

                    text: 'Vial Donations',

                  ),

                ],

              ),

            ),



            Flexible(

              child:

                  _loadingDetails
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: LoadingAnimationWidget.fallingDot(
                              color: Colors.orange,
                              size: 50,
                            ),
                          ),
                        )

                      : TabBarView(

                        controller: _tabController,

                        children: [

                          _buildDetailsTab(

                            pet,

                            isLocked,

                            isUnderMed,

                            isForAdopt,

                            imageUrl,

                          ),

                          _buildHealthRecordsTab(healthRecords),

                          _buildVialDonationsTab(vials),

                        ],

                      ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildNavBar(String name) {

    return Container(

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



          Tooltip(

            message: 'Refresh from database',

            child: GestureDetector(

              onTap: () {

                final petId = _parsePetId(_pet);

                if (petId != null) {

                  _livePetCache.remove(petId);

                  _healthRecordsCache.remove(petId);

                  _offspringCache.remove(petId); // ← add this

                  _vialCache.remove(petId);

                }

                _fetchDetailsForCurrentPet(

                  forceRefresh: true,

                ); // ← force refresh

              },

              child: const Icon(Icons.refresh, color: Colors.white54, size: 18),

            ),

          ),

          const SizedBox(width: 8),

          GestureDetector(

            onTap: () => Navigator.pop(context),

            child: const Icon(Icons.close, color: Colors.white54, size: 22),

          ),

        ],

      ),

    );

  }



  Widget _buildDetailsTab(

    Map<String, dynamic> pet,

    bool isLocked,

    bool isUnderMed,

    bool isForAdopt,

    String imageUrl,

  ) {

    final name = pet['name'] ?? 'Unnamed';

    final breed = pet['breed'] ?? 'Unknown';

    final type = pet['type'] ?? 'Unknown';

    final age = pet['age']?.toString() ?? 'N/A';

    final color = pet['color'] ?? 'Unknown';

    final gender = pet['sex'] ?? 'Unknown';

    final energy = pet['energy'] ?? 'N/A';

    final status = pet['status'] ?? 'N/A';

    final description = pet['description'] ?? '—';

    final createdAt = pet['created_at'] ?? 'N/A';

    final hasDisab = pet['has_disability']?.toString() ?? 'No';



    final origin = pet['origin'] ?? '';

    final intakeDate = pet['intake_date'];

    final dateOfBirth = pet['date_of_birth'];

    final rescueAge = pet['rescue_age'];

    final isOffspring = pet['is_offspring'] == true;

    final healthStatus = pet['health_status'] ?? '';

    final vacStatus = pet['vaccination_status'] ?? '';

    final deworm = pet['deworming_status'] ?? '';

    final neutered = pet['neutered_spayed_details'] ?? '';

    final vetName = pet['veterinarian'] ?? '';

    final diseaseType = pet['disease_type'] ?? '';

    final diseaseDet = pet['disease_details'] ?? '';

    final surgeryType = pet['surgery_type'] ?? '';

    final surgeryDet = pet['surgery_details'] ?? '';



    return SingleChildScrollView(

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

                      height: 200,

                      fit: BoxFit.cover,

                      errorBuilder: (_, __, ___) => _imagePlaceholder(),

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

              if (isUnderMed)

                _StatusBadge(label: 'Under Medication', color: Colors.redAccent)

              else if (isForAdopt)

                _StatusBadge(label: 'Ready For Adoption', color: Colors.green),

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

              _InfoItem(label: 'Disability', value: hasDisab),

              _InfoItem(label: 'Status', value: status),

            ],

          ),

          const SizedBox(height: 14),



          if (origin.isNotEmpty ||

              intakeDate != null ||

              dateOfBirth != null) ...[

            _sectionHeader('Background'),

            _infoCard([

              if (origin.isNotEmpty) _detailRow('Origin', origin),

              if (isOffspring) _detailRow('Shelter born', 'Yes (offspring)'),

              if (rescueAge != null && rescueAge.toString().isNotEmpty)

                _detailRow('Age at rescue', rescueAge.toString()),

              if (dateOfBirth != null)

                _detailRow('Date of birth', _formatDate(dateOfBirth)),

              if (intakeDate != null)

                _detailRow('Intake date', _formatDate(intakeDate)),

            ]),



            const SizedBox(height: 14),

          ],



          if (healthStatus.isNotEmpty ||

              vacStatus.isNotEmpty ||

              deworm.isNotEmpty ||

              vetName.isNotEmpty) ...[

            _sectionHeader('Health summary'),

            _infoCard([

              if (healthStatus.isNotEmpty)

                _detailRow('Health status', healthStatus),

              if (vacStatus.isNotEmpty) _detailRow('Vaccination', vacStatus),

              if (deworm.isNotEmpty) _detailRow('Deworming', deworm),

              if (neutered.isNotEmpty) _detailRow('Neutered/Spayed', neutered),

              if (vetName.isNotEmpty) _detailRow('Veterinarian', vetName),

            ]),

            const SizedBox(height: 14),

          ],



          if (diseaseType.isNotEmpty || surgeryType.isNotEmpty) ...[

            _sectionHeader('Medical history'),

            _infoCard([

              if (diseaseType.isNotEmpty)

                _detailRow('Disease type', diseaseType),

              if (diseaseDet.isNotEmpty)

                _detailRow('Disease details', diseaseDet),

              if (surgeryType.isNotEmpty)

                _detailRow('Surgery type', surgeryType),

              if (surgeryDet.isNotEmpty)

                _detailRow('Surgery details', surgeryDet),

            ]),

            const SizedBox(height: 14),

          ],



          if (description.isNotEmpty && description != '—') ...[

            _sectionHeader('Description'),

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



          Text(

            'Added: $createdAt',

            style: const TextStyle(

              color: Colors.white38,

              fontFamily: 'Montserrat',

              fontSize: 11,

            ),

          ),

          const SizedBox(height: 20),



          Builder(

            builder: (context) {

              final petId2 = _parsePetId(pet);

              final offspringList =

                  petId2 != null

                      ? (_offspringCache[petId2] ?? <Map<String, dynamic>>[])

                      : <Map<String, dynamic>>[];



              final isFemale =

                  (pet['sex'] ?? '').toString().toLowerCase() == 'female';



              return Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  if (isFemale) ...[

                    const Divider(color: Colors.white12, height: 1),

                    const SizedBox(height: 16),

                    Row(

                      children: [

                        _sectionHeader('Litter'),

                        const Spacer(),

                        GestureDetector(

                          onTap: () {

                            widget.onAddOffspring(pet);

                          },

                          child: Container(

                            padding: const EdgeInsets.symmetric(

                              horizontal: 12,

                              vertical: 6,

                            ),

                            decoration: BoxDecoration(

                              color: Colors.pink.withOpacity(0.12),

                              borderRadius: BorderRadius.circular(20),

                              border: Border.all(color: Colors.pink),

                            ),

                            child: const Row(

                              mainAxisSize: MainAxisSize.min,

                              children: [

                                Icon(Icons.add, color: Colors.pink, size: 14),

                                SizedBox(width: 4),

                                Text(

                                  'Add Offspring',

                                  style: TextStyle(

                                    color: Colors.pink,

                                    fontFamily: 'Montserrat',

                                    fontSize: 12,

                                    fontWeight: FontWeight.w600,

                                  ),

                                ),

                              ],

                            ),

                          ),

                        ),

                      ],

                    ),

                    const SizedBox(height: 10),

                    if (offspringList.isEmpty)

                      const Text(

                        'No offspring recorded yet.',

                        style: TextStyle(

                          color: Colors.white38,

                          fontFamily: 'Montserrat',

                          fontSize: 13,

                        ),

                      )

                    else

                      SizedBox(

                        height: 88,

                        child: ListView.separated(

                          scrollDirection: Axis.horizontal,

                          itemCount: offspringList.length,

                          separatorBuilder:

                              (_, __) => const SizedBox(width: 10),

                          itemBuilder: (_, i) {

                            final o = offspringList[i];

                            final oImg = o['image_url_1'] ?? '';

                            final oName = o['name'] ?? 'Unnamed';

                            final oSex = o['sex'] ?? '';

                            return Column(

                              mainAxisSize: MainAxisSize.min,

                              children: [

                                ClipOval(

                                  child:

                                      oImg.isNotEmpty

                                          ? Image.network(

                                            oImg,

                                            width: 56,

                                            height: 56,

                                            fit: BoxFit.cover,

                                            errorBuilder:

                                                (_, __, ___) => Container(

                                                  width: 56,

                                                  height: 56,

                                                  color: Colors.grey[800],

                                                  child: const Icon(

                                                    Icons.pets,

                                                    color: Colors.white38,

                                                    size: 24,

                                                  ),

                                                ),

                                          )

                                          : Container(

                                            width: 56,

                                            height: 56,

                                            color: Colors.grey[800],

                                            child: const Icon(

                                              Icons.pets,

                                              color: Colors.white38,

                                              size: 24,

                                            ),

                                          ),

                                ),

                                const SizedBox(height: 4),

                                SizedBox(

                                  width: 56,

                                  child: Text(

                                    oName,

                                    textAlign: TextAlign.center,

                                    maxLines: 1,

                                    overflow: TextOverflow.ellipsis,

                                    style: TextStyle(

                                      color:

                                          oSex.toLowerCase() == 'female'

                                              ? Colors.pinkAccent

                                              : Colors.lightBlueAccent,

                                      fontFamily: 'Montserrat',

                                      fontSize: 11,

                                      fontWeight: FontWeight.w600,

                                    ),

                                  ),

                                ),

                              ],

                            );

                          },

                        ),

                      ),

                    const SizedBox(height: 14),

                  ],

                ],

              );

            },

          ),



          if (!isLocked) ...[

            const Divider(color: Colors.white12, height: 1),

            const SizedBox(height: 16),

            _sectionHeader('Actions'),

            const SizedBox(height: 10),

            Wrap(

              spacing: 10,

              runSpacing: 10,

              children: [

                _ActionChip(

                  label: 'Edit',

                  icon: Icons.edit,

                  color: Colors.orange,

                  onTap: () => widget.onEdit(_pet),

                ),



                _ActionChip(

                  label: 'Move to Medication',

                  icon: Icons.medical_services,

                  color: Colors.green,

                  onTap: () => widget.onMoveToMedication(_pet),

                ),

                _ActionChip(

                  label: 'Assign to Shelter',

                  icon: Icons.location_city,

                  color: Colors.purple,

                  onTap: () => widget.onMoveToShelter(_pet),

                ),

                _ActionChip(

                  label: 'View QR',

                  icon: Icons.qr_code,

                  color: Colors.teal,

                  onTap: () => widget.onShowQr(_pet),

                ),

                _ActionChip(

                  label: 'Delete',

                  icon: Icons.delete,

                  color: Colors.red,

                  onTap: () => widget.onDelete(_pet),

                ),

              ],

            ),

          ] else ...[

            const Divider(color: Colors.white12, height: 1),

            const SizedBox(height: 16),

            _ActionChip(

              label: 'View QR',

              icon: Icons.qr_code,

              color: Colors.teal,

              onTap: () => widget.onShowQr(_pet),

            ),

          ],

          const SizedBox(height: 8),

        ],

      ),

    );

  }



  Widget _buildHealthRecordsTab(List<Map<String, dynamic>> records) {

    if (records.isEmpty) {

      return const Center(

        child: Padding(

          padding: EdgeInsets.all(40),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              Icon(Icons.history_toggle_off, size: 56, color: Colors.white24),

              SizedBox(height: 12),

              Text(

                'No health records from vet yet',

                style: TextStyle(

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



    return ListView.builder(

      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

      itemCount: records.length,

      itemBuilder: (_, index) {

        final r = records[index];

        final type = r['record_type'] ?? 'checkup';

        final color = _recordTypeColor(type);

        final icon = _recordTypeIcon(type);

        final vaccineName =

            r['vaccination_cms'] != null

                ? r['vaccination_cms']['vaccine_name'] as String?

                : null;

        final notes = r['notes'] as String? ?? '';

        final dateAdmin = _formatDate(r['date_administered']);

        final nextDue = r['next_due_date'];



        return Container(

          margin: const EdgeInsets.only(bottom: 10),

          decoration: BoxDecoration(

            color: const Color(0xFF2A2A2A),

            borderRadius: BorderRadius.circular(12),

            border: Border(left: BorderSide(color: color, width: 4)),

          ),

          child: Padding(

            padding: const EdgeInsets.all(14),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Row(

                  children: [

                    Container(

                      padding: const EdgeInsets.all(6),

                      decoration: BoxDecoration(

                        color: color.withOpacity(0.15),

                        borderRadius: BorderRadius.circular(8),

                      ),

                      child: Icon(icon, color: color, size: 16),

                    ),

                    const SizedBox(width: 10),

                    Expanded(

                      child: Text(

                        vaccineName ?? _capitalize(type),

                        style: TextStyle(

                          color: color,

                          fontFamily: 'Montserrat',

                          fontWeight: FontWeight.bold,

                          fontSize: 14,

                        ),

                      ),

                    ),

                    Container(

                      padding: const EdgeInsets.symmetric(

                        horizontal: 8,

                        vertical: 3,

                      ),

                      decoration: BoxDecoration(

                        color: color.withOpacity(0.12),

                        borderRadius: BorderRadius.circular(12),

                      ),

                      child: Text(

                        _capitalize(type),

                        style: TextStyle(

                          color: color,

                          fontFamily: 'Montserrat',

                          fontSize: 11,

                          fontWeight: FontWeight.w600,

                        ),

                      ),

                    ),

                  ],

                ),

                const SizedBox(height: 8),

                Row(

                  children: [

                    Icon(Icons.calendar_today, size: 12, color: Colors.white38),

                    const SizedBox(width: 5),

                    Text(

                      'Administered: $dateAdmin',

                      style: const TextStyle(

                        color: Colors.white54,

                        fontFamily: 'Montserrat',

                        fontSize: 12,

                      ),

                    ),

                  ],

                ),

                if (nextDue != null) ...[

                  const SizedBox(height: 4),

                  Row(

                    children: [

                      const Icon(

                        Icons.event_repeat,

                        size: 12,

                        color: Colors.orangeAccent,

                      ),

                      const SizedBox(width: 5),

                      Text(

                        'Next due: ${_formatDate(nextDue)}',

                        style: const TextStyle(

                          color: Colors.orangeAccent,

                          fontFamily: 'Montserrat',

                          fontSize: 12,

                          fontWeight: FontWeight.w500,

                        ),

                      ),

                    ],

                  ),

                ],

                if (notes.isNotEmpty) ...[

                  const SizedBox(height: 8),

                  Container(

                    padding: const EdgeInsets.all(10),

                    decoration: BoxDecoration(

                      color: Colors.white.withOpacity(0.04),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: Text(

                      notes,

                      style: const TextStyle(

                        color: Colors.white60,

                        fontFamily: 'Montserrat',

                        fontSize: 12,

                        height: 1.5,

                      ),

                    ),

                  ),

                ],

              ],

            ),

          ),

        );

      },

    );

  }



  Widget _buildVialDonationsTab(List<Map<String, dynamic>> vials) {

    if (vials.isEmpty) {

      return const Center(

        child: Padding(

          padding: EdgeInsets.all(40),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              Icon(Icons.vaccines, size: 56, color: Colors.white24),

              SizedBox(height: 12),

              Text(

                'No vial donations logged yet',

                style: TextStyle(

                  color: Colors.white38,

                  fontFamily: 'Montserrat',

                  fontSize: 14,

                ),

              ),

              SizedBox(height: 6),

              Text(

                'Vets log vial donations from their app',

                style: TextStyle(

                  color: Colors.white24,

                  fontFamily: 'Montserrat',

                  fontSize: 12,

                ),

              ),

            ],

          ),

        ),

      );

    }



    final totalVials = vials.fold<int>(

      0,

      (sum, v) => sum + (v['quantity'] as int? ?? 0),

    );



    return Column(

      children: [

        Container(

          margin: const EdgeInsets.all(16),

          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),

          decoration: BoxDecoration(

            color: Colors.teal.withOpacity(0.12),

            borderRadius: BorderRadius.circular(12),

            border: Border.all(color: Colors.teal.withOpacity(0.3)),

          ),

          child: Row(

            children: [

              const Icon(Icons.vaccines, color: Colors.teal, size: 28),

              const SizedBox(width: 14),

              Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const Text(

                    'Total vials donated',

                    style: TextStyle(

                      color: Colors.white54,

                      fontFamily: 'Montserrat',

                      fontSize: 12,

                    ),

                  ),

                  Text(

                    '$totalVials vials  •  ${vials.length} records',

                    style: const TextStyle(

                      color: Colors.teal,

                      fontFamily: 'Montserrat',

                      fontSize: 16,

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ],

              ),

            ],

          ),

        ),

        Expanded(

          child: ListView.builder(

            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

            itemCount: vials.length,

            itemBuilder: (_, index) {

              final v = vials[index];

              final vaccineName =

                  v['vaccination_cms']?['vaccine_name'] ?? 'Unknown Vaccine';

              final species = v['vaccination_cms']?['target_species'] ?? '';

              final vetFirst = v['veterinarians']?['first_name'] ?? '';

              final vetLast = v['veterinarians']?['last_name'] ?? '';

              final vetName = '$vetFirst $vetLast'.trim();

              final quantity = v['quantity'] as int? ?? 0;

              final donationDate = _formatDate(v['donation_date']);

              final notes = v['notes'] as String? ?? '';



              return Container(

                margin: const EdgeInsets.only(bottom: 10),

                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(

                  color: const Color(0xFF2A2A2A),

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: Colors.teal.withOpacity(0.2)),

                ),

                child: Row(

                  children: [

                    Container(

                      padding: const EdgeInsets.all(10),

                      decoration: BoxDecoration(

                        color: Colors.teal.withOpacity(0.12),

                        borderRadius: BorderRadius.circular(10),

                      ),

                      child: const Icon(

                        Icons.vaccines,

                        color: Colors.teal,

                        size: 22,

                      ),

                    ),

                    const SizedBox(width: 12),

                    Expanded(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            vaccineName,

                            style: const TextStyle(

                              color: Colors.white,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 14,

                            ),

                          ),

                          if (species.isNotEmpty)

                            Text(

                              'For: $species',

                              style: const TextStyle(

                                color: Colors.white38,

                                fontFamily: 'Montserrat',

                                fontSize: 12,

                              ),

                            ),

                          if (vetName.isNotEmpty)

                            Row(

                              children: [

                                const Icon(

                                  Icons.person,

                                  size: 11,

                                  color: Colors.white38,

                                ),

                                const SizedBox(width: 4),

                                Text(

                                  'Dr. $vetName',

                                  style: const TextStyle(

                                    color: Colors.white54,

                                    fontFamily: 'Montserrat',

                                    fontSize: 12,

                                  ),

                                ),

                              ],

                            ),

                          Text(

                            donationDate,

                            style: const TextStyle(

                              color: Colors.white38,

                              fontFamily: 'Montserrat',

                              fontSize: 11,

                            ),

                          ),

                          if (notes.isNotEmpty)

                            Text(

                              notes,

                              style: const TextStyle(

                                color: Colors.white38,

                                fontFamily: 'Montserrat',

                                fontSize: 11,

                              ),

                            ),

                        ],

                      ),

                    ),

                    Container(

                      padding: const EdgeInsets.symmetric(

                        horizontal: 12,

                        vertical: 6,

                      ),

                      decoration: BoxDecoration(

                        color: Colors.teal,

                        borderRadius: BorderRadius.circular(20),

                      ),

                      child: Text(

                        '$quantity vials',

                        style: const TextStyle(

                          color: Colors.white,

                          fontFamily: 'Montserrat',

                          fontWeight: FontWeight.bold,

                          fontSize: 13,

                        ),

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



  Widget _imagePlaceholder() => Container(

    width: double.infinity,

    height: 200,

    color: Colors.grey[800],

    child: const Icon(Icons.pets, color: Colors.white38, size: 60),

  );



  Widget _sectionHeader(String title) => Text(

    title,

    style: const TextStyle(

      color: Colors.orange,

      fontFamily: 'Montserrat',

      fontWeight: FontWeight.bold,

      fontSize: 13,

    ),

  );



  Widget _infoCard(List<Widget> rows) => Container(

    padding: const EdgeInsets.all(12),

    decoration: BoxDecoration(

      color: const Color(0xFF2A2A2A),

      borderRadius: BorderRadius.circular(10),

    ),

    child: Column(children: rows),

  );



  Widget _detailRow(String label, String value) => Padding(

    padding: const EdgeInsets.only(bottom: 6),

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

              fontWeight: FontWeight.w500,

            ),

          ),

        ),

        Expanded(

          child: Text(

            value,

            style: const TextStyle(

              color: Colors.white70,

              fontFamily: 'Montserrat',

              fontSize: 12,

            ),

          ),

        ),

      ],

    ),

  );

}



//



class AdminVialSummaryWidget extends StatefulWidget {

  const AdminVialSummaryWidget({super.key});



  @override

  State<AdminVialSummaryWidget> createState() => _AdminVialSummaryWidgetState();

}



class _AdminVialSummaryWidgetState extends State<AdminVialSummaryWidget> {

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _vials = [];

  bool _isLoading = true;



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    setState(() => _isLoading = true);

    try {

      final data = await supabase

          .from('vet_vials')

          .select(

            '*, vaccination_cms(vaccine_name, target_species), '

            'veterinarians(first_name, last_name)',

          )

          .order('donation_date', ascending: false);

      setState(() {

        _vials = List<Map<String, dynamic>>.from(data);

        _isLoading = false;

      });

    } catch (e) {

      debugPrint('❌ AdminVialSummary error: $e');

      setState(() => _isLoading = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    final totalVials = _vials.fold<int>(

      0,

      (sum, v) => sum + (v['quantity'] as int? ?? 0),

    );



    return Container(

      decoration: BoxDecoration(

        color: const Color(0xFF1C1C1C),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.teal.withOpacity(0.2)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

            decoration: BoxDecoration(

              color: Colors.teal.withOpacity(0.1),

              borderRadius: const BorderRadius.only(

                topLeft: Radius.circular(16),

                topRight: Radius.circular(16),

              ),

            ),

            child: Row(

              children: [

                const Icon(Icons.vaccines, color: Colors.teal, size: 22),

                const SizedBox(width: 10),

                const Expanded(

                  child: Text(

                    'Vet Vial Donations',

                    style: TextStyle(

                      color: Colors.white,

                      fontFamily: 'Montserrat',

                      fontWeight: FontWeight.bold,

                      fontSize: 15,

                    ),

                  ),

                ),

                if (!_isLoading)

                  Text(

                    '$totalVials total vials',

                    style: const TextStyle(

                      color: Colors.teal,

                      fontFamily: 'Montserrat',

                      fontSize: 13,

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                const SizedBox(width: 8),

                GestureDetector(

                  onTap: _load,

                  child: const Icon(

                    Icons.refresh,

                    color: Colors.white38,

                    size: 18,

                  ),

                ),

              ],

            ),

          ),



          _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: LoadingAnimationWidget.fallingDot(
                      color: Colors.orange,
                      size: 50,
                    ),
                  ),
                )

              : _vials.isEmpty

              ? const Padding(

                padding: EdgeInsets.all(24),

                child: Center(

                  child: Text(

                    'No donations yet',

                    style: TextStyle(

                      color: Colors.white38,

                      fontFamily: 'Montserrat',

                    ),

                  ),

                ),

              )

              : ListView.separated(

                shrinkWrap: true,

                physics: const NeverScrollableScrollPhysics(),

                padding: const EdgeInsets.all(12),

                itemCount: _vials.length,

                separatorBuilder:

                    (_, __) => const Divider(color: Colors.white12, height: 1),

                itemBuilder: (_, index) {

                  final v = _vials[index];

                  final name = v['vaccination_cms']?['vaccine_name'] ?? '—';

                  final species = v['vaccination_cms']?['target_species'] ?? '';

                  final vetFirst = v['veterinarians']?['first_name'] ?? '';

                  final vetLast = v['veterinarians']?['last_name'] ?? '';

                  final vetName = 'Dr. $vetFirst $vetLast'.trim();

                  final qty = v['quantity'] as int? ?? 0;

                  final date = v['donation_date']?.toString() ?? '';



                  return ListTile(

                    contentPadding: const EdgeInsets.symmetric(

                      horizontal: 8,

                      vertical: 4,

                    ),

                    leading: Container(

                      padding: const EdgeInsets.all(8),

                      decoration: BoxDecoration(

                        color: Colors.teal.withOpacity(0.12),

                        borderRadius: BorderRadius.circular(8),

                      ),

                      child: const Icon(

                        Icons.vaccines,

                        color: Colors.teal,

                        size: 18,

                      ),

                    ),

                    title: Text(

                      name,

                      style: const TextStyle(

                        color: Colors.white,

                        fontFamily: 'Montserrat',

                        fontWeight: FontWeight.w600,

                        fontSize: 13,

                      ),

                    ),

                    subtitle: Text(

                      '${species.isNotEmpty ? "For: $species  •  " : ""}$vetName',

                      style: const TextStyle(

                        color: Colors.white38,

                        fontFamily: 'Montserrat',

                        fontSize: 11,

                      ),

                    ),

                    trailing: Column(

                      mainAxisAlignment: MainAxisAlignment.center,

                      crossAxisAlignment: CrossAxisAlignment.end,

                      children: [

                        Container(

                          padding: const EdgeInsets.symmetric(

                            horizontal: 10,

                            vertical: 4,

                          ),

                          decoration: BoxDecoration(

                            color: Colors.teal,

                            borderRadius: BorderRadius.circular(12),

                          ),

                          child: Text(

                            '$qty vials',

                            style: const TextStyle(

                              color: Colors.white,

                              fontFamily: 'Montserrat',

                              fontWeight: FontWeight.bold,

                              fontSize: 12,

                            ),

                          ),

                        ),

                        const SizedBox(height: 4),

                        Text(

                          date.length >= 10 ? date.substring(0, 10) : date,

                          style: const TextStyle(

                            color: Colors.white24,

                            fontFamily: 'Montserrat',

                            fontSize: 10,

                          ),

                        ),

                      ],

                    ),

                  );

                },

              ),

        ],

      ),

    );

  }

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

  Widget build(BuildContext context) => Container(

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
    final isMobile = MediaQuery.of(context).size.width < 900;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 14,
            vertical: isMobile ? 6 : 8,
          ),
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
                size: isMobile ? 13 : 15,
                color: _hovered ? Colors.white : widget.color,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? Colors.white : widget.color,
                  fontFamily: 'Montserrat',
                  fontSize: isMobile ? 11 : 12,
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

      await supabase.from('notifications').delete().eq('id', id);

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

                        final id = notif['id'] as int?;

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

