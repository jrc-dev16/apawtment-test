import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui_web' as ui;
import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:apawtmentweb_admin/donationpage.dart';
import 'package:apawtmentweb_admin/main.dart';

import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:apawtmentweb_admin/dashboardpage.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';

import 'package:url_launcher/url_launcher.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final supabase = Supabase.instance.client;
  String _selectedItem = "Events";
  Timer? _eventCheckTimer;
  Timer? _statusUpdateTimer;
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;

  String? mapUrl;
  String? embedUrl;
  String? viewType;

  @override
  void initState() {
    super.initState();
    saveLastVisitedPage('Events');
    _startEventEndChecker();
    _startStatusUpdateTimer();

    if (kIsWeb) {
      const viewType = "google-maps-iframe";
      ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final iframe =
            html.IFrameElement()
              ..src = embedUrl ?? ""
              ..style.border = "0"
              ..style.width = "100%"
              ..style.height = "200px";
        return iframe;
      });
    }

    _loadProfileImageForAvatar();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImageForAvatar();
    });

    _checkAndUpdateEventStatuses();
  }

  @override
  void dispose() {
    _eventCheckTimer?.cancel();
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  Future<List<String>> _getRecentLocationSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('recent_location_searches') ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRecentLocationSearch(String locationName) async {
    if (locationName.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('recent_location_searches') ?? [];
      list.removeWhere(
        (item) => item.toLowerCase() == locationName.trim().toLowerCase(),
      );
      list.insert(0, locationName.trim());
      if (list.length > 5) {
        list.removeRange(5, list.length);
      }
      await prefs.setStringList('recent_location_searches', list);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _searchLocation(String query) async {
    if (query.trim().isEmpty) return [];
    final encoded = Uri.encodeComponent(query.trim());
    final results = <Map<String, dynamic>>[];

    try {
      final photonUrl =
          "https://photon.komoot.io/api/?q=$encoded&limit=10&bbox=116.92,4.60,126.60,21.12&lat=12.8797&lon=121.7740";
      final res = await http.get(Uri.parse(photonUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          for (final f in features) {
            final props = f['properties'] as Map<String, dynamic>? ?? {};
            final geom = f['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geom['coordinates'] as List?;
            if (coords != null && coords.length >= 2) {
              final double lon = (coords[0] as num).toDouble();
              final double lat = (coords[1] as num).toDouble();

              if (lat < 4.5 || lat > 21.5 || lon < 116.0 || lon > 127.0) {
                continue;
              }

              final country = props['country']?.toString() ?? '';
              if (country.isNotEmpty &&
                  !country.toLowerCase().contains('philippine') &&
                  !country.toLowerCase().contains('ph')) {
                continue;
              }

              final name = props['name']?.toString() ?? '';
              final city =
                  props['city']?.toString() ??
                  props['county']?.toString() ??
                  props['district']?.toString() ??
                  '';
              final state = props['state']?.toString() ?? '';

              final parts = [name, city, state, 'Philippines']
                  .where((p) => p.isNotEmpty)
                  .toSet()
                  .toList();
              final displayName = parts.join(', ');

              results.add({
                'display_name':
                    displayName.isNotEmpty ? displayName : query.trim(),
                'lat': lat.toString(),
                'lon': lon.toString(),
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Photon location search error: $e');
    }

    if (results.isNotEmpty) return results.take(5).toList();

    try {
      final nomUrl =
          "https://api.allorigins.win/raw?url=${Uri.encodeComponent("https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=5&countrycodes=ph")}";
      final res = await http.get(Uri.parse(nomUrl));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0;

          if (lat >= 4.5 && lat <= 21.5 && lon >= 116.0 && lon <= 127.0) {
            results.add({
              'display_name': item['display_name'] ?? query.trim(),
              'lat': lat.toString(),
              'lon': lon.toString(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Nominatim proxy search error: $e');
    }

    return results.take(5).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchVetComments(dynamic eventId) async {
    try {
      final commentsRaw = await Supabase.instance.client
          .from('event_comments')
          .select('*, is_admin, admin_name, image_url')
          .eq('eventid', eventId)
          .order('created_at', ascending: true);

      final rawList = commentsRaw as List;
      if (rawList.isEmpty) return [];

      final comments = <Map<String, dynamic>>[];
      for (final row in rawList) {
        if (row == null) continue;
        final safeRow = <String, dynamic>{};
        (row as Map).forEach((key, value) {
          safeRow[key.toString()] = value;
        });
        comments.add(safeRow);
      }

      final enriched = await Future.wait(
        comments.map((comment) async {
          final vetId = comment['vet_id'];
          final result = <String, dynamic>{};
          comment.forEach((k, v) => result[k] = v);

          if (comment['is_admin'] == true || vetId == null) {
            result['first_name'] = '';
            result['last_name'] = '';
            result['avatar_url'] = '';
            return result;
          }

          try {
            final vetRaw =
                await Supabase.instance.client
                    .from('veterinarians')
                    .select('first_name, last_name, avatar_url')
                    .eq('vet_id', vetId)
                    .maybeSingle();

            result['first_name'] = vetRaw?['first_name'] ?? 'Unknown';
            result['last_name'] = vetRaw?['last_name'] ?? '';
            result['avatar_url'] = vetRaw?['avatar_url'];
          } catch (e) {
            debugPrint('⚠️ Vet fetch failed for vet_id=$vetId: $e');
            result['first_name'] = 'Unknown';
            result['last_name'] = '';
            result['avatar_url'] = null;
          }

          return result;
        }),
      );

      return enriched;
    } catch (e, stack) {
      debugPrint('❌ Error fetching comments: $e\n$stack');
      rethrow;
    }
  }

  Future<String> _fetchAdminName() async {
    try {
      final adminData =
          await Supabase.instance.client
              .from('admin')
              .select('name')
              .eq('admin_id', 1)
              .maybeSingle();
      return adminData?['name']?.toString() ?? 'Admin';
    } catch (e) {
      debugPrint('❌ Error fetching admin name: $e');
      return 'Admin';
    }
  }

  Future<String?> _uploadCommentImage(PlatformFile file) async {
    try {
      final bytes = file.bytes;
      if (bytes == null) return null;

      final fileName =
          'comment_${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      await Supabase.instance.client.storage
          .from('event_comment_images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: file.extension == 'png' ? 'image/png' : 'image/jpeg',
              upsert: true,
            ),
          );

      return Supabase.instance.client.storage
          .from('event_comment_images')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      if (mounted) {
        // NEW
        _showSnackBar('Failed to upload image.', Colors.red);
        debugPrint('Failed to upload image: $e');
      }
      return null;
    }
  }

  Future<void> _postAdminComment({
    required int eventId,
    required String comment,
    String? imageUrl,
  }) async {
    try {
      final adminName = await _fetchAdminName();

      // 1. Insert the comment
      await Supabase.instance.client.from('event_comments').insert({
        'eventid': eventId,
        'vet_id': null,
        'is_admin': true,
        'admin_name': adminName,
        'comment': comment,
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Fetch event title for the notification message
      final eventData =
          await Supabase.instance.client
              .from('events')
              .select('title')
              .eq('eventid', eventId)
              .maybeSingle();
      final eventTitle = eventData?['title']?.toString() ?? 'an event';

      // 3. Notify all active vets
      await _notifyAllVetsAdminComment(
        eventId: eventId,
        eventTitle: eventTitle,
        adminName: adminName,
        comment: comment,
        hasImage: imageUrl != null && imageUrl.isNotEmpty,
      );
    } catch (e) {
      debugPrint('❌ Error posting admin comment: $e');
      if (mounted) {
        // NEW
        _showSnackBar('Failed to post comment.', Colors.red);
      }
    }
  }

  String _formatCommentDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  void _startStatusUpdateTimer() {
    _updateEventStatusesInDatabase();
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _updateEventStatusesInDatabase();
      if (mounted) setState(() {});
    });
  }

  Future<void> _checkAndUpdateEventStatuses() async {
    try {
      final now = DateTime.now();
      final response = await supabase
          .from('events')
          .select('*')
          .order('date', ascending: true);
      final events = List<Map<String, dynamic>>.from(response);

      for (var event in events) {
        try {
          final eventDateStr = event['date'];
          final startTimeStr = event['start_time'];
          final endTimeStr = event['end_time'];
          final notifiedOnEnd =
              event['notified_on_end'] == true ||
              event['notified_on_end'] == 'true';

          if (eventDateStr == null ||
              startTimeStr == null ||
              endTimeStr == null)
            continue;

          final eventDate = DateTime.parse(eventDateStr);
          final startTime = _parseTime(startTimeStr, eventDateStr);
          final endTime = _parseTime(endTimeStr, eventDateStr);
          if (startTime == null || endTime == null) continue;

          final eventEnd = DateTime(
            eventDate.year,
            eventDate.month,
            eventDate.day,
            endTime.hour,
            endTime.minute,
          );

          if (now.isAfter(eventEnd) && !notifiedOnEnd) {
            await supabase
                .from('events')
                .update({'notified_on_end': true})
                .eq('eventid', event['eventid']);
          }
        } catch (e) {
          debugPrint("⚠️ Error processing event ${event['title']}: $e");
        }
      }
    } catch (e, st) {
      debugPrint("❌ Error in _checkAndUpdateEventStatuses: $e\n$st");
    }
  }

  Future<void> _updateEventStatusesInDatabase() async {
    try {
      final now = DateTime.now();
      final response = await supabase
          .from('events')
          .select(
            'eventid, title, date, start_time, end_time, status, notified_on_end',
          );
      final allEvents = List<Map<String, dynamic>>.from(response);
      final events =
          allEvents.where((e) {
            final s = (e['status'] as String?) ?? '';
            return s == 'Upcoming' || s == 'Ongoing';
          }).toList();

      for (var event in events) {
        try {
          final eventId = event['eventid'];
          final title = (event['title'] as String?) ?? 'Untitled';
          final eventDateStr = event['date'] as String?;
          final startTimeStr = event['start_time'] as String?;
          final endTimeStr = event['end_time'] as String?;
          final currentStatus = (event['status'] as String?) ?? 'Unknown';

          if (eventDateStr == null ||
              startTimeStr == null ||
              endTimeStr == null)
            continue;

          final eventDate = DateTime.parse(eventDateStr);
          final startTime = _parseTime(startTimeStr, eventDateStr);
          final endTime = _parseTime(endTimeStr, eventDateStr);
          if (startTime == null || endTime == null) continue;

          final eventStart = DateTime(
            eventDate.year,
            eventDate.month,
            eventDate.day,
            startTime.hour,
            startTime.minute,
          );
          final eventEnd = DateTime(
            eventDate.year,
            eventDate.month,
            eventDate.day,
            endTime.hour,
            endTime.minute,
          );

          String newStatus;
          if (now.isBefore(eventStart)) {
            newStatus = 'Upcoming';
          } else if (now.isBefore(eventEnd)) {
            newStatus = 'Ongoing';
          } else {
            newStatus = 'Ended';
          }

          if (currentStatus != newStatus) {
            await supabase
                .from('events')
                .update({'status': newStatus})
                .eq('eventid', eventId);

            if (newStatus == 'Ended' && event['notified_on_end'] != true) {
              await supabase
                  .from('events')
                  .update({'notified_on_end': true})
                  .eq('eventid', eventId);
              await logActivity(
                action: 'Event Ended',
                description: 'Event "$title" has ended',
                entityType: 'Event',
                entityId: eventId is int ? eventId : int.tryParse(eventId.toString()),
              );
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error processing event: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ _updateEventStatusesInDatabase skipped: $e');
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

  void _startEventEndChecker() {
    _checkAndUpdateEventStatuses();
    _eventCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _checkAndUpdateEventStatuses();
      await _checkForEndedEvents();
    });
  }

  Future<void> _checkForEndedEvents() async {
    try {
      final now = DateTime.now();
      final response = await supabase
          .from('events')
          .select('eventid, title, date, end_time, notified_on_end')
          .order('date', ascending: true);
      final events = List<Map<String, dynamic>>.from(response);

      for (var event in events) {
        if (event['notified_on_end'] == true) continue;
        final eventDate = DateTime.tryParse(event['date'] ?? '');
        final endTime = _parseTime(event['end_time'], event['date']);

        if (eventDate != null && endTime != null) {
          final eventEnd = DateTime(
            eventDate.year,
            eventDate.month,
            eventDate.day,
            endTime.hour,
            endTime.minute,
          );

          if (now.isAfter(eventEnd) &&
              now.difference(eventEnd).inMinutes <= 1) {
            await supabase
                .from('events')
                .update({'notified_on_end': true})
                .eq('eventid', event['eventid']);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking ended events: $e');
    }
  }

  DateTime? _parseTime(String? rawTime, String? date) {
    if (rawTime == null || rawTime.isEmpty) return null;
    try {
      if (rawTime.contains(':') &&
          !rawTime.toUpperCase().contains('AM') &&
          !rawTime.toUpperCase().contains('PM')) {
        final parts = rawTime.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            return DateTime(2000, 1, 1, hour, minute);
          }
        }
      }
      if (rawTime.toUpperCase().contains('AM') ||
          rawTime.toUpperCase().contains('PM')) {
        String cleanTime = rawTime.replaceAll(' ', '').toUpperCase();
        final isPM = cleanTime.contains('PM');
        cleanTime = cleanTime.replaceAll('AM', '').replaceAll('PM', '');
        final parts = cleanTime.split(':');
        if (parts.length >= 2) {
          int? hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            if (isPM && hour != 12)
              hour += 12;
            else if (!isPM && hour == 12)
              hour = 0;
            return DateTime(2000, 1, 1, hour, minute);
          }
        }
      }
      try {
        return DateFormat("HH:mm:ss").parseStrict(rawTime);
      } catch (_) {
        try {
          return DateFormat(
            "h:mma",
          ).parseStrict(rawTime.toUpperCase().replaceAll(' ', ''));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("⚠️ Error parsing time: $rawTime - $e");
    }
    return null;
  }

  Stream<List<Map<String, dynamic>>> _getEventsStream() {
    return supabase
        .from('events')
        .stream(primaryKey: ['eventid'])
        .order('date', ascending: true)
        .map((data) {
          final now = DateTime.now();
          return data.map((event) {
            try {
              final eventDate = DateTime.parse(event['date']);
              final startTime = _parseTime(event['start_time'], event['date']);
              final endTime = _parseTime(event['end_time'], event['date']);
              if (startTime == null || endTime == null) {
                event['status'] = "Unknown";
                return event;
              }
              final eventStart = DateTime(
                eventDate.year,
                eventDate.month,
                eventDate.day,
                startTime.hour,
                startTime.minute,
              );
              final eventEnd = DateTime(
                eventDate.year,
                eventDate.month,
                eventDate.day,
                endTime.hour,
                endTime.minute,
              );
              if (now.isBefore(eventStart)) {
                event['status'] = "Upcoming";
              } else if ((now.isAtSameMomentAs(eventStart) ||
                      now.isAfter(eventStart)) &&
                  now.isBefore(eventEnd)) {
                event['status'] = "Ongoing";
              } else {
                event['status'] = "Ended";
              }
            } catch (e) {
              event['status'] = "Unknown";
            }
            return event;
          }).toList();
        });
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

  void _showVetComments(BuildContext context, Map<String, dynamic> event) {
    final rawEventId = event['eventid'];
    final eventId =
        rawEventId is int ? rawEventId : int.tryParse(rawEventId.toString());

    final refreshNotifier = ValueNotifier<int>(0);
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        PlatformFile? selectedImage;
        bool isPosting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              expand: false,
              snap: true,
              snapSizes: const [0.65, 0.92],
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Comments — ${event['title'] ?? 'Event'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: 'Montserrat',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: refreshNotifier,
                        builder: (_, __, ___) {
                          return FutureBuilder<List<Map<String, dynamic>>>(
                            future: _fetchVetComments(eventId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.orangeAccent,
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Error: ${snapshot.error}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                );
                              }

                              final comments = snapshot.data ?? [];

                              if (comments.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 56,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No comments yet. Be the first!',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 15,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                itemCount: comments.length,
                                separatorBuilder:
                                    (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final comment = comments[index];
                                  final isAdmin = comment['is_admin'] == true;
                                  return isAdmin
                                      ? _buildAdminCommentBubble(comment)
                                      : _buildVetCommentBubble(comment);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const Divider(height: 1),

                    if (selectedImage != null)
                      Container(
                        color: Colors.grey.shade50,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                selectedImage!.bytes!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedImage!.name,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed:
                                  () =>
                                      setSheetState(() => selectedImage = null),
                            ),
                          ],
                        ),
                      ),

                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: 10,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.orange.withOpacity(0.15),
                            backgroundImage:
                                (_cachedProfileImage != null &&
                                        _cachedProfileImage!.isNotEmpty)
                                    ? NetworkImage(_cachedProfileImage!)
                                    : null,
                            child:
                                (_cachedProfileImage == null ||
                                        _cachedProfileImage!.isEmpty)
                                    ? const Icon(
                                      Icons.person,
                                      color: Colors.orange,
                                      size: 18,
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 8),

                          IconButton(
                            icon: Icon(
                              selectedImage != null
                                  ? Icons.image
                                  : Icons.image_outlined,
                              color:
                                  selectedImage != null
                                      ? Colors.orange
                                      : Colors.grey.shade500,
                              size: 22,
                            ),
                            tooltip: 'Attach image',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.image,
                                    withData: true,
                                  );
                              if (result != null && result.files.isNotEmpty) {
                                setSheetState(
                                  () => selectedImage = result.files.first,
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 6),

                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: TextField(
                                controller: commentController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Write a comment as Admin…',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: commentController,
                            builder: (_, value, __) {
                              final hasContent =
                                  value.text.trim().isNotEmpty ||
                                  selectedImage != null;
                              return Material(
                                color:
                                    hasContent
                                        ? Colors.orange
                                        : Colors.grey.shade300,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap:
                                      hasContent && !isPosting
                                          ? () async {
                                            setSheetState(
                                              () => isPosting = true,
                                            );

                                            String? uploadedUrl;
                                            if (selectedImage != null) {
                                              uploadedUrl =
                                                  await _uploadCommentImage(
                                                    selectedImage!,
                                                  );
                                            }

                                            await _postAdminComment(
                                              eventId: eventId!,
                                              comment:
                                                  commentController.text.trim(),
                                              imageUrl: uploadedUrl,
                                            );

                                            commentController.clear();
                                            setSheetState(() {
                                              isPosting = false;
                                              selectedImage = null;
                                            });
                                            refreshNotifier.value++;
                                          }
                                          : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child:
                                        isPosting
                                            ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                            : Icon(
                                              Icons.send_rounded,
                                              size: 18,
                                              color:
                                                  hasContent
                                                      ? Colors.white
                                                      : Colors.grey.shade500,
                                            ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVetCommentBubble(Map<String, dynamic> comment) {
    final vetFirstName = (comment['first_name'] as String?) ?? 'Unknown';
    final vetLastName = (comment['last_name'] as String?) ?? '';
    final fullName = '$vetFirstName $vetLastName'.trim();
    final commentText = (comment['comment'] as String?) ?? '';
    final createdAt = comment['created_at'] as String?;
    final avatarUrl = comment['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.withOpacity(0.15),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child:
                avatarUrl == null
                    ? Text(
                      vetFirstName.isNotEmpty
                          ? vetFirstName[0].toUpperCase()
                          : 'V',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Dr. $fullName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Vet',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (createdAt != null)
                      Text(
                        _formatCommentDate(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Montserrat',
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Text(
                    commentText,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.black87,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCommentBubble(Map<String, dynamic> comment) {
    final commentText = (comment['comment'] as String?) ?? '';
    final createdAt = comment['created_at'] as String?;
    final adminName = (comment['admin_name'] as String?) ?? 'Admin';
    final imageUrl = comment['image_url'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (createdAt != null)
                      Text(
                        _formatCommentDate(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Montserrat',
                          color: Colors.grey.shade500,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.4),
                        ),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      adminName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => _showFullImage(context, imageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              width: 200,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                  ),
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  width: 200,
                                  height: 120,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (commentText.isNotEmpty) const SizedBox(height: 8),
                      ],

                      if (commentText.isNotEmpty)
                        Text(
                          commentText,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.orange.withOpacity(0.15),
            backgroundImage:
                (_cachedProfileImage != null && _cachedProfileImage!.isNotEmpty)
                    ? NetworkImage(_cachedProfileImage!)
                    : null,
            child:
                (_cachedProfileImage == null || _cachedProfileImage!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.orange, size: 18)
                    : null,
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white38,
                              size: 48,
                            ),
                          ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
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
              ],
            ),
          ),
    );
  }

  Future<void> _addEvent() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final venuelocationController = TextEditingController();
    final otherCategoryController = TextEditingController();
    final petsAvailableController = TextEditingController();
    final maxAttendeesController = TextEditingController();
    final notesController = TextEditingController();

    String? category;
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    latlng.LatLng? selectedLatLng;

    int currentStep = 0;
    List<Map<String, dynamic>> searchResults = [];
    List<String> recentSearches = await _getRecentLocationSearches();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bool isMobile = MediaQuery.of(ctx).size.width < 600;
            return AlertDialog(
              backgroundColor: const Color(0xFF3C3B3B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 40,
                vertical: isMobile ? 24 : 60,
              ),
              contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
              title: const Text(
                "Add Event",
                style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
              ),
              content: SizedBox(
                width: isMobile ? MediaQuery.of(ctx).size.width : 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(2, (index) {
                          final isActive = currentStep == index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        isActive
                                            ? const Color(0xFFFFA200)
                                            : Colors.grey.shade700,
                                    boxShadow:
                                        isActive
                                            ? [
                                              BoxShadow(
                                                color: Colors.orange
                                                    .withOpacity(0.4),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                            : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  index == 0 ? 'Details' : 'Date & Location',
                                  style: TextStyle(
                                    color:
                                        isActive
                                            ? Colors.orange
                                            : Colors.white54,
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    fontWeight:
                                        isActive
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 2,
                                color:
                                    currentStep >= 1
                                        ? Colors.orange
                                        : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (currentStep == 0) ...[
                        TextField(
                          controller: titleController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                          decoration: _inputDecoration("Title"),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: category,
                          dropdownColor: const Color(0xFF2A2A2A),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                          decoration: _inputDecoration("Category"),
                          items:
                              [
                                    "Adoption",
                                    "Vaccination",
                                    "Medication",
                                    "Others",
                                  ]
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        style: const TextStyle(
                                          fontFamily: "Montserrat",
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) => setModalState(() => category = val),
                        ),
                        const SizedBox(height: 10),
                        if (category == "Others") ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: otherCategoryController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration("Specify Category"),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: descriptionController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: "Montserrat",
                          ),
                          maxLines: 1,
                          decoration: _inputDecoration("Description"),
                        ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: petsAvailableController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                          decoration: _inputDecoration(
                            "Number of Pets Available for Adoption",
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: maxAttendeesController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                          decoration: _inputDecoration(
                            "Max Attendees (optional)",
                          ),
                        ),
                        const SizedBox(height: 8),

                        const SizedBox(height: 8),
                        TextField(
                          controller: notesController,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                          decoration: _inputDecoration(
                            "Additional Notes / Requirements",
                          ),
                        ),
                      ],
                      if (currentStep == 1) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Date & Time",
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: "Montserrat",
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                             GestureDetector(
                               onTap: () async {
                                 final now = DateTime.now();
                                 final today = DateTime(
                                   now.year,
                                   now.month,
                                   now.day,
                                 );

                                 final picked = await showDatePicker(
                                   context: ctx,
                                   initialDate:
                                       selectedDate ??
                                       today.add(const Duration(days: 1)),
                                   firstDate: today.add(
                                     const Duration(days: 1),
                                   ),
                                   lastDate: DateTime(2100),
                                 );

                                 if (picked != null) {
                                   setModalState(() {
                                     selectedDate = picked;
                                   });
                                 }
                               },
                               child: _dateTimeBox(
                                 icon: Icons.calendar_today,
                                 label:
                                     selectedDate == null
                                         ? "Select Date"
                                         : DateFormat(
                                           'MMM dd, yyyy',
                                         ).format(selectedDate!),
                               ),
                             ),
                             const SizedBox(height: 10),
                             Row(
                               children: [
                                 const Text(
                                   "from",
                                   style: TextStyle(
                                     color: Colors.white70,
                                     fontFamily: 'Montserrat',
                                     fontSize: 12,
                                   ),
                                 ),
                                 const SizedBox(width: 6),
                                 Expanded(
                                   child: GestureDetector(
                                     onTap: () async {
                                       final t = await showTimePicker(
                                         context: ctx,
                                         initialTime: TimeOfDay.now(),
                                       );
                                       if (t != null)
                                         setModalState(() => startTime = t);
                                     },
                                     child: _dateTimeBox(
                                       icon: Icons.access_time,
                                       label:
                                           startTime == null
                                               ? "--:--"
                                               : startTime!.format(ctx),
                                     ),
                                   ),
                                 ),
                                 const SizedBox(width: 10),
                                 const Text(
                                   "to",
                                   style: TextStyle(
                                     color: Colors.white70,
                                     fontFamily: 'Montserrat',
                                     fontSize: 12,
                                   ),
                                 ),
                                 const SizedBox(width: 6),
                                 Expanded(
                                   child: GestureDetector(
                                     onTap: () async {
                                       final t = await showTimePicker(
                                         context: ctx,
                                         initialTime: TimeOfDay.now(),
                                       );
                                       if (t != null)
                                         setModalState(() => endTime = t);
                                     },
                                     child: _dateTimeBox(
                                       icon: Icons.access_time,
                                       label:
                                           endTime == null
                                               ? "--:--"
                                               : endTime!.format(ctx),
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                          ],
                        ),
                        const SizedBox(height: 10),
                         TextField(
                          controller: venuelocationController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                          decoration: _inputDecoration("Search Location"),
                          onChanged: (value) async {
                            if (value.trim().isEmpty) {
                              setModalState(() {
                                searchResults = [];
                                selectedLatLng = null;
                              });
                              return;
                            }
                            if (value.trim().length > 2) {
                              final resList = await _searchLocation(value);
                              setModalState(() {
                                searchResults = resList;
                              });
                            }
                          },
                        ),
                        if (searchResults.isEmpty && recentSearches.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Recent Location Searches:',
                              style: TextStyle(
                                color: Colors.orange,
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children:
                                recentSearches.map((loc) {
                                  return ActionChip(
                                    avatar: const Icon(
                                      Icons.history,
                                      size: 13,
                                      color: Colors.orange,
                                    ),
                                    label: Text(
                                      loc,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF2A2A2A),
                                    onPressed: () async {
                                      venuelocationController.text = loc;
                                      final resList = await _searchLocation(loc);
                                      setModalState(() {
                                        searchResults = resList;
                                        if (resList.isNotEmpty) {
                                          final first = resList.first;
                                          final lat =
                                              double.tryParse(
                                                first["lat"].toString(),
                                              ) ??
                                              0.0;
                                          final lon =
                                              double.tryParse(
                                                first["lon"].toString(),
                                              ) ??
                                              0.0;
                                          selectedLatLng = latlng.LatLng(
                                            lat,
                                            lon,
                                          );
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (searchResults.isNotEmpty)
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final place = searchResults[index];
                                return ListTile(
                                  title: Text(
                                    place["display_name"] ?? "",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: "Montserrat",
                                    ),
                                  ),
                                  onTap: () async {
                                    final lat = double.parse(
                                      place["lat"].toString(),
                                    );
                                    final lon = double.parse(
                                      place["lon"].toString(),
                                    );
                                    final placeName =
                                        place["display_name"] ?? "";
                                    setModalState(() {
                                      venuelocationController.text = placeName;
                                      selectedLatLng = latlng.LatLng(lat, lon);
                                      searchResults = [];
                                    });
                                    await _saveRecentLocationSearch(placeName);
                                    final updatedRecents =
                                        await _getRecentLocationSearches();
                                    setModalState(
                                      () => recentSearches = updatedRecents,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        if (selectedLatLng != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 200,
                            width: 400,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FlutterMap(
                                options: MapOptions(
                                  center: selectedLatLng,
                                  zoom: 15,
                                  interactiveFlags: InteractiveFlag.all,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                    subdomains: ['a', 'b', 'c'],
                                    userAgentPackageName:
                                        'com.example.apawtmentweb_admin',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        width: 40,
                                        height: 40,
                                        point: selectedLatLng!,
                                        builder:
                                            (ctx) => const Icon(
                                              Icons.location_on,
                                              color: Colors.red,
                                              size: 36,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              if (selectedLatLng != null) {
                                final Uri url = Uri.parse(
                                  "https://www.google.com/maps?q=${selectedLatLng!.latitude},${selectedLatLng!.longitude}",
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              }
                            },
                            child: const Text(
                              "Open in Google Maps",
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontFamily: "Montserrat",
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (currentStep == 1)
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setModalState(() => currentStep = 0),
                    child: const Text(
                      "Back",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: "Montserrat",
                      ),
                    ),
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF8C6A2F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (currentStep == 0) {
                      setModalState(() => currentStep = 1);
                    } else {
                      if (titleController.text.trim().isEmpty ||
                          category == null ||
                          descriptionController.text.trim().isEmpty ||
                          selectedDate == null ||
                          startTime == null ||
                          endTime == null ||
                          selectedLatLng == null ||
                          (category == "Others" &&
                              otherCategoryController.text.trim().isEmpty)) {
                        // NEW
                        _showSnackBar(
                          'Please fill out all fields before saving.',
                          Colors.orange,
                        );
                        return;
                      }

                      final String finalCategory =
                          category == "Others"
                              ? otherCategoryController.text.trim()
                              : category!;

                      try {
                        final status = _calculateEventStatus(
                          date: selectedDate!,
                          startTime: startTime!,
                          endTime: endTime!,
                        );

                        final Map<String, dynamic> insertData = {
                          "title": titleController.text.trim(),
                          "category": finalCategory,
                          "description": descriptionController.text.trim(),

                          "date": selectedDate!.toIso8601String().split('T')[0],

                          "start_time": _formatTimeForDatabase(startTime!),
                          "end_time": _formatTimeForDatabase(endTime!),

                          "location": venuelocationController.text.trim(),

                          "latitude": selectedLatLng!.latitude,
                          "longitude": selectedLatLng!.longitude,

                          "notified_on_end": false,
                          "status": status,
                        };

                        final int? petsVal = int.tryParse(
                          petsAvailableController.text.trim(),
                        );
                        if (petsVal != null) {
                          insertData["pets_available"] = petsVal;
                        }

                        final int? maxVal = int.tryParse(
                          maxAttendeesController.text.trim(),
                        );
                        if (maxVal != null) {
                          insertData["max_attendees"] = maxVal;
                        }

                        final notes = notesController.text.trim();
                        if (notes.isNotEmpty) {
                          insertData["notes"] = notes;
                        }

                        debugPrint('📤 Inserting event: $insertData');

                        await supabase.from('events').insert(insertData);

                        await logActivity(
                          action: 'Created Event',
                          description:
                              'Created event "${titleController.text.trim()}"',
                          entityType: 'Event',
                        );

                        await _notifyAllVetsEventAdded(
                          eventTitle: titleController.text.trim(),
                          eventDate: DateFormat(
                            'MMM d, yyyy',
                          ).format(selectedDate!),
                        );

                        if (context.mounted) Navigator.pop(context);

                        // NEW
                        _showSnackBar(
                          'Event added successfully!',
                          Colors.green,
                        );
                      } catch (error, stackTrace) {
                        debugPrint("❌ Error adding event: $error");
                        debugPrint("❌ Stack: $stackTrace");

                        if (context.mounted) {
                          // NEW
                          _showSnackBar('Failed to add event.', Colors.red);
                        }
                      }
                    }
                  },
                  child: Text(
                    currentStep == 0 ? "Next" : "Save",
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _notifyAllVetsAdminComment({
    required int eventId,
    required String eventTitle,
    required String adminName,
    required String comment,
    bool hasImage = false,
  }) async {
    try {
      final vets = await Supabase.instance.client
          .from('veterinarians')
          .select('vet_id')
          .eq('is_active', true);

      // Build a concise preview — truncate long comments
      final preview =
          comment.length > 80 ? '${comment.substring(0, 80)}…' : comment;

      final messageBody =
          hasImage && comment.isEmpty
              ? '$adminName posted an image on "$eventTitle".'
              : hasImage
              ? '$adminName commented on "$eventTitle": "$preview" [+ image]'
              : '$adminName commented on "$eventTitle": "$preview"';

      for (final vet in vets) {
        await Supabase.instance.client.from('vet_notifications').insert({
          'vet_id': vet['vet_id'],
          'title': '💬 New Admin Comment',
          'message': messageBody,
          'is_read': false,
        });
      }
    } catch (e) {
      debugPrint('❌ Error notifying vets of admin comment: $e');
    }
  }

  Future<void> _notifyAllVetsEventAdded({
    required String eventTitle,
    required String eventDate,
  }) async {
    try {
      final vets = await Supabase.instance.client
          .from('veterinarians')
          .select('vet_id')
          .eq('is_active', true);

      for (final vet in vets) {
        await Supabase.instance.client.from('vet_notifications').insert({
          'vet_id': vet['vet_id'],
          'title': '📅 New Event Added',
          'message':
              '"$eventTitle" has been scheduled on $eventDate. Check the events section for details.',
          'is_read': false,
        });
      }
    } catch (e) {
      debugPrint('❌ Error notifying vets of event: $e');
    }
  }

  Widget _dateTimeBox({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white38),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 15),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: "Montserrat",
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateEventStatus({
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) {
    final now = DateTime.now();
    final eventStart = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    final eventEnd = DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );

    if (now.isBefore(eventStart)) return 'Upcoming';
    if (now.isBefore(eventEnd) || now.isAtSameMomentAs(eventEnd))
      return 'Ongoing';
    return 'Ended';
  }

  String _formatTimeForDatabase(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String formatTimeForDatabase(TimeOfDay time) => _formatTimeForDatabase(time);

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: Colors.white70,
      fontFamily: "Montserrat",
      fontSize: 13,
    ),
    filled: true,
    fillColor: Colors.black26,
    isDense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFFFA200)),
    ),
  );

  Future<Map<String, int>> _fetchRsvpCounts(int eventId) async {
    final rows = await supabase
        .from('event_rsvp')
        .select('response')
        .eq('eventid', eventId);
    int going = 0, notGoing = 0;
    for (final r in rows) {
      if (r['response'] == 'Going') going++;
      if (r['response'] == 'Not Going') notGoing++;
    }
    return {'Going': going, 'Not Going': notGoing};
  }

  Future<void> _submitRsvp(int eventId, String response) async {
    await supabase.from('event_rsvp').upsert({
      'eventid': eventId,
      'user_id': 'admin_1',
      'response': response,
    }, onConflict: 'eventid,user_id');
  }

  Future<void> _viewEvent(Map<String, dynamic> event) async {
    final displayName = event['location'] ?? "No location";
    final latitude = event['latitude'] as double?;
    final longitude = event['longitude'] as double?;
    final petsAvailable =
        int.tryParse(event['pets_available']?.toString() ?? '0') ?? 0;
    final maxAttendees = int.tryParse(event['max_attendees']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            event['title'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (latitude != null && longitude != null)
                    Container(
                      height: 250,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            center: latlng.LatLng(latitude, longitude),
                            zoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                              subdomains: ['a', 'b', 'c'],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: latlng.LatLng(latitude, longitude),
                                  builder:
                                      (ctx) => const Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 40,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "⚠️ No coordinates saved for this event.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: "Montserrat",
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildInfoContainer("Category", event['category'] ?? ''),
                  const SizedBox(height: 10),
                  _buildInfoContainer(
                    "Description",
                    event['description'] ?? '',
                  ),

                  if (petsAvailable > 0) ...[
                    const SizedBox(height: 10),
                    _buildInfoContainer(
                      'Pets Available for Adoption',
                      '$petsAvailable',
                    ),
                  ],

                  if ((event['contact_person']?.toString() ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildInfoContainer(
                      "Contact Person",
                      event['contact_person'].toString(),
                    ),
                  ],
                  if ((event['contact_number']?.toString() ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildInfoContainer(
                      "Contact Number",
                      event['contact_number'].toString(),
                    ),
                  ],
                  if ((event['notes']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildInfoContainer(
                      "Notes / Requirements",
                      event['notes'].toString(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildInfoContainer("Date", _formatDate(event['date'])),
                  const SizedBox(height: 10),
                  _buildInfoContainer(
                    "Time",
                    "${_formatTime(event['start_time'])} - ${_formatTime(event['end_time'])}",
                  ),
                  const SizedBox(height: 10),
                  _buildInfoContainer("Location", displayName),
                ],
              ),
            ),
          ),
          actions: [
            if (latitude != null && longitude != null)
              TextButton(
                onPressed: () async {
                  final googleMapsUrl =
                      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
                  if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
                    await launchUrl(
                      Uri.parse(googleMapsUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: const Text(
                  "Open in Google Maps",
                  style: TextStyle(
                    color: Colors.orange,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "Close",
                style: TextStyle(color: Colors.white, fontFamily: "Montserrat"),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEventPetRoster(
    BuildContext context,
    Map<String, dynamic> event,
  ) async {
    final eventId = event['eventid'];
    if (eventId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _EventRosterSheet(
            eventId: eventId,
            eventTitle: event['title'] ?? 'Event',
          ),
    );
  }

  Future<void> _editEvent({
    required int eventid,
    required String title,
    required String category,
    required String description,
    required String date,
    required String startTime,
    required String endTime,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    final titleController = TextEditingController(text: title);
    final descriptionController = TextEditingController(text: description);
    final venuelocationController = TextEditingController(text: location);
    String? currentCategory = category;

    DateTime? selectedDate;
    try {
      selectedDate = DateTime.parse(date);
    } catch (_) {}

    TimeOfDay? start;
    final startDateTime = _parseTime(startTime, date);
    if (startDateTime != null) {
      start = TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute);
    }

    TimeOfDay? end;
    final endDateTime = _parseTime(endTime, date);
    if (endDateTime != null) {
      end = TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute);
    }

    latlng.LatLng? selectedLatLng = latlng.LatLng(latitude, longitude);
    int currentStep = 0;
    List<Map<String, dynamic>> searchResults = [];
    List<String> recentSearches = await _getRecentLocationSearches();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF3C3B3B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 100,
                vertical: 80,
              ),
              contentPadding: const EdgeInsets.all(16),
              title: const Text(
                "Edit Event",
                style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(2, (index) {
                          return Column(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      currentStep == index
                                          ? const Color.fromARGB(
                                            255,
                                            255,
                                            162,
                                            0,
                                          )
                                          : Colors.grey.shade700,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: "Montserrat",
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                              Text(
                                index == 0 ? "Details" : "Date & Location",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: "Montserrat",
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (currentStep == 0) ...[
                        TextField(
                          controller: titleController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                          decoration: _inputDecoration("Title"),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: currentCategory,
                          dropdownColor: const Color(0xFF2A2A2A),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("Category"),
                          items:
                              [
                                    "Adoption",
                                    "Vaccination",
                                    "Medication",
                                    "Others",
                                  ]
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        style: const TextStyle(
                                          fontFamily: "Montserrat",
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) =>
                                  setModalState(() => currentCategory = val),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descriptionController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: "Montserrat",
                          ),
                          maxLines: 1,
                          decoration: _inputDecoration("Description"),
                        ),
                      ],
                      if (currentStep == 1) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Date & Time",
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: "Montserrat",
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                             GestureDetector(
                               onTap: () async {
                                 final picked = await showDatePicker(
                                   context: ctx,
                                   initialDate:
                                       selectedDate ?? DateTime.now(),
                                   firstDate: DateTime(2020),
                                   lastDate: DateTime(2100),
                                 );
                                 if (picked != null)
                                   setModalState(
                                     () => selectedDate = picked,
                                   );
                               },
                               child: _dateTimeBox(
                                 icon: Icons.calendar_today,
                                 label:
                                     selectedDate == null
                                         ? "Select Date"
                                         : DateFormat(
                                           'MMM dd, yyyy',
                                         ).format(selectedDate!),
                               ),
                             ),
                             const SizedBox(height: 10),
                             Row(
                               children: [
                                 const Text(
                                   "from",
                                   style: TextStyle(
                                     color: Colors.white70,
                                     fontFamily: 'Montserrat',
                                     fontSize: 12,
                                   ),
                                 ),
                                 const SizedBox(width: 6),
                                 Expanded(
                                   child: GestureDetector(
                                     onTap: () async {
                                       final t = await showTimePicker(
                                         context: ctx,
                                         initialTime: start ?? TimeOfDay.now(),
                                       );
                                       if (t != null)
                                         setModalState(() => start = t);
                                     },
                                     child: _dateTimeBox(
                                       icon: Icons.access_time,
                                       label:
                                           start == null
                                               ? "--:--"
                                               : start!.format(ctx),
                                     ),
                                   ),
                                 ),
                                 const SizedBox(width: 10),
                                 const Text(
                                   "to",
                                   style: TextStyle(
                                     color: Colors.white70,
                                     fontFamily: 'Montserrat',
                                     fontSize: 12,
                                   ),
                                 ),
                                 const SizedBox(width: 6),
                                 Expanded(
                                   child: GestureDetector(
                                     onTap: () async {
                                       final t = await showTimePicker(
                                         context: ctx,
                                         initialTime: end ?? TimeOfDay.now(),
                                       );
                                       if (t != null)
                                         setModalState(() => end = t);
                                     },
                                     child: _dateTimeBox(
                                       icon: Icons.access_time,
                                       label:
                                           end == null
                                               ? "--:--"
                                               : end!.format(ctx),
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: venuelocationController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                          decoration: _inputDecoration("Search Location"),
                          onChanged: (value) async {
                            setModalState(() => selectedLatLng = null);
                            if (value.trim().length > 2) {
                              final resList = await _searchLocation(value);
                              setModalState(() {
                                searchResults = resList;
                              });
                            } else {
                              setModalState(() => searchResults = []);
                            }
                          },
                        ),
                        if (searchResults.isEmpty && recentSearches.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Recent Location Searches:',
                              style: TextStyle(
                                color: Colors.orange,
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children:
                                recentSearches.map((loc) {
                                  return ActionChip(
                                    avatar: const Icon(
                                      Icons.history,
                                      size: 13,
                                      color: Colors.orange,
                                    ),
                                    label: Text(
                                      loc,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFF2A2A2A),
                                    onPressed: () async {
                                      venuelocationController.text = loc;
                                      final resList = await _searchLocation(loc);
                                      setModalState(() {
                                        searchResults = resList;
                                        if (resList.isNotEmpty) {
                                          final first = resList.first;
                                          final lat =
                                              double.tryParse(
                                                first["lat"].toString(),
                                              ) ??
                                              0.0;
                                          final lon =
                                              double.tryParse(
                                                first["lon"].toString(),
                                              ) ??
                                              0.0;
                                          selectedLatLng = latlng.LatLng(
                                            lat,
                                            lon,
                                          );
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (searchResults.isNotEmpty)
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final place = searchResults[index];
                                return ListTile(
                                  title: Text(
                                    place["display_name"] ?? "",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: "Montserrat",
                                    ),
                                  ),
                                  onTap: () async {
                                    final lat = double.parse(
                                      place["lat"].toString(),
                                    );
                                    final lon = double.parse(
                                      place["lon"].toString(),
                                    );
                                    final placeName =
                                        place["display_name"] ?? "";
                                    setModalState(() {
                                      venuelocationController.text = placeName;
                                      selectedLatLng = latlng.LatLng(lat, lon);
                                      searchResults = [];
                                    });
                                    await _saveRecentLocationSearch(placeName);
                                    final updatedRecents =
                                        await _getRecentLocationSearches();
                                    setModalState(
                                      () => recentSearches = updatedRecents,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        if (selectedLatLng != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 200,
                            width: 400,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FlutterMap(
                                options: MapOptions(
                                  center: selectedLatLng,
                                  zoom: 15,
                                  interactiveFlags: InteractiveFlag.all,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                    subdomains: ['a', 'b', 'c'],
                                    userAgentPackageName:
                                        'com.example.apawtmentweb_admin',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        width: 40,
                                        height: 40,
                                        point: selectedLatLng!,
                                        builder:
                                            (ctx) => const Icon(
                                              Icons.location_on,
                                              color: Colors.red,
                                              size: 36,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final Uri url = Uri.parse(
                                "https://www.google.com/maps?q=${selectedLatLng!.latitude},${selectedLatLng!.longitude}",
                              );
                              if (await canLaunchUrl(url)) {
                                await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            child: const Text(
                              "Open in Google Maps",
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontFamily: "Montserrat",
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (currentStep == 1)
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setModalState(() => currentStep = 0),
                    child: const Text(
                      "Back",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF8C6A2F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (currentStep == 0) {
                      setModalState(() => currentStep = 1);
                    } else {
                      if (titleController.text.trim().isEmpty ||
                          currentCategory == null ||
                          descriptionController.text.trim().isEmpty ||
                          selectedDate == null ||
                          start == null ||
                          end == null ||
                          selectedLatLng == null) {
                        // NEW
                        _showSnackBar(
                          'Please fill out all fields.',
                          Colors.orange,
                        );
                        return;
                      }

                      final startFormatted =
                          "${start!.hour.toString().padLeft(2, '0')}:${start!.minute.toString().padLeft(2, '0')}:00";
                      final endFormatted =
                          "${end!.hour.toString().padLeft(2, '0')}:${end!.minute.toString().padLeft(2, '0')}:00";

                      await Supabase.instance.client
                          .from('events')
                          .update({
                            'title': titleController.text.trim(),
                            'category': currentCategory,
                            'description': descriptionController.text.trim(),
                            'date': DateFormat(
                              'yyyy-MM-dd',
                            ).format(selectedDate!),
                            'start_time': startFormatted,
                            'end_time': endFormatted,
                            'location': venuelocationController.text.trim(),
                            'latitude': selectedLatLng!.latitude,
                            'longitude': selectedLatLng!.longitude,
                          })
                          .eq('eventid', eventid);

                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    }
                  },
                  child: Text(
                    currentStep == 0 ? "Next" : "Save",
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEvent(int eventid) async {
    await supabase.from('event_comments').delete().eq('eventid', eventid);
    await supabase.from('events').delete().eq('eventid', eventid);
    setState(() {});
  }

  Future<void> _confirmDeleteEvent(int eventid, String eventTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              "Confirm Delete",
              style: TextStyle(
                color: Colors.white,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "Are you sure you want to delete the event \"$eventTitle\"?",
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: "Montserrat",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deleteEvent(eventid);
      // NEW
      _showSnackBar('Event deleted successfully.', Colors.green);
    }
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

  Widget _buildInfoContainer(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4A4A4A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : "No data available",
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontFamily: "Montserrat",
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

          Padding(
            padding: EdgeInsets.only(left: isMobile ? 4 : 0),
            child: Text(
              'Events',
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

  Widget _buildEventsContent() {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFF101510),
      drawer: isMobile ? Drawer(width: 200, child: _buildSidebar()) : null,
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 32,
                0,
                isMobile ? 16 : 32,
                32,
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _getEventsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Connection timed out.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      );
                    }

                    final events = snapshot.data ?? [];
                    if (events.isEmpty) {
                      return const Center(
                        child: Text(
                          'No events found',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontFamily: "Montserrat",
                          ),
                        ),
                      );
                    }

                    final now = DateTime.now();
                    final List<Map<String, dynamic>> upcomingEvents = [];
                    final List<Map<String, dynamic>> endedEvents = [];

                    for (final event in events) {
                      try {
                        final eventDate = DateTime.tryParse(
                          event['date'] ?? '',
                        );
                        DateTime? parseTime(String? time, DateTime? date) {
                          if (time == null || date == null) return null;
                          final parts = time.split(':');
                          if (parts.length < 2) return null;
                          final h = int.tryParse(parts[0]);
                          final m = int.tryParse(parts[1]);
                          if (h == null || m == null) return null;
                          return DateTime(
                            date.year,
                            date.month,
                            date.day,
                            h,
                            m,
                          );
                        }

                        final start = parseTime(event['start_time'], eventDate);
                        final end = parseTime(event['end_time'], eventDate);

                        if (end != null && now.isAfter(end)) {
                          endedEvents.add(event);
                          event['status'] = 'Ended';
                        } else if (start != null && now.isBefore(start)) {
                          upcomingEvents.add(event);
                          event['status'] = 'Upcoming';
                        } else {
                          upcomingEvents.add(event);
                          event['status'] = 'Ongoing';
                        }
                      } catch (_) {
                        upcomingEvents.add(event);
                        event['status'] = 'Unknown';
                      }
                    }

                    upcomingEvents.sort((a, b) {
                      final ad =
                          DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
                      final bd =
                          DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
                      return bd.compareTo(ad);
                    });
                    endedEvents.sort((a, b) {
                      final ad =
                          DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
                      final bd =
                          DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
                      return bd.compareTo(ad);
                    });

                    return DefaultTabController(
                      length: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const TabBar(
                              indicatorColor: Colors.orange,
                              labelStyle: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              tabs: [
                                Tab(text: "Upcoming Events"),
                                Tab(text: "Events History"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final controller = DefaultTabController.of(
                                context,
                              );
                              return AnimatedBuilder(
                                animation: controller,
                                builder: (_, __) {
                                  if (controller.index != 0)
                                    return const SizedBox.shrink();
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF8C6A2F,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: _addEvent,
                                      icon: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        "Add Event",
                                        style: TextStyle(
                                          fontFamily: "Montserrat",
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _UpcomingEventsView(
                                  events: upcomingEvents,
                                  now: now,
                                  buildCard:
                                      (event, status) => _buildUpcomingCard(
                                        event,
                                        now,
                                        status,
                                      ),
                                ),
                                _buildHistoryList(endedEvents, now),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> events, DateTime now) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          "No Past Events",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontFamily: "Montserrat",
          ),
        ),
      );
    }

    return _HistoryListView(
      events: events,
      now: now,
      buildCard: (event) => _buildHistoryCard(event, now),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> event, DateTime now) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        children: [
          if ((event['category'] ?? '') == "Adoption")
            _eventBackground("assets/images/adoption.png"),
          if ((event['category'] ?? '') == "Vaccination")
            _eventBackground("assets/images/vaccination.png"),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Text(
                  event['title'] ?? 'Untitled Event',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDate(event['date']),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: _historyEventActions(event)),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showVetComments(context, event),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showEventPetRoster(context, event),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.pets,
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── _historyEventActions: removed "Adoption Claims" button ────────────────
  List<Widget> _historyEventActions(Map<String, dynamic> event) {
    return [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8C6A2F),
        ),
        onPressed: () => _viewEvent(event),
        child: const Text(
          "View Details",
          style: TextStyle(fontFamily: 'Montserrat'),
        ),
      ),
    ];
  }

  Widget _buildUpcomingCard(
    Map<String, dynamic> event,
    DateTime now,
    String status,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        children: [
          if ((event['category'] ?? '') == "Adoption")
            _eventBackground("assets/images/adoption.png"),
          if ((event['category'] ?? '') == "Vaccination")
            _eventBackground("assets/images/vaccination.png"),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Text(
                  event['title'] ?? 'Untitled Event',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDate(event['date']),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, int>>(
                  future: _fetchRsvpCounts(event['eventid'] as int),
                  builder: (context, snap) {
                    final going = snap.data?['Going'] ?? 0;
                    final notGoing = snap.data?['Not Going'] ?? 0;
                    final rsvpButtons = [
                      _rsvpButton(
                        label: '✅ Going',
                        count: going,
                        color: Colors.green,
                        onTap: () async {
                          await _submitRsvp(event['eventid'] as int, 'Going');
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      _rsvpButton(
                        label: '❌ Not Going',
                        count: notGoing,
                        color: Colors.red,
                        onTap: () async {
                          await _submitRsvp(
                            event['eventid'] as int,
                            'Not Going',
                          );
                          setState(() {});
                        },
                      ),
                    ];

                    return isMobile
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ..._eventActions(event),
                              const SizedBox(width: 8),
                              ...rsvpButtons,
                            ],
                          )
                        : Row(
                            children: [
                              ..._eventActions(event),
                              const SizedBox(width: 12),
                              ...rsvpButtons,
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showVetComments(context, event),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showEventPetRoster(context, event),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.pets,
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        status == "Ongoing"
                            ? Colors.green
                            : status == "Ended"
                            ? Colors.red
                            : Colors.blueGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rsvpButton({
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
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
      ),
    );
  }

  Widget _eventBackground(String asset) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    );
  }

  // ── _eventActions: removed "Process Adoption" button ─────────────────────
  List<Widget> _eventActions(Map<String, dynamic> event) {
    return [
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed:
            () => _editEvent(
              eventid: event['eventid'],
              title: event['title'] ?? '',
              category: event['category'] ?? '',
              description: event['description'] ?? '',
              date: event['date'] ?? '',
              startTime: event['start_time'] ?? '',
              endTime: event['end_time'] ?? '',
              location: event['location'] ?? '',
              latitude: (event['latitude'] as num?)?.toDouble() ?? 0,
              longitude: (event['longitude'] as num?)?.toDouble() ?? 0,
            ),
        child: const Text("Edit", style: TextStyle(fontFamily: 'Montserrat')),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8C6A2F),
        ),
        onPressed: () => _viewEvent(event),
        child: const Text(
          "View Details",
          style: TextStyle(fontFamily: 'Montserrat'),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.white),
        onPressed: () => _confirmDeleteEvent(event['eventid'], event['title']),
      ),
    ];
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

  String _formatDate(dynamic dateValue) {
    try {
      final parsed = DateTime.parse(dateValue.toString());
      return DateFormat.yMMMMd('en_US').format(parsed);
    } catch (_) {
      return dateValue.toString();
    }
  }

  String _formatTime(dynamic timeValue) {
    try {
      final parsed = DateFormat("HH:mm:ss").parse(timeValue.toString());
      return DateFormat.jm().format(parsed);
    } catch (_) {
      return timeValue.toString();
    }
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
            child: Column(
              children: [
                _buildTopHeader(isMobile),
                Expanded(child: _buildEventsContent()),
                _buildFooter(context),
              ],
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
}

// ═══════════════════════════════════════════════════════════════════════════
// EventMapPage  (unchanged)
// ═══════════════════════════════════════════════════════════════════════════

class EventMapPage extends StatefulWidget {
  final String displayName;
  final String location;
  final double latitude;
  final double longitude;

  const EventMapPage({
    super.key,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.location,
  });

  @override
  State<EventMapPage> createState() => _EventMapPageState();
}

class _EventMapPageState extends State<EventMapPage> {
  final MapController _mapController = MapController();
  double _currentZoom = 13;

  void _zoomIn() {
    setState(() {
      _currentZoom++;
      _mapController.move(
        latlng.LatLng(widget.latitude, widget.longitude),
        _currentZoom,
      );
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom--;
      _mapController.move(
        latlng.LatLng(widget.latitude, widget.longitude),
        _currentZoom,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.displayName,
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: latlng.LatLng(widget.latitude, widget.longitude),
              zoom: _currentZoom,
              minZoom: 3,
              maxZoom: 18,
              interactiveFlags: InteractiveFlag.all,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: latlng.LatLng(widget.latitude, widget.longitude),
                    width: 80,
                    height: 80,
                    builder:
                        (ctx) => const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 10,
            bottom: 30,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _NotificationBell  (unchanged)
// ═══════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════
// _NotificationPanel  (unchanged)
// ═══════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════
// _HistoryListView  (unchanged)
// ═══════════════════════════════════════════════════════════════════════════

class _HistoryListView extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final DateTime now;
  final Widget Function(Map<String, dynamic> event) buildCard;

  const _HistoryListView({
    required this.events,
    required this.now,
    required this.buildCard,
  });

  @override
  State<_HistoryListView> createState() => _HistoryListViewState();
}

class _HistoryListViewState extends State<_HistoryListView> {
  static const int _pageSize = 10;

  int _visibleCount = _pageSize;

  bool get _hasMore => _visibleCount < widget.events.length;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = widget.events.take(_visibleCount).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...visibleEvents.map(widget.buildCard),

              if (_hasMore) ...[
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange, width: 1.4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text(
                      'See More  '
                      '(${widget.events.length - _visibleCount} remaining)',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    onPressed:
                        () => setState(
                          () =>
                              _visibleCount = (_visibleCount + _pageSize).clamp(
                                0,
                                widget.events.length,
                              ),
                        ),
                  ),
                ),
              ],

              if (!_hasMore && widget.events.length > _pageSize) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white12)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'All ${widget.events.length} events shown',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _HoverSidebarItem  (unchanged)
// ═══════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════
// _UpcomingEventsView  (unchanged)
// ═══════════════════════════════════════════════════════════════════════════

class _UpcomingEventsView extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final DateTime now;
  final Widget Function(Map<String, dynamic> event, String status) buildCard;

  const _UpcomingEventsView({
    required this.events,
    required this.now,
    required this.buildCard,
  });

  @override
  State<_UpcomingEventsView> createState() => _UpcomingEventsViewState();
}

class _UpcomingEventsViewState extends State<_UpcomingEventsView> {
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final withStatus =
        widget.events.map((event) {
          String status = 'Upcoming';
          try {
            final eventDate = DateTime.tryParse(event['date'] ?? '');
            if (eventDate != null) {
              final parts = (event['start_time'] as String?)?.split(':');
              final eParts = (event['end_time'] as String?)?.split(':');
              if (parts != null &&
                  parts.length >= 2 &&
                  eParts != null &&
                  eParts.length >= 2) {
                final start = DateTime(
                  eventDate.year,
                  eventDate.month,
                  eventDate.day,
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                );
                final end = DateTime(
                  eventDate.year,
                  eventDate.month,
                  eventDate.day,
                  int.parse(eParts[0]),
                  int.parse(eParts[1]),
                );
                if (widget.now.isBefore(start)) {
                  status = 'Upcoming';
                } else if (widget.now.isBefore(end)) {
                  status = 'Ongoing';
                } else {
                  status = 'Ended';
                }
              }
            }
          } catch (_) {}
          return {'event': event, 'status': status};
        }).toList();

    final filtered =
        _statusFilter == 'All'
            ? withStatus
            : withStatus.where((e) => e['status'] == _statusFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              const Spacer(),
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    isDense: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    icon: const Icon(
                      Icons.expand_more,
                      color: Colors.white54,
                      size: 16,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(
                        value: 'Upcoming',
                        child: Text('Upcoming'),
                      ),
                      DropdownMenuItem(
                        value: 'Ongoing',
                        child: Text('Ongoing'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _statusFilter = v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child:
              filtered.isEmpty
                  ? Center(
                    child: Text(
                      _statusFilter == 'All'
                          ? 'No Upcoming Events'
                          : 'No $_statusFilter Events',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  )
                  : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: Column(
                          children:
                              filtered
                                  .map(
                                    (e) => widget.buildCard(
                                      e['event'] as Map<String, dynamic>,
                                      e['status'] as String,
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _RosterEntry — simple data holder
// ═══════════════════════════════════════════════════════════════════════════

class _RosterEntry {
  final int petId;
  final String? addedAt;
  final Map<String, dynamic> pet;
  final Map<String, dynamic>? claim; // null = no claim yet

  const _RosterEntry({
    required this.petId,
    required this.addedAt,
    required this.pet,
    required this.claim,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// _EventRosterSheet — now unified: pet list + inline adoption claim processing
// ═══════════════════════════════════════════════════════════════════════════

class _EventRosterSheet extends StatefulWidget {
  final int eventId;
  final String eventTitle;
  const _EventRosterSheet({required this.eventId, required this.eventTitle});

  @override
  State<_EventRosterSheet> createState() => _EventRosterSheetState();
}

class _EventRosterSheetState extends State<_EventRosterSheet> {
  final _supabase = Supabase.instance.client;

  List<_RosterEntry> _entries = [];
  bool _loading = true;
  String _filter = 'All'; // All | Pending | Approved | Rejected | Unclaimed
  String? _updatingCode;

  static const _orange = Color(0xFFFFA200);
  static const _teal = Color(0xFF1DB377);
  static const _cardBg = Color(0xFF2A2A2A);

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1. Roster rows with pet details
      final rosterRows = await _supabase
          .from('event_pet_roster')
          .select(
            'pet_id, added_at, '
            'adoptable_pets(name, type, breed, sex, image_url_1, status)',
          )
          .eq('event_id', widget.eventId)
          .order('added_at', ascending: true);

      final petIds =
          (rosterRows as List).map((r) => r['pet_id'] as int).toList();

      // 2. Adoption claims for those pets (most-recent claim per pet)
      Map<int, Map<String, dynamic>> claimByPetId = {};
      if (petIds.isNotEmpty) {
        final claims = await _supabase
            .from('adoption_event_codes')
            .select()
            .inFilter('pet_id', petIds)
            .order('created_at', ascending: false);

        for (final c in claims as List) {
          final pid = c['pet_id'] as int;
          claimByPetId.putIfAbsent(pid, () => Map<String, dynamic>.from(c));
        }
      }

      final entries =
          (rosterRows as List).map((row) {
            final petId = row['pet_id'] as int;
            return _RosterEntry(
              petId: petId,
              addedAt: row['added_at']?.toString(),
              pet: Map<String, dynamic>.from(
                (row['adoptable_pets'] as Map?) ?? {},
              ),
              claim: claimByPetId[petId],
            );
          }).toList();

      if (mounted)
        setState(() {
          _entries = entries;
          _loading = false;
        });
    } catch (e) {
      debugPrint('Roster load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removePet(int petId) async {
    await _supabase
        .from('event_pet_roster')
        .delete()
        .eq('event_id', widget.eventId)
        .eq('pet_id', petId);
    setState(() => _entries.removeWhere((e) => e.petId == petId));
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

  Future<void> _updateClaimStatus(
    String code,
    int petId,
    String newStatus,
  ) async {
    setState(() => _updatingCode = code);
    try {
      await _supabase
          .from('adoption_event_codes')
          .update({'status': newStatus})
          .eq('code', code);
      await _load();
    } catch (e) {
      debugPrint('Status update error: $e');
      if (mounted) {
        // NEW
        _showSnackBar('Failed to update status.', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _updatingCode = null);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _claimStatus(_RosterEntry e) {
    if (e.claim == null) return 'Unclaimed';
    return (e.claim!['status']?.toString() ?? 'pending');
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return _teal;
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.white38; // unclaimed
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'pending':
        return Icons.hourglass_empty;
      default:
        return Icons.help_outline;
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, yyyy  h:mm a').format(d);
    } catch (_) {
      return raw;
    }
  }

  List<_RosterEntry> get _filtered {
    if (_filter == 'All') return _entries;
    return _entries.where((e) {
      final s = _claimStatus(e);
      return s.toLowerCase() == _filter.toLowerCase();
    }).toList();
  }

  Map<String, int> get _counts => {
    'All': _entries.length,
    'Pending':
        _entries
            .where((e) => _claimStatus(e).toLowerCase() == 'pending')
            .length,
    'Approved':
        _entries
            .where((e) => _claimStatus(e).toLowerCase() == 'approved')
            .length,
    'Rejected':
        _entries
            .where((e) => _claimStatus(e).toLowerCase() == 'rejected')
            .length,
    'Unclaimed': _entries.where((e) => e.claim == null).length,
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.75, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pets, color: _orange, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pet Roster & Adoption Claims',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            widget.eventTitle,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white54,
                        size: 20,
                      ),
                      tooltip: 'Refresh',
                      onPressed: _load,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Filter chips
              if (!_loading) _buildFilterBar(),

              const Divider(color: Colors.white12, height: 1),

              // Body
              Expanded(
                child:
                    _loading
                        ? const Center(
                          child: CircularProgressIndicator(color: _orange),
                        )
                        : _buildBody(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    final counts = _counts;
    final filters = ['All', 'Unclaimed', 'Pending', 'Approved', 'Rejected'];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isActive = _filter == f;
          Color chipColor;
          switch (f) {
            case 'Claimed':
              chipColor = _orange;
              break;
            case 'Unclaimed':
              chipColor = Colors.white38;
              break;
            default:
              chipColor = _teal;
          }
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? chipColor.withOpacity(0.18) : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? chipColor : Colors.white12,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? chipColor : Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? chipColor.withOpacity(0.3)
                              : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${counts[f] ?? 0}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActive ? chipColor : Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, color: Colors.white12, size: 52),
            const SizedBox(height: 12),
            const Text(
              'No pets assigned to this event.',
              style: TextStyle(
                color: Colors.white38,
                fontFamily: 'Montserrat',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Assign pets from the Ready to Adopt section.',
              style: TextStyle(
                color: Colors.white24,
                fontFamily: 'Montserrat',
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No $_filter entries.',
          style: const TextStyle(
            color: Colors.white38,
            fontFamily: 'Montserrat',
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildPetClaimCard(list[i]),
    );
  }

  // ── Per-pet card with inline claim management ─────────────────────────────

  Widget _buildPetClaimCard(_RosterEntry entry) {
    final pet = entry.pet;
    final claim = entry.claim;
    final name = pet['name']?.toString() ?? 'Unknown';
    final breed = pet['breed']?.toString() ?? '—';
    final type = pet['type']?.toString() ?? '—';
    final sex = pet['sex']?.toString() ?? '—';
    final imageUrl = pet['image_url_1']?.toString() ?? '';
    final status = _claimStatus(entry);
    final statusColor = _statusColor(status);
    final isUpdating =
        claim != null && _updatingCode == claim['code']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: claim != null ? statusColor.withOpacity(0.3) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Pet identity row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 52,
                    height: 52,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$type · $breed · $sex',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Remove from roster
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white24,
                    size: 18,
                  ),
                  tooltip: 'Remove from event',
                  onPressed: () => _removePet(entry.petId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // ── Claim details ─────────────────────────────────────────────────
          if (claim != null) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                'ADOPTION CLAIM',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white24,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 20,
                runSpacing: 6,
                children: [
                  _chip(
                    Icons.person_outline,
                    'Adopter',
                    claim['adopter_name']?.toString() ?? '—',
                  ),
                  _chip(
                    Icons.phone_outlined,
                    'Phone',
                    claim['adopter_phone']?.toString() ?? '—',
                  ),
                  _chip(
                    Icons.cake_outlined,
                    'Age',
                    claim['adopter_age']?.toString() ?? '—',
                  ),
                  _chip(
                    Icons.badge_outlined,
                    'ID Type',
                    claim['id_type']?.toString() ?? '—',
                  ),
                  _chip(
                    Icons.location_on_outlined,
                    'Address',
                    claim['adopter_address']?.toString() ?? '—',
                  ),
                  _chip(Icons.tag, 'Code', claim['code']?.toString() ?? '—'),
                  if (claim['created_at'] != null)
                    _chip(
                      Icons.schedule,
                      'Submitted',
                      _fmtDate(claim['created_at']?.toString()),
                    ),
                  if (claim['expires_at'] != null)
                    _chip(
                      Icons.timer_outlined,
                      'Expires',
                      _fmtDate(claim['expires_at']?.toString()),
                    ),
                  if (claim['requires_parent_consent'] == true &&
                      claim['parent_guardian_name'] != null)
                    _chip(
                      Icons.supervisor_account_outlined,
                      'Guardian',
                      claim['parent_guardian_name'].toString(),
                    ),
                ],
              ),
            ),

            // ID image
            if ((claim['id_image_url']?.toString() ?? '').isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: GestureDetector(
                  onTap: () => _viewImage(claim['id_image_url'].toString()),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          claim['id_image_url'].toString(),
                          height: 80,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.white24,
                                  ),
                                ),
                              ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black26,
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Tap to view ID',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Approve / Reject buttons (pending only)
            if (status.toLowerCase() == 'pending')
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            isUpdating
                                ? null
                                : () => _updateClaimStatus(
                                  claim['code'].toString(),
                                  entry.petId,
                                  'rejected',
                                ),
                        icon:
                            isUpdating
                                ? const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.redAccent,
                                  ),
                                )
                                : const Icon(Icons.close, size: 14),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            isUpdating
                                ? null
                                : () => _updateClaimStatus(
                                  claim['code'].toString(),
                                  entry.petId,
                                  'approved',
                                ),
                        icon:
                            isUpdating
                                ? const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.check, size: 14),
                        label: const Text(
                          'Approve',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        isUpdating
                            ? null
                            : () => _updateClaimStatus(
                              claim['code'].toString(),
                              entry.petId,
                              'pending',
                            ),
                    icon: const Icon(Icons.undo, size: 13),
                    label: const Text(
                      'Revert to Pending',
                      style: TextStyle(fontFamily: 'Montserrat', fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white38,
                    ),
                  ),
                ),
              ),
          ] else ...[
            // No claim yet
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white24, size: 13),
                  const SizedBox(width: 6),
                  const Text(
                    'No adoption claim submitted yet',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────

  Widget _chip(IconData icon, String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: Colors.white38),
      const SizedBox(width: 3),
      Text(
        '$label: ',
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 11,
          color: Colors.white38,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 11,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _avatarFallback(String name) => Container(
    color: const Color(0xFF3C3C3E),
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        color: _orange,
        fontWeight: FontWeight.bold,
        fontFamily: 'Montserrat',
        fontSize: 18,
      ),
    ),
  );

  void _viewImage(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white38,
                              size: 48,
                            ),
                          ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
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
              ],
            ),
          ),
    );
  }
}
