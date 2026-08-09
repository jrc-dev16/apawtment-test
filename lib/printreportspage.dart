import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:math' as math;

enum PrintReportType { adoptions, reports, donations, population, all }

enum PrintRangeFilter { daily, weekly, monthly, quarterly, yearly, custom }

enum SectionView { chart, table }

class PrintReportPage extends StatefulWidget {
  const PrintReportPage({super.key});

  @override
  State<PrintReportPage> createState() => _PrintReportPageState();
}

class _PrintReportPageState extends State<PrintReportPage> {
  final supabase = Supabase.instance.client;

  PrintReportType _selectedReportType = PrintReportType.all;
  PrintRangeFilter _selectedRange = PrintRangeFilter.monthly;
  String _reportSubType = 'All';
  bool _isLoading = false;

  // Custom date range
  DateTime? _customStart;
  DateTime? _customEnd;

  SectionView _adoptionView = SectionView.chart;
  SectionView _reportsView = SectionView.chart;
  SectionView _donationsView = SectionView.chart;
  SectionView _populationView = SectionView.chart;

  List<Map<String, dynamic>> _adoptionData = [];
  List<Map<String, dynamic>> _reportData = [];
  List<Map<String, dynamic>> _donationData = [];
  // All pets (no date filter needed — population is a snapshot + trend)
  List<Map<String, dynamic>> _petData = [];

  // ─── Date range helpers ─────────────────────────────────────────────────────

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedRange) {
      case PrintRangeFilter.daily:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 4)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case PrintRangeFilter.weekly:
        final currentWeekMonday = today.subtract(
          Duration(days: today.weekday - 1),
        );
        final prevWeekMonday = currentWeekMonday.subtract(
          const Duration(days: 7),
        );
        final currentWeekEnd = currentWeekMonday.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        final end = currentWeekEnd.isBefore(now) ? currentWeekEnd : now;
        return DateTimeRange(start: prevWeekMonday, end: end);
      case PrintRangeFilter.quarterly:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case PrintRangeFilter.monthly:
        final startMonth = DateTime(now.year, now.month - 5, 1);
        return DateTimeRange(start: startMonth, end: now);
      case PrintRangeFilter.yearly:
        return DateTimeRange(start: DateTime(now.year - 4, 1, 1), end: now);
      case PrintRangeFilter.custom:
        final s = _customStart ?? today;
        final e = _customEnd ?? now;
        return DateTimeRange(start: s, end: e);
    }
  }

  // ─── Period key helpers ──────────────────────────────────────────────────────

  List<String> _allPeriodKeys() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = _getDateRange();

    switch (_selectedRange) {
      case PrintRangeFilter.daily:
        final keys = <String>[];
        var cur = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final endDay = DateTime(now.year, now.month, now.day);
        while (!cur.isAfter(endDay)) {
          keys.add(DateFormat('MMM d').format(cur));
          cur = cur.add(const Duration(days: 1));
        }
        return keys;

      case PrintRangeFilter.weekly:
        final keys = <String>[];
        var cur = range.start;
        while (!cur.isAfter(now)) {
          final isThisWeek =
              !cur.isBefore(today.subtract(Duration(days: today.weekday - 1)));
          final prefix = isThisWeek ? '' : 'Prev ';
          keys.add('$prefix${DateFormat('EEE M/d').format(cur)}');
          cur = cur.add(const Duration(days: 1));
        }
        return keys;

      case PrintRangeFilter.quarterly:
        final currentQ = ((now.month - 1) ~/ 3) + 1;
        return List.generate(currentQ, (i) => 'Q${i + 1}');

      case PrintRangeFilter.monthly:
        final keys = <String>[];
        var cur = DateTime(range.start.year, range.start.month, 1);
        final endMonth = DateTime(now.year, now.month, 1);
        while (!cur.isAfter(endMonth)) {
          keys.add(DateFormat('MMM yyyy').format(cur));
          cur = DateTime(cur.year, cur.month + 1, 1);
        }
        return keys;

      case PrintRangeFilter.yearly:
        return List.generate(5, (i) => '${now.year - 4 + i}');

      case PrintRangeFilter.custom:
        return _customPeriodKeys();
    }
  }

  List<String> _customPeriodKeys() {
    final range = _getDateRange();
    final span = range.end.difference(range.start).inDays;
    final keys = <String>[];

    if (span <= 14) {
      var cur = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      while (!cur.isAfter(end)) {
        keys.add(DateFormat('MMM d').format(cur));
        cur = cur.add(const Duration(days: 1));
      }
    } else if (span <= 90) {
      var cur = _startOfWeek(range.start);
      while (cur.isBefore(range.end)) {
        keys.add('Wk ${DateFormat('M/d').format(cur)}');
        cur = cur.add(const Duration(days: 7));
      }
    } else if (span <= 365) {
      var cur = DateTime(range.start.year, range.start.month, 1);
      final end = DateTime(range.end.year, range.end.month, 1);
      while (!cur.isAfter(end)) {
        keys.add(DateFormat('MMM yy').format(cur));
        cur = DateTime(cur.year, cur.month + 1, 1);
      }
    } else {
      for (var y = range.start.year; y <= range.end.year; y++) {
        keys.add('$y');
      }
    }
    return keys;
  }

  DateTime _startOfWeek(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  String _periodKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedRange) {
      case PrintRangeFilter.daily:
        return DateFormat('MMM d').format(dt);
      case PrintRangeFilter.weekly:
        final thisWeekMonday = today.subtract(
          Duration(days: today.weekday - 1),
        );
        final isThisWeek =
            !DateTime(dt.year, dt.month, dt.day).isBefore(thisWeekMonday);
        final prefix = isThisWeek ? '' : 'Prev ';
        return '$prefix${DateFormat('EEE M/d').format(dt)}';
      case PrintRangeFilter.quarterly:
        final q = ((dt.month - 1) ~/ 3) + 1;
        return 'Q$q';
      case PrintRangeFilter.monthly:
        return DateFormat('MMM yyyy').format(dt);
      case PrintRangeFilter.yearly:
        return '${dt.year}';
      case PrintRangeFilter.custom:
        return _customPeriodKey(dt);
    }
  }

  String _customPeriodKey(DateTime dt) {
    final range = _getDateRange();
    final span = range.end.difference(range.start).inDays;
    if (span <= 14) return DateFormat('MMM d').format(dt);
    if (span <= 90) {
      final wStart = _startOfWeek(dt);
      return 'Wk ${DateFormat('M/d').format(wStart)}';
    }
    if (span <= 365) return DateFormat('MMM yy').format(dt);
    return '${dt.year}';
  }

  // ─── Data fetching ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final range = _getDateRange();
    final start = range.start.toIso8601String();
    final end = range.end.toIso8601String();

    try {
      final adoptions = await supabase
          .from('adoptions')
          .select('*')
          .gte('created_at', start)
          .lte('created_at', end)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> pets = List<Map<String, dynamic>>.from(
        await supabase.from('pets').select('*'),
      );
      final List<Map<String, dynamic>> profiles =
          List<Map<String, dynamic>>.from(
            await supabase.from('profiles').select('*'),
          );

      final merged =
          (adoptions as List).map((a) {
            final aMap = Map<String, dynamic>.from(a as Map);
            Map<String, dynamic>? pet;
            try {
              pet = pets.firstWhere((p) => p['id'] == aMap['pet_id']);
            } catch (_) {}
            Map<String, dynamic>? profile;
            try {
              profile = profiles.firstWhere(
                (p) => p['furparent_id'] == aMap['furparent_id'],
              );
            } catch (_) {}
            return {...aMap, 'pets': pet, 'profiles': profile};
          }).toList();

      final reports = await supabase
          .from('reports')
          .select('*')
          .gte('created_at', start)
          .lte('created_at', end)
          .order('created_at', ascending: false);

      final donations = await supabase
          .from('donations')
          .select('*')
          .eq('status', 'Completed')
          .gte('created_at', start)
          .lte('created_at', end)
          .order('created_at', ascending: false);

      // ── Pet population: fetch pets registered within the selected range
      final petsInRange = await supabase
          .from('pets')
          .select('*')
          .gte('created_at', start)
          .lte('created_at', end)
          .order('created_at', ascending: false);

      setState(() {
        _adoptionData = List<Map<String, dynamic>>.from(merged);
        _reportData = List<Map<String, dynamic>>.from(reports);
        _donationData = List<Map<String, dynamic>>.from(donations);
        _petData = List<Map<String, dynamic>>.from(petsInRange);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching print data: $e');
      setState(() => _isLoading = false);
    }
  }

  // ─── Grouping ─────────────────────────────────────────────────────────────────

  Map<String, int> _groupByPeriod(List<Map<String, dynamic>> data) {
    final result = <String, int>{for (final k in _allPeriodKeys()) k: 0};
    for (final row in data) {
      final dt = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (dt == null) continue;
      final key = _periodKey(dt);
      if (result.containsKey(key)) result[key] = result[key]! + 1;
    }
    return result;
  }

  Map<String, double> _groupDonationsByPeriod() {
    final result = <String, double>{for (final k in _allPeriodKeys()) k: 0.0};
    for (final row in _donationData) {
      final dt = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (dt == null) continue;
      final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0.0;
      final key = _periodKey(dt);
      if (result.containsKey(key)) result[key] = result[key]! + amount;
    }
    return result;
  }

  /// Returns {period: {'cats': N, 'dogs': N}}
  Map<String, Map<String, int>> _groupPetPopulation() {
    final keys = _allPeriodKeys();
    final result = <String, Map<String, int>>{
      for (final k in keys) k: {'cats': 0, 'dogs': 0},
    };

    for (final pet in _petData) {
      final dt = DateTime.tryParse(pet['created_at']?.toString() ?? '');
      if (dt == null) continue;
      final key = _periodKey(dt);
      if (!result.containsKey(key)) continue;
      final type = (pet['type']?.toString() ?? '').toLowerCase();
      if (type == 'cat') {
        result[key]!['cats'] = result[key]!['cats']! + 1;
      } else if (type == 'dog') {
        result[key]!['dogs'] = result[key]!['dogs']! + 1;
      }
    }
    return result;
  }

  // ─── Filtered reports ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredReports {
    if (_reportSubType == 'All') return _reportData;
    return _reportData.where((r) {
      final type = r['type']?.toString() ?? '';
      if (_reportSubType == 'Lost & Found') return type == 'Lost & Found';
      if (_reportSubType == 'Incident Reporting') {
        return type == 'Incident Reporting' || type == 'Report';
      }
      if (_reportSubType == 'Adoption') return type == 'Adoption';
      if (_reportSubType == 'Donation') return type == 'Donation';
      return true;
    }).toList();
  }

  // ─── Labels ───────────────────────────────────────────────────────────────────

  String get _rangeLabel {
    final range = _getDateRange();
    final fmt = DateFormat('MMM d, yyyy');
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }

  String get _rangeModeLabel {
    switch (_selectedRange) {
      case PrintRangeFilter.daily:
        return 'Daily (Last 5 Days)';
      case PrintRangeFilter.weekly:
        return 'Weekly (Prev + Current Week)';
      case PrintRangeFilter.monthly:
        return 'Monthly (Last 6 Months)';
      case PrintRangeFilter.quarterly:
        return 'Quarterly (This Year)';
      case PrintRangeFilter.yearly:
        return 'Yearly (Last 5 Years)';
      case PrintRangeFilter.custom:
        return 'Custom Range';
    }
  }

  String get _reportTypeLabel {
    switch (_selectedReportType) {
      case PrintReportType.adoptions:
        return 'Adoptions';
      case PrintReportType.reports:
        return 'Reports ($_reportSubType)';
      case PrintReportType.donations:
        return 'Donations';
      case PrintReportType.population:
        return 'Animal Population';
      case PrintReportType.all:
        return 'All Data';
    }
  }

  // ─── Custom date picker ────────────────────────────────────────────────────────

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 30)),
        end: _customEnd ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: Colors.black,
              surface: Color(0xFF2A2A2A),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF1C1C1C),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
      _fetchData();
    }
  }

  // ─── PDF helpers ───────────────────────────────────────────────────────────────

  pw.Widget _pdfBarChart({
    required String title,
    required Map<String, num> data,
    required PdfColor barColor,
  }) {
    if (data.isEmpty) {
      return pw.Container(
        height: 100,
        alignment: pw.Alignment.center,
        child: pw.Text(
          'No data',
          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
        ),
      );
    }

    final entries = data.entries.toList();
    final maxVal = entries.map((e) => e.value.toDouble()).reduce(math.max);
    final safeMax = maxVal > 0 ? maxVal : 1.0;
    const double barAreaH = 90.0;
    const double labelH = 20.0;
    const double leftW = 40.0;
    const int gridCount = 4;

    final yAxisCol = pw.SizedBox(
      width: leftW,
      height: barAreaH,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: List.generate(gridCount + 1, (i) {
          final val = safeMax * (gridCount - i) / gridCount;
          final lbl =
              val >= 1000
                  ? '${(val / 1000).toStringAsFixed(1)}K'
                  : val.toStringAsFixed(0);
          return pw.Text(
            lbl,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          );
        }),
      ),
    );

    final barsRow = pw.Expanded(
      child: pw.Column(
        children: [
          pw.SizedBox(
            height: barAreaH,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children:
                  entries.map((entry) {
                    final val = entry.value.toDouble();
                    final barH = ((val / safeMax) * barAreaH).clamp(
                      1.0,
                      barAreaH,
                    );
                    final lbl =
                        val >= 1000
                            ? '${(val / 1000).toStringAsFixed(1)}K'
                            : val.toStringAsFixed(0);
                    return pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                          val > 0 ? lbl : '',
                          style: pw.TextStyle(
                            fontSize: 6.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          width: 14,
                          height: barH,
                          decoration: pw.BoxDecoration(color: barColor),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
          pw.Divider(thickness: 0.6, color: PdfColors.grey400),
          pw.SizedBox(
            height: labelH,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children:
                  entries.map((entry) {
                    return pw.SizedBox(
                      width: 30,
                      child: pw.Text(
                        entry.key,
                        style: const pw.TextStyle(
                          fontSize: 6.5,
                          color: PdfColors.grey700,
                        ),
                        textAlign: pw.TextAlign.center,
                        maxLines: 2,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          height: barAreaH + labelH + 10,
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey50,
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              left: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              right: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
            ),
          ),
          padding: const pw.EdgeInsets.fromLTRB(6, 8, 6, 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [yAxisCol, pw.SizedBox(width: 4), barsRow],
          ),
        ),
      ],
    );
  }

  /// PDF dual-bar chart for cats vs dogs
  pw.Widget _pdfDualBarChart({
    required String title,
    required Map<String, Map<String, int>> data,
  }) {
    if (data.isEmpty) {
      return pw.Container(
        height: 100,
        alignment: pw.Alignment.center,
        child: pw.Text(
          'No data',
          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
        ),
      );
    }

    const PdfColor catColor = PdfColor.fromInt(0xFFED7C3A); // brown
    const PdfColor dogColor = PdfColor.fromInt(0xFFEA580C); // orange

    final entries = data.entries.toList();
    int maxVal = 1;
    for (final e in entries) {
      final cats = e.value['cats'] ?? 0;
      final dogs = e.value['dogs'] ?? 0;
      if (cats > maxVal) maxVal = cats;
      if (dogs > maxVal) maxVal = dogs;
    }
    final safeMax = maxVal.toDouble();
    const double barAreaH = 90.0;
    const double labelH = 20.0;
    const double leftW = 40.0;
    const int gridCount = 4;

    final yAxisCol = pw.SizedBox(
      width: leftW,
      height: barAreaH,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: List.generate(gridCount + 1, (i) {
          final val = safeMax * (gridCount - i) / gridCount;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(right: 4),
            child: pw.Text(
              val.toStringAsFixed(0),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          );
        }),
      ),
    );

    final barsRow = pw.Expanded(
      child: pw.Column(
        children: [
          pw.SizedBox(
            height: barAreaH,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children:
                  entries.map((entry) {
                    final cats = (entry.value['cats'] ?? 0).toDouble();
                    final dogs = (entry.value['dogs'] ?? 0).toDouble();
                    final catH = ((cats / safeMax) * barAreaH).clamp(
                      cats > 0 ? 1.0 : 0.0,
                      barAreaH,
                    );
                    final dogH = ((dogs / safeMax) * barAreaH).clamp(
                      dogs > 0 ? 1.0 : 0.0,
                      barAreaH,
                    );
                    return pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        // Cat bar
                        pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            if (cats > 0)
                              pw.Text(
                                cats.toInt().toString(),
                                style: const pw.TextStyle(
                                  fontSize: 6,
                                  color: PdfColors.deepOrange,
                                ),
                              ),
                            pw.SizedBox(height: 1),
                            pw.Container(
                              width: 10,
                              height: catH,
                              decoration: pw.BoxDecoration(color: catColor),
                            ),
                          ],
                        ),
                        pw.SizedBox(width: 2),
                        // Dog bar
                        pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            if (dogs > 0)
                              pw.Text(
                                dogs.toInt().toString(),
                                style: const pw.TextStyle(
                                  fontSize: 6,
                                  color: PdfColors.orange,
                                ),
                              ),
                            pw.SizedBox(height: 1),
                            pw.Container(
                              width: 10,
                              height: dogH,
                              decoration: pw.BoxDecoration(color: dogColor),
                            ),
                          ],
                        ),
                        pw.SizedBox(width: 6),
                      ],
                    );
                  }).toList(),
            ),
          ),
          pw.Divider(thickness: 0.6, color: PdfColors.grey400),
          pw.SizedBox(
            height: labelH,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children:
                  entries.map((entry) {
                    return pw.SizedBox(
                      width: 38,
                      child: pw.Text(
                        entry.key,
                        style: const pw.TextStyle(
                          fontSize: 6,
                          color: PdfColors.grey700,
                        ),
                        textAlign: pw.TextAlign.center,
                        maxLines: 2,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );

    // Legend
    final legend = pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Container(width: 10, height: 10, color: catColor),
        pw.SizedBox(width: 4),
        pw.Text(
          'Cats',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
        ),
        pw.SizedBox(width: 16),
        pw.Container(width: 10, height: 10, color: dogColor),
        pw.SizedBox(width: 4),
        pw.Text(
          'Dogs',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
        ),
      ],
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 4),
        legend,
        pw.SizedBox(height: 6),
        pw.Container(
          height: barAreaH + labelH + 10,
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey50,
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              left: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              right: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
            ),
          ),
          padding: const pw.EdgeInsets.fromLTRB(6, 8, 6, 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [yAxisCol, pw.SizedBox(width: 4), barsRow],
          ),
        ),
      ],
    );
  }

  Future<pw.Document> _buildPdfDocument() async {
    final doc = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy – h:mm a').format(now);

    pw.Font? ttfRegular, ttfBold;
    try {
      final r = await rootBundle.load('assets/fonts/Montserrat-Regular.ttf');
      final b = await rootBundle.load('assets/fonts/Montserrat-Bold.ttf');
      ttfRegular = pw.Font.ttf(r);
      ttfBold = pw.Font.ttf(b);
    } catch (_) {}

    final theme =
        ttfRegular != null
            ? pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold)
            : pw.ThemeData.base();

    final adoptionCounts = _groupByPeriod(_adoptionData);
    final reportCounts = _groupByPeriod(_filteredReports);
    final donationAmounts = _groupDonationsByPeriod();
    final petPopulation = _groupPetPopulation();
    final totalDonations = _donationData.fold<double>(
      0,
      (s, d) => s + (double.tryParse(d['amount']?.toString() ?? '0') ?? 0),
    );

    // Total cats & dogs in range
    final totalCats =
        _petData
            .where((p) => (p['type']?.toString() ?? '').toLowerCase() == 'cat')
            .length;
    final totalDogs =
        _petData
            .where((p) => (p['type']?.toString() ?? '').toLowerCase() == 'dog')
            .length;

    String viewLabel(SectionView v) =>
        v == SectionView.chart ? 'Chart' : 'Table';
    final viewNote = [
      if (_selectedReportType == PrintReportType.adoptions ||
          _selectedReportType == PrintReportType.all)
        'Adoptions: ${viewLabel(_adoptionView)}',
      if (_selectedReportType == PrintReportType.reports ||
          _selectedReportType == PrintReportType.all)
        'Reports: ${viewLabel(_reportsView)}',
      if (_selectedReportType == PrintReportType.donations ||
          _selectedReportType == PrintReportType.all)
        'Donations: ${viewLabel(_donationsView)}',
      if (_selectedReportType == PrintReportType.population ||
          _selectedReportType == PrintReportType.all)
        'Population: ${viewLabel(_populationView)}',
    ].join('   |   ');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 26),
        theme: theme,
        header:
            (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Apawtment Admin Report',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Type: $_reportTypeLabel',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          'Period: $_rangeLabel',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          'View: $viewNote',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey500,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Printed: $dateStr',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey500,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Harvard 2025 Pet Adoption',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 1.5, color: PdfColors.orange),
                pw.SizedBox(height: 3),
              ],
            ),
        footer:
            (ctx) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Apawtment Admin Report – Confidential',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          // ── Adoptions ──────────────────────────────────────────────────
          if (_selectedReportType == PrintReportType.adoptions ||
              _selectedReportType == PrintReportType.all) {
            final showChart = _adoptionView == SectionView.chart;
            final showTable = _adoptionView == SectionView.table;

            widgets.add(
              _pdfSectionHeader(
                'Adoption Records',
                '${_adoptionData.length} records  ·  ${showChart ? 'Chart' : 'Table'}',
                PdfColors.blue700,
              ),
            );
            widgets.add(pw.SizedBox(height: 10));

            if (showChart) {
              widgets.add(
                _pdfBarChart(
                  title: 'Adoptions Over Time',
                  data: adoptionCounts,
                  barColor: PdfColors.blue400,
                ),
              );
              final statusMap = <String, int>{};
              for (final r in _adoptionData) {
                final s = r['status']?.toString() ?? 'Unknown';
                statusMap[s] = (statusMap[s] ?? 0) + 1;
              }
              if (statusMap.isNotEmpty) {
                widgets.add(pw.SizedBox(height: 8));
                widgets.add(
                  _pdfSummaryRow(
                    statusMap.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('   '),
                  ),
                );
              }
            }

            if (showTable) {
              widgets.add(
                _adoptionData.isEmpty
                    ? _pdfEmptyNote('No adoption records for this period.')
                    : _pdfAdoptionTable(_adoptionData),
              );
            }

            widgets.add(pw.SizedBox(height: 22));
          }

          // ── Reports ────────────────────────────────────────────────────
          if (_selectedReportType == PrintReportType.reports ||
              _selectedReportType == PrintReportType.all) {
            final filtered = _filteredReports;
            final showChart = _reportsView == SectionView.chart;
            final showTable = _reportsView == SectionView.table;

            widgets.add(
              _pdfSectionHeader(
                'Report Records',
                '${filtered.length} records  ·  ${showChart ? 'Chart' : 'Table'}',
                PdfColors.red700,
              ),
            );
            widgets.add(pw.SizedBox(height: 10));

            if (showChart) {
              widgets.add(
                _pdfBarChart(
                  title: 'Reports Over Time',
                  data: reportCounts,
                  barColor: PdfColors.red400,
                ),
              );
              final typeMap = <String, int>{};
              for (final r in filtered) {
                final t = r['type']?.toString() ?? 'Unknown';
                typeMap[t] = (typeMap[t] ?? 0) + 1;
              }
              if (typeMap.isNotEmpty) {
                widgets.add(pw.SizedBox(height: 8));
                widgets.add(
                  _pdfSummaryRow(
                    typeMap.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('   '),
                  ),
                );
              }
            }

            if (showTable) {
              widgets.add(
                filtered.isEmpty
                    ? _pdfEmptyNote('No report records for this period.')
                    : _pdfReportTable(filtered),
              );
            }

            widgets.add(pw.SizedBox(height: 22));
          }

          // ── Donations ──────────────────────────────────────────────────
          if (_selectedReportType == PrintReportType.donations ||
              _selectedReportType == PrintReportType.all) {
            final showChart = _donationsView == SectionView.chart;
            final showTable = _donationsView == SectionView.table;

            widgets.add(
              _pdfSectionHeader(
                'Donation Records',
                '${_donationData.length} records  ·  '
                    'Total: ₱${totalDonations.toStringAsFixed(2)}  ·  ${showChart ? 'Chart' : 'Table'}',
                PdfColors.orange,
              ),
            );
            widgets.add(pw.SizedBox(height: 10));

            if (showChart) {
              widgets.add(
                _pdfBarChart(
                  title: 'Donations Over Time (₱)',
                  data: donationAmounts,
                  barColor: PdfColors.orange,
                ),
              );
            }

            if (showTable) {
              widgets.add(
                _donationData.isEmpty
                    ? _pdfEmptyNote('No donation records for this period.')
                    : _pdfDonationTable(_donationData, totalDonations),
              );
            }

            widgets.add(pw.SizedBox(height: 22));
          }

          // ── Animal Population ──────────────────────────────────────────
          if (_selectedReportType == PrintReportType.population ||
              _selectedReportType == PrintReportType.all) {
            final showChart = _populationView == SectionView.chart;
            final showTable = _populationView == SectionView.table;

            widgets.add(
              _pdfSectionHeader(
                'Animal Population',
                'Cats: $totalCats  ·  Dogs: $totalDogs  ·  ${showChart ? 'Chart' : 'Table'}',
                const PdfColor.fromInt(0xFFEA580C),
              ),
            );
            widgets.add(pw.SizedBox(height: 10));

            if (showChart) {
              widgets.add(
                _pdfDualBarChart(
                  title: 'Cats & Dogs Registered Over Time',
                  data: petPopulation,
                ),
              );
            }

            if (showTable) {
              widgets.add(
                _petData.isEmpty
                    ? _pdfEmptyNote('No pet records for this period.')
                    : _pdfPopulationTable(petPopulation),
              );
            }
          }

          return widgets;
        },
      ),
    );

    return doc;
  }

  // ─── PDF section widgets ──────────────────────────────────────────────────────

  pw.Widget _pdfSectionHeader(String title, String sub, PdfColor accent) {
    return pw.Container(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      child: pw.Row(
        children: [
          pw.Container(width: 4, height: 34, color: accent),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  sub,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryRow(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: const pw.BoxDecoration(color: PdfColors.grey50),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
    ),
  );

  pw.Widget _pdfEmptyNote(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
    ),
  );

  pw.Widget _pdfAdoptionTable(List<Map<String, dynamic>> data) {
    return pw.TableHelper.fromTextArray(
      headers: ['#', 'Pet Name', 'Type', 'Adopter', 'Status', 'Date'],
      data:
          data.asMap().entries.map((e) {
            final row = e.value;
            final pet = row['pets'] as Map<String, dynamic>?;
            final profile = row['profiles'] as Map<String, dynamic>?;
            return [
              '${e.key + 1}',
              pet?['pet_name']?.toString() ?? '—',
              pet?['type']?.toString() ?? '—',
              profile != null
                  ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                      .trim()
                  : row['furparent_name']?.toString() ?? '—',
              row['status']?.toString() ?? '—',
              row['created_at'] != null
                  ? DateFormat(
                    'MMM d, yyyy',
                  ).format(DateTime.parse(row['created_at'].toString()))
                  : '—',
            ];
          }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(0.9),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.1),
        5: const pw.FlexColumnWidth(1.4),
      },
    );
  }

  pw.Widget _pdfReportTable(List<Map<String, dynamic>> data) {
    return pw.TableHelper.fromTextArray(
      headers: ['#', 'Type', 'Description', 'Status', 'Date'],
      data:
          data.asMap().entries.map((e) {
            final row = e.value;
            final desc =
                (row['description'] ?? row['content'] ?? '—').toString();
            return [
              '${e.key + 1}',
              row['type']?.toString() ?? '—',
              desc.length > 70 ? '${desc.substring(0, 70)}...' : desc,
              row['status']?.toString() ?? '—',
              row['created_at'] != null
                  ? DateFormat(
                    'MMM d, yyyy',
                  ).format(DateTime.parse(row['created_at'].toString()))
                  : '—',
            ];
          }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.red50),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(3.2),
        3: const pw.FlexColumnWidth(1.1),
        4: const pw.FlexColumnWidth(1.4),
      },
    );
  }

  pw.Widget _pdfDonationTable(List<Map<String, dynamic>> data, double total) {
    final table = pw.TableHelper.fromTextArray(
      headers: ['#', 'Donor', 'Amount (₱)', 'Reference', 'Date'],
      data:
          data.asMap().entries.map((e) {
            final row = e.value;
            final amount =
                double.tryParse(row['amount']?.toString() ?? '0') ?? 0.0;
            return [
              '${e.key + 1}',
              row['furparent_name']?.toString() ?? 'Anonymous',
              amount.toStringAsFixed(2),
              row['reference_number']?.toString() ?? '—',
              row['created_at'] != null
                  ? DateFormat(
                    'MMM d, yyyy',
                  ).format(DateTime.parse(row['created_at'].toString()))
                  : '—',
            ];
          }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.orange50),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.4),
      },
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        table,
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: const pw.BoxDecoration(color: PdfColors.orange),
          child: pw.Text(
            'Total Donations: ₱${total.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// PDF table for animal population — one row per period
  pw.Widget _pdfPopulationTable(Map<String, Map<String, int>> data) {
    return pw.TableHelper.fromTextArray(
      headers: ['Period', 'Cats', 'Dogs', 'Total'],
      data:
          data.entries.map((e) {
            final cats = e.value['cats'] ?? 0;
            final dogs = e.value['dogs'] ?? 0;
            return [e.key, '$cats', '$dogs', '${cats + dogs}'];
          }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFEA580C),
      ),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF5F3FF),
      ),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
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

  Future<void> _showPrintPreview() async {
    setState(() => _isLoading = true);
    pw.Document? doc;
    try {
      doc = await _buildPdfDocument();
    } catch (e) {
      debugPrint('PDF build error: $e');
      if (mounted) {
        _showSnackBar('Failed to build PDF.', Colors.red);
      }
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = false);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PrintPreviewScreen(doc: doc!),
        fullscreenDialog: true,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF101510),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1C),
        foregroundColor: Colors.white,
        title: const Text(
          'Print Report',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _showPrintPreview,
              icon:
                  _isLoading
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                      : const Icon(Icons.print, size: 18),
              label: Text(
                _isLoading ? 'Preparing...' : 'Print / Save PDF',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter bar ───────────────────────────────────────────────────
          Container(
            color: const Color(0xFF1C1C1C),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child:
                isMobile
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReportTypeFilter(),
                        const SizedBox(height: 10),
                        _buildRangeFilter(),
                        if (_selectedRange == PrintRangeFilter.custom) ...[
                          const SizedBox(height: 10),
                          _buildCustomDatePicker(),
                        ],
                        if (_selectedReportType == PrintReportType.reports ||
                            _selectedReportType == PrintReportType.all) ...[
                          const SizedBox(height: 10),
                          _buildSubTypeFilter(),
                        ],
                      ],
                    )
                    : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildReportTypeFilter()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildRangeFilter()),
                            if (_selectedReportType ==
                                    PrintReportType.reports ||
                                _selectedReportType == PrintReportType.all) ...[
                              const SizedBox(width: 12),
                              Expanded(child: _buildSubTypeFilter()),
                            ],
                          ],
                        ),
                        if (_selectedRange == PrintRangeFilter.custom) ...[
                          const SizedBox(height: 10),
                          _buildCustomDatePicker(),
                        ],
                      ],
                    ),
          ),

          // ── Period info bar ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: const Color(0xFF181818),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.orange,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_rangeModeLabel  ·  $_rangeLabel  ·  $_reportTypeLabel',
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

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedReportType ==
                                  PrintReportType.adoptions ||
                              _selectedReportType == PrintReportType.all) ...[
                            _buildPreviewSection(
                              title: 'Adoption Records',
                              count: _adoptionData.length,
                              icon: Icons.pets,
                              color: Colors.blue,
                              chartWidget: _buildFlutterBarChart(
                                label: 'Adoptions Over Time',
                                data: _groupByPeriod(
                                  _adoptionData,
                                ).map((k, v) => MapEntry(k, v.toDouble())),
                                barColor: Colors.blue,
                              ),
                              currentView: _adoptionView,
                              onViewChanged:
                                  (v) => setState(() => _adoptionView = v),
                              tableChild: _buildAdoptionPreviewTable(),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (_selectedReportType == PrintReportType.reports ||
                              _selectedReportType == PrintReportType.all) ...[
                            _buildPreviewSection(
                              title: 'Report Records',
                              count: _filteredReports.length,
                              icon: Icons.report,
                              color: Colors.redAccent,
                              chartWidget: _buildFlutterBarChart(
                                label: 'Reports Over Time',
                                data: _groupByPeriod(
                                  _filteredReports,
                                ).map((k, v) => MapEntry(k, v.toDouble())),
                                barColor: Colors.redAccent,
                              ),
                              currentView: _reportsView,
                              onViewChanged:
                                  (v) => setState(() => _reportsView = v),
                              tableChild: _buildReportPreviewTable(),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (_selectedReportType ==
                                  PrintReportType.donations ||
                              _selectedReportType == PrintReportType.all) ...[
                            _buildPreviewSection(
                              title: 'Donation Records',
                              count: _donationData.length,
                              icon: Icons.volunteer_activism,
                              color: Colors.orange,
                              chartWidget: _buildFlutterBarChart(
                                label: 'Donations Over Time (₱)',
                                data: _groupDonationsByPeriod(),
                                barColor: Colors.orange,
                              ),
                              currentView: _donationsView,
                              onViewChanged:
                                  (v) => setState(() => _donationsView = v),
                              tableChild: _buildDonationPreviewTable(),
                            ),
                            const SizedBox(height: 20),
                          ],
                          // ── Animal Population ──────────────────────────
                          if (_selectedReportType ==
                                  PrintReportType.population ||
                              _selectedReportType == PrintReportType.all) ...[
                            _buildPreviewSection(
                              title: 'Animal Population',
                              count: _petData.length,
                              icon: Icons.monitor_heart_outlined,
                              color: const Color(0xFFEA580C),
                              chartWidget: _buildDualBarChart(),
                              currentView: _populationView,
                              onViewChanged:
                                  (v) => setState(() => _populationView = v),
                              tableChild: _buildPopulationPreviewTable(),
                            ),
                          ],
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // ─── Filter widgets ───────────────────────────────────────────────────────────

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String label,
  }) {
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
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontSize: 13,
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportTypeFilter() => _buildDropdown<PrintReportType>(
    label: 'Report Type',
    value: _selectedReportType,
    items: const [
      DropdownMenuItem(value: PrintReportType.all, child: Text('All Data')),
      DropdownMenuItem(
        value: PrintReportType.adoptions,
        child: Text('Adoptions'),
      ),
      DropdownMenuItem(value: PrintReportType.reports, child: Text('Reports')),
      DropdownMenuItem(
        value: PrintReportType.donations,
        child: Text('Donations'),
      ),
      DropdownMenuItem(
        value: PrintReportType.population,
        child: Text('Animal Population'),
      ),
    ],
    onChanged: (v) {
      if (v != null) setState(() => _selectedReportType = v);
    },
  );

  Widget _buildRangeFilter() => _buildDropdown<PrintRangeFilter>(
    label: 'Time Period',
    value: _selectedRange,
    items: const [
      DropdownMenuItem(
        value: PrintRangeFilter.daily,
        child: Text('Daily  (Last 5 Days)'),
      ),
      DropdownMenuItem(
        value: PrintRangeFilter.weekly,
        child: Text('Weekly  (Prev + This Week)'),
      ),
      DropdownMenuItem(
        value: PrintRangeFilter.monthly,
        child: Text('Monthly  (Last 6 Months)'),
      ),
      DropdownMenuItem(
        value: PrintRangeFilter.quarterly,
        child: Text('Quarterly  (This Year)'),
      ),
      DropdownMenuItem(
        value: PrintRangeFilter.yearly,
        child: Text('Yearly  (Last 5 Years)'),
      ),
      DropdownMenuItem(
        value: PrintRangeFilter.custom,
        child: Text('Custom Date Range'),
      ),
    ],
    onChanged: (v) {
      if (v != null) {
        setState(() => _selectedRange = v);
        if (v != PrintRangeFilter.custom) _fetchData();
      }
    },
  );

  Widget _buildSubTypeFilter() => _buildDropdown<String>(
    label: 'Report Sub-Type',
    value: _reportSubType,
    items: const [
      DropdownMenuItem(value: 'All', child: Text('All Types')),
      DropdownMenuItem(value: 'Lost & Found', child: Text('Lost & Found')),
      DropdownMenuItem(
        value: 'Incident Reporting',
        child: Text('Incident Reporting'),
      ),
      DropdownMenuItem(value: 'Adoption', child: Text('Adoption')),
      DropdownMenuItem(value: 'Donation', child: Text('Donation')),
    ],
    onChanged: (v) {
      if (v != null) setState(() => _reportSubType = v);
    },
  );

  Widget _buildCustomDatePicker() {
    final fmt = DateFormat('MMM d, yyyy');
    final startLabel =
        _customStart != null ? fmt.format(_customStart!) : 'Start Date';
    final endLabel = _customEnd != null ? fmt.format(_customEnd!) : 'End Date';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom Date Range',
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$startLabel  →  $endLabel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _pickCustomRange,
            icon: const Icon(
              Icons.edit_calendar,
              color: Colors.orange,
              size: 16,
            ),
            label: const Text(
              'Change',
              style: TextStyle(
                color: Colors.orange,
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          if (_customStart != null && _customEnd != null) ...[
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Chart helpers ────────────────────────────────────────────────────────────

  static const double _barAreaH = 180.0;
  static const double _xLabelH = 40.0;
  static const double _yAxisW = 46.0;
  static const double _minColW = 48.0;
  static const double _maxBarW = 32.0;
  static const double _minBarW = 8.0;
  static const double _valLabelH = 16.0;

  Widget _buildFlutterBarChart({
    required String label,
    required Map<String, double> data,
    required Color barColor,
  }) {
    if (data.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const Text(
          'No data for this period',
          style: TextStyle(
            color: Colors.white38,
            fontFamily: 'Montserrat',
            fontSize: 12,
          ),
        ),
      );
    }

    final entries = data.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce(math.max);
    final safeMax = maxVal > 0 ? maxVal : 1.0;
    const double usableBarH = _barAreaH - _valLabelH - 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final availW = constraints.maxWidth - _yAxisW - 24;
            final naturalW = entries.length * _minColW;
            final needsScroll = naturalW > availW;
            final barAreaW = needsScroll ? naturalW : availW;
            final colW = barAreaW / entries.length;
            final barRectW = (colW * 0.50).clamp(_minBarW, _maxBarW);

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _yAxisW,
                    height: _barAreaH + 8 + _xLabelH,
                    child: Column(
                      children: [
                        SizedBox(
                          height: _barAreaH,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(5, (i) {
                              final val = safeMax * (4 - i) / 4;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  _fmtVal(val),
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 9,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 8 + _xLabelH),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics:
                          needsScroll
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: barAreaW,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: _barAreaH,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children:
                                    entries.map((entry) {
                                      final val = entry.value;
                                      final barH =
                                          ((val / safeMax) * usableBarH).clamp(
                                            val > 0 ? 2.0 : 0.0,
                                            usableBarH,
                                          );
                                      return SizedBox(
                                        width: colW,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            SizedBox(
                                              height: _valLabelH,
                                              child:
                                                  val > 0
                                                      ? Center(
                                                        child: Text(
                                                          _fmtVal(val),
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          maxLines: 1,
                                                          style: TextStyle(
                                                            color: barColor
                                                                .withOpacity(
                                                                  0.9,
                                                                ),
                                                            fontSize: 9,
                                                            fontFamily:
                                                                'Montserrat',
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      )
                                                      : const SizedBox.shrink(),
                                            ),
                                            const SizedBox(height: 4),
                                            Center(
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                curve: Curves.easeOut,
                                                width: barRectW,
                                                height: barH,
                                                decoration: BoxDecoration(
                                                  color: barColor.withOpacity(
                                                    0.85,
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(5),
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: Colors.white24,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            SizedBox(
                              height: _xLabelH,
                              child: Row(
                                children:
                                    entries.map((entry) {
                                      return SizedBox(
                                        width: colW,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Text(
                                            entry.key,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 9,
                                              fontFamily: 'Montserrat',
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (data.length > 10) ...[
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chevron_left, color: Colors.white24, size: 14),
              Text(
                '  scroll to see all  ',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontFamily: 'Montserrat',
                  fontStyle: FontStyle.italic,
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white24, size: 14),
            ],
          ),
        ],
      ],
    );
  }

  /// Flutter dual-bar chart for cats 🐱 vs dogs 🐶
  Widget _buildDualBarChart() {
    final population = _groupPetPopulation();
    if (population.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const Text(
          'No pet data for this period',
          style: TextStyle(
            color: Colors.white38,
            fontFamily: 'Montserrat',
            fontSize: 12,
          ),
        ),
      );
    }

    const Color catColor = Color(0xFFED7C3A); // purple
    const Color dogColor = Color(0xFFEA580C); // orange

    final entries = population.entries.toList();
    int maxVal = 1;
    for (final e in entries) {
      final c = e.value['cats'] ?? 0;
      final d = e.value['dogs'] ?? 0;
      if (c > maxVal) maxVal = c;
      if (d > maxVal) maxVal = d;
    }
    final safeMax = maxVal.toDouble();
    const double usableBarH = _barAreaH - _valLabelH - 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Cats & Dogs Registered Over Time',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Legend
        Row(
          children: [
            _legendDot(catColor, '🐱  Cats'),
            const SizedBox(width: 20),
            _legendDot(dogColor, '🐶  Dogs'),
          ],
        ),
        const SizedBox(height: 10),
        // Chart
        LayoutBuilder(
          builder: (context, constraints) {
            // Each group = cat bar + gap + dog bar + padding
            const double groupW = 56.0;
            final naturalW = entries.length * groupW;
            final availW = constraints.maxWidth - _yAxisW - 24;
            final needsScroll = naturalW > availW;
            final chartW = needsScroll ? naturalW : availW;
            final colW = chartW / entries.length;
            const double barW = 14.0;

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Y-axis
                  SizedBox(
                    width: _yAxisW,
                    height: _barAreaH + 8 + _xLabelH,
                    child: Column(
                      children: [
                        SizedBox(
                          height: _barAreaH,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(5, (i) {
                              final val = safeMax * (4 - i) / 4;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  _fmtVal(val),
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 9,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 8 + _xLabelH),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Bars
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics:
                          needsScroll
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: chartW,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: _barAreaH,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children:
                                    entries.map((entry) {
                                      final cats =
                                          (entry.value['cats'] ?? 0).toDouble();
                                      final dogs =
                                          (entry.value['dogs'] ?? 0).toDouble();
                                      final catH =
                                          ((cats / safeMax) * usableBarH).clamp(
                                            cats > 0 ? 2.0 : 0.0,
                                            usableBarH,
                                          );
                                      final dogH =
                                          ((dogs / safeMax) * usableBarH).clamp(
                                            dogs > 0 ? 2.0 : 0.0,
                                            usableBarH,
                                          );

                                      return SizedBox(
                                        width: colW,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            // Cat bar
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                if (cats > 0)
                                                  Text(
                                                    cats.toInt().toString(),
                                                    style: const TextStyle(
                                                      color: catColor,
                                                      fontSize: 8,
                                                      fontFamily: 'Montserrat',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                const SizedBox(height: 2),
                                                AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 400,
                                                  ),
                                                  curve: Curves.easeOut,
                                                  width: barW,
                                                  height: catH,
                                                  decoration: BoxDecoration(
                                                    color: catColor.withOpacity(
                                                      0.85,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            4,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 3),
                                            // Dog bar
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                if (dogs > 0)
                                                  Text(
                                                    dogs.toInt().toString(),
                                                    style: const TextStyle(
                                                      color: dogColor,
                                                      fontSize: 8,
                                                      fontFamily: 'Montserrat',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                const SizedBox(height: 2),
                                                AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 400,
                                                  ),
                                                  curve: Curves.easeOut,
                                                  width: barW,
                                                  height: dogH,
                                                  decoration: BoxDecoration(
                                                    color: dogColor.withOpacity(
                                                      0.85,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            4,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: Colors.white24,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            SizedBox(
                              height: _xLabelH,
                              child: Row(
                                children:
                                    entries.map((entry) {
                                      return SizedBox(
                                        width: colW,
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 9,
                                            fontFamily: 'Montserrat',
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Totals summary row
        const SizedBox(height: 8),
        _buildPopulationSummaryChip(),
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontFamily: 'Montserrat',
          fontSize: 12,
        ),
      ),
    ],
  );

  Widget _buildPopulationSummaryChip() {
    final totalCats =
        _petData
            .where((p) => (p['type']?.toString() ?? '').toLowerCase() == 'cat')
            .length;
    final totalDogs =
        _petData
            .where((p) => (p['type']?.toString() ?? '').toLowerCase() == 'dog')
            .length;
    final other = _petData.length - totalCats - totalDogs;

    return Wrap(
      spacing: 10,
      children: [
        _summaryChip('🐱 Cats', totalCats, const Color(0xFFED7C3A)),
        _summaryChip('🐶 Dogs', totalDogs, const Color(0xFFEA580C)),
        if (other > 0) _summaryChip('Other', other, Colors.white38),
      ],
    );
  }

  Widget _summaryChip(String label, int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Text(
      '$label: $count',
      style: TextStyle(
        color: color,
        fontFamily: 'Montserrat',
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  String _fmtVal(double val) {
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  // ─── Preview section container ────────────────────────────────────────────────

  Widget _buildPreviewSection({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Widget chartWidget,
    required SectionView currentView,
    required ValueChanged<SectionView> onViewChanged,
    required Widget tableChild,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(
                    '$count records',
                    style: TextStyle(
                      color: color,
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                _buildViewToggle(
                  currentView: currentView,
                  onViewChanged: onViewChanged,
                  color: color,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                count == 0
                    ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No records found for this period.',
                          style: TextStyle(
                            color: Colors.white38,
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                    : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child:
                          currentView == SectionView.chart
                              ? KeyedSubtree(
                                key: const ValueKey('chart'),
                                child: chartWidget,
                              )
                              : KeyedSubtree(
                                key: const ValueKey('table'),
                                child: tableChild,
                              ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle({
    required SectionView currentView,
    required ValueChanged<SectionView> onViewChanged,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn(
            icon: Icons.bar_chart,
            label: 'Chart',
            selected: currentView == SectionView.chart,
            selectedColor: color,
            onTap: () => onViewChanged(SectionView.chart),
          ),
          Container(width: 1, height: 28, color: Colors.white12),
          _toggleBtn(
            icon: Icons.table_rows_rounded,
            label: 'Table',
            selected: currentView == SectionView.table,
            selectedColor: color,
            onTap: () => onViewChanged(SectionView.table),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn({
    required IconData icon,
    required String label,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? selectedColor.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? selectedColor : Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? selectedColor : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Table preview widgets ────────────────────────────────────────────────────

  List<DataColumn> _cols(List<String> labels) =>
      labels
          .map(
            (l) => DataColumn(
              label: Text(
                l,
                style: TextStyle(
                  color: l == '#' ? Colors.white54 : Colors.white,
                  fontFamily: 'Montserrat',
                  fontWeight: l == '#' ? FontWeight.normal : FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          )
          .toList();

  DataCell _cell(String t, {Color c = Colors.white}) => DataCell(
    Text(t, style: TextStyle(color: c, fontFamily: 'Montserrat', fontSize: 12)),
  );

  Widget _buildAdoptionPreviewTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF2A2A2A)),
        dataRowColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? Colors.orange.withOpacity(0.1)
                  : const Color(0xFF1A1A1A),
        ),
        columnSpacing: 20,
        columns: _cols(['#', 'Pet Name', 'Type', 'Adopter', 'Status', 'Date']),
        rows:
            _adoptionData.asMap().entries.map((e) {
              final row = e.value;
              final pet = row['pets'] as Map<String, dynamic>?;
              final profile = row['profiles'] as Map<String, dynamic>?;
              final status = row['status']?.toString() ?? '—';
              Color sc = Colors.white54;
              if (status == 'Approved') sc = Colors.green;
              if (status == 'Pending') sc = Colors.orange;
              if (status == 'Rejected') sc = Colors.red;
              return DataRow(
                cells: [
                  _cell('${e.key + 1}', c: Colors.white38),
                  _cell(pet?['pet_name']?.toString() ?? '—'),
                  _cell(pet?['type']?.toString() ?? '—', c: Colors.white70),
                  _cell(
                    profile != null
                        ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                            .trim()
                        : row['furparent_name']?.toString() ?? '—',
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sc.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: sc,
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  _cell(
                    row['created_at'] != null
                        ? DateFormat(
                          'MMM d, yyyy',
                        ).format(DateTime.parse(row['created_at'].toString()))
                        : '—',
                    c: Colors.white54,
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildReportPreviewTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF2A2A2A)),
        dataRowColor: WidgetStateProperty.resolveWith(
          (_) => const Color(0xFF1A1A1A),
        ),
        columnSpacing: 20,
        columns: _cols(['#', 'Type', 'Description', 'Status', 'Date']),
        rows:
            _filteredReports.asMap().entries.map((e) {
              final row = e.value;
              final type = row['type']?.toString() ?? '—';
              final desc =
                  (row['description'] ?? row['content'] ?? '—').toString();
              Color tc = Colors.white54;
              if (type == 'Lost & Found') tc = Colors.blueAccent;
              if (type == 'Incident Reporting' || type == 'Report') {
                tc = Colors.redAccent;
              }
              if (type == 'Adoption') tc = Colors.green;
              if (type == 'Donation') tc = Colors.orange;
              return DataRow(
                cells: [
                  _cell('${e.key + 1}', c: Colors.white38),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tc.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: tc,
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 220,
                      child: Text(
                        desc.length > 50 ? '${desc.substring(0, 50)}...' : desc,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  _cell(row['status']?.toString() ?? '—', c: Colors.white54),
                  _cell(
                    row['created_at'] != null
                        ? DateFormat(
                          'MMM d, yyyy',
                        ).format(DateTime.parse(row['created_at'].toString()))
                        : '—',
                    c: Colors.white54,
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildDonationPreviewTable() {
    final total = _donationData.fold<double>(
      0,
      (s, d) => s + (double.tryParse(d['amount']?.toString() ?? '0') ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFF2A2A2A)),
            dataRowColor: WidgetStateProperty.resolveWith(
              (_) => const Color(0xFF1A1A1A),
            ),
            columnSpacing: 20,
            columns: _cols(['#', 'Donor', 'Amount (₱)', 'Reference', 'Date']),
            rows:
                _donationData.asMap().entries.map((e) {
                  final row = e.value;
                  final amount =
                      double.tryParse(row['amount']?.toString() ?? '0') ?? 0.0;
                  return DataRow(
                    cells: [
                      _cell('${e.key + 1}', c: Colors.white38),
                      _cell(row['furparent_name']?.toString() ?? 'Anonymous'),
                      DataCell(
                        Text(
                          '₱${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _cell(
                        row['reference_number']?.toString() ?? '—',
                        c: Colors.white54,
                      ),
                      _cell(
                        row['created_at'] != null
                            ? DateFormat('MMM d, yyyy').format(
                              DateTime.parse(row['created_at'].toString()),
                            )
                            : '—',
                        c: Colors.white54,
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: Text(
            'Total: ₱${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.orange,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  /// Flutter table for animal population per period
  Widget _buildPopulationPreviewTable() {
    final population = _groupPetPopulation();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF2A2A2A)),
        dataRowColor: WidgetStateProperty.resolveWith(
          (_) => const Color(0xFF1A1A1A),
        ),
        columnSpacing: 20,
        columns: _cols(['Period', 'Cats 🐱', 'Dogs 🐶', 'Total']),
        rows:
            population.entries.map((e) {
              final cats = e.value['cats'] ?? 0;
              final dogs = e.value['dogs'] ?? 0;
              final total = cats + dogs;
              return DataRow(
                cells: [
                  _cell(e.key, c: Colors.white70),
                  DataCell(
                    Text(
                      '$cats',
                      style: const TextStyle(
                        color: Color(0xFFED7C3A),
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '$dogs',
                      style: const TextStyle(
                        color: Color(0xFFEA580C),
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _cell('$total'),
                ],
              );
            }).toList(),
      ),
    );
  }
}

// ─── Print Preview Screen ──────────────────────────────────────────────────────

class _PrintPreviewScreen extends StatelessWidget {
  final pw.Document doc;
  const _PrintPreviewScreen({required this.doc});

  @override
  Widget build(BuildContext context) {
    final fileName =
        'Apawtment_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    return Scaffold(
      backgroundColor: const Color(0xFF101510),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1C),
        foregroundColor: Colors.white,
        title: const Text(
          'Print Preview',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton.icon(
              onPressed: () async {
                await Printing.layoutPdf(
                  onLayout: (_) async => doc.save(),
                  name: fileName,
                );
              },
              icon: const Icon(Icons.print, color: Colors.white, size: 18),
              label: const Text(
                'Print',
                style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Printing.sharePdf(
                  bytes: await doc.save(),
                  filename: fileName,
                );
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text(
                'Download / Share',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => doc.save(),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: true,
        canChangePageFormat: true,
        canDebug: false,
        pdfFileName: fileName,
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 12),
              Text(
                'Rendering PDF…',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
