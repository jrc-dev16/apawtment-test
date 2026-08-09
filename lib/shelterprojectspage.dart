import 'dart:convert';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:io';
import 'dart:html' as html;
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import 'networkimage.dart'
    if (dart.library.io) 'network_image_widget_stub.dart'
    as platform;

class NetworkImageWidget extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const NetworkImageWidget({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.loadingWidget,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (kIsWeb) {
      child = platform.buildWebImage(
        url: url,
        width: width,
        height: height,
        fit: fit,
        errorWidget: errorWidget,
      );
    } else {
      child = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return loadingWidget ??
              SizedBox(
                width: width,
                height: height,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.orange,
                    strokeWidth: 2,
                  ),
                ),
              );
        },
        errorBuilder:
            (_, __, ___) => errorWidget ?? _defaultErrorWidget(width, height),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}

Widget _defaultErrorWidget(double? width, double? height) {
  return Container(
    width: width,
    height: height,
    color: Colors.grey[850],
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image, color: Colors.white38, size: 40),
        SizedBox(height: 6),
        Text(
          'Image unavailable',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    ),
  );
}

class ShelterProjectsPage extends StatefulWidget {
  const ShelterProjectsPage({super.key});

  @override
  State<ShelterProjectsPage> createState() => _ShelterProjectsPageState();
}

class _ShelterProjectsPageState extends State<ShelterProjectsPage> {
  final supabase = Supabase.instance.client;
  String? previousSelectedItem;
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> adoptionJourneys = [];
  bool loadingJourneys = true;
  String selectedItem = "Shelter Dashboard";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String selectedFilterCategory = 'All';
  String selectedFilterSubcategory = 'All';

  List<XFile> pickedMedia = [];
  List<Uint8List> webPreviewBytes = [];
  List<File> mobileMediaFiles = [];
  List<String> mediaTypes = [];

  final ImagePicker _picker = ImagePicker();

  final Map<String, List<String>> filterSubcategories = {
    'Donation': ['Food', 'Transportation', 'Pet Medical Needs', 'Audit'],
    'Events': ['Adoption', 'Medication', 'Vaccination', 'Others'],
  };

  List<Map<String, dynamic>> projects = [];
  bool loading = true;
  final Map<int, VideoPlayerController> _videoControllers = {};
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  String selectedCategory = 'Donation';
  Map<String, dynamic>? adminData;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadAdoptionJourneys();
    _subscribeToUpdates();
    _subscribeToJourneyUpdates();
    _loadAdmin();
    _loadProfileImageForAvatar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImageForAvatar();
    });
  }

  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ── Styled snackbar (matches ReportsPage) ──────────────────────────────────
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

  // ── Upload loading snackbar (keeps the longer duration for uploads) ────────
  void _showUploadingSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Uploading post...',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          duration: const Duration(seconds: 60),
        ),
      );
  }

  String _detectMimeType(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
    if (name.endsWith('.tiff') || name.endsWith('.tif')) return 'image/tiff';
    if (name.endsWith('.bmp')) return 'image/bmp';
    if (name.endsWith('.svg')) return 'image/svg+xml';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';

    if (name.endsWith('.mp4') || name.endsWith('.m4v') || name.endsWith('.mp3')) return 'video/mp4';
    if (name.endsWith('.mov')) return 'video/quicktime';
    if (name.endsWith('.avi')) return 'video/x-msvideo';
    if (name.endsWith('.mkv')) return 'video/x-matroska';
    if (name.endsWith('.flv')) return 'video/x-flv';
    if (name.endsWith('.wmv')) return 'video/x-ms-wmv';
    if (name.endsWith('.webm')) return 'video/webm';
    if (name.endsWith('.3gp') || name.endsWith('.3g2')) return 'video/3gpp';

    final reported = (file.mimeType ?? '').split(';').first.trim().toLowerCase();
    if (reported.isNotEmpty) return reported;
    return 'image/jpeg';
  }

  String _extFromMime(String mime) {
    final cleanMime = mime.toLowerCase();
    switch (cleanMime) {
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
      case 'image/heif':
        return 'heic';
      case 'image/tiff':
        return 'tiff';
      case 'image/bmp':
        return 'bmp';
      case 'image/svg+xml':
        return 'svg';
      case 'video/mp4':
        return 'mp4';
      case 'video/quicktime':
        return 'mov';
      case 'video/x-msvideo':
        return 'avi';
      case 'video/x-matroska':
        return 'mkv';
      case 'video/x-flv':
        return 'flv';
      case 'video/x-ms-wmv':
        return 'wmv';
      case 'video/webm':
        return 'webm';
      case 'video/3gpp':
        return '3gp';
      default:
        return 'jpg';
    }
  }

  Future<String?> _uploadToCloudinary(XFile file, String resourceType) async {
    try {
      const cloudName = 'djbcm7mvr';
      const uploadPreset = 'adoption_journey_uploads';
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final mime = _detectMimeType(file);
        final ext = _extFromMime(mime);
        final baseName =
            file.name.contains('.') ? file.name : '${file.name}.$ext';
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: baseName,
            contentType: MediaType.parse(mime),
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        return jsonDecode(respStr)['secure_url'] as String?;
      } else {
        debugPrint(
          '❌ Cloudinary upload failed (${response.statusCode}): $respStr',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ Cloudinary upload error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _uploadAllMedia() async {
    if (pickedMedia.isEmpty) return {'images': [], 'video': null};
    List<String> uploadedImageUrls = [];
    String? uploadedVideoUrl;
    for (int i = 0; i < pickedMedia.length; i++) {
      final mediaType = mediaTypes[i];
      final file = pickedMedia[i];
      if (mediaType == 'image') {
        final url = await _uploadToCloudinary(file, 'image');
        if (url != null) uploadedImageUrls.add(url);
      } else if (mediaType == 'video') {
        uploadedVideoUrl = await _uploadToCloudinary(file, 'video');
      }
    }
    return {'images': uploadedImageUrls, 'video': uploadedVideoUrl};
  }

  Future<void> _pickMedia(String type) async {
    if (type == 'image') {
      final existingImages = mediaTypes.where((t) => t == 'image').length;
      final remainingSlots = 2 - existingImages;
      if (remainingSlots <= 0) {
        _showSnackBar('Maximum 2 images allowed', Colors.orange);
        return;
      }
      final List<XFile> selected = await _picker.pickMultiImage();
      if (selected.isEmpty) return;
      for (var img in selected.take(remainingSlots)) {
        pickedMedia.add(img);
        mediaTypes.add('image');
        if (kIsWeb) {
          webPreviewBytes.add(await img.readAsBytes());
        } else {
          mobileMediaFiles.add(File(img.path));
        }
      }
      setState(() {});
    } else if (type == 'video') {
      if (mediaTypes.contains('video')) {
        _showSnackBar('Only 1 video allowed', Colors.orange);
        return;
      }
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      pickedMedia.add(video);
      mediaTypes.add('video');
      if (kIsWeb) {
        webPreviewBytes.add(await video.readAsBytes());
      } else {
        mobileMediaFiles.add(File(video.path));
      }
      setState(() {});
    }
  }

  void _clearAllMedia() {
    setState(() {
      pickedMedia.clear();
      webPreviewBytes.clear();
      mobileMediaFiles.clear();
      mediaTypes.clear();
    });
  }

  Future<void> _shareToFacebook(Map<String, dynamic> post) async {
    try {
      final description = post['description']?.toString() ?? '';
      final imageUrl = post['proj_image']?.toString() ?? '';
      final shareUrl =
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(imageUrl)}&quote=${Uri.encodeComponent(description)}';
      final uri = Uri.parse(shareUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!mounted) return;
        _showSnackBar('Opening Facebook...', Colors.blue);
      } else {
        throw 'Could not launch Facebook';
      }
    } catch (e) {
      if (!mounted) return;
      _showShareOptionsDialog(post);
    }
  }

  void _showShareOptionsDialog(Map<String, dynamic> post) {
    final shareText =
        '${post['description'] ?? ''}\n\nImage: ${post['proj_image'] ?? ''}';
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Share Post',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.orange),
                  title: const Text(
                    'Copy to Clipboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: shareText));
                    Navigator.pop(context);
                    _showSnackBar('Copied to clipboard!', Colors.green);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.facebook, color: Colors.blue),
                  title: const Text(
                    'Open Facebook',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final url = Uri.parse('https://www.facebook.com');
                    if (await canLaunchUrl(url))
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.orange,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _loadAdoptionJourneys() async {
    try {
      final journeys = await supabase
          .from('adoption_journey')
          .select('*')
          .order('created_at', ascending: false);
      final furparentIds =
          journeys
              .map((j) => j['furparent_id'])
              .where((id) => id != null)
              .toSet()
              .toList();
      final profiles =
          furparentIds.isEmpty
              ? []
              : await supabase
                  .from('profiles')
                  .select('furparent_id, first_name, last_name, avatar_url')
                  .inFilter('furparent_id', furparentIds);
      final profileMap = {for (final p in profiles) p['furparent_id']: p};
      final merged =
          journeys
              .map((j) => {...j, 'profiles': profileMap[j['furparent_id']]})
              .toList();
      if (!mounted) return;
      setState(() {
        adoptionJourneys = List<Map<String, dynamic>>.from(merged);
        loadingJourneys = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading adoption journeys: $e');
      if (mounted) setState(() => loadingJourneys = false);
    }
  }

  void _subscribeToJourneyUpdates() {
    supabase
        .channel('journey-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'adoption_journey',
          callback: (_) => _loadAdoptionJourneys(),
        )
        .subscribe();
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
      debugPrint('❌ Error loading profile image: $e');
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  Future<void> _loadAdmin() async {
    try {
      final response =
          await supabase
              .from('admin')
              .select('admin_id, name')
              .eq('admin_id', 1)
              .maybeSingle();
      if (!mounted) return;
      setState(() => adminData = response);
    } catch (e) {
      debugPrint('ERROR loading admin data: $e');
    }
  }

  Future<void> _loadProjects() async {
    try {
      final response = await supabase
          .from('shelter_projects')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        projects = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  void _subscribeToUpdates() {
    supabase
        .channel('projects-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'shelter_projects',
          callback: (_) => _loadProjects(),
        )
        .subscribe();
  }

  List<Map<String, dynamic>> get filteredProjects {
    return projects.where((post) {
      final category = post['category'];
      final subcategory = post['subcategory'];
      if (selectedFilterCategory != 'All' && category != selectedFilterCategory)
        return false;
      if (selectedFilterSubcategory != 'All' &&
          subcategory != selectedFilterSubcategory)
        return false;
      return true;
    }).toList();
  }

  void _openCreateModal() {
    final TextEditingController descCtrl = TextEditingController();
    final Map<String, List<String>> subcategoryOptions = {
      'Donation': ['Food', 'Transportation', 'Pet Medical Needs', 'Audit'],
      'Events': ['Adoption', 'Medication', 'Vaccination', 'Others'],
    };
    String selectedCategory = 'Donation';
    String selectedSubcategory = subcategoryOptions['Donation']!.first;
    _clearAllMedia();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Dialog(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                      maxWidth: 600,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Category',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            dropdownColor: const Color(0xFF2A2A2A),
                            decoration: _dropdownDecoration(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                            ),
                            items:
                                subcategoryOptions.keys
                                    .map(
                                      (cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text(cat),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModal(() {
                                selectedCategory = value;
                                selectedSubcategory =
                                    subcategoryOptions[value]!.first;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Sub-Category',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedSubcategory,
                            dropdownColor: const Color(0xFF2A2A2A),
                            decoration: _dropdownDecoration(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                            ),
                            items:
                                (subcategoryOptions[selectedCategory] ?? [])
                                    .map(
                                      (sub) => DropdownMenuItem(
                                        value: sub,
                                        child: Text(sub),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModal(() => selectedSubcategory = value);
                            },
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: descCtrl,
                            maxLines: 4,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Create a post...',
                              hintStyle: TextStyle(
                                color: Colors.white54,
                                fontFamily: 'Montserrat',
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: () async {
                              showDialog(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF2D2D2D),
                                      title: const Text(
                                        'Add Media',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.photo_library_outlined,
                                              color: Colors.orange,
                                            ),
                                            title: const Text(
                                              'Add Photos (up to 2)',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Montserrat',
                                              ),
                                            ),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              await _pickMedia('image');
                                              setModal(() {});
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.videocam_outlined,
                                              color: Colors.orange,
                                            ),
                                            title: const Text(
                                              'Add Video (1 max)',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Montserrat',
                                              ),
                                            ),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              await _pickMedia('video');
                                              setModal(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontFamily: 'Montserrat',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                            },
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 26,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Add photos or video...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Montserrat',
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          if (pickedMedia.isNotEmpty)
                            Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: List.generate(pickedMedia.length, (
                                    i,
                                  ) {
                                    final isVideo = mediaTypes[i] == 'video';
                                    return Container(
                                      margin: const EdgeInsets.only(
                                        right: 10,
                                        top: 10,
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child:
                                                isVideo
                                                    ? Container(
                                                      width: 120,
                                                      height: 120,
                                                      color: Colors.grey[800],
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons
                                                              .play_circle_fill,
                                                          color: Colors.white,
                                                          size: 40,
                                                        ),
                                                      ),
                                                    )
                                                    : kIsWeb
                                                    ? Image.memory(
                                                      webPreviewBytes[i],
                                                      width: 120,
                                                      height: 120,
                                                      fit: BoxFit.cover,
                                                      gaplessPlayback: true,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => Container(
                                                            width: 120,
                                                            height: 120,
                                                            color:
                                                                Colors
                                                                    .grey[700],
                                                            child: const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color:
                                                                  Colors
                                                                      .white54,
                                                            ),
                                                          ),
                                                    )
                                                    : Image.file(
                                                      mobileMediaFiles[i],
                                                      width: 120,
                                                      height: 120,
                                                      fit: BoxFit.cover,
                                                    ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () {
                                                setModal(() {
                                                  pickedMedia.removeAt(i);
                                                  mediaTypes.removeAt(i);
                                                  if (kIsWeb) {
                                                    webPreviewBytes.removeAt(i);
                                                  } else {
                                                    mobileMediaFiles.removeAt(
                                                      i,
                                                    );
                                                  }
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    _clearAllMedia();
                                  },
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  onPressed: () async {
                                    if (descCtrl.text.trim().isEmpty) {
                                      _showSnackBar(
                                        'Please add a description.',
                                        Colors.red,
                                      );
                                      return;
                                    }
                                    final descText = descCtrl.text.trim();
                                    Navigator.pop(dialogContext);
                                    _showUploadingSnackBar();
                                    try {
                                      final uploadedMedia =
                                          await _uploadAllMedia();
                                      final uploadedImageUrls =
                                          uploadedMedia['images']
                                              as List<String>;
                                      final uploadedVideoUrl =
                                          uploadedMedia['video'] as String?;
                                      await supabase
                                          .from('shelter_projects')
                                          .insert({
                                            'description': descText,
                                            'proj_image':
                                                uploadedImageUrls.isNotEmpty
                                                    ? uploadedImageUrls[0]
                                                    : null,
                                            'proj_images': uploadedImageUrls,
                                            'proj_video': uploadedVideoUrl,
                                            'category': selectedCategory,
                                            'sub_category': selectedSubcategory,
                                            'views': 0,
                                          });
                                      await logActivity(
                                        action: 'Created Shelter Post',
                                        description:
                                            'Created shelter post under category $selectedCategory',
                                        entityType: 'Shelter Post',
                                      );
                                      _clearAllMedia();
                                      await _loadProjects();
                                      _showSnackBar(
                                        'Post created!',
                                        Colors.green,
                                      );
                                    } catch (e) {
                                      debugPrint('❌ Post error: $e');
                                      _showSnackBar(
                                        'Failed to post shelter project.',
                                        Colors.red,
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Post',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      color: Colors.white,
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1000;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1F1F1F),
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
              children: [
                _buildTopHeaderWithMenu(isDesktop: isDesktop),

                Container(
                  color: const Color(0xFF2A2A2A),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTab(
                          'Shelter Projects',
                          0,
                          Icons.home_work,
                        ),
                      ),
                      Expanded(
                        child: _buildTab('Adoption Journey', 1, Icons.pets),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child:
                      _currentTabIndex == 0
                          ? _buildProjectsTab()
                          : _buildAdoptionJourneyTab(),
                ),

                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeaderWithMenu({required bool isDesktop}) {
    final bool isMobile = !isDesktop;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 20,
        vertical: isMobile ? 10 : 15,
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 24),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

          if (isMobile)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => DashboardPage()),
                  );
                }
              },
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => DashboardPage()),
                  );
                }
              },
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

          SizedBox(width: isMobile ? 6 : 12),

          Expanded(
            child: Text(
              'Shelter Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 22 : 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),

          SizedBox(width: isMobile ? 4 : 12),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: _openCreateModal,
                tooltip: 'Create Post',
              ),
              _NotificationBell(
                iconSize: isMobile ? 22 : 24,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
              SizedBox(width: isMobile ? 4 : 8),
              buildProfileAvatar(context, radius: isMobile ? 14 : 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isActive = _currentTabIndex == index;
    final isMobile = MediaQuery.of(context).size.width < 800;
    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Colors.orange : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? Colors.orange : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.orange : Colors.grey,
                fontSize: isMobile ? 12 : 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsTab() {
    if (loading) {
      return Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 50,
        ),
      );
    }
    if (projects.isEmpty) {
      return const Center(
        child: Text(
          'No projects found',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontSize: 16,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: projects.length,
      itemBuilder: (context, index) => _buildProjectCard(projects[index]),
    );
  }

  Widget _buildAdoptionJourneyTab() {
    if (loadingJourneys) {
      return Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 50,
        ),
      );
    }
    if (adoptionJourneys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 16),
            const Text(
              'No adoption updates yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: adoptionJourneys.length,
      itemBuilder: (context, i) => _buildJourneyCard(adoptionJourneys[i]),
    );
  }

  Widget _buildJourneyCard(Map<String, dynamic> journey) {
    final profile = journey['profiles'];
    final firstName = profile?['first_name']?.toString() ?? '';
    final lastName = profile?['last_name']?.toString() ?? '';
    final userName =
        (firstName.isEmpty && lastName.isEmpty)
            ? 'Anonymous User'
            : '$firstName $lastName'.trim();
    final avatarUrl = profile?['avatar_url']?.toString();
    final description = (journey['description'] ?? '').toString().trim();
    final fileUrl = journey['proj_file']?.toString();
    bool isImage = journey['is_image'] == true;
    bool isVideo = journey['is_video'] == true;

    if (fileUrl != null && fileUrl.isNotEmpty && !isImage && !isVideo) {
      final urlLower = fileUrl.toLowerCase();
      if (urlLower.endsWith('.mp4') ||
          urlLower.endsWith('.mov') ||
          urlLower.endsWith('.avi') ||
          urlLower.endsWith('.mkv') ||
          urlLower.endsWith('.flv') ||
          urlLower.endsWith('.wmv') ||
          urlLower.endsWith('.webm') ||
          urlLower.endsWith('.3gp') ||
          urlLower.endsWith('.m4v') ||
          urlLower.contains('video/')) {
        isVideo = true;
      } else {
        isImage = true;
      }
    }

    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(journey['created_at']);
    } catch (_) {}
    final formattedDate =
        createdAt != null
            ? '${_getMonthName(createdAt.month)} ${createdAt.day}, ${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
            : '';

    void openFullScreen(String url, bool video) {
      showDialog(
        context: context,
        builder:
            (_) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                children: [
                  Positioned.fill(
                    child:
                        video
                            ? VideoPlayerWidget(url: url)
                            : InteractiveViewer(
                              child: NetworkImageWidget(
                                url: url,
                                fit: BoxFit.contain,
                                errorWidget: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 80,
                                ),
                              ),
                            ),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.orange[100],
                  child:
                      avatarUrl != null && avatarUrl.isNotEmpty
                          ? ClipOval(
                            child: NetworkImageWidget(
                              url: avatarUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          )
                          : Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),

          if (fileUrl != null && fileUrl.isNotEmpty && (isImage || isVideo))
            Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => openFullScreen(fileUrl, isVideo),
                child:
                    isImage
                        ? NetworkImageWidget(
                          url: fileUrl,
                          width: double.infinity,
                          height: 300,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(12),
                          errorWidget: _mediaErrorPlaceholder(),
                        )
                        : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(height: 300, color: const Color(0xFF1A1A1A)),
                              const Icon(
                                Icons.play_circle_fill,
                                size: 64,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mediaErrorPlaceholder() {
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'Media not available',
            style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat'),
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

  void _navigateWithHighlightRestore(Widget Function() pageBuilder) {
    final previous = selectedItem;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => pageBuilder()),
    ).then((_) => setState(() => selectedItem = previous));
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

  Widget _buildFooter(BuildContext context) {
    return Container(
      height: 40,
      color: const Color(0xFF181818),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
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
                  child: NetworkImageWidget(
                    url: _cachedProfileImage!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorWidget: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: radius,
                    ),
                  ),
                )
                : Icon(Icons.person, color: Colors.black, size: radius),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> post) {
    List<String> imageUrls = [];
    final rawImages = post['proj_images'];
    if (rawImages != null) {
      if (rawImages is List) {
        imageUrls =
            rawImages
                .map((e) => e?.toString() ?? '')
                .where((url) => url.isNotEmpty)
                .toList();
      } else if (rawImages is String && rawImages.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawImages);
          if (decoded is List) {
            imageUrls =
                decoded
                    .map((e) => e?.toString() ?? '')
                    .where((url) => url.isNotEmpty)
                    .toList();
          }
        } catch (_) {
          imageUrls = [rawImages];
        }
      }
    }
    if (imageUrls.isEmpty) {
      final single = post['proj_image']?.toString();
      if (single != null && single.isNotEmpty) imageUrls = [single];
    }

    final videoUrl = post['proj_video']?.toString();
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;

    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(post['created_at']);
    } catch (_) {}
    final formattedDate =
        createdAt != null
            ? '${_getMonthName(createdAt.month)} ${createdAt.day}, ${createdAt.year}'
            : '';

    Future<void> deleteProject(int id) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (dialogCtx) => AlertDialog(
              backgroundColor: const Color(0xFF2D2D2D),
              title: const Text(
                'Delete Project',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              content: const Text(
                'Are you sure you want to delete this project?',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: Colors.white70,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
      );
      if (confirm != true) return;
      try {
        await supabase.from('shelter_projects').delete().eq('project_id', id);
        await logActivity(
          action: 'Deleted Shelter Post',
          description: 'Deleted shelter post ID $id',
          entityType: 'Shelter Post',
          entityId: id,
        );
        if (!mounted) return;
        setState(() => projects.removeWhere((e) => e['project_id'] == id));
        _showSnackBar('Project deleted', Colors.green);
      } catch (e) {
        debugPrint('❌ Error deleting shelter posts: $e');
        if (!mounted) return;
        _showSnackBar('Failed to delete.', Colors.red);
      }
    }

    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: isMobile ? 20 : 26,
                  backgroundColor: Colors.grey[300],
                  child: ClipOval(
                    child:
                        (_cachedProfileImage != null &&
                                _cachedProfileImage!.isNotEmpty)
                            ? NetworkImageWidget(
                              url: _cachedProfileImage!,
                              width: isMobile ? 40 : 52,
                              height: isMobile ? 40 : 52,
                              fit: BoxFit.cover,
                              errorWidget: Icon(
                                Icons.person,
                                color: Colors.grey[600],
                                size: isMobile ? 20 : 26,
                              ),
                            )
                            : Icon(
                              Icons.person,
                              color: Colors.grey[600],
                              size: isMobile ? 20 : 26,
                            ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              adminData?['name'] ?? 'Admin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 16 : 20,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share, color: Colors.blue, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () => _shareToFacebook(post),
                                tooltip: 'Share to Facebook',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () {
                                  final id = post['id'];
                                  if (id != null) deleteProject(id as int);
                                },
                                tooltip: 'Delete Project',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: isMobile ? 12 : 14,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          if (post['category'] != null &&
                              post['category'].toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey[800],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                post['category'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (post['sub_category'] != null &&
                              post['sub_category'].toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal[800],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                post['sub_category'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
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
          if (post['description'] != null &&
              post['description'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                post['description'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Montserrat',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          if (imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child:
                  imageUrls.length == 1
                      ? _buildSingleImage(imageUrls[0])
                      : _buildImageGrid(imageUrls),
            ),
          ],

          if (hasVideo) ...[
            const SizedBox(height: 10),
            _buildVideoThumbnailCard(videoUrl),
          ],

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post['views'] ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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

  Widget _buildVideoThumbnailCard(String videoUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap:
            () => showDialog(
              context: context,
              builder:
                  (_) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: EdgeInsets.zero,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: VideoPlayerWidget(url: videoUrl),
                        ),
                        Positioned(
                          top: 40,
                          right: 20,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 220,
                width: double.infinity,
                color: Colors.grey[900],
              ),
              const Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleImage(String imageUrl) {
    return NetworkImageWidget(
      url: imageUrl,
      width: double.infinity,
      height: 300,
      fit: BoxFit.contain,
      borderRadius: BorderRadius.circular(8),
      loadingWidget: Container(
        height: 300,
        color: Colors.grey[900],
        child: Center(
          child: LoadingAnimationWidget.fallingDot(
            color: Colors.orange,
            size: 50,
          ),
        ),
      ),
      errorWidget: Container(
        height: 300,
        color: Colors.grey[850],
        child: const Icon(Icons.broken_image, size: 50, color: Colors.white38),
      ),
    );
  }

  Widget _buildImageGrid(List<String> imageUrls) {
    if (imageUrls.length < 2) return _buildSingleImage(imageUrls[0]);
    return Row(
      children: [
        Expanded(
          child: NetworkImageWidget(
            url: imageUrls[0],
            height: 300,
            fit: BoxFit.cover,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
            errorWidget: Container(
              height: 300,
              color: Colors.grey[850],
              child: const Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.white38,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: NetworkImageWidget(
            url: imageUrls[1],
            height: 300,
            fit: BoxFit.cover,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            errorWidget: Container(
              height: 300,
              color: Colors.grey[850],
              child: const Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.white38,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

// ── VideoPlayerWidget ──────────────────────────────────────────────────────────

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized)
      return Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 50,
        ),
      );
    return GestureDetector(
      onTap:
          () => setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          }),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

// ── Web image helpers ──────────────────────────────────────────────────────────

int _viewCounter = 0;

Widget buildWebImage({
  required String url,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? errorWidget,
}) {
  if (url.isEmpty) {
    return _placeholder(width, height, errorWidget);
  }

  final viewId = 'net-img-${_viewCounter++}';

  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewId, (_) {
    final img =
        html.ImageElement()
          ..src = url
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = _cssFit(fit)
          ..style.display = 'block'
          ..setAttribute('crossorigin', 'anonymous');

    return img;
  });

  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewId),
  );
}

String _cssFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.cover:
      return 'cover';
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.none:
      return 'none';
    default:
      return 'cover';
  }
}

Widget _placeholder(double? width, double? height, Widget? errorWidget) {
  return errorWidget ??
      Container(
        width: width,
        height: height,
        color: Colors.grey[850],
        child: const Icon(Icons.broken_image, color: Colors.white38, size: 40),
      );
}

// ── _NotificationBell ──────────────────────────────────────────────────────────

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
                final deletedId = payload.oldRecord['id'];
                if (deletedId != null && mounted) {
                  setState(
                    () =>
                        _notifications.removeWhere((n) => n['id'] == deletedId),
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

// ── _NotificationPanel ─────────────────────────────────────────────────────────

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

// ── _HoverSidebarItem ──────────────────────────────────────────────────────────

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
