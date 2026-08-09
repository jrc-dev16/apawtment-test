import 'dart:math' as Math;

import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';
import 'package:apawtmentweb_admin/donationpage.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/main.dart';
import 'package:apawtmentweb_admin/printreportspage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

const double _kMobile = 700;
const double _kTablet = 1100;

enum DashboardFilterType { monthly, quarterly, annually }

class DashboardFilter {
  final DashboardFilterType type;
  final int? month;
  final int? quarter;
  final int year;

  const DashboardFilter({
    required this.type,
    required this.year,
    this.month,
    this.quarter,
  });

  String get label {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    switch (type) {
      case DashboardFilterType.monthly:
        return '${months[(month ?? 1) - 1]} $year';
      case DashboardFilterType.quarterly:
        return 'Q$quarter $year';
      case DashboardFilterType.annually:
        return 'Year $year';
    }
  }

  DateTimeRange get dateRange {
    switch (type) {
      case DashboardFilterType.monthly:
        final m = month ?? DateTime.now().month;
        return DateTimeRange(
          start: DateTime(year, m, 1),
          end: DateTime(year, m + 1, 0, 23, 59, 59),
        );
      case DashboardFilterType.quarterly:
        final q = quarter ?? 1;
        final startMonth = (q - 1) * 3 + 1;
        final endMonth = startMonth + 2;
        return DateTimeRange(
          start: DateTime(year, startMonth, 1),
          end: DateTime(year, endMonth + 1, 0, 23, 59, 59),
        );
      case DashboardFilterType.annually:
        return DateTimeRange(
          start: DateTime(year, 1, 1),
          end: DateTime(year, 12, 31, 23, 59, 59),
        );
    }
  }
}

class DashboardPage extends StatefulWidget {
  final int? eventid;
  final String? title;
  final String? category;
  final String? description;
  final String? date;
  final String? time1;
  final String? time2;
  final String? location;
  final bool? skipBackInterceptor;

  const DashboardPage({
    super.key,
    this.title,
    this.category,
    this.description,
    this.date,
    this.location,
    this.eventid,
    this.time1,
    this.time2,
    this.skipBackInterceptor,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedItem = 'Dashboard';

  late DashboardFilter _dashFilter;
  List<DashboardFilter> _filterOptions = [];

  String _barFilter = 'Monthly';
  DateTimeRange? _customBarRange;

  late Future<List<Map<String, dynamic>>> _statsFuture;
  late Future<Map<String, int>> _reportsFuture;
  late Future<Map<String, int>> _neuterFuture;
  late Future<Map<String, int>> _dogCatFuture;
  Future<Map<String, List<FlSpot>>>? _barSpotsFuture;
  late Future<Map<String, int>> _donationFuture;
  late Future<Map<String, int>> _adoptionFuture;

  String? _avatarUrl;
  bool _avatarLoading = false;

  final _db = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    saveLastVisitedPage('Dashboard');
    _buildFilterOptions();
    _loadData();
    _barSpotsFuture = _fetchDogCatBarSpots(
      _barFilter,
      DateTimeRange(start: DateTime(2000), end: DateTime(2100)),
    );
    _loadAvatar();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAvatar());
  }

  void _buildFilterOptions() {
    final now = DateTime.now();
    final options = <DashboardFilter>[];

    for (int y = now.year; y >= now.year - 1; y--) {
      final maxMonth = (y == now.year) ? now.month : 12;
      for (int m = maxMonth; m >= 1; m--) {
        options.add(
          DashboardFilter(type: DashboardFilterType.monthly, year: y, month: m),
        );
      }
      final maxQ = (y == now.year) ? ((now.month - 1) ~/ 3) + 1 : 4;
      for (int q = maxQ; q >= 1; q--) {
        options.add(
          DashboardFilter(
            type: DashboardFilterType.quarterly,
            year: y,
            quarter: q,
          ),
        );
      }
      options.add(DashboardFilter(type: DashboardFilterType.annually, year: y));
    }

    _dashFilter = DashboardFilter(
      type: DashboardFilterType.monthly,
      year: now.year,
      month: now.month,
    );
    _filterOptions = options;
  }

  void _loadData() {
    final r = _dashFilter.dateRange;
    _statsFuture = _fetchStats(r);
    _reportsFuture = _fetchReports(r.start, r.end);
    _neuterFuture = _fetchNeuter(r.start, r.end);
    _dogCatFuture = _fetchDogCat(r.start, r.end);
    _donationFuture = _fetchTrend('donations', r);
    _adoptionFuture = _fetchAdoptionTrend(r);
  }

  void _applyFilter(DashboardFilter? f) {
    if (f == null) return;
    setState(() {
      _dashFilter = f;
      _loadData();
    });
  }

  Future<String> _fetchAdminName() async {
    final r = await _db.from('admin').select('name').eq('admin_id', 1).single();
    return r['name'] as String;
  }

  Future<Map<String, int>> _fetchDogCat(DateTime start, DateTime end) async {
    final r1 = await _db
        .from('pets')
        .select('type')
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String());
    final r2 = await _db
        .from('adoptable_pets')
        .select('type')
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String());
    final data = [...(r1 as List<dynamic>), ...(r2 as List<dynamic>)];
    return {
      'Dog':
          data.where((d) => d['type'] == 'Dog' || d['type'] == 'dog' || d['type'] == 'Dogs').length,
      'Cat':
          data.where((d) => d['type'] == 'Cat' || d['type'] == 'cat' || d['type'] == 'Cats').length,
    };
  }

  Future<void> _loadAvatar() async {
    if (_avatarLoading) return;
    setState(() => _avatarLoading = true);
    try {
      final r =
          await _db
              .from('admin')
              .select('admin_profile')
              .eq('admin_id', 1)
              .maybeSingle();
      if (r == null) {
        if (mounted) setState(() => _avatarLoading = false);
        return;
      }
      final p = r['admin_profile']?.toString();
      String? url;
      if (p != null && p.isNotEmpty) {
        url =
            (p.startsWith('http://') || p.startsWith('https://'))
                ? p
                : _db.storage.from('admin_profile').getPublicUrl(p);
        url = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      }
      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _avatarLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _avatarLoading = false);
    }
  }

  DateTime _groupBy(DateTime date, String filter) {
    switch (filter) {
      case 'Daily':
        return DateTime(date.year, date.month, date.day);
      case 'Weekly':
        final monday = date.subtract(Duration(days: date.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case 'Monthly':
        return DateTime(date.year, date.month, 1);
      case 'Quarterly':
        final q = ((date.month - 1) ~/ 3);
        return DateTime(date.year, q * 3 + 1, 1);
      case 'Yearly':
        return DateTime(date.year, 1, 1);
      default:
        return DateTime(date.year, date.month, date.day);
    }
  }

  Future<Map<String, List<FlSpot>>> _fetchDogCatBarSpots(
    String filter,
    DateTimeRange range,
  ) async {
    final now = DateTime.now();

    DateTime fetchStart;
    DateTime fetchEnd;

    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final quarterStartMonth = (currentQuarter - 1) * 3 + 1;
    final quarterEndMonth = quarterStartMonth + 2;

    switch (filter) {
      case 'Daily':
        fetchStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        fetchEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;

      case 'Weekly':
        fetchStart = DateTime(now.year, now.month, 1);
        fetchEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;

      case 'Monthly':
        fetchStart = DateTime(now.year, 1, 1);
        fetchEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'Quarterly':
        fetchStart = DateTime(now.year, 1, 1);
        final currentQ = ((now.month - 1) ~/ 3) + 1;
        final lastQEndMonth = currentQ * 3;
        fetchEnd = DateTime(now.year, lastQEndMonth + 1, 0, 23, 59, 59);
        break;

      case 'Yearly':
        fetchStart = DateTime(now.year - 4, 1, 1);
        fetchEnd = DateTime(now.year, 12, 31, 23, 59, 59);
        break;

      default:
        fetchStart =
            range.start.year == 2000 ? DateTime(now.year, 1, 1) : range.start;
        fetchEnd =
            range.end.year == 2100
                ? DateTime(now.year, 12, 31, 23, 59, 59)
                : range.end;
        break;
    }

    final r1 = await supabase
        .from('pets')
        .select('created_at, type')
        .gte('created_at', formatDate(fetchStart))
        .lte('created_at', formatDate(fetchEnd))
        .order('created_at', ascending: true);

    final r2 = await supabase
        .from('adoptable_pets')
        .select('created_at, type')
        .gte('created_at', formatDate(fetchStart))
        .lte('created_at', formatDate(fetchEnd))
        .order('created_at', ascending: true);

    final rows = [...(r1 as List<dynamic>), ...(r2 as List<dynamic>)];

    final Map<DateTime, int> dogGrouped = {};
    final Map<DateTime, int> catGrouped = {};

    for (final row in rows) {
      final raw = row['created_at'];
      final type = (row['type'] as String? ?? '');
      if (raw == null) continue;
      try {
        final dt = DateTime.parse(raw.toString());

        final key = _groupBy(dt, filter);
        if (type == 'Dog' || type == 'dog' || type == 'Dogs') {
          dogGrouped[key] = (dogGrouped[key] ?? 0) + 1;
        } else if (type == 'Cat' || type == 'cat' || type == 'Cats') {
          catGrouped[key] = (catGrouped[key] ?? 0) + 1;
        }
      } catch (_) {}
    }

    switch (filter) {
      case 'Daily':
        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          final key = DateTime(day.year, day.month, day.day);
          dogGrouped.putIfAbsent(key, () => 0);
          catGrouped.putIfAbsent(key, () => 0);
        }
        break;

      case 'Weekly':
        break;

      case 'Quarterly':
        final currentQ = ((now.month - 1) ~/ 3) + 1;
        for (int q = 1; q <= currentQ; q++) {
          final key = DateTime(now.year, (q - 1) * 3 + 1, 1);
          dogGrouped.putIfAbsent(key, () => 0);
          catGrouped.putIfAbsent(key, () => 0);
        }
        break;
      case 'Monthly':
        for (int m = 1; m <= now.month; m++) {
          final key = DateTime(now.year, m, 1);
          dogGrouped.putIfAbsent(key, () => 0);
          catGrouped.putIfAbsent(key, () => 0);
        }
        break;

      case 'Yearly':
        for (int y = now.year - 4; y <= now.year; y++) {
          final key = DateTime(y, 1, 1);
          dogGrouped.putIfAbsent(key, () => 0);
          catGrouped.putIfAbsent(key, () => 0);
        }
        break;
       default:
        fetchStart = range.start;
        fetchEnd = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        final daysCount = fetchEnd.difference(fetchStart).inDays;
        if (daysCount >= 0 && daysCount <= 60) {
          for (int i = 0; i <= daysCount; i++) {
            final day = fetchStart.add(Duration(days: i));
            final key = DateTime(day.year, day.month, day.day);
            dogGrouped.putIfAbsent(key, () => 0);
            catGrouped.putIfAbsent(key, () => 0);
          }
        }
        break;
    }

    final allKeys =
        <DateTime>{...dogGrouped.keys, ...catGrouped.keys}.toList()..sort();

    final dogSpots =
        allKeys
            .map(
              (k) => FlSpot(
                k.millisecondsSinceEpoch.toDouble(),
                (dogGrouped[k] ?? 0).toDouble(),
              ),
            )
            .toList();
    final catSpots =
        allKeys
            .map(
              (k) => FlSpot(
                k.millisecondsSinceEpoch.toDouble(),
                (catGrouped[k] ?? 0).toDouble(),
              ),
            )
            .toList();

    return {
      'Dog': dogSpots,
      'Cat': catSpots,
      'keys':
          allKeys
              .map((k) => FlSpot(k.millisecondsSinceEpoch.toDouble(), 0))
              .toList(),
    };
  }

  Future<Map<String, int>> _fetchNeuter(DateTime start, DateTime end) async {
    final r1 = await _db
        .from('pets')
        .select('neutered_spayed_details')
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String());
    final r2 = await _db
        .from('adoptable_pets')
        .select('neutered_spayed_details')
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String());
    final rows = [...(r1 as List<dynamic>), ...(r2 as List<dynamic>)];
    final counts = {
      'Neutered (Male)': 0,
      'Spayed (Female)': 0,
      'Not Spayed/Neutered': 0,
    };
    for (final r in rows) {
      final s = r['neutered_spayed_details'] as String?;
      if (s != null && counts.containsKey(s)) counts[s] = counts[s]! + 1;
    }
    return counts;
  }

  String formatDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<List<Map<String, dynamic>>> _fetchStats(DateTimeRange range) async {
    try {
      final sheltered = await _db
          .from('pets')
          .select('*')
          .or('status.eq.In Shelter,status.eq.Under Medication')
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String());

      final adopted = await _db
          .from('adoptable_pets')
          .select('*')
          .eq('status', 'Approved')
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String());

      final petsCount = await _db
          .from('pets')
          .select('*')
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String());

      final adoptableCount = await _db
          .from('adoptable_pets')
          .select('*')
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String());

      final totalNewPets = petsCount.length + adoptableCount.length;

      return [
        {'title': 'Pets Sheltered (${_dashFilter.label})', 'value': sheltered.length},
        {
          'title': 'Adopted Pets (${_dashFilter.label})',
          'value': adopted.length,
        },
        {'title': 'New Pets (${_dashFilter.label})', 'value': totalNewPets},
      ];
    } catch (_) {
      return [
        {'title': 'Pets Sheltered', 'value': 0},
        {'title': 'Adopted Pets', 'value': 0},
        {'title': 'New Pets', 'value': 0},
      ];
    }
  }

  Widget _buildStatsSection(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 18,
              vertical: 12,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white10, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 3),
                      _buildPeriodBadge(),
                    ],
                  ),
                ),
                _buildPeriodDropdown(isMobile),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _statsFuture,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 100,
                    child: Center(
                      child: LoadingAnimationWidget.fallingDot(
                        color: Colors.orange,
                        size: 50,
                      ),
                    ),
                  );
                }
                final stats =
                    snap.data ??
                    [
                      {'title': 'Pets Sheltered', 'value': 0},
                      {'title': 'Adopted Pets', 'value': 0},
                      {'title': 'Pets', 'value': 0},
                    ];

                final cards = [
                  _statCard(
                    stats[0]['title'] as String,
                    stats[0]['value'] as int,
                    Icons.home_outlined,
                    Colors.blueAccent,
                  ),
                  _statCard(
                    stats[1]['title'] as String,
                    stats[1]['value'] as int,
                    Icons.favorite_outline,
                    Colors.greenAccent,
                  ),
                  _statCard(
                    stats[2]['title'] as String,
                    stats[2]['value'] as int,
                    Icons.pets,
                    Colors.orange,
                  ),
                ];

                final screenWidth = MediaQuery.of(context).size.width;
                if (screenWidth < 1000) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cards[0],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: cards[1]),
                          const SizedBox(width: 10),
                          Expanded(child: cards[2]),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 10),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 10),
                    Expanded(child: cards[2]),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: TextStyle(
              color: accent,
              fontSize: 28,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontFamily: 'Montserrat',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodBadge() {
    IconData ic;
    Color col;
    String label;
    switch (_dashFilter.type) {
      case DashboardFilterType.monthly:
        ic = Icons.calendar_view_month;
        col = Colors.blueAccent;
        label = 'Monthly';
        break;
      case DashboardFilterType.quarterly:
        ic = Icons.date_range;
        col = Colors.greenAccent;
        label = 'Quarterly';
        break;
      case DashboardFilterType.annually:
        ic = Icons.calendar_today;
        col = Colors.orange;
        label = 'Annual';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 11, color: col),
          const SizedBox(width: 5),
          Text(
            '$label · ${_dashFilter.label}',
            style: TextStyle(
              color: col,
              fontSize: 11,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodDropdown(bool isMobile) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isMobile ? 130 : 160),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<DashboardFilter>(
            value: _filterOptions.firstWhere(
              (f) => f.label == _dashFilter.label,
              orElse: () => _dashFilter,
            ),
            dropdownColor: const Color(0xFF2A2A2A),
            icon: const Icon(Icons.expand_more, color: Colors.orange, size: 16),
            isDense: true,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Montserrat',
              fontSize: isMobile ? 11 : 12,
            ),
            items:
                _filterOptions.map((f) {
                  IconData ic;
                  Color col;
                  switch (f.type) {
                    case DashboardFilterType.monthly:
                      ic = Icons.calendar_view_month;
                      col = Colors.blueAccent;
                      break;
                    case DashboardFilterType.quarterly:
                      ic = Icons.date_range;
                      col = Colors.greenAccent;
                      break;
                    case DashboardFilterType.annually:
                      ic = Icons.calendar_today;
                      col = Colors.orange;
                      break;
                  }
                  return DropdownMenuItem<DashboardFilter>(
                    value: f,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ic, size: 12, color: col),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(f.label, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            onChanged: _applyFilter,
          ),
        ),
      ),
    );
  }

  Future<Map<String, int>> _fetchReports(DateTime start, DateTime end) async {
    final rows = await _db
        .from('reports')
        .select('type')
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String());
    final Map<String, int> counts = {};
    for (final r in rows) {
      final t = r['type'] as String?;
      if (t != null) counts[t] = (counts[t] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, int>> _fetchTrend(
    String table,
    DateTimeRange range,
  ) async {
    try {
      final rows = await _db
          .from(table)
          .select('created_at')
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String())
          .order('created_at', ascending: true);
      const mo = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final Map<String, int> counts = {};
      for (final r in rows) {
        final raw = r['created_at'];
        if (raw == null) continue;
        try {
          final dt = DateTime.parse(raw.toString());
          final key = '${mo[dt.month - 1]} ${dt.year}';
          counts[key] = (counts[key] ?? 0) + 1;
        } catch (_) {}
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, int>> _fetchAdoptionTrend(DateTimeRange range) async {
    try {
      final rows = await _db
          .from('adoptions')
          .select('created_at')
          .eq('status', 'Approved')
          .gte('created_at', range.start.toIso8601String())
          .lte('created_at', range.end.toIso8601String())
          .order('created_at', ascending: true);
      const mo = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final Map<String, int> counts = {};
      for (final r in rows) {
        final raw = r['created_at'];
        if (raw == null) continue;
        try {
          final dt = DateTime.parse(raw.toString());
          final key = '${mo[dt.month - 1]} ${dt.year}';
          counts[key] = (counts[key] ?? 0) + 1;
        } catch (_) {}
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _timeStr {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$h:$m:$s ${now.hour >= 12 ? "PM" : "AM"}';
  }

  String get _dateStr {
    final now = DateTime.now();
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${mo[now.month - 1]} ${now.day}, ${now.year}';
  }

  String _adoptionInsight(Map<String, int> data) {
    if (data.isEmpty) return '';
    final sorted =
        data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final peak = sorted.first;
    final total = data.values.fold(0, (a, b) => a + b);
    if (data.length == 1) return '📊 ${peak.key}: $total adoptions total.';
    final inc = data.values.toList().last > data.values.toList().first;
    return '${inc ? "📈 Increasing" : "📉 Decreasing"} trend · Peak: ${peak.key} (${peak.value}) · Total: $total';
  }

  String _donationInsight(Map<String, int> data) {
    if (data.isEmpty) return '';
    final sorted =
        data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final peak = sorted.first;
    final total = data.values.fold(0, (a, b) => a + b);
    if (data.length == 1) return '💰 ${peak.key}: $total donations total.';
    final inc = data.values.toList().last > data.values.toList().first;
    return '${inc ? "📈 Increasing" : "📉 Decreasing"} trend · Peak: ${peak.key} (${peak.value}) · Total: $total';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isMobile = w < _kMobile;

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
                      _buildHeader(isMobile),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(isMobile ? 12 : 20),
                          child: _buildBody(w),
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

  Widget _buildHeader(bool isMobile) {
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
              'Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 14 : 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          const Spacer(),
          isMobile
              ? IconButton(
                icon: const Icon(Icons.print, color: Colors.orange, size: 20),
                padding: EdgeInsets.zero,
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrintReportPage(),
                      ),
                    ),
              )
              : ElevatedButton.icon(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrintReportPage(),
                      ),
                    ),
                icon: const Icon(Icons.print, size: 16),
                label: const Text(
                  'Print',
                  style: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                ),
              ),
          const SizedBox(width: 6),
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
          _buildAvatar(radius: isMobile ? 14 : 16),
        ],
      ),
    );
  }

  Widget _buildAvatar({double radius = 16}) {
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfilePage()),
          ).then((_) => _loadAvatar()),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child:
            _avatarLoading
                ? SizedBox(
                  width: radius,
                  height: radius,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                )
                : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ? ClipOval(
                  child: Image.network(
                    _avatarUrl!,
                    key: ValueKey(_avatarUrl),
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Icon(
                          Icons.person,
                          color: Colors.black,
                          size: radius,
                        ),
                    loadingBuilder: (_, child, p) {
                      if (p == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value:
                              p.expectedTotalBytes != null
                                  ? p.cumulativeBytesLoaded /
                                      p.expectedTotalBytes!
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

  Widget _buildFooter() {
    return Container(
      height: 36,
      color: const Color(0xFF181818),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: const Text(
        'Harvard 2025 Pet Adoption',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontFamily: 'Montserrat',
        ),
      ),
    );
  }

  Widget _buildBody(double width) {
    final isMobile = width < _kMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGreetingCard(isMobile),
        const SizedBox(height: 16),
        _buildStatsSection(isMobile),
        const SizedBox(height: 20),
        _buildPieRow(width),
        const SizedBox(height: 20),
        _buildAnimalBarChartSection(),
        const SizedBox(height: 20),
        isMobile
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<Map<String, int>>(
                  future: _adoptionFuture,
                  builder:
                      (_, snap) => _trendCard(
                        title: 'Adoption Trends',
                        color: Colors.greenAccent,
                        data: snap.data ?? {},
                        insight: _adoptionInsight(snap.data ?? {}),
                        isLoading:
                            snap.connectionState == ConnectionState.waiting,
                        emptyMsg: 'No adoption data for this period',
                      ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, int>>(
                  future: _donationFuture,
                  builder:
                      (_, snap) => _trendCard(
                        title: 'Donation Activity',
                        color: Colors.amberAccent,
                        data: snap.data ?? {},
                        insight: _donationInsight(snap.data ?? {}),
                        isLoading:
                            snap.connectionState == ConnectionState.waiting,
                        emptyMsg: 'No donation data for this period',
                      ),
                ),
              ],
            )
            : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: FutureBuilder<Map<String, int>>(
                      future: _adoptionFuture,
                      builder:
                          (_, snap) => _trendCard(
                            title: 'Adoption Trends',
                            color: Colors.greenAccent,
                            data: snap.data ?? {},
                            insight: _adoptionInsight(snap.data ?? {}),
                            isLoading:
                                snap.connectionState == ConnectionState.waiting,
                            emptyMsg: 'No adoption data for this period',
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FutureBuilder<Map<String, int>>(
                      future: _donationFuture,
                      builder:
                          (_, snap) => _trendCard(
                            title: 'Donation Activity',
                            color: Colors.amberAccent,
                            data: snap.data ?? {},
                            insight: _donationInsight(snap.data ?? {}),
                            isLoading:
                                snap.connectionState == ConnectionState.waiting,
                            emptyMsg: 'No donation data for this period',
                          ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGreetingCard(bool isMobile) {
    final clockSize = isMobile ? 72.0 : 110.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          isMobile
              ? Row(
                children: [
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _fetchAdminName(),
                      builder:
                          (_, snap) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_greeting,',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                snap.data ?? 'Admin',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                              const SizedBox(height: 12),
                              StreamBuilder(
                                stream: Stream.periodic(
                                  const Duration(seconds: 1),
                                ),
                                builder:
                                    (_, __) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _timeStr,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Montserrat',
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _dateStr,
                                          style: const TextStyle(
                                            color: Colors.white54,
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
                  ),
                  const SizedBox(width: 16),
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(seconds: 1)),
                    builder:
                        (_, __) => SizedBox(
                          width: clockSize,
                          height: clockSize,
                          child: CustomPaint(
                            painter: _AnalogClockPainter(DateTime.now()),
                          ),
                        ),
                  ),
                ],
              )
              : Column(
                children: [
                  FutureBuilder<String>(
                    future: _fetchAdminName(),
                    builder:
                        (_, snap) => Text(
                          '$_greeting, ${snap.data ?? 'Admin'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                          textAlign: TextAlign.center,
                        ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(seconds: 1)),
                    builder:
                        (_, __) => Column(
                          children: [
                            SizedBox(
                              width: clockSize,
                              height: clockSize,
                              child: CustomPaint(
                                painter: _AnalogClockPainter(DateTime.now()),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _timeStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dateStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
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

  Widget _buildPieRow(double width) {
    final isMobile = width < _kMobile;
    final isTablet = width >= _kMobile && width < _kTablet;

    Widget reports = _pieCard(
      child: _buildPieChart(
        label: 'Reports',
        title: 'Reports Overview',
        subtitle: _dashFilter.label,
        future: _reportsFuture,
      ),
    );
    Widget neuter = _pieCard(child: _buildNeuterSpayChart());
    Widget dogCat = _pieCard(child: _buildDogCatChart());

    if (isMobile) {
      return Column(
        children: [
          reports,
          const SizedBox(height: 12),
          neuter,
          const SizedBox(height: 12),
          dogCat,
        ],
      );
    }
    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: reports),
              const SizedBox(width: 12),
              Expanded(child: neuter),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Expanded(child: dogCat)],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: reports),
        const SizedBox(width: 12),
        Expanded(child: neuter),
        const SizedBox(width: 12),
        Expanded(child: dogCat),
      ],
    );
  }

  Widget _pieCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildPieChart({
    required String label,
    required String title,
    required String subtitle,
    required Future<Map<String, int>> future,
  }) {
    const palette = [
      Colors.orangeAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.pinkAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontFamily: 'Montserrat',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: FutureBuilder<Map<String, int>>(
            future: future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: LoadingAnimationWidget.fallingDot(
                    color: Colors.orange,
                    size: 50,
                  ),
                );
              }
              final data = snap.data ?? {};
              final total = data.values.fold<int>(0, (a, b) => a + b);
              if (total == 0) return _emptyPie(label);

              final sections =
                  data.entries.toList().asMap().entries.map((entry) {
                    final idx = entry.key;
                    final e = entry.value;
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      title: '${e.key}\n${e.value}',
                      radius: 50,
                      color: palette[idx % palette.length],
                      titleStyle: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    );
                  }).toList();

              return Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 36,
                      sectionsSpace: 2,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      Text(
                        '$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNeuterSpayChart() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Neuter / Spay',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          _dashFilter.label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontFamily: 'Montserrat',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            _legendDot(Colors.green, 'Neutered ♂'),
            _legendDot(Colors.blue, 'Spayed ♀'),
            _legendDot(Colors.red, 'Not Done'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: FutureBuilder<Map<String, int>>(
            future: _neuterFuture,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: LoadingAnimationWidget.fallingDot(
                    color: Colors.orange,
                    size: 50,
                  ),
                );
              }
              final data = snap.data ?? {};
              final hasData = data.values.any((v) => v > 0);

              if (!hasData) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            color: Colors.grey.withOpacity(0.3),
                            value: 1,
                            showTitle: false,
                            radius: 65,
                          ),
                        ],
                        sectionsSpace: 0,
                        centerSpaceRadius: 0,
                      ),
                    ),
                    const Text(
                      'No Data',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                );
              }

              final sections =
                  data.entries.map((e) {
                    final col =
                        e.key == 'Neutered (Male)'
                            ? Colors.green
                            : e.key == 'Spayed (Female)'
                            ? Colors.blue
                            : Colors.red;
                    return PieChartSectionData(
                      color: col,
                      value: e.value.toDouble(),
                      title: '${e.value}',
                      radius: 65,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    );
                  }).toList();

              return PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDogCatChart() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Pets Statistics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(Colors.blue, 'Dogs'),
            const SizedBox(width: 16),
            _legendDot(Colors.orange, 'Cats'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: FutureBuilder<Map<String, int>>(
            future: _dogCatFuture,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: LoadingAnimationWidget.fallingDot(
                    color: Colors.orange,
                    size: 50,
                  ),
                );
              }
              final data = snap.data ?? {};
              final dogs = data['Dog'] ?? 0;
              final cats = data['Cat'] ?? 0;
              final total = dogs + cats;
              if (total == 0) return _emptyPie('Pets');

              return PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: dogs.toDouble(),
                      color: Colors.blue,
                      radius: 65,
                      title:
                          'Dogs\n${((dogs / total) * 100).toStringAsFixed(1)}%\n($dogs)',
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    PieChartSectionData(
                      value: cats.toDouble(),
                      color: Colors.orange,
                      radius: 65,
                      title:
                          'Cats\n${((cats / total) * 100).toStringAsFixed(1)}%\n($cats)',
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyPie(String label) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: [
              PieChartSectionData(
                value: 1,
                color: Colors.grey.shade700,
                showTitle: false,
                radius: 50,
              ),
            ],
            centerSpaceRadius: 36,
            sectionsSpace: 0,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontFamily: 'Montserrat',
              ),
            ),
            const Text(
              '0',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimalBarChartSection() {
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Animal Population Statistics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    if (_barFilter == 'Custom' && _customBarRange != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('MMM d, yyyy').format(_customBarRange!.start)} – ${DateFormat('MMM d, yyyy').format(_customBarRange!.end)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _legendDot(Colors.blue, 'Dog'),
              const SizedBox(width: 8),
              _legendDot(Colors.orange, 'Cat'),
              const SizedBox(width: 12),
              _buildBarSubFilter(),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, List<FlSpot>>>(
            future: _barSpotsFuture,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: LoadingAnimationWidget.fallingDot(
                      color: Colors.orange,
                      size: 50,
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'Failed to load chart, please check your Internet connection.',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                );
              }
              final dogSpots = snap.data?['Dog'] ?? [];
              final catSpots = snap.data?['Cat'] ?? [];
              if (dogSpots.isEmpty && catSpots.isEmpty) return _emptyBox(200);
              return SizedBox(
                height: 220,
                child: _dogCatBarChart(dogSpots, catSpots),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dogCatBarChart(List<FlSpot> dogSpots, List<FlSpot> catSpots) {
    final allKeys =
        <DateTime>{
            ...dogSpots.map(
              (s) => DateTime.fromMillisecondsSinceEpoch(s.x.toInt()),
            ),
            ...catSpots.map(
              (s) => DateTime.fromMillisecondsSinceEpoch(s.x.toInt()),
            ),
          }.toList()
          ..sort();

    final dogMap = {
      for (final s in dogSpots)
        DateTime.fromMillisecondsSinceEpoch(s.x.toInt()): s.y,
    };
    final catMap = {
      for (final s in catSpots)
        DateTime.fromMillisecondsSinceEpoch(s.x.toInt()): s.y,
    };

    final groups = List.generate(allKeys.length, (i) {
      final key = allKeys[i];
      return BarChartGroupData(
        x: i,
        groupVertically: false,
        barRods: [
          BarChartRodData(
            toY: dogMap[key] ?? 0,
            color: Colors.blue,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: catMap[key] ?? 0,
            color: Colors.orange,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        barsSpace: 3,
      );
    });

    final allValues = [
      ...dogSpots.map((s) => s.y),
      ...catSpots.map((s) => s.y),
    ];
    final maxY =
        allValues.isEmpty
            ? 10.0
            : allValues.reduce((a, b) => a > b ? a : b) * 1.3;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: groups,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.black87,
            getTooltipItem: (group, gi, rod, rodIndex) {
              if (gi < 0 || gi >= allKeys.length) return null;
              final date = allKeys[gi];
              final count = rod.toY.toInt();
              final label = rodIndex == 0 ? '🐶 Dogs' : '🐱 Cats';
              String dateLbl;
              switch (_barFilter) {
                case 'Daily':
                  dateLbl = DateFormat('MMM d, yyyy').format(date);
                  break;
                case 'Weekly':
                  final e = date.add(const Duration(days: 6));
                  dateLbl =
                      '${DateFormat("MMM d").format(date)}–${DateFormat("MMM d").format(e)}';
                  break;
                case 'Monthly':
                  dateLbl = DateFormat('MMMM yyyy').format(date);
                  break;
                case 'Quarterly':
                  final q = ((date.month - 1) ~/ 3) + 1;
                  dateLbl = 'Q$q ${date.year}';
                  break;
                default:
                  dateLbl = DateFormat('yyyy').format(date);
              }
              return BarTooltipItem(
                '$dateLbl\n$label: $count',
                const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine:
              (_) => FlLine(color: Colors.white24, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: _niceIntervalFromValues(allValues),
              getTitlesWidget:
                  (v, _) => Text(
                    v >= 1000
                        ? '${(v / 1000).toStringAsFixed(1)}K'
                        : v.toInt().toString(),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontFamily: 'Montserrat',
                    ),
                    textAlign: TextAlign.right,
                  ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= allKeys.length)
                  return const SizedBox.shrink();
                final date = allKeys[i];
                String lbl;
                switch (_barFilter) {
                  case 'Daily':
                    lbl = DateFormat('MMM d').format(date);
                    break;
                  case 'Weekly':
                    lbl = 'Week ${i + 1}';
                    break;
                  case 'Monthly':
                    lbl = DateFormat('MMM').format(date);
                    break;
                  case 'Quarterly':
                    final q = ((date.month - 1) ~/ 3) + 1;
                    lbl = 'Q$q';
                    break;
                  case 'Yearly':
                    lbl = DateFormat('yyyy').format(date);
                    break;
                  default:
                    lbl = DateFormat('MMM d').format(date);
                }

                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    lbl,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white24),
        ),
      ),
    );
  }

  double _niceIntervalFromValues(List<double> values) {
    if (values.isEmpty) return 1;
    final maxY = values.reduce((a, b) => a > b ? a : b);
    if (maxY <= 5) return 1;
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    return (maxY / 5).ceilToDouble();
  }

  Widget _buildBarSubFilter() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _barFilter,
          isDense: true,
          dropdownColor: const Color(0xFF3A3A3A),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontSize: 12,
          ),
          icon: const Icon(Icons.expand_more, color: Colors.white54, size: 14),
          items:
              [
                'Daily',
                'Weekly',
                'Monthly',
                'Quarterly',
                'Yearly',
                'Custom',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) async {
            if (v == null) return;
            if (v == 'Custom') {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _customBarRange ?? DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 30)),
                  end: DateTime.now(),
                ),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.orange,
                        onPrimary: Colors.white,
                        surface: const Color(0xFF2C2C2C),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _barFilter = v;
                  _customBarRange = picked;
                  _barSpotsFuture = _fetchDogCatBarSpots(_barFilter, picked);
                });
              }
            } else {
              setState(() {
                _barFilter = v;
                _barSpotsFuture = _fetchDogCatBarSpots(
                  _barFilter,
                  DateTimeRange(start: DateTime(2000), end: DateTime(2100)),
                );
              });
            }
          },
        ),
      ),
    );
  }

  double _niceInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 5) return 1;
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    return (maxY / 5).ceilToDouble();
  }

  Widget _buildTrendRow(double width) {
    final isMobile = width < _kMobile;

    final adoption = FutureBuilder<Map<String, int>>(
      future: _adoptionFuture,
      builder:
          (_, snap) => _trendCard(
            title: 'Adoption Trends',
            color: Colors.greenAccent,
            data: snap.data ?? {},
            insight: _adoptionInsight(snap.data ?? {}),
            isLoading: snap.connectionState == ConnectionState.waiting,
            emptyMsg: 'No adoption data for this period',
          ),
    );
    final donation = FutureBuilder<Map<String, int>>(
      future: _donationFuture,
      builder:
          (_, snap) => _trendCard(
            title: 'Donation Activity',
            color: Colors.amberAccent,
            data: snap.data ?? {},
            insight: _donationInsight(snap.data ?? {}),
            isLoading: snap.connectionState == ConnectionState.waiting,
            emptyMsg: 'No donation data for this period',
          ),
    );

    if (isMobile) {
      return Column(children: [adoption, const SizedBox(height: 16), donation]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: adoption),
        const SizedBox(width: 16),
        Expanded(child: donation),
      ],
    );
  }

  Widget _trendCard({
    required String title,
    required Color color,
    required Map<String, int> data,
    required String insight,
    required bool isLoading,
    required String emptyMsg,
  }) {
    if (isLoading) {
      return Container(
        height: 240,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: LoadingAnimationWidget.fallingDot(color: Colors.orange, size: 50),
        ),
      );
    }

    final keys = data.keys.toList();
    final values = data.values.toList();
    final hasData = values.any((v) => v > 0);
    final maxY =
        hasData
            ? values.reduce((a, b) => a > b ? a : b).toDouble() * 1.3
            : 10.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _dashFilter.label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontFamily: 'Montserrat',
            ),
          ),
          if (insight.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                insight,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child:
                hasData
                    ? BarChart(
                      BarChartData(
                        maxY: maxY,
                        barGroups: List.generate(
                          keys.length,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: values[i].toDouble(),
                                color: color,
                                width: 14,
                                borderRadius: BorderRadius.circular(4),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: color.withOpacity(0.06),
                                ),
                              ),
                            ],
                          ),
                        ),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: Colors.black87,
                            getTooltipItem:
                                (g, _, rod, __) => BarTooltipItem(
                                  '${keys[g.x]}\n${rod.toY.toInt()}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Montserrat',
                                    fontSize: 11,
                                  ),
                                ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine:
                              (_) => FlLine(
                                color: Colors.white12,
                                strokeWidth: 0.5,
                              ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= keys.length)
                                  return const SizedBox.shrink();
                                final parts = keys[i].split(' ');
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 4,
                                  child: Text(
                                    parts.isNotEmpty ? parts[0] : keys[i],
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 9,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: (maxY / 4).ceilToDouble(),
                              getTitlesWidget:
                                  (v, _) => Text(
                                    v.toInt().toString(),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 9,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.white12),
                        ),
                      ),
                    )
                    : _emptyBox(160, message: emptyMsg),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    );
  }

  Widget _emptyBox(double height, {String message = 'No data available'}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white38,
            fontFamily: 'Montserrat',
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class WeeklyData {
  final double x;
  final double y;
  final List<DateTime> dates;
  WeeklyData(this.x, this.y, this.dates);
}

class _AnalogClockPainter extends CustomPainter {
  final DateTime time;
  _AnalogClockPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    for (int i = 0; i < 12; i++) {
      final a = i * 30 * Math.pi / 180;
      final main = i % 3 == 0;
      final len = main ? 10.0 : 6.0;
      canvas.drawLine(
        Offset(c.dx + (r - 4) * Math.sin(a), c.dy - (r - 4) * Math.cos(a)),
        Offset(
          c.dx + (r - 4 - len) * Math.sin(a),
          c.dy - (r - 4 - len) * Math.cos(a),
        ),
        Paint()
          ..color = main ? Colors.orange : Colors.white54
          ..strokeWidth = main ? 2.5 : 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    void hand(double angle, double length, double width, Color color) {
      canvas.drawLine(
        c,
        Offset(
          c.dx + length * Math.sin(angle),
          c.dy - length * Math.cos(angle),
        ),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand(
      ((time.hour % 12) + time.minute / 60) * 30 * Math.pi / 180,
      r * 0.50,
      4,
      Colors.white,
    );
    hand(
      (time.minute + time.second / 60) * 6 * Math.pi / 180,
      r * 0.70,
      3,
      Colors.white70,
    );
    hand(time.second * 6 * Math.pi / 180, r * 0.75, 2, Colors.orange);

    canvas.drawCircle(c, 5, Paint()..color = Colors.orange);
    canvas.drawCircle(c, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AnalogClockPainter o) => true;
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
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _notifs = [];
  RealtimeChannel? _ch;

  @override
  void initState() {
    super.initState();
    _load();
    _ch =
        _db
            .channel('notif_bell_${identityHashCode(this)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              callback: (p) {
                if (mounted) setState(() => _notifs.insert(0, p.newRecord));
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'notifications',
              callback: (p) {
                final id = p.oldRecord['id'];
                if (id != null && mounted) {
                  setState(
                    () =>
                        _notifs.removeWhere((n) => n['notification_id'] == id),
                  );
                }
              },
            )
            .subscribe();
  }

  @override
  void dispose() {
    _ch?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _db
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      if (mounted) setState(() => _notifs = List<Map<String, dynamic>>.from(r));
    } catch (e) {
      debugPrint('Bell load error: $e');
    }
  }

  Future<void> _delete(int id) async {
    setState(() => _notifs.removeWhere((n) => n['notification_id'] == id));
    try {
      await _db.from('notifications').delete().eq('notification_id', id);
    } catch (_) {
      await _load();
    }
  }

  String _ago(String? s) {
    if (s == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(s).toLocal());
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      final dt = DateTime.parse(s).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  void _openPanel() {
    final snap = List<Map<String, dynamic>>.from(_notifs);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _NotificationPanel(
            notifications: snap,
            onDelete: _delete,
            onClearAll: () async {
              final ids = _notifs.map((n) => n['notification_id']).toList();
              setState(() => _notifs.clear());
              Navigator.pop(context);
              for (final id in ids) {
                try {
                  await _db
                      .from('notifications')
                      .delete()
                      .eq('notification_id', id);
                } catch (_) {}
              }
            },
            onRefresh: _load,
            timeAgo: _ago,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _notifs.length;
    return GestureDetector(
      onTap: _openPanel,
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

  IconData _icon(String? t) {
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

  Color _color(String? t) {
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
                      itemBuilder: (context, i) {
                        final n = _items[i];
                        final id = n['notification_id'] as int?;
                        final title = n['title'] as String? ?? 'Notification';
                        final msg = n['message'] as String? ?? '';
                        final type = n['type'] as String? ?? 'system';
                        final ago = widget.timeAgo(n['created_at'] as String?);
                        final col = _color(type);

                        return Dismissible(
                          key: ValueKey('pn_${id}_$i'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            setState(() => _items.removeAt(i));
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
                              backgroundColor: col.withOpacity(0.18),
                              child: Icon(_icon(type), color: col, size: 18),
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
                                if (msg.isNotEmpty)
                                  Text(
                                    msg,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontFamily: 'Montserrat',
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (ago.isNotEmpty)
                                  Text(
                                    ago,
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
                                        setState(() => _items.removeAt(i));
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
