import 'dart:ui_web' as ui_web;

import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/sched_config.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

import 'package:apawtmentweb_admin/dashboardpage.dart';
import 'package:apawtmentweb_admin/donationpage.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/main.dart';
import 'package:apawtmentweb_admin/medicationspage.dart';
import 'package:apawtmentweb_admin/notificationpage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';

import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:universal_html/html.dart' as html;

const int _kAdminId = 1;

enum AppointmentType { adoption, donation, all }

class Appointment {
  final int id;
  final DateTime date;
  final String title;
  final String type;
  final String status;
  final String? notes;
  final String? timeStart;
  final String? timeEnd;

  final int? furparentId;
  final String? furparentName;
  final String? furparentContact;
  final String? furparentAvatar;

  final int? reportId;

  const Appointment({
    required this.id,
    required this.date,
    required this.title,
    required this.type,
    required this.status,
    this.notes,
    this.timeStart,
    this.timeEnd,
    this.furparentId,
    this.furparentName,
    this.furparentContact,
    this.furparentAvatar,
    this.reportId,
  });

  factory Appointment.fromMap(Map<String, dynamic> map, String type) {
    final pkKey =
        type == 'adoption'
            ? 'adoptionappointment_id'
            : type == 'rescue'
            ? 'rescueappointment_id'
            : 'donationappointment_id';
    return Appointment(
      id: map[pkKey] as int,
      date: DateTime.parse(map['scheduled_date'].toString()).toLocal(),
      title: (map['title']?.toString() ?? 'Appointment')
          .replaceAll(RegExp(r'\$\w+'), '')
          .trim()
          .replaceAll(RegExp(r'\s{2,}'), ' '),
      type: type,
      status: map['status']?.toString() ?? 'Pending',
      notes: map['notes']?.toString(),
      timeStart: map['time_start']?.toString(),
      timeEnd: map['time_end']?.toString(),
      furparentId: map['furparent_id'] as int?,
      furparentName: map['furparent_name']?.toString(),
      furparentContact: map['furparent_contact']?.toString(),
      furparentAvatar: map['furparent_avatar']?.toString(),
      reportId: map['report_id'] as int?,
    );
  }
}

class AvailableSlot {
  final DateTime date;
  final String timeStart;
  final String timeEnd;
  final String type;
  final int? id;

  AvailableSlot({
    required this.date,
    required this.timeStart,
    required this.timeEnd,
    required this.type,
    this.id,
  });

  factory AvailableSlot.fromMap(Map<String, dynamic> map) {
    return AvailableSlot(
      id: map['slot_id'] as int?,
      date: DateTime.parse(map['date'].toString()),
      timeStart: map['time_start']?.toString() ?? '',
      timeEnd: map['time_end']?.toString() ?? '',
      type: map['type']?.toString() ?? 'adoption',
    );
  }
}

class AppointmentPage extends StatefulWidget {
  const AppointmentPage({super.key});

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  String _selectedItem = 'Appointment';

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  final AppointmentType _filter = AppointmentType.all;

  ScheduleConfig _rescueConfig = ScheduleConfig.defaultFor('rescue');
  List<Appointment> _appointments = [];
  List<AvailableSlot> _availableSlots = [];
  bool _isLoading = true;
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  final Set<String> _expandedSlotTypes = {'adoption', 'donation', 'rescue'};
  bool _slotsAccordionOpen = true;
  bool _appointmentsAccordionOpen = true;
  final Set<String> _expandedStatuses = {'Pending'};
  final supabase = Supabase.instance.client;
  ScheduleConfig _adoptionConfig = ScheduleConfig.defaultFor('adoption');
  ScheduleConfig _donationConfig = ScheduleConfig.defaultFor('donation');

  ScheduleConfig _configFor(String type) {
    if (type == 'adoption') return _adoptionConfig;
    if (type == 'rescue') return _rescueConfig;
    return _donationConfig;
  }

  bool _isDateAllowed(DateTime date) {
    final today = _dateOnly(DateTime.now());
    final picked = _dateOnly(date);
    return !picked.isBefore(today);
  }

  @override
  void initState() {
    super.initState();
    saveLastVisitedPage('Appointment');
    _fetchAll();
    _fetchScheduleConfigs();
    _loadProfileImageForAvatar();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchAppointments(), _fetchAvailableSlots()]);
  }

  Future<void> _fetchScheduleConfigs() async {
    try {
      final res = await supabase.from('schedule_config').select('*');
      for (final row in res as List) {
        final cfg = ScheduleConfig.fromMap(row);
        if (mounted) {
          setState(() {
            if (cfg.type == 'adoption') _adoptionConfig = cfg;
            if (cfg.type == 'donation') _donationConfig = cfg;
            if (cfg.type == 'rescue') _rescueConfig = cfg;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching schedule config: $e');
    }
  }

  static const List<String> _weekdayNames = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
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

  Future<void> _saveScheduleConfig(ScheduleConfig cfg) async {
    final payload = {
      'type': cfg.type,
      'allowed_weekdays': cfg.allowedWeekdays.join(','),
      'default_slots_per_day': cfg.defaultSlotsPerDay,
      'default_time_start': cfg.defaultTimeStart,
      'default_time_end': cfg.defaultTimeEnd,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      if (cfg.id != null) {
        await supabase
            .from('schedule_config')
            .update(payload)
            .eq('config_id', cfg.id!);
      } else {
        await supabase.from('schedule_config').upsert({
          ...payload,
        }, onConflict: 'type');
      }
      await _fetchScheduleConfigs();
    } catch (e) {
      debugPrint('Error saving config: $e');
    }
  }

  Future<void> _updateAppointmentStatus(
    Appointment appt,
    String newStatus,
  ) async {
    if (newStatus == 'Approved') {
      String timeStart;
      String timeEnd;
      if (appt.timeStart != null && appt.timeEnd != null) {
        timeStart = appt.timeStart!;
        timeEnd = appt.timeEnd!;
      } else {
        final h = appt.date.hour.toString().padLeft(2, '0');
        final m = appt.date.minute.toString().padLeft(2, '0');
        timeStart = '$h:$m';

        final endHour = (appt.date.hour + 1) % 24;
        timeEnd = '${endHour.toString().padLeft(2, '0')}:$m';
      }

      if (_hasOverlap(
        date: appt.date,
        timeStart: timeStart,
        timeEnd: timeEnd,
        type: appt.type,
        excludeAppointmentId: appt.id,
      )) {
        if (mounted) {
          _showSnackBar(
            'Cannot approve: this time slot overlaps an existing approved appointment.',
            Colors.red,
          );
        }
        return;
      }
    }

    final table =
        appt.type == 'adoption'
            ? 'adoption_appointments'
            : appt.type == 'rescue'
            ? 'rescue_appointments'
            : 'donation_appointments';
    final pk =
        appt.type == 'adoption'
            ? 'adoptionappointment_id'
            : appt.type == 'rescue'
            ? 'rescueappointment_id'
            : 'donationappointment_id';
    try {
      await supabase.from(table).update({'status': newStatus}).eq(pk, appt.id);

      await supabase.from('user_notifications').insert({
        'title': 'Appointment $newStatus',
        'message':
            'Your ${appt.type} appointment "${appt.title}" has been $newStatus.',
        'type': 'appointment',
        'created_at': DateTime.now().toIso8601String(),
      });

      await _fetchAppointments();
      if (mounted) {
        _showSnackBar(
          'Appointment $newStatus',
          newStatus == 'Approved' ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  Future<void> _rescheduleAppointment(Appointment appt) async {
    DateTime? pickedDate;
    TimeOfDay? pickedTime;

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              return Dialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
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
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.edit_calendar,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Reschedule Appointment',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appt.title,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'New Date',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,

                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              builder:
                                  (_, child) => Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Colors.orange,
                                        onPrimary: Colors.white,
                                        surface: Color(0xFF2A2A2A),
                                      ),
                                    ),
                                    child: child!,
                                  ),
                            );
                            if (d != null) setDialogState(() => pickedDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  pickedDate != null
                                      ? DateFormat(
                                        'MMM d, yyyy',
                                      ).format(pickedDate!)
                                      : 'Tap to select date',
                                  style: TextStyle(
                                    color:
                                        pickedDate != null
                                            ? Colors.white
                                            : Colors.white38,
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'New Time',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.now(),
                              builder:
                                  (_, child) => Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Colors.orange,
                                        onPrimary: Colors.white,
                                        surface: Color(0xFF2A2A2A),
                                      ),
                                    ),
                                    child: child!,
                                  ),
                            );
                            if (t != null) setDialogState(() => pickedTime = t);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  pickedTime != null
                                      ? pickedTime!.format(ctx)
                                      : 'Tap to select time',
                                  style: TextStyle(
                                    color:
                                        pickedTime != null
                                            ? Colors.white
                                            : Colors.white38,
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (pickedDate == null || pickedTime == null)
                                    ? null
                                    : () async {
                                      final newDt = DateTime(
                                        pickedDate!.year,
                                        pickedDate!.month,
                                        pickedDate!.day,
                                        pickedTime!.hour,
                                        pickedTime!.minute,
                                      );
                                      final table =
                                          appt.type == 'adoption'
                                              ? 'adoption_appointments'
                                              : appt.type == 'rescue'
                                              ? 'rescue_appointments'
                                              : 'donation_appointments';
                                      final pk =
                                          appt.type == 'adoption'
                                              ? 'adoptionappointment_id'
                                              : appt.type == 'rescue'
                                              ? 'rescueappointment_id'
                                              : 'donationappointment_id';

                                      try {
                                        final rsStart = pickedTime!.format(ctx);
                                        final rsEndHour =
                                            (pickedTime!.hour + 1) % 24;
                                        final rsEnd =
                                            '${rsEndHour.toString().padLeft(2, '0')}:${pickedTime!.minute.toString().padLeft(2, '0')}';

                                        if (_hasOverlap(
                                          date: newDt,
                                          timeStart: rsStart,
                                          timeEnd: rsEnd,
                                          type: appt.type,
                                          excludeAppointmentId: appt.id,
                                        )) {
                                          if (mounted) {
                                            _showSnackBar(
                                              'Cannot reschedule: this time overlaps an existing approved appointment.',
                                              Colors.red,
                                            );
                                          }
                                          return;
                                        }

                                        await supabase
                                            .from(table)
                                            .update({
                                              'scheduled_date':
                                                  newDt.toIso8601String(),
                                              'time_start': pickedTime!.format(
                                                ctx,
                                              ),
                                              'status': 'Approved',
                                            })
                                            .eq(pk, appt.id);

                                        await supabase
                                            .from('user_notifications')
                                            .insert({
                                              'title':
                                                  'Appointment Rescheduled',
                                              'message':
                                                  'Your ${appt.type} appointment "${appt.title}" has been rescheduled to ${DateFormat('MMM d, yyyy').format(newDt)} at ${pickedTime!.format(ctx)}.',
                                              'type': 'appointment',
                                              'created_at':
                                                  DateTime.now()
                                                      .toIso8601String(),
                                            });

                                        await _fetchAppointments();
                                        if (mounted) Navigator.pop(ctx);
                                        if (mounted) {
                                          _showSnackBar(
                                            'Appointment rescheduled & approved.',
                                            Colors.green,
                                          );
                                        }
                                      } catch (e) {
                                        debugPrint('Reschedule error: $e');
                                      }
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              disabledBackgroundColor: Colors.white12,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Confirm Reschedule',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Map<String, List<Appointment>> _groupedByStatus(List<Appointment> appts) {
    final definedOrder = ['Pending', 'Approved', 'Declined', 'Rejected', 'Cancelled'];
    final knownLower = definedOrder.map((s) => s.toLowerCase()).toSet();
    final extraStatuses = appts
        .map((a) => a.status)
        .where((s) => !knownLower.contains(s.toLowerCase()))
        .toSet()
        .toList();
    final order = [...definedOrder, ...extraStatuses];
    final grouped = <String, List<Appointment>>{};
    for (final status in order) {
      final group =
          appts
              .where((a) => a.status.toLowerCase() == status.toLowerCase())
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      if (group.isNotEmpty) grouped[status] = group;
    }
    return grouped;
  }

  Widget _buildGroupedAppointments(List<Appointment> appts) {
    final grouped = _groupedByStatus(appts);
    if (grouped.isEmpty) return const SizedBox.shrink();

    final statusColors = {
      'Pending': Colors.amber,
      'Approved': Colors.green,
      'Declined': Colors.red,
      'Rejected': Colors.red,
      'Cancelled': Colors.red,
    };

    return Column(
      children:
          grouped.entries.map((entry) {
            final status = entry.key;
            final list = entry.value;
            final color = statusColors[status] ?? Colors.white54;
            final isExpanded = _expandedStatuses.contains(status);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap:
                        () => setState(() {
                          if (isExpanded) {
                            _expandedStatuses.remove(status);
                          } else {
                            _expandedStatuses.add(status);
                          }
                        }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: color,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${list.length} appointment${list.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: color,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      itemCount: list.length,
                      separatorBuilder:
                          (_, __) => const Divider(color: Colors.white10),
                      itemBuilder: (_, i) => _buildAppointmentTile(list[i]),
                    ),
                ],
              ),
            );
          }).toList(),
    );
  }

  bool _hasOverlap({
    required DateTime date,
    required String timeStart,
    required String timeEnd,
    required String type,
    int? excludeSlotId,
    int? excludeAppointmentId,
  }) {
    final newS = _timeStringToMinutes(timeStart);
    final newE = _timeStringToMinutes(timeEnd);

    for (final s in _slotsForDay(date)) {
      if (s.type != type) continue;
      if (excludeSlotId != null && s.id == excludeSlotId) continue;
      final existS = _timeStringToMinutes(s.timeStart);
      final existE = _timeStringToMinutes(s.timeEnd);
      if (newS < existE && newE > existS) return true;
    }

    for (final appt in _appointmentsForDay(date)) {
      if (appt.type != type) continue;
      if (excludeAppointmentId != null && appt.id == excludeAppointmentId)
        continue;

      final s = appt.status.toLowerCase();
      if (s == 'cancelled' || s == 'rejected' || s == 'declined') continue;

      int apptS;
      int apptE;
      if (appt.timeStart != null && appt.timeEnd != null) {
        apptS = _timeStringToMinutes(appt.timeStart!);
        apptE = _timeStringToMinutes(appt.timeEnd!);
      } else {
        apptS = appt.date.hour * 60 + appt.date.minute;
        apptE = apptS + 60;
      }
      if (newS < apptE && newE > apptS) return true;
    }

    return false;
  }

  void _showScheduleConfigDialog() {
    var adoptionDays = List<int>.from(_adoptionConfig.allowedWeekdays);
    var donationDays = List<int>.from(_donationConfig.allowedWeekdays);
    TimeOfDay? adoptStart = _parseTimeOfDay(_adoptionConfig.defaultTimeStart);
    TimeOfDay? adoptEnd = _parseTimeOfDay(_adoptionConfig.defaultTimeEnd);
    TimeOfDay? donStart = _parseTimeOfDay(_donationConfig.defaultTimeStart);
    TimeOfDay? donEnd = _parseTimeOfDay(_donationConfig.defaultTimeEnd);
    bool isSaving = false;
    var rescueDays = List<int>.from(_rescueConfig.allowedWeekdays);
    TimeOfDay? rescueStart = _parseTimeOfDay(_rescueConfig.defaultTimeStart);
    TimeOfDay? rescueEnd = _parseTimeOfDay(_rescueConfig.defaultTimeEnd);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDs) {
              Widget dayToggleRow(
                List<int> selected,
                List<int> otherSelected,
                Color color,
                void Function(List<int>) onChanged,
              ) {
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final isSelected = selected.contains(day);
                    final isOther = otherSelected.contains(day);
                    return GestureDetector(
                      onTap: () {
                        setDs(() {
                          final updated = List<int>.from(selected);
                          if (isSelected) {
                            updated.remove(day);
                          } else {
                            updated.add(day);
                          }
                          updated.sort();
                          onChanged(updated);
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? color.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isSelected
                                    ? color
                                    : isOther
                                    ? Colors.white24
                                    : Colors.white12,
                            width: isSelected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                _weekdayNames[day],
                                style: TextStyle(
                                  color: isSelected ? color : Colors.white38,
                                  fontFamily: 'Montserrat',
                                  fontSize: 11,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isOther && !isSelected)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              }

              Future<void> pickTime(
                bool isAdoption,
                bool isStart, {
                bool isRescue = false,
              }) async {
                final initial =
                    isRescue
                        ? (isStart ? rescueStart : rescueEnd)
                        : isAdoption
                        ? (isStart ? adoptStart : adoptEnd)
                        : (isStart ? donStart : donEnd);
                final t = await showTimePicker(
                  context: ctx,
                  initialTime: initial ?? TimeOfDay.now(),
                  builder:
                      (_, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.orange,
                            onPrimary: Colors.white,
                            surface: Color(0xFF2A2A2A),
                          ),
                        ),
                        child: child!,
                      ),
                );
                if (t != null) {
                  setDs(() {
                    if (isRescue) {
                      if (isStart) {
                        rescueStart = t;
                      } else {
                        rescueEnd = t;
                      }
                    } else if (isAdoption) {
                      if (isStart) {
                        adoptStart = t;
                      } else {
                        adoptEnd = t;
                      }
                    } else {
                      if (isStart) {
                        donStart = t;
                      } else {
                        donEnd = t;
                      }
                    }
                  });
                }
              }

              final allSelected = [
                ...adoptionDays,
                ...donationDays,
                ...rescueDays,
              ];
              final sharedDays =
                  allSelected
                      .where((d) => allSelected.where((x) => x == d).length > 1)
                      .toSet()
                      .toList()
                    ..sort();
              return Dialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 540,
                    maxHeight: 720,
                  ),
                  child: SingleChildScrollView(
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
                                color: Colors.purple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.tune,
                                color: Colors.purple,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Schedule Configuration',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                  Text(
                                    'Set allowed days & default times',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (sharedDays.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Both types share: ${sharedDays.map((d) => _weekdayNames[d]).join(', ')}. '
                                    'Both will appear on those days.',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontFamily: 'Montserrat',
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _configSectionHeader(
                          Icons.pets,
                          'Adoption Days',
                          Colors.blue,
                        ),
                        const SizedBox(height: 10),
                        dayToggleRow(
                          adoptionDays,
                          [...donationDays, ...rescueDays],
                          Colors.blue,
                          (updated) {
                            adoptionDays = updated;
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Default time window',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _timePickerField(
                                label: 'Start',
                                value: adoptStart?.format(ctx) ?? '–',
                                icon: Icons.access_time,
                                onTap: () => pickTime(true, true),
                                hasValue: adoptStart != null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _timePickerField(
                                label: 'End',
                                value: adoptEnd?.format(ctx) ?? '–',
                                icon: Icons.access_time_filled,
                                onTap: () => pickTime(true, false),
                                hasValue: adoptEnd != null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 16),
                        _configSectionHeader(
                          Icons.volunteer_activism,
                          'Donation Days',
                          Colors.green,
                        ),
                        const SizedBox(height: 10),
                        dayToggleRow(
                          donationDays,
                          [...adoptionDays, ...rescueDays],
                          Colors.green,
                          (updated) {
                            donationDays = updated;
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Default time window',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _timePickerField(
                                label: 'Start',
                                value: donStart?.format(ctx) ?? '–',
                                icon: Icons.access_time,
                                onTap: () => pickTime(false, true),
                                hasValue: donStart != null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _timePickerField(
                                label: 'End',
                                value: donEnd?.format(ctx) ?? '–',
                                icon: Icons.access_time_filled,
                                onTap: () => pickTime(false, false),
                                hasValue: donEnd != null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 16),
                        _configSectionHeader(
                          Icons.local_hospital,
                          'Rescue Days',
                          Colors.redAccent,
                        ),
                        const SizedBox(height: 10),
                        dayToggleRow(
                          rescueDays,
                          [...adoptionDays, ...donationDays],
                          Colors.redAccent,
                          (updated) {
                            rescueDays = updated;
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Default time window',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _timePickerField(
                                label: 'Start',
                                value: rescueStart?.format(ctx) ?? '–',
                                icon: Icons.access_time,
                                onTap:
                                    () => pickTime(false, true, isRescue: true),
                                hasValue: rescueStart != null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _timePickerField(
                                label: 'End',
                                value: rescueEnd?.format(ctx) ?? '–',
                                icon: Icons.access_time_filled,
                                onTap:
                                    () =>
                                        pickTime(false, false, isRescue: true),
                                hasValue: rescueEnd != null,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _legendDot(Colors.blue),
                            const SizedBox(width: 4),
                            const Text(
                              'Adoption  ',
                              style: TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                              ),
                            ),
                            _legendDot(Colors.green),
                            const SizedBox(width: 4),
                            const Text(
                              'Donation  ',
                              style: TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                              ),
                            ),
                            _legendDot(Colors.redAccent),
                            const SizedBox(width: 4),
                            const Text(
                              'Rescue  ',
                              style: TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                              ),
                            ),
                            _legendDot(Colors.orange),
                            const SizedBox(width: 4),
                            const Text(
                              'Shared day',
                              style: TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
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
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed:
                                    isSaving
                                        ? null
                                        : () async {
                                          setDs(() => isSaving = true);

                                          final newAdopt = ScheduleConfig(
                                            id: _adoptionConfig.id,
                                            type: 'adoption',
                                            allowedWeekdays: adoptionDays,
                                            defaultSlotsPerDay:
                                                _adoptionConfig
                                                    .defaultSlotsPerDay,
                                            defaultTimeStart:
                                                adoptStart?.format(ctx) ??
                                                _adoptionConfig
                                                    .defaultTimeStart,
                                            defaultTimeEnd:
                                                adoptEnd?.format(ctx) ??
                                                _adoptionConfig.defaultTimeEnd,
                                          );
                                          final newDon = ScheduleConfig(
                                            id: _donationConfig.id,
                                            type: 'donation',
                                            allowedWeekdays: donationDays,
                                            defaultSlotsPerDay:
                                                _donationConfig
                                                    .defaultSlotsPerDay,
                                            defaultTimeStart:
                                                donStart?.format(ctx) ??
                                                _donationConfig
                                                    .defaultTimeStart,
                                            defaultTimeEnd:
                                                donEnd?.format(ctx) ??
                                                _donationConfig.defaultTimeEnd,
                                          );
                                          final newRescue = ScheduleConfig(
                                            id: _rescueConfig.id,
                                            type: 'rescue',
                                            allowedWeekdays: rescueDays,
                                            defaultSlotsPerDay:
                                                _rescueConfig
                                                    .defaultSlotsPerDay,
                                            defaultTimeStart:
                                                rescueStart?.format(ctx) ??
                                                _rescueConfig.defaultTimeStart,
                                            defaultTimeEnd:
                                                rescueEnd?.format(ctx) ??
                                                _rescueConfig.defaultTimeEnd,
                                          );

                                          if (_timeStringToMinutes(newAdopt.defaultTimeEnd) <=
                                              _timeStringToMinutes(newAdopt.defaultTimeStart)) {
                                            _showSnackBar(
                                              'Adoption end time must be after start time.',
                                              Colors.red,
                                            );
                                            setDs(() => isSaving = false);
                                            return;
                                          }
                                          if (_timeStringToMinutes(newDon.defaultTimeEnd) <=
                                              _timeStringToMinutes(newDon.defaultTimeStart)) {
                                            _showSnackBar(
                                              'Donation end time must be after start time.',
                                              Colors.red,
                                            );
                                            setDs(() => isSaving = false);
                                            return;
                                          }
                                          if (_timeStringToMinutes(newRescue.defaultTimeEnd) <=
                                              _timeStringToMinutes(newRescue.defaultTimeStart)) {
                                            _showSnackBar(
                                              'Rescue end time must be after start time.',
                                              Colors.red,
                                            );
                                            setDs(() => isSaving = false);
                                            return;
                                          }

                                          await _saveScheduleConfig(newRescue);
                                          await _saveScheduleConfig(newAdopt);
                                          await _saveScheduleConfig(newDon);

                                          if (mounted) Navigator.pop(ctx);
                                          if (mounted) {
                                            _showSnackBar(
                                              'Schedule configuration saved.',
                                              Colors.green,
                                            );
                                          }
                                        },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  disabledBackgroundColor: Colors.white12,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child:
                                    isSaving
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text(
                                          'Save Configuration',
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
            },
          ),
    );
  }

  Widget _configSectionHeader(IconData icon, String label, Color color) {
    return Row(
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
          label,
          style: TextStyle(
            color: color,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Future<void> _seedDefaultSlotsIfNeeded(DateTime date) async {
    if (!_isDateAllowed(date)) return;

    final existingSlots = _slotsForDay(date);
    final existingTypes = existingSlots.map((s) => s.type).toSet();

    for (final type in ['adoption', 'donation', 'rescue']) {
      if (existingTypes.contains(type)) continue;
      if (!_isDayAllowedForType(date, type)) continue;

      final cfg = _configFor(type);
      await supabase.from('available_slots').insert({
        'date': DateFormat('yyyy-MM-dd').format(date),
        'time_start': cfg.defaultTimeStart,
        'time_end': cfg.defaultTimeEnd,
        'type': type,
        'admin_id': _kAdminId,
      });
    }
    await _fetchAvailableSlots();
  }

  void _showAppointmentDetailDialog(Appointment appt) {
    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isAdoption = appt.type == 'adoption';
              final isRescue = appt.type == 'rescue';
              final tc =
                  isAdoption
                      ? Colors.blue
                      : isRescue
                      ? Colors.redAccent
                      : Colors.green;

              Color statusColor;
              switch (appt.status.toLowerCase()) {
                case 'approved':
                case 'completed':
                  statusColor = Colors.green;
                  break;
                case 'declined':
                case 'rejected':
                case 'cancelled':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.amber;
              }

              return Dialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                    maxHeight: 700,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: tc.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isAdoption
                                    ? Icons.pets
                                    : isRescue
                                    ? Icons.local_hospital
                                    : Icons.volunteer_activism,
                                color: tc,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appt.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tc.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          appt.type.toUpperCase(),
                                          style: TextStyle(
                                            color: tc,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Montserrat',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          appt.status.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Montserrat',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 16),
                        _detailSection(
                          'Appointment Details',
                          Icons.event,
                          Colors.orange,
                          [
                            _detailRow(
                              Icons.calendar_today,
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(appt.date),
                            ),
                            _detailRow(
                              Icons.access_time,
                              DateFormat('h:mm a').format(appt.date),
                            ),
                            if (appt.timeStart != null && appt.timeEnd != null)
                              _detailRow(
                                Icons.timelapse,
                                '${appt.timeStart} – ${appt.timeEnd}',
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _detailSection(
                          'Fur Parent',
                          Icons.person,
                          Colors.purple,
                          [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white12,
                                  backgroundImage:
                                      appt.furparentAvatar != null &&
                                              appt.furparentAvatar!.isNotEmpty
                                          ? NetworkImage(appt.furparentAvatar!)
                                          : null,
                                  child:
                                      appt.furparentAvatar == null ||
                                              appt.furparentAvatar!.isEmpty
                                          ? const Icon(
                                            Icons.person,
                                            color: Colors.white54,
                                            size: 22,
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        appt.furparentName ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (appt.furparentContact != null)
                                        Text(
                                          appt.furparentContact!,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontFamily: 'Montserrat',
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (appt.reportId != null)
                          _ReportInfoSection(
                            reportId: appt.reportId!,
                            supabase: supabase,
                            furparentId: appt.furparentId,
                          ),
                        if (appt.notes != null && appt.notes!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.sticky_note_2_rounded,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'NOTES',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        appt.notes!,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontFamily: 'Montserrat',
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (appt.status == 'Pending') ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _updateAppointmentStatus(
                                      appt,
                                      'Approved',
                                    );
                                  },
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _updateAppointmentStatus(
                                      appt,
                                      'Declined',
                                    );
                                  },
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text(
                                    'Decline',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _rescheduleAppointment(appt);
                            },
                            icon: const Icon(
                              Icons.edit_calendar,
                              size: 16,
                              color: Colors.orange,
                            ),
                            label: const Text(
                              'Reschedule',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
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
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _detailSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isDayAllowedForType(DateTime date, String type) {
    final cfg = _configFor(type);
    return cfg.allowedWeekdays.contains(date.weekday);
  }

  bool _isSpecialDay(DateTime date, String type) {
    if (_isDayAllowedForType(date, type)) return false;
    return _slotsForDay(date).any((s) => s.type == type);
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final List<Appointment> all = [];

      final adoptionRes = await supabase
          .from('adoption_appointments')
          .select('*')
          .order('scheduled_date', ascending: true);
      for (final row in adoptionRes) {
        try {
          all.add(Appointment.fromMap(row, 'adoption'));
        } catch (e) {
          debugPrint('Error parsing adoption row: $e');
        }
      }

      final donationRes = await supabase
          .from('donation_appointments')
          .select('*')
          .order('scheduled_date', ascending: true);
      for (final row in donationRes) {
        try {
          all.add(Appointment.fromMap(row, 'donation'));
        } catch (e) {
          debugPrint('Error parsing donation row: $e');
        }
      }

      final rescueRes = await supabase
          .from('rescue_appointments')
          .select('*')
          .order('scheduled_date', ascending: true);
      for (final row in rescueRes) {
        try {
          all.add(Appointment.fromMap(row, 'rescue'));
        } catch (e) {
          debugPrint('Error parsing rescue row: $e');
        }
      }

      if (mounted) {
        setState(() {
          _appointments = all;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAvailableSlots() async {
    try {
      final res = await supabase
          .from('available_slots')
          .select('*')
          .order('date', ascending: true);
      if (mounted) {
        setState(() {
          _availableSlots =
              (res as List).map((r) => AvailableSlot.fromMap(r)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching slots: $e');
    }
  }

  Widget _timePickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool hasValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontFamily: 'Montserrat',
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.orange, size: 16),
                const SizedBox(width: 7),
                Text(
                  value,
                  style: TextStyle(
                    color: hasValue ? Colors.white : Colors.white38,
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TimeOfDay? _parseTimeOfDay(String? t) {
    if (t == null || t.isEmpty) return null;
    try {
      final clean = t.trim().toUpperCase();
      final isPm = clean.endsWith('PM');
      final timePart = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = timePart.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  Future<void> _editAvailableSlot(AvailableSlot slot) async {
    String selectedType = slot.type;
    TimeOfDay? pickedStart = _parseTimeOfDay(slot.timeStart);
    TimeOfDay? pickedEnd = _parseTimeOfDay(slot.timeEnd);

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDs) {
              Future<void> pickTime(bool isStart) async {
                final t = await showTimePicker(
                  context: ctx,
                  initialTime:
                      isStart
                          ? (pickedStart ?? TimeOfDay.now())
                          : (pickedEnd ?? TimeOfDay.now()),
                  builder:
                      (_, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.orange,
                            onPrimary: Colors.white,
                            surface: Color(0xFF2A2A2A),
                          ),
                        ),
                        child: child!,
                      ),
                );
                if (t != null) {
                  setDs(() => isStart ? pickedStart = t : pickedEnd = t);
                }
              }

              final screenWidth = MediaQuery.of(ctx).size.width;
              final isMobileEdit = screenWidth < 600;
              return Dialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                insetPadding: EdgeInsets.symmetric(
                  horizontal: isMobileEdit ? 12 : 40,
                  vertical: isMobileEdit ? 20 : 40,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobileEdit ? 16 : 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.edit_calendar,
                                color: Colors.orange,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Edit Slot',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Type',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              ['adoption', 'donation', 'rescue'].map((t) {
                                final active = selectedType == t;
                                final tc =
                                    t == 'adoption'
                                        ? Colors.blue
                                        : t == 'rescue'
                                        ? Colors.redAccent
                                        : Colors.green;
                                return GestureDetector(
                                  onTap: () => setDs(() => selectedType = t),
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                      milliseconds: 160,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          active
                                              ? tc.withOpacity(0.2)
                                              : const Color(0xFF2A2A2A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: active ? tc : Colors.white12,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          t == 'adoption'
                                              ? Icons.pets
                                              : t == 'rescue'
                                              ? Icons.local_hospital
                                              : Icons.volunteer_activism,
                                          color: active ? tc : Colors.white38,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          t[0].toUpperCase() + t.substring(1),
                                          style: TextStyle(
                                            color:
                                                active ? tc : Colors.white54,
                                            fontFamily: 'Montserrat',
                                            fontWeight:
                                                active
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _timePickerField(
                                label: 'Start Time',
                                value: pickedStart?.format(ctx) ?? 'Tap to set',
                                icon: Icons.access_time,
                                onTap: () => pickTime(true),
                                hasValue: pickedStart != null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _timePickerField(
                                label: 'End Time',
                                value: pickedEnd?.format(ctx) ?? 'Tap to set',
                                icon: Icons.access_time_filled,
                                onTap: () => pickTime(false),
                                hasValue: pickedEnd != null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (pickedStart == null || pickedEnd == null)
                                    ? null
                                    : () async {
                                      final newStart = pickedStart!.format(ctx);
                                      final newEnd = pickedEnd!.format(ctx);

                                      if (_timeStringToMinutes(newEnd) <=
                                          _timeStringToMinutes(newStart)) {
                                        _showSnackBar(
                                          'End time must be after start time.',
                                          Colors.red,
                                        );
                                        return;
                                      }

                                      if (_hasOverlap(
                                        date: slot.date,
                                        timeStart: newStart,
                                        timeEnd: newEnd,
                                        type: selectedType,
                                        excludeSlotId: slot.id,
                                      )) {
                                        _showSnackBar(
                                          'This time overlaps an existing slot.',
                                          Colors.red,
                                        );
                                        return;
                                      }

                                      try {
                                        await supabase
                                            .from('available_slots')
                                            .update({
                                              'time_start': newStart,
                                              'time_end': newEnd,
                                              'type': selectedType,
                                            })
                                            .eq('slot_id', slot.id!);
                                        await _fetchAvailableSlots();
                                        if (mounted) Navigator.pop(ctx);
                                        if (mounted) {
                                          _showSnackBar(
                                            'Slot updated.',
                                            Colors.green,
                                          );
                                        }
                                      } catch (e) {
                                        debugPrint('Edit slot error: $e');
                                      }
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              disabledBackgroundColor: Colors.white12,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Future<bool> _saveAvailableSlot(AvailableSlot slot) async {
    if (_timeStringToMinutes(slot.timeEnd) <=
        _timeStringToMinutes(slot.timeStart)) {
      if (mounted) {
        _showSnackBar('End time must be after start time.', Colors.red);
      }
      return false;
    }

    if (_hasOverlap(
      date: slot.date,
      timeStart: slot.timeStart,
      timeEnd: slot.timeEnd,
      type: slot.type,
    )) {
      if (mounted) {
        _showSnackBar('This time overlaps an existing slot.', Colors.red);
      }
      return false;
    }

    try {
      await supabase.from('available_slots').insert({
        'date': DateFormat('yyyy-MM-dd').format(slot.date),
        'time_start': slot.timeStart,
        'time_end': slot.timeEnd,
        'type': slot.type,
        'admin_id': _kAdminId,
      });
      await logActivity(
        action: 'Added Appointment Slot',
        description:
            'Added ${slot.type} slot on ${DateFormat('yyyy-MM-dd').format(slot.date)} (${slot.timeStart} - ${slot.timeEnd})',
        entityType: 'Appointment Slot',
      );
      await _fetchAvailableSlots();
      return true;
    } catch (e) {
      debugPrint('Error saving slot: $e');
      return false;
    }
  }

  Future<void> _deleteAvailableSlot(int id) async {
    try {
      await supabase.from('available_slots').delete().eq('slot_id', id);
      await _fetchAvailableSlots();
    } catch (e) {
      debugPrint('Error deleting slot: $e');
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
              .eq('admin_id', _kAdminId)
              .maybeSingle();
      if (response == null) {
        if (mounted) setState(() => _isLoadingAvatar = false);
        return;
      }
      final profileData = response['admin_profile']?.toString();
      String? publicUrl;
      if (profileData != null && profileData.isNotEmpty) {
        publicUrl =
            (profileData.startsWith('http://') ||
                    profileData.startsWith('https://'))
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
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  List<Appointment> get _filteredAppointments =>
      _appointments.where((a) {
        if (_filter == AppointmentType.adoption) return a.type == 'adoption';
        if (_filter == AppointmentType.donation) return a.type == 'donation';
        return true;
      }).toList();

  List<Appointment> _appointmentsForDay(DateTime day) =>
      _filteredAppointments
          .where(
            (a) =>
                a.date.year == day.year &&
                a.date.month == day.month &&
                a.date.day == day.day,
          )
          .toList();

  List<AvailableSlot> _slotsForDay(DateTime day) =>
      _availableSlots
          .where(
            (s) =>
                s.date.year == day.year &&
                s.date.month == day.month &&
                s.date.day == day.day,
          )
          .toList();

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  int _timeStringToMinutes(String t) {
    final clean = t.trim().toUpperCase();
    final isPm = clean.endsWith('PM');
    final timePart = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = timePart.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    return hour * 60 + minute;
  }

  List<String> _allowedTypesForDay(DateTime date) {
    final result = <String>[];
    for (final type in ['adoption', 'donation', 'rescue']) {
      if (_isDayAllowedForType(date, type) || _isSpecialDay(date, type)) {
        result.add(type);
      }
    }
    return result;
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

  void _showAddAppointmentDialog({DateTime? preselectedDate}) {
    if (preselectedDate != null && !_isDateAllowed(preselectedDate)) {
      _showSnackBar('Cannot add slots for past dates.', Colors.red);
      return;
    }

    DateTime? pickedDate = preselectedDate;
    TimeOfDay? pickedTimeStart;
    TimeOfDay? pickedTimeEnd;
    String selectedType = 'adoption';
    final List<Map<String, dynamic>> entries = [];
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              Future<void> pickDate() async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: pickedDate ?? DateTime.now(),

                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  builder:
                      (_, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.orange,
                            onPrimary: Colors.white,
                            surface: Color(0xFF2A2A2A),
                          ),
                        ),
                        child: child!,
                      ),
                );
                if (d != null) setDialogState(() => pickedDate = d);
              }

              Future<void> pickTime(bool isStart) async {
                final t = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay.now(),
                  builder:
                      (_, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.orange,
                            onPrimary: Colors.white,
                            surface: Color(0xFF2A2A2A),
                          ),
                        ),
                        child: child!,
                      ),
                );
                if (t != null) {
                  setDialogState(() {
                    if (isStart) {
                      pickedTimeStart = t;
                    } else {
                      pickedTimeEnd = t;
                    }
                  });
                }
              }

              void addEntry() {
                if (pickedDate == null ||
                    pickedTimeStart == null ||
                    pickedTimeEnd == null) {
                  return;
                }
                final tsStr = pickedTimeStart!.format(ctx);
                final teStr = pickedTimeEnd!.format(ctx);

                if (_timeStringToMinutes(teStr) <=
                    _timeStringToMinutes(tsStr)) {
                  _showSnackBar(
                    'End time must be after start time.',
                    Colors.red,
                  );
                  return;
                }

                if (_hasOverlap(
                  date: pickedDate!,
                  timeStart: tsStr,
                  timeEnd: teStr,
                  type: selectedType,
                )) {
                  _showSnackBar(
                    'This time ($tsStr – $teStr) overlaps an existing $selectedType slot or approved appointment on that day.',
                    Colors.red,
                  );
                  return;
                }

                setDialogState(() {
                  entries.add({
                    'date': pickedDate,
                    'timeStart': tsStr,
                    'timeEnd': teStr,
                    'type': selectedType,
                  });
                  if (preselectedDate == null) pickedDate = null;
                  pickedTimeStart = null;
                  pickedTimeEnd = null;
                });
              }

              Color typeColor(String t) {
                if (t == 'adoption') return Colors.blue;
                if (t == 'rescue') return Colors.redAccent;
                return Colors.green;
              }

              final bool canAdd =
                  pickedDate != null &&
                  pickedTimeStart != null &&
                  pickedTimeEnd != null;

              return Dialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Add Available Slot',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
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
                        const SizedBox(height: 24),
                        const Text(
                          'Appointment Type',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children:
                              ['adoption', 'donation', 'rescue'].map((t) {
                                final active = selectedType == t;
                                final tc = typeColor(t);
                                final isAllowed =
                                    pickedDate == null ||
                                    _isDayAllowedForType(pickedDate!, t) ||
                                    _isSpecialDay(pickedDate!, t);
                                return Expanded(
                                  child: Opacity(
                                    opacity: isAllowed ? 1.0 : 0.45,
                                    child: GestureDetector(
                                      onTap: () {
                                        if (!isAllowed) {
                                          showDialog(
                                            context: ctx,
                                            builder:
                                                (_) => AlertDialog(
                                                  backgroundColor: const Color(
                                                    0xFF2A2A2A,
                                                  ),
                                                  title: Text(
                                                    '${t[0].toUpperCase()}${t.substring(1)} not scheduled',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  content: Text(
                                                    '${_weekdayNames[pickedDate!.weekday]} is not a '
                                                    'configured $t day. Add as a special override?',
                                                    style: const TextStyle(
                                                      color: Colors.white54,
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                        style: TextStyle(
                                                          color: Colors.white54,
                                                          fontFamily:
                                                              'Montserrat',
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        setDialogState(
                                                          () =>
                                                              selectedType = t,
                                                        );
                                                      },
                                                      child: const Text(
                                                        'Add Override',
                                                        style: TextStyle(
                                                          color: Colors.orange,
                                                          fontFamily:
                                                              'Montserrat',
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
                                        setDialogState(() => selectedType = t);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        margin: EdgeInsets.only(
                                          right: t != 'rescue' ? 8 : 0,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              active
                                                  ? tc.withOpacity(0.2)
                                                  : const Color(0xFF2A2A2A),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: active ? tc : Colors.white12,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  t == 'adoption'
                                                      ? Icons.pets
                                                      : t == 'rescue'
                                                      ? Icons.local_hospital
                                                      : Icons.volunteer_activism,
                                                  color:
                                                      active ? tc : Colors.white38,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  t[0].toUpperCase() +
                                                      t.substring(1),
                                                  style: TextStyle(
                                                    color:
                                                        active
                                                            ? tc
                                                            : Colors.white54,
                                                    fontFamily: 'Montserrat',
                                                    fontWeight:
                                                        active
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Date',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  pickedDate != null
                                      ? DateFormat(
                                        'MMM d, yyyy',
                                      ).format(pickedDate!)
                                      : 'Tap to select date',
                                  style: TextStyle(
                                    color:
                                        pickedDate != null
                                            ? Colors.white
                                            : Colors.white38,
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start Time',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => pickTime(true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2A2A2A),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white12,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            color: Colors.orange,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            pickedTimeStart != null
                                                ? pickedTimeStart!.format(ctx)
                                                : 'Start',
                                            style: TextStyle(
                                              color:
                                                  pickedTimeStart != null
                                                      ? Colors.white
                                                      : Colors.white38,
                                              fontFamily: 'Montserrat',
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'End Time',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => pickTime(false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2A2A2A),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white12,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time_filled,
                                            color: Colors.orange,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            pickedTimeEnd != null
                                                ? pickedTimeEnd!.format(ctx)
                                                : 'End',
                                            style: TextStyle(
                                              color:
                                                  pickedTimeEnd != null
                                                      ? Colors.white
                                                      : Colors.white38,
                                              fontFamily: 'Montserrat',
                                              fontSize: 13,
                                            ),
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
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: canAdd ? addEntry : null,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              'Add Another Date',
                              style: TextStyle(fontFamily: 'Montserrat'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: BorderSide(
                                color: canAdd ? Colors.orange : Colors.white24,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        if (entries.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Slots to be saved:',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...entries.asMap().entries.map((e) {
                            final idx = e.key;
                            final entry = e.value;
                            final tc = typeColor(entry['type']);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: tc.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: tc.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    entry['type'] == 'adoption'
                                        ? Icons.pets
                                        : entry['type'] == 'rescue'
                                        ? Icons.local_hospital
                                        : Icons.volunteer_activism,
                                    color: tc,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${DateFormat('MMM d, y').format(entry['date'])}  •  ${entry['timeStart']} – ${entry['timeEnd']}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontFamily: 'Montserrat',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap:
                                        () => setDialogState(
                                          () => entries.removeAt(idx),
                                        ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white38,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 24),
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
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed:
                                    isSaving
                                        ? null
                                        : () async {
                                          final toSave =
                                              List<Map<String, dynamic>>.from(
                                                entries,
                                              );
                                          if (canAdd) {
                                            toSave.add({
                                              'date': pickedDate,
                                              'timeStart': pickedTimeStart!
                                                  .format(ctx),
                                              'timeEnd': pickedTimeEnd!.format(
                                                ctx,
                                              ),
                                              'type': selectedType,
                                            });
                                          }
                                          if (toSave.isEmpty) return;
                                          setDialogState(() => isSaving = true);
                                          int saved = 0;
                                          for (final entry in toSave) {
                                            if (!_isDateAllowed(
                                              entry['date'] as DateTime,
                                            )) {
                                              if (mounted) {
                                                _showSnackBar(
                                                  'Cannot save slots for past dates.',
                                                  Colors.red,
                                                );
                                              }
                                              setDialogState(
                                                () => isSaving = false,
                                              );
                                              return;
                                            }

                                            if (_timeStringToMinutes(
                                                  entry['timeEnd'],
                                                ) <=
                                                _timeStringToMinutes(
                                                  entry['timeStart'],
                                                )) {
                                              if (mounted) {
                                                _showSnackBar(
                                                  'End time must be after start time.',
                                                  Colors.red,
                                                );
                                              }
                                              setDialogState(
                                                () => isSaving = false,
                                              );
                                              return;
                                            }

                                            final ok = await _saveAvailableSlot(
                                              AvailableSlot(
                                                date: entry['date'],
                                                timeStart: entry['timeStart'],
                                                timeEnd: entry['timeEnd'],
                                                type: entry['type'],
                                              ),
                                            );
                                            if (ok) {
                                              saved++;
                                            } else {
                                              setDialogState(
                                                () => isSaving = false,
                                              );
                                              return;
                                            }
                                          }
                                          if (!mounted) return;
                                          Navigator.pop(ctx);
                                          _showSnackBar(
                                            '$saved slot(s) saved!',
                                            Colors.green,
                                          );
                                        },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child:
                                    isSaving
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text(
                                          'Save Slot(s)',
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
            },
          ),
    );
  }

  Future<void> _showDayDetailDialog(DateTime day) async {
    await _seedDefaultSlotsIfNeeded(day);
    final adoptOk = _adoptionConfig.allowedWeekdays.contains(day.weekday);
    final donOk = _donationConfig.allowedWeekdays.contains(day.weekday);
    final rescueOk = _rescueConfig.allowedWeekdays.contains(day.weekday);
    final isPast = _dateOnly(day).isBefore(_dateOnly(DateTime.now()));
    if (_rescueConfig.allowedWeekdays.isEmpty &&
        _adoptionConfig.allowedWeekdays.isEmpty) {
      await _fetchScheduleConfigs();
    }
    await _seedDefaultSlotsIfNeeded(day);
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              final appts = _appointmentsForDay(day);
              final slots = _slotsForDay(day);

              return Dialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                insetPadding: EdgeInsets.symmetric(
                  horizontal:
                      MediaQuery.of(ctx).size.width < 600 ? 12 : 40,
                  vertical:
                      MediaQuery.of(ctx).size.width < 600 ? 20 : 40,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                  ),
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
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.event,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE').format(day),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                                Text(
                                  DateFormat('MMMM d, yyyy').format(day),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
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
                        const SizedBox(height: 20),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isPast) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: Colors.white38,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              const Text(
                                                'Allowed types:',
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 11,
                                                ),
                                              ),
                                              adoptOk
                                                  ? _typeBadge(
                                                    'Adoption',
                                                    Colors.blue,
                                                  )
                                                  : _typeBadge(
                                                    'Adoption',
                                                    Colors.white24,
                                                    strikethrough: true,
                                                  ),
                                              donOk
                                                  ? _typeBadge(
                                                    'Donation',
                                                    Colors.green,
                                                  )
                                                  : _typeBadge(
                                                    'Donation',
                                                    Colors.white24,
                                                    strikethrough: true,
                                                  ),
                                              rescueOk
                                                  ? _typeBadge(
                                                    'Rescue',
                                                    Colors.redAccent,
                                                  )
                                                  : _typeBadge(
                                                    'Rescue',
                                                    Colors.white24,
                                                    strikethrough: true,
                                                  ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                _sectionHeader(
                                  'Available Slots',
                                  slots.length,
                                  Colors.orange,
                                ),
                                const SizedBox(height: 10),
                                if (slots.isEmpty)
                                  _emptyChip('No slots set for this day')
                                else
                                  ...slots.map((slot) {
                                    final isRescue = slot.type == 'rescue';
                                    final isAdoption = slot.type == 'adoption';
                                    final tc =
                                        isAdoption
                                            ? Colors.blue
                                            : isRescue
                                            ? Colors.redAccent
                                            : Colors.green;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: tc.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: tc.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: tc.withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              isAdoption
                                                  ? Icons.pets
                                                  : isRescue
                                                  ? Icons.local_hospital
                                                  : Icons.volunteer_activism,
                                              color: tc,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // ── Info column (takes all free space) ──
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  slot.type[0].toUpperCase() +
                                                      slot.type.substring(1),
                                                  style: TextStyle(
                                                    color: tc,
                                                    fontFamily: 'Montserrat',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.access_time,
                                                      color: Colors.white54,
                                                      size: 13,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        '${slot.timeStart} – ${slot.timeEnd}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // ── Action buttons (always pinned right, never overlay) ──
                                          if (slot.id != null) ...[
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () async {
                                                Navigator.pop(ctx);
                                                await _editAvailableSlot(slot);
                                                if (mounted) setState(() {});
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.edit,
                                                  color: Colors.orange,
                                                  size: 15,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () async {
                                                await _deleteAvailableSlot(
                                                  slot.id!,
                                                );
                                                if (mounted) {
                                                  setDialogState(() {});
                                                  setState(() {});
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(
                                                    0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 20),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 20),
                                _sectionHeader(
                                  'Booked Appointments',
                                  appts.length,
                                  Colors.white70,
                                ),
                                const SizedBox(height: 10),
                                if (appts.isEmpty)
                                  _emptyChip('No appointments booked')
                                else
                                  ...appts.map((appt) {
                                    final isAdoption = appt.type == 'adoption';
                                    final isRescue = appt.type == 'rescue';
                                    final tc =
                                        isAdoption
                                            ? Colors.blue
                                            : isRescue
                                            ? Colors.redAccent
                                            : Colors.green;
                                    Color sc;
                                    switch (appt.status.toLowerCase()) {
                                      case 'approved':
                                      case 'completed':
                                        sc = Colors.green;
                                        break;
                                      case 'declined':
                                      case 'rejected':
                                      case 'cancelled':
                                        sc = Colors.red;
                                        break;
                                      default:
                                        sc = Colors.amber;
                                    }
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2A2A2A),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white12,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: tc.withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              isAdoption
                                                  ? Icons.pets
                                                  : isRescue
                                                  ? Icons.local_hospital
                                                  : Icons.volunteer_activism,
                                              color: tc,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  appt.title,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: 'Montserrat',
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.access_time,
                                                      color: Colors.white54,
                                                      size: 13,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        DateFormat(
                                                          'h:mm a',
                                                        ).format(appt.date),
                                                        style: const TextStyle(
                                                          color: Colors.white54,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Status badge inline with time
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: sc.withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                      ),
                                                      child: Text(
                                                        appt.status,
                                                        style: TextStyle(
                                                          color: sc,
                                                          fontFamily: 'Montserrat',
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (appt.notes != null &&
                                                    appt.notes!.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      appt.notes!,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white38,
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _typeBadge(String label, Color color, {bool strikethrough = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: strikethrough ? Colors.white24 : color,
          fontFamily: 'Montserrat',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          decoration:
              strikethrough ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: Colors.white24,
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, int count, Color badgeColor) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: badgeColor,
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyChip(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white24, size: 16),
          const SizedBox(width: 8),
          Text(
            msg,
            style: const TextStyle(
              color: Colors.white38,
              fontFamily: 'Montserrat',
              fontSize: 12,
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
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isMobile ? 4 : 0),
              child: Text(
                'Appointments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          isMobile
              ? IconButton(
                icon: const Icon(Icons.tune, color: Colors.purple, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _showScheduleConfigDialog,
              )
              : ElevatedButton.icon(
                onPressed: _showScheduleConfigDialog,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text(
                  'Configure',
                  style: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                ),
              ),
          SizedBox(width: isMobile ? 2 : 6),
          isMobile
              ? IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.orange,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _showAddAppointmentDialog,
              )
              : ElevatedButton.icon(
                onPressed: _showAddAppointmentDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add Slot',
                  style: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                ),
              ),
          SizedBox(width: isMobile ? 2 : 6),
          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ShelterProjectsPage()),
                ),
            child: Image.asset(
              'assets/icons/shelterprojects.png',
              width: isMobile ? 20 : 26,
              height: isMobile ? 20 : 26,
            ),
          ),
          SizedBox(width: isMobile ? 2 : 4),
          _NotificationBell(
            iconSize: isMobile ? 18 : 22,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 2 : 6),
          ),
          SizedBox(width: isMobile ? 4 : 6),
          _buildProfileAvatar(radius: isMobile ? 13 : 16),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 40,
      width: double.infinity,
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

  Widget _buildCalendar() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final firstWeekday =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed:
                    () => setState(
                      () =>
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month - 1,
                            1,
                          ),
                    ),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed:
                    () => setState(
                      () =>
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month + 1,
                            1,
                          ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legendItem(Colors.orange, 'Has appointment'),
              _legendItem(Colors.blue.shade300, 'Adoption slot'),
              _legendItem(Colors.green.shade300, 'Donation slot'),
              _legendItem(Colors.redAccent, 'Rescue slot'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children:
                ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.05,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox.shrink();
              final day = index - firstWeekday + 1;
              final date = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                day,
              );
              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected =
                  _selectedDay != null &&
                  date.year == _selectedDay!.year &&
                  date.month == _selectedDay!.month &&
                  date.day == _selectedDay!.day;
              final isPastDay = _dateOnly(date).isBefore(_dateOnly(today));
              final hasAppts = _appointmentsForDay(date).isNotEmpty;
              final daySlots = _slotsForDay(date);
              final hasAdoption = daySlots.any((s) => s.type == 'adoption');
              final hasDonation = daySlots.any((s) => s.type == 'donation');
              final hasRescue = daySlots.any((s) => s.type == 'rescue');

              final adoptionAllowed = _adoptionConfig.allowedWeekdays.contains(
                date.weekday,
              );
              final donationAllowed = _donationConfig.allowedWeekdays.contains(
                date.weekday,
              );
              final rescueAllowed = _rescueConfig.allowedWeekdays.contains(
                date.weekday,
              );
              final allowedCount =
                  [
                    adoptionAllowed,
                    donationAllowed,
                    rescueAllowed,
                  ].where((b) => b).length;

              Color? dayBg;
              if (!isSelected && !isToday && !isPastDay) {
                if (allowedCount > 1) {
                  dayBg = Colors.purple.withOpacity(0.08);
                } else if (adoptionAllowed) {
                  dayBg = Colors.blue.withOpacity(0.07);
                } else if (donationAllowed) {
                  dayBg = Colors.green.withOpacity(0.07);
                } else if (rescueAllowed) {
                  dayBg = Colors.redAccent.withOpacity(0.07);
                }
              }

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDay = date);
                  _showDayDetailDialog(date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Colors.orange
                            : isToday
                            ? Colors.orange.withOpacity(0.15)
                            : isPastDay
                            ? Colors.white.withOpacity(0.02)
                            : dayBg,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        isToday && !isSelected
                            ? Border.all(color: Colors.orange, width: 1.5)
                            : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color:
                              isSelected
                                  ? Colors.white
                                  : isToday
                                  ? Colors.orange
                                  : isPastDay
                                  ? Colors.white24
                                  : Colors.white70,
                          fontFamily: 'Montserrat',
                          fontWeight:
                              (isToday || isSelected)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasAppts)
                            _dot(isSelected ? Colors.white : Colors.orange),
                          if (hasAdoption)
                            _dot(
                              isSelected ? Colors.white : Colors.blue.shade300,
                            ),
                          if (hasDonation)
                            _dot(
                              isSelected ? Colors.white : Colors.green.shade300,
                            ),
                          if (hasRescue)
                            _dot(isSelected ? Colors.white : Colors.redAccent),
                        ],
                      ),
                      if (!isSelected &&
                          !isPastDay &&
                          (adoptionAllowed || donationAllowed || rescueAllowed))
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (adoptionAllowed)
                              Container(
                                width: 4,
                                height: 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            if (donationAllowed)
                              Container(
                                width: 4,
                                height: 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            if (rescueAllowed)
                              Container(
                                width: 4,
                                height: 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _legendItem(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontFamily: 'Montserrat',
        ),
      ),
    ],
  );

  Widget _buildAppointmentList({double? maxHeight}) {
    final appts =
        _selectedDay == null
            ? _filteredAppointments
            : _appointmentsForDay(_selectedDay!);

    final slots =
        (_selectedDay == null ? _availableSlots : _slotsForDay(_selectedDay!))
            .where((s) {
              if (_filter == AppointmentType.adoption) {
                return s.type == 'adoption';
              }
              if (_filter == AppointmentType.donation) {
                return s.type == 'donation';
              }
              return true;
            })
            .toList();

    final label =
        _selectedDay == null
            ? 'All Appointments'
            : 'Appointments on ${DateFormat('MMM d, y').format(_selectedDay!)}';

    final bool isEmpty = appts.isEmpty && slots.isEmpty;

    Widget body;
    if (_isLoading) {
      body = Center(
        child: LoadingAnimationWidget.fallingDot(
          color: Colors.orange,
          size: 40,
        ),
      );
    } else if (isEmpty) {
      body = Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: const Column(
          children: [
            Icon(Icons.event_busy, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'No appointments or slots',
              style: TextStyle(
                color: Colors.white38,
                fontFamily: 'Montserrat',
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          if (slots.isNotEmpty) ...[
            _buildSectionAccordion(
              isOpen: _slotsAccordionOpen,
              onToggle:
                  () => setState(
                    () => _slotsAccordionOpen = !_slotsAccordionOpen,
                  ),
              icon: Icons.event_available,
              iconColor: Colors.orange,
              label: 'Available Slots',
              count: slots.length,
              countColor: Colors.orange,
              child: _buildSlotsAccordionBody(slots),
            ),
            if (appts.isNotEmpty) const SizedBox(height: 10),
          ],
          if (appts.isNotEmpty)
            _buildSectionAccordion(
              isOpen: _appointmentsAccordionOpen,
              onToggle:
                  () => setState(
                    () =>
                        _appointmentsAccordionOpen =
                            !_appointmentsAccordionOpen,
                  ),
              icon: Icons.calendar_month,
              iconColor: Colors.white70,
              label: 'Booked Appointments',
              count: appts.length,
              countColor: Colors.white54,
              child: _buildAppointmentsAccordionBody(appts),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
              if (_selectedDay != null)
                TextButton(
                  onPressed: () => setState(() => _selectedDay = null),
                  child: const Text(
                    'Show All',
                    style: TextStyle(
                      color: Colors.orange,
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (maxHeight != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(child: body),
            )
          else
            body,
        ],
      ),
    );
  }

  Widget _buildSectionAccordion({
    required bool isOpen,
    required VoidCallback onToggle,
    required IconData icon,
    required Color iconColor,
    required String label,
    required int count,
    required Color countColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius:
                isOpen
                    ? const BorderRadius.vertical(top: Radius.circular(10))
                    : BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: iconColor,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: countColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: countColor,
                        fontFamily: 'Montserrat',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState:
                isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: child,
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsAccordionBody(List<AvailableSlot> slots) {
    final adoptionSlots =
        slots.where((s) => s.type == 'adoption').toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final donationSlots =
        slots.where((s) => s.type == 'donation').toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final rescueSlots =
        slots.where((s) => s.type == 'rescue').toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      children: [
        if (adoptionSlots.isNotEmpty)
          _buildSlotTypeAccordion(
            type: 'adoption',
            color: Colors.blue,
            icon: Icons.pets,
            slots: adoptionSlots,
          ),
        if (adoptionSlots.isNotEmpty && donationSlots.isNotEmpty)
          const SizedBox(height: 8),
        if (donationSlots.isNotEmpty)
          _buildSlotTypeAccordion(
            type: 'donation',
            color: Colors.green,
            icon: Icons.volunteer_activism,
            slots: donationSlots,
          ),
        if (rescueSlots.isNotEmpty &&
            (adoptionSlots.isNotEmpty || donationSlots.isNotEmpty))
          const SizedBox(height: 8),
        if (rescueSlots.isNotEmpty)
          _buildSlotTypeAccordion(
            type: 'rescue',
            color: Colors.redAccent,
            icon: Icons.local_hospital,
            slots: rescueSlots,
          ),
      ],
    );
  }

  Widget _buildSlotTypeAccordion({
    required String type,
    required Color color,
    required IconData icon,
    required List<AvailableSlot> slots,
  }) {
    final isOpen = _expandedSlotTypes.contains(type);
    final label = type[0].toUpperCase() + type.substring(1);

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap:
                () => setState(() {
                  if (isOpen) {
                    _expandedSlotTypes.remove(type);
                  } else {
                    _expandedSlotTypes.add(type);
                  }
                }),
            borderRadius:
                isOpen
                    ? const BorderRadius.vertical(top: Radius.circular(8))
                    : BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 7),
                  Text(
                    '$label Slots',
                    style: TextStyle(
                      color: color,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${slots.length}',
                      style: TextStyle(
                        color: color,
                        fontFamily: 'Montserrat',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: color.withOpacity(0.6),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
              child: Column(
                children:
                    slots
                        .map(
                          (slot) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildSlotTile(slot),
                          ),
                        )
                        .toList(),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsAccordionBody(List<Appointment> appts) {
    final definedOrder = ['Pending', 'Approved', 'Declined', 'Rejected', 'Cancelled'];
    final knownLower = definedOrder.map((s) => s.toLowerCase()).toSet();
    final extraStatuses = appts
        .map((a) => a.status)
        .where((s) => !knownLower.contains(s.toLowerCase()))
        .toSet()
        .toList();
    final statusOrder = [...definedOrder, ...extraStatuses];

    final statusColors = {
      'Pending': Colors.amber,
      'Approved': Colors.green,
      'Declined': Colors.red,
      'Rejected': Colors.red,
      'Cancelled': Colors.red,
    };
    final statusIcons = {
      'Pending': Icons.hourglass_empty,
      'Approved': Icons.check_circle_outline,
      'Declined': Icons.cancel_outlined,
      'Rejected': Icons.cancel_outlined,
      'Cancelled': Icons.remove_circle_outline,
    };

    final grouped = <String, List<Appointment>>{};
    for (final status in statusOrder) {
      final group =
          appts
              .where((a) => a.status.toLowerCase() == status.toLowerCase())
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      if (group.isNotEmpty) grouped[status] = group;
    }

    if (grouped.isEmpty) return const SizedBox.shrink();

    return Column(
      children:
          grouped.entries.toList().asMap().entries.map((outer) {
            final idx = outer.key;
            final status = outer.value.key;
            final list = outer.value.value;
            final color = statusColors[status] ?? Colors.white54;
            final statusIcon = statusIcons[status] ?? Icons.circle_outlined;
            final isOpen = _expandedStatuses.contains(status);

            return Padding(
              padding: EdgeInsets.only(top: idx == 0 ? 0 : 8),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap:
                          () => setState(() {
                            if (isOpen) {
                              _expandedStatuses.remove(status);
                            } else {
                              _expandedStatuses.add(status);
                            }
                          }),
                      borderRadius:
                          isOpen
                              ? const BorderRadius.vertical(
                                top: Radius.circular(8),
                              )
                              : BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, color: color, size: 14),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: color,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${list.length} appointment${list.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            AnimatedRotation(
                              turns: isOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: color.withOpacity(0.6),
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 210),
                      crossFadeState:
                          isOpen
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                      firstChild: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: list.length,
                        separatorBuilder:
                            (_, __) =>
                                const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (_, i) => _buildAppointmentTile(list[i]),
                      ),
                      secondChild: const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSlotTile(AvailableSlot slot) {
    final isAdoption = slot.type == 'adoption';
    final isRescue = slot.type == 'rescue';
    final tc =
        isAdoption
            ? Colors.blue
            : isRescue
            ? Colors.redAccent
            : Colors.green;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRect(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tc.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tc.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tc.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isAdoption
                      ? Icons.pets
                      : isRescue
                      ? Icons.local_hospital
                      : Icons.volunteer_activism,
                  color: tc,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAdoption
                          ? 'Adoption Slot'
                          : isRescue
                          ? 'Rescue Slot'
                          : 'Donation Slot',
                      style: TextStyle(
                        color: tc,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white38,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            DateFormat('MMM d, yyyy').format(slot.date),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.white38,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${slot.timeStart} – ${slot.timeEnd}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Available',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontFamily: 'Montserrat',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentTile(Appointment appt) {
    final isAdoption = appt.type == 'adoption';
    final isRescue = appt.type == 'rescue';
    final tc =
        isAdoption
            ? Colors.blue
            : isRescue
            ? Colors.redAccent
            : Colors.green;
    Color sc;
    switch (appt.status.toLowerCase()) {
      case 'approved':
      case 'completed':
        sc = Colors.green;
        break;
      case 'declined':
      case 'rejected':
      case 'cancelled':
        sc = Colors.red;
        break;
      default:
        sc = Colors.amber;
    }
    return InkWell(
      onTap: () => _showAppointmentDetailDialog(appt),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tc.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isAdoption
                    ? Icons.pets
                    : isRescue
                    ? Icons.local_hospital
                    : Icons.volunteer_activism,
                color: tc,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        appt.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sc.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          appt.status,
                          style: TextStyle(
                            color: sc,
                            fontFamily: 'Montserrat',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        DateFormat('MMM d, y').format(appt.date),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '•  ${DateFormat('h:mm a').format(appt.date)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (appt.notes != null && appt.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        appt.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Montserrat',
                          fontSize: 11,
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

  Widget _buildMainContent(double width) {
    final isMobile = width < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        if (isMobile)
          Column(
            children: [
              _buildCalendar(),
              const SizedBox(height: 16),
              _buildAppointmentList(),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: _buildCalendar(),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: ClipRect(
                  child: _buildAppointmentList(maxHeight: 500),
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 900;

        return PopScope(
          canPop: false,
          onPopInvoked: (_) {},
          child: Scaffold(
            backgroundColor: const Color(0xFF101510),
            drawer: isMobile ? Drawer(width: 200, child: _buildSidebar()) : null,
            body: Row(
              children: [
                if (!isMobile) _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      Material(
                        color: const Color(0xFF1C1C1C),
                        elevation: 2,
                        shadowColor: Colors.black54,
                        child: _buildTopHeader(isMobile),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildMainContent(width),
                        ),
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
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
    setState(() => _notifications.removeWhere((n) => n['id'] == id));
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

class _ReportInfoSection extends StatefulWidget {
  final int? reportId;
  final int? furparentId;
  final SupabaseClient supabase;

  const _ReportInfoSection({
    required this.reportId,
    required this.furparentId,
    required this.supabase,
  });

  @override
  State<_ReportInfoSection> createState() => _ReportInfoSectionState();
}

class _ReportInfoSectionState extends State<_ReportInfoSection> {
  Map<String, dynamic>? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      Map<String, dynamic>? res;

      if (widget.reportId != null) {
        res =
            await widget.supabase
                .from('reports')
                .select('*')
                .eq('reportid', widget.reportId!)
                .maybeSingle();
      } else if (widget.furparentId != null) {
        final list = await widget.supabase
            .from('reports')
            .select('*')
            .eq('furparent_id', widget.furparentId!)
            .order('created_at', ascending: false)
            .limit(1);
        if ((list as List).isNotEmpty) {
          res = list.first;
        }
      }

      if (mounted) {
        setState(() {
          _report = res;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('_ReportInfoSection fetch error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(
            color: Colors.orange,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_report == null) return const SizedBox.shrink();

    final r = _report!;
    final type = r['type']?.toString() ?? '';
    final isDonation = type == 'Donation';

    final fields = <Map<String, String>>[];
    if (isDonation) {
      if (r['donation_item'] != null) {
        fields.add({'label': 'Item', 'value': r['donation_item']});
      }
      if (r['donation_category'] != null) {
        fields.add({'label': 'Category', 'value': r['donation_category']});
      }
      if (r['donation_quantity'] != null) {
        fields.add({'label': 'Quantity', 'value': r['donation_quantity']});
      }
      if (r['pickup_address'] != null) {
        fields.add({'label': 'Pickup', 'value': r['pickup_address']});
      }
    } else {
      if ((r['name'] ?? '').toString().isNotEmpty) {
        fields.add({'label': 'Pet Name', 'value': r['name']});
      }
      if (r['pet_type'] != null) {
        fields.add({'label': 'Pet Type', 'value': r['pet_type']});
      }
      if (r['breed'] != null) {
        fields.add({'label': 'Breed', 'value': r['breed']});
      }
      if (r['color'] != null) {
        fields.add({'label': 'Color', 'value': r['color']});
      }
      if (r['sex'] != null) fields.add({'label': 'Sex', 'value': r['sex']});
      if (r['age'] != null) fields.add({'label': 'Age', 'value': r['age']});
      if (r['health'] != null) {
        fields.add({'label': 'Health', 'value': r['health']});
      }
      if (r['pet_situation'] != null) {
        fields.add({'label': 'Situation', 'value': r['pet_situation']});
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r['image_url_1'] != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              r['image_url_1'],
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder:
                  (_, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                            height: 160,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const CircularProgressIndicator(
                              color: Colors.orange,
                              strokeWidth: 2,
                            ),
                          ),
              errorBuilder:
                  (_, __, ___) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white24,
                      size: 32,
                    ),
                  ),
            ),
          ),
          if (r['image_url_2'] != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                r['image_url_2'],
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Icon(Icons.description, color: Colors.teal, size: 14),
            const SizedBox(width: 6),
            const Text(
              'Report Info',
              style: TextStyle(
                color: Colors.teal,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                type.toUpperCase(),
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontFamily: 'Montserrat',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.withOpacity(0.2)),
          ),
          child: Column(
            children:
                fields.map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            f['label']!,
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
                            f['value']!,
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
                }).toList(),
          ),
        ),
        if (r['venue'] != null && r['venue'].toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.teal, size: 14),
              const SizedBox(width: 6),
              const Text(
                'LOCATION',
                style: TextStyle(
                  color: Colors.teal,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r['venue'].toString(),
            style: const TextStyle(
              color: Colors.white54,
              fontFamily: 'Montserrat',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _VenueMap(address: r['venue'].toString()),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _VenueMap extends StatefulWidget {
  final String address;
  const _VenueMap({required this.address});

  @override
  State<_VenueMap> createState() => _VenueMapState();
}

class _VenueMapState extends State<_VenueMap> {
  LatLng? _location;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _geocodeAddress();
  }

  Future<void> _geocodeAddress() async {
    try {
      final locations = await locationFromAddress(widget.address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        if (!mounted) return;
        setState(() {
          _location = LatLng(loc.latitude, loc.longitude);
          _loading = false;
        });
      } else {
        _fail();
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      _fail();
    }
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const CircularProgressIndicator(color: Colors.orange),
      );
    }

    if (_location == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Unable to load map location',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: FlutterMap(
          options: MapOptions(center: _location!, zoom: 15),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: 'com.your.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _location!,
                  width: 40,
                  height: 40,
                  builder:
                      (context) => const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                ),
              ],
            ),
          ],
        ),
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
