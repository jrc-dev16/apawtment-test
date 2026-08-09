import 'dart:convert';

import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';
import 'package:apawtmentweb_admin/dashboardpage.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/main.dart';
import 'package:apawtmentweb_admin/medicationspage.dart';
import 'package:apawtmentweb_admin/notificationpage.dart';
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:apawtmentweb_admin/networkimage.dart'
    if (dart.library.io) 'package:apawtmentweb_admin/networkimage_stub.dart';
import 'package:apawtmentweb_admin/shelterprojectspage.dart';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:html' as html;

import 'package:supabase_flutter/supabase_flutter.dart';

enum DonationFilter { daily, weekly, quarterly, monthly, yearly }

class DonationPage extends StatefulWidget {
  const DonationPage({super.key});

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  String _selectedItem = "Donation";
  String? _cachedProfileImage;
  bool _isLoadingAvatar = false;
  List<Map<String, dynamic>> donationSections = [];
  double _totalAllocated = 0.0;
  List<Map<String, dynamic>> donations = [];

  List<Map<String, dynamic>> _vials = [];
  bool _isLoadingVials = false;
  int _vialsPage = 0;
  String _vialsSortCol = 'created_at';
  bool _vialsSortAsc = false;
  final TextEditingController _vialsSearchCtrl = TextEditingController();
  String _vialsSearch = '';
  DateTime? _vialsDateFrom;
  DateTime? _vialsDateTo;

  List<Map<String, dynamic>> _vetsList = [];
  List<Map<String, dynamic>> _vaccinesList = [];
  DateTime? _chartDateFrom;
  DateTime? _chartDateTo;

  List<Map<String, dynamic>> _nonMonetaryDonations = [];

  List<Map<String, dynamic>> _pendingDonations = [];

  List<Map<String, dynamic>> _pendingNonMonetaryDonations = [];

  int _verifySubTab = 0;

  RealtimeChannel? _subscription;
  DonationFilter _currentFilter = DonationFilter.monthly;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _reportPage = 0;
  static const int _pageSize = 10;
  String _reportSortCol = 'created_at';
  bool _reportSortAsc = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _amountFilter = 'All';

  List<Map<String, dynamic>> _expenses = [];
  String _expenseSearch = '';
  int _expensePage = 0;
  String _expenseSortCol = 'created_at';
  bool _expenseSortAsc = false;
  DateTime? _expenseDateFrom;
  DateTime? _expenseDateTo;
  final TextEditingController _expenseSearchCtrl = TextEditingController();

  final TextEditingController _nonMonSearchController = TextEditingController();
  String _nonMonSearchQuery = '';
  int _nonMonPage = 0;
  String _nonMonSortCol = 'created_at';
  bool _nonMonSortAsc = false;

  int _donationTabIndex = 0;

  double _totalBalance = 0.0;
  final ScrollController _donationsScrollController = ScrollController();
  final ScrollController _expensesScrollController = ScrollController();
  final ScrollController _pendingMonScrollController = ScrollController();
  final ScrollController _pendingNonMonScrollController = ScrollController();
  final ScrollController _vialsScrollController = ScrollController();
  final ScrollController _nonMonScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    saveLastVisitedPage('Donation');
    _loadDonations();
    _loadTotalDonations();
    _loadProfileImageForAvatar();
    _subscribeToDonations();
    _loadNonMonetaryDonations();
    _loadDonationSections();
    _loadVials();
    _loadVetsAndVaccines();
    _loadExpenses();
    _loadPendingDonations();
    _loadPendingNonMonetaryDonations();
    _vialsSearchCtrl.addListener(() {
      setState(() {
        _vialsSearch = _vialsSearchCtrl.text.toLowerCase();
        _vialsPage = 0;
      });
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _reportPage = 0;
      });
    });
    _nonMonSearchController.addListener(() {
      setState(() {
        _nonMonSearchQuery = _nonMonSearchController.text.toLowerCase();
        _nonMonPage = 0;
      });
    });
    _expenseSearchCtrl.addListener(() {
      setState(() {
        _expenseSearch = _expenseSearchCtrl.text.toLowerCase();
        _expensePage = 0;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _nonMonSearchController.dispose();
    _searchController.dispose();
    _expenseSearchCtrl.dispose();
    _vialsSearchCtrl.dispose();
    _donationsScrollController.dispose();
    _expensesScrollController.dispose();
    _pendingMonScrollController.dispose();
    _pendingNonMonScrollController.dispose();
    _vialsScrollController.dispose();
    _nonMonScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVials() async {
    if (!mounted) return;
    setState(() => _isLoadingVials = true);
    try {
      final res = await Supabase.instance.client
          .from('vet_vials')
          .select(
            'vial_id, quantity, donation_date, notes, created_at, '
            'veterinarians(vet_id, first_name, last_name), '
            'vaccination_cms(vaccine_id, vaccine_name)',
          )
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _vials = List<Map<String, dynamic>>.from(res);
        _isLoadingVials = false;
      });
    } catch (e) {
      debugPrint('Vials load error: $e');
      if (mounted) setState(() => _isLoadingVials = false);
    }
  }

  Future<void> _loadVetsAndVaccines() async {
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('veterinarians')
            .select('vet_id, first_name, last_name')
            .eq('account_status', 'Active')
            .order('last_name'),
        Supabase.instance.client
            .from('vaccination_cms')
            .select('vaccine_id, vaccine_name')
            .order('vaccine_name'),
      ]);
      if (!mounted) return;
      setState(() {
        _vetsList = List<Map<String, dynamic>>.from(results[0]);
        _vaccinesList = List<Map<String, dynamic>>.from(results[1]);
      });
    } catch (e) {
      debugPrint('Vets/vaccines load error: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredVials {
    var list =
        _vials.where((v) {
          if (_vialsSearch.isNotEmpty) {
            final vet = _vetName(v).toLowerCase();
            final vaccine = _vaccineName(v).toLowerCase();
            final notes = (v['notes'] ?? '').toString().toLowerCase();
            if (!vet.contains(_vialsSearch) &&
                !vaccine.contains(_vialsSearch) &&
                !notes.contains(_vialsSearch))
              return false;
          }
          if (_vialsDateFrom != null || _vialsDateTo != null) {
            final date = _parseDate(v['created_at']);
            if (date == null) return false;
            if (_vialsDateFrom != null && date.isBefore(_vialsDateFrom!))
              return false;
            if (_vialsDateTo != null &&
                date.isAfter(_vialsDateTo!.add(const Duration(days: 1))))
              return false;
          }
          return true;
        }).toList();

    list.sort((a, b) {
      dynamic va, vb;
      if (_vialsSortCol == 'vet_name') {
        va = _vetName(a);
        vb = _vetName(b);
      } else if (_vialsSortCol == 'vaccine_name') {
        va = _vaccineName(a);
        vb = _vaccineName(b);
      } else {
        va = a[_vialsSortCol];
        vb = b[_vialsSortCol];
      }
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      if (_vialsSortCol == 'quantity') {
        final da = int.tryParse(va.toString()) ?? 0;
        final db = int.tryParse(vb.toString()) ?? 0;
        return _vialsSortAsc ? da.compareTo(db) : db.compareTo(da);
      }
      final cmp = va.toString().compareTo(vb.toString());
      return _vialsSortAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Map<String, dynamic>> get _pagedVials {
    final all = _filteredVials;
    final start = _vialsPage * _pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  int get _totalVialsPages =>
      (_filteredVials.length / _pageSize).ceil().clamp(1, 999);

  int get _totalVialsCount => _filteredVials.fold(
    0,
    (s, v) => s + ((v['quantity'] as num?)?.toInt() ?? 0),
  );

  String _vetName(Map<String, dynamic> vial) {
    final vet = vial['veterinarians'];
    if (vet == null) return '—';
    final fn = vet['first_name'] ?? '';
    final ln = vet['last_name'] ?? '';
    return '$fn $ln'.trim().isEmpty ? '—' : '$fn $ln'.trim();
  }

  String _vaccineName(Map<String, dynamic> vial) =>
      vial['vaccination_cms']?['vaccine_name']?.toString() ?? '—';

  void _vialsSortBy(String col) {
    setState(() {
      if (_vialsSortCol == col) {
        _vialsSortAsc = !_vialsSortAsc;
      } else {
        _vialsSortCol = col;
        _vialsSortAsc = false;
      }
      _vialsPage = 0;
    });
  }

  Future<void> _deleteVial(int vialId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Delete Vial Record',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            content: const Text(
              'Are you sure you want to delete this vial donation record?',
              style: TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('vet_vials')
          .delete()
          .eq('vial_id', vialId);
      await _loadVials();
      if (!mounted) return;
      _showSnackBar('Vial record deleted.', Colors.red);
    } catch (e) {
      debugPrint('Delete vial error: $e');
    }
  }

  Widget _buildStackableImage({
    required String url,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (url.isEmpty) return _imagePlaceholder(width, height);
    String resolvedUrl = url;
    if (url.contains('cloudinary.com')) {
      const marker = '/upload/';
      final idx = url.indexOf(marker);
      if (idx != -1) {
        final before = url.substring(0, idx + marker.length);
        final after = url.substring(idx + marker.length);
        if (!after.startsWith('f_auto') && !after.contains('/f_auto')) {
          resolvedUrl = '${before}f_auto,q_auto/$after';
        }
      }
    }
    final cssWidth = width == double.infinity ? '100%' : '${width}px';
    final cssHeight = '${height}px';
    final cssFit = fit == BoxFit.cover ? 'cover' : 'contain';
    return HtmlElementView.fromTagName(
      tagName: 'img',
      onElementCreated: (element) {
        final img = element as html.ImageElement;
        img.style.width = cssWidth;
        img.style.height = cssHeight;
        img.style.objectFit = cssFit;
        img.style.display = 'block';
        img.setAttribute('crossorigin', 'anonymous');
        bool triedOriginal = false;
        img.onError.listen((_) {
          if (!triedOriginal && resolvedUrl != url) {
            triedOriginal = true;
            img.src = url;
          } else {
            img.replaceWith(_buildErrorHtml());
          }
        });
        img.src = resolvedUrl;
      },
    );
  }

  html.DivElement _buildErrorHtml() {
    final div =
        html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#2C2C2C'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center';
    div.append(
      html.SpanElement()
        ..style.fontSize = '24px'
        ..text = '🖼️',
    );
    return div;
  }

  Widget _imagePlaceholder(double width, double height) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      color: const Color(0xFF2C2C2C),
      child: const Icon(Icons.broken_image, color: Colors.white24, size: 32),
    );
  }

  Widget _buildThumbnail(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.white24,
          size: 18,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: buildWebImage(
        url: url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorWidget: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.broken_image,
            color: Colors.white24,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget buildWebImage({
    required String url,
    double? width,
    double? height,
    BoxFit? fit,
    Widget? errorWidget,
  }) {
    try {
      if (url.startsWith('data:image')) {
        final base64Str = url.split(',').last;
        return Image.memory(
          base64Decode(base64Str),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => errorWidget ?? const Icon(Icons.error),
        );
      }
      if (url.toLowerCase().endsWith('.svg')) {
        return SvgPicture.network(
          url,
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
          placeholderBuilder: (_) => errorWidget ?? const Icon(Icons.image),
        );
      }
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => errorWidget ?? const Icon(Icons.error),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    } catch (e) {
      return errorWidget ?? const Icon(Icons.error);
    }
  }

  Future<void> _loadDonations() async {
    final res = await Supabase.instance.client
        .from('donations')
        .select()
        .eq('status', 'Completed')
        .order('created_at', ascending: false);
    setState(() {
      donations =
          List<Map<String, dynamic>>.from(res)
              .map((d) => {...d, 'status': d['status']?.toString() ?? '—'})
              .toList();
    });
  }

  Future<void> _loadPendingDonations() async {
    try {
      final res = await Supabase.instance.client
          .from('donations')
          .select('*')
          .eq('status', 'Pending')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => _pendingDonations = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Error loading pending donations: $e');
    }
  }

  Future<void> _loadPendingNonMonetaryDonations() async {
    try {
      final res = await Supabase.instance.client
          .from('donation_appointments')
          .select('*')
          .eq('status', 'Pending')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(
        () =>
            _pendingNonMonetaryDonations = List<Map<String, dynamic>>.from(res),
      );
    } catch (e) {
      debugPrint('Error loading pending non-monetary donations: $e');
    }
  }

  Future<void> _loadTotalDonations() async {
    try {
      final data = await Supabase.instance.client
          .from('donations')
          .select('amount')
          .eq('status', 'Completed');
      double total = 0;
      for (final d in data) {
        total += double.tryParse(d['amount']?.toString() ?? '0') ?? 0;
      }
      if (!mounted) return;
      setState(() => _totalBalance = total - _totalAllocated);
    } catch (e) {
      debugPrint('Error loading total donations: $e');
    }
  }

  Future<void> _loadNonMonetaryDonations() async {
    try {
      final res = await Supabase.instance.client
          .from('donation_appointments')
          .select('*')
          .eq('status', 'Completed')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(
        () => _nonMonetaryDonations = List<Map<String, dynamic>>.from(res),
      );
    } catch (e) {
      debugPrint('Error loading non-monetary donations: $e');
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final res = await Supabase.instance.client
          .from('donation_section')
          .select(
            'donationsec_id, section_name, amount, description, created_at',
          )
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => _expenses = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Error loading expenses: $e');
    }
  }

  Future<void> _loadDonationSections() async {
    try {
      final sections = await Supabase.instance.client
          .from('donation_section')
          .select('donationsec_id, section_name, amount, description');
      if (!mounted) return;
      double totalAllocated = 0;
      final loaded =
          (sections as List).map((e) {
            final amt = (e['amount'] as num).toDouble();
            totalAllocated += amt;
            return {
              'donationsec_id': e['donationsec_id'],
              'section_name': e['section_name'],
              'amount': amt,
              'description': e['description'] ?? '',
            };
          }).toList();
      setState(() {
        donationSections = loaded;
        _totalAllocated = totalAllocated;
      });
      _loadTotalDonations();
    } catch (e) {
      debugPrint('Error loading donation sections: $e');
    }
  }

  Future<void> _addDonation({
    required double amount,
    required String reference,
    required String furParent,
    required String phoneNumber,
    required String email,
    String status = 'Completed',
  }) async {
    await Supabase.instance.client.from('donations').insert({
      'amount': amount,
      'reference_number': reference.trim(),
      'furparent_name': furParent.trim(),
      'email': email.trim(),
      'status': status,
      'phone_number': phoneNumber.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
    await logActivity(
      action: 'Added Cash Donation',
      description:
          'Added cash donation of ₱${amount.toStringAsFixed(2)} from ${furParent.trim()}',
      entityType: 'Donation',
    );
    await _loadDonations();
    await _loadPendingDonations();
    await _loadTotalDonations();
  }

  void _subscribeToDonations() {
    _subscription =
        Supabase.instance.client
            .channel('donations')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'donations',
              callback: (payload) {
                _loadDonations();
                _loadPendingDonations();
                _loadTotalDonations();
              },
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
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  Future<void> _deleteFundAndReturnBalance({
    required int sectionId,
    required double amount,
  }) async {
    try {
      await Supabase.instance.client
          .from('donation_section')
          .delete()
          .eq('donationsec_id', sectionId);
      await _loadDonationSections();
      await _loadExpenses();
      await _loadTotalDonations();
      if (!mounted) return;
      _showSnackBar(
        'Fund allocation removed and balance restored',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to delete fund allocation', Colors.red);
    }
  }

  List<Map<String, dynamic>> get _chartFilteredDonations {
    if (_chartDateFrom == null && _chartDateTo == null) return donations;
    return donations.where((d) {
      final date = _parseDate(d['created_at']);
      if (date == null) return false;
      if (_chartDateFrom != null && date.isBefore(_chartDateFrom!))
        return false;
      if (_chartDateTo != null &&
          date.isAfter(_chartDateTo!.add(const Duration(days: 1))))
        return false;
      return true;
    }).toList();
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

  Map<String, double> _groupDonationsFixed() {
    final Map<String, double> result = {};
    final now = DateTime.now();

    if (_currentFilter == DonationFilter.daily) {
      final todayWeekday = now.weekday;
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: todayWeekday - 1));

      for (int i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        result[DateFormat('EEE\nMMM d').format(day)] = 0;
      }

      for (final d in _chartFilteredDonations) {
        final date = _parseDate(d['created_at']);
        if (date == null) continue;
        final dayOnly = DateTime(date.year, date.month, date.day);
        final key = DateFormat('EEE\nMMM d').format(dayOnly);
        if (result.containsKey(key)) {
          result[key] = result[key]! + _parseAmount(d['amount']);
        }
      }
    } else if (_currentFilter == DonationFilter.weekly) {
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);

      final firstMonday = monthStart.subtract(
        Duration(days: (monthStart.weekday - 1) % 7),
      );

      final List<DateTime> weekStarts = [];
      DateTime ws = firstMonday;
      while (!ws.isAfter(monthEnd)) {
        weekStarts.add(ws);
        ws = ws.add(const Duration(days: 7));
      }

      for (int i = 0; i < weekStarts.length; i++) {
        final clampedStart =
            weekStarts[i].isBefore(monthStart) ? monthStart : weekStarts[i];
        final wEnd = weekStarts[i].add(const Duration(days: 6));
        final clampedEnd = wEnd.isAfter(monthEnd) ? monthEnd : wEnd;
        final label =
            '${DateFormat('MMM d').format(clampedStart)}–${DateFormat('d').format(clampedEnd)}';
        result[label] = 0;
      }

      for (final d in _chartFilteredDonations) {
        final date = _parseDate(d['created_at']);
        if (date == null) continue;

        if (date.year != now.year || date.month != now.month) continue;
        for (int i = 0; i < weekStarts.length; i++) {
          final wEnd = weekStarts[i].add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
          );
          if (!date.isBefore(weekStarts[i]) && !date.isAfter(wEnd)) {
            final clampedStart =
                weekStarts[i].isBefore(monthStart) ? monthStart : weekStarts[i];
            final clampedEnd = wEnd.isAfter(monthEnd) ? monthEnd : wEnd;
            final label =
                '${DateFormat('MMM d').format(clampedStart)}–${DateFormat('d').format(clampedEnd)}';
            result[label] = (result[label] ?? 0) + _parseAmount(d['amount']);
            break;
          }
        }
      }
    } else if (_currentFilter == DonationFilter.quarterly) {
      final currentQ = ((now.month - 1) ~/ 3) + 1;
      for (int q = 1; q <= currentQ; q++) {
        result['Q$q'] = 0;
      }

      for (final d in _chartFilteredDonations) {
        final date = _parseDate(d['created_at']);
        if (date == null || date.year != now.year) continue;
        final q = ((date.month - 1) ~/ 3) + 1;
        if (q > currentQ) continue;
        final key = 'Q$q';
        if (result.containsKey(key)) {
          result[key] = result[key]! + _parseAmount(d['amount']);
        }
      }
    } else if (_currentFilter == DonationFilter.monthly) {
      for (int m = 1; m <= now.month; m++) {
        result[DateFormat('MMM').format(DateTime(now.year, m))] = 0;
      }
      for (final d in _chartFilteredDonations) {
        final date = _parseDate(d['created_at']);
        if (date == null || date.year != now.year) continue;
        if (date.month > now.month) continue;
        final key = DateFormat('MMM').format(date);
        if (result.containsKey(key)) {
          result[key] = result[key]! + _parseAmount(d['amount']);
        }
      }
    } else {
      for (int y = now.year - 4; y <= now.year; y++) {
        result['$y'] = 0;
      }
      for (final d in _chartFilteredDonations) {
        final date = _parseDate(d['created_at']);
        if (date == null) continue;
        final key = '${date.year}';
        if (result.containsKey(key)) {
          result[key] = result[key]! + _parseAmount(d['amount']);
        }
      }
    }

    return result;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  double _parseAmount(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0;
  }

  List<Map<String, dynamic>> get _filteredDonations {
    var list =
        donations.where((d) {
          if (_searchQuery.isNotEmpty) {
            final name = (d['furparent_name'] ?? '').toString().toLowerCase();
            final ref = (d['reference_number'] ?? '').toString().toLowerCase();
            final amount = (d['amount'] ?? '').toString().toLowerCase();
            if (!name.contains(_searchQuery) &&
                !ref.contains(_searchQuery) &&
                !amount.contains(_searchQuery)) {
              return false;
            }
          }
          if (_dateFrom != null || _dateTo != null) {
            final date = _parseDate(d['created_at']);
            if (date == null) return false;
            if (_dateFrom != null && date.isBefore(_dateFrom!)) return false;
            if (_dateTo != null &&
                date.isAfter(_dateTo!.add(const Duration(days: 1))))
              return false;
          }
          if (_amountFilter != 'All') {
            final amt = _parseAmount(d['amount']);
            if (_amountFilter == '<500' && amt >= 500) return false;
            if (_amountFilter == '500-2000' && (amt < 500 || amt > 2000))
              return false;
            if (_amountFilter == '>2000' && amt <= 2000) return false;
          }
          return true;
        }).toList();

    list.sort((a, b) {
      dynamic va = a[_reportSortCol];
      dynamic vb = b[_reportSortCol];
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      if (_reportSortCol == 'amount') {
        final da = double.tryParse(va.toString()) ?? 0;
        final db = double.tryParse(vb.toString()) ?? 0;
        return _reportSortAsc ? da.compareTo(db) : db.compareTo(da);
      }
      final cmp = va.toString().compareTo(vb.toString());
      return _reportSortAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Map<String, dynamic>> get _pagedDonations {
    final all = _filteredDonations;
    final start = _reportPage * _pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  int get _totalPages =>
      (_filteredDonations.length / _pageSize).ceil().clamp(1, 999);
  double get _filteredTotal =>
      _filteredDonations.fold(0.0, (s, d) => s + _parseAmount(d['amount']));

  void _sortBy(String col) {
    setState(() {
      if (_reportSortCol == col) {
        _reportSortAsc = !_reportSortAsc;
      } else {
        _reportSortCol = col;
        _reportSortAsc = false;
      }
      _reportPage = 0;
    });
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    var list =
        _expenses.where((e) {
          if (_expenseSearch.isNotEmpty) {
            final name = (e['section_name'] ?? '').toString().toLowerCase();
            final desc = (e['description'] ?? '').toString().toLowerCase();
            if (!name.contains(_expenseSearch) &&
                !desc.contains(_expenseSearch))
              return false;
          }
          if (_expenseDateFrom != null || _expenseDateTo != null) {
            final date = _parseDate(e['created_at']);
            if (date == null) return false;
            if (_expenseDateFrom != null && date.isBefore(_expenseDateFrom!))
              return false;
            if (_expenseDateTo != null &&
                date.isAfter(_expenseDateTo!.add(const Duration(days: 1))))
              return false;
          }
          return true;
        }).toList();

    list.sort((a, b) {
      dynamic va = a[_expenseSortCol];
      dynamic vb = b[_expenseSortCol];
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      if (_expenseSortCol == 'amount') {
        final da = double.tryParse(va.toString()) ?? 0;
        final db = double.tryParse(vb.toString()) ?? 0;
        return _expenseSortAsc ? da.compareTo(db) : db.compareTo(da);
      }
      final cmp = va.toString().compareTo(vb.toString());
      return _expenseSortAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Map<String, dynamic>> get _pagedExpenses {
    final all = _filteredExpenses;
    final start = _expensePage * _pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  int get _totalExpensePages =>
      (_filteredExpenses.length / _pageSize).ceil().clamp(1, 999);
  double get _expenseTotal =>
      _filteredExpenses.fold(0.0, (s, e) => s + _parseAmount(e['amount']));

  List<Map<String, dynamic>> get _filteredNonMon {
    var list =
        _nonMonetaryDonations.where((d) {
          if (_nonMonSearchQuery.isEmpty) return true;
          final name = (d['furparent_name'] ?? '').toString().toLowerCase();
          final item = (d['donation_item'] ?? '').toString().toLowerCase();
          final cat = (d['donation_category'] ?? '').toString().toLowerCase();
          final status = (d['status'] ?? '').toString().toLowerCase();
          final contact =
              (d['furparent_contact'] ?? '').toString().toLowerCase();
          return name.contains(_nonMonSearchQuery) ||
              item.contains(_nonMonSearchQuery) ||
              cat.contains(_nonMonSearchQuery) ||
              status.contains(_nonMonSearchQuery) ||
              contact.contains(_nonMonSearchQuery);
        }).toList();

    list.sort((a, b) {
      dynamic va = a[_nonMonSortCol];
      dynamic vb = b[_nonMonSortCol];
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      final cmp = va.toString().compareTo(vb.toString());
      return _nonMonSortAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Map<String, dynamic>> get _pagedNonMon {
    final all = _filteredNonMon;
    final start = _nonMonPage * _pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  int get _totalNonMonPages =>
      (_filteredNonMon.length / _pageSize).ceil().clamp(1, 999);

  void _nonMonSortBy(String col) {
    setState(() {
      if (_nonMonSortCol == col)
        _nonMonSortAsc = !_nonMonSortAsc;
      else {
        _nonMonSortCol = col;
        _nonMonSortAsc = false;
      }
      _nonMonPage = 0;
    });
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

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_chartDateFrom ?? now) : (_chartDateTo ?? now),
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: Colors.black,
              surface: Color(0xFF3A3A3A),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF2A2A2A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _chartDateFrom = picked;
          if (_chartDateTo != null && _chartDateFrom!.isAfter(_chartDateTo!)) {
            _chartDateTo = null;
          }
        } else {
          _chartDateTo = picked;
          if (_chartDateFrom != null &&
              _chartDateTo!.isBefore(_chartDateFrom!)) {
            _chartDateFrom = null;
          }
        }
      });
    }
  }

  Widget _buildChartFilters() {
    Widget datePill(String label, DateTime? date, bool isStart) {
      return GestureDetector(
        onTap: () => _pickDate(context, isStart),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: date != null ? Colors.orange : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: date != null ? Colors.orange : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                date != null ? DateFormat('MMM d, yyyy').format(date) : label,
                style: TextStyle(
                  color: date != null ? Colors.white : Colors.white54,
                  fontFamily: "Montserrat",
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    String? activeRangeLabel;
    if (_chartDateFrom != null && _chartDateTo != null) {
      activeRangeLabel =
          '${DateFormat('MMM d').format(_chartDateFrom!)} – ${DateFormat('MMM d, yyyy').format(_chartDateTo!)}';
    } else if (_chartDateFrom != null) {
      activeRangeLabel =
          'From ${DateFormat('MMM d, yyyy').format(_chartDateFrom!)}';
    } else if (_chartDateTo != null) {
      activeRangeLabel =
          'Until ${DateFormat('MMM d, yyyy').format(_chartDateTo!)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            datePill("Start Date", _chartDateFrom, true),
            const Text(
              "—",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            datePill("End Date", _chartDateTo, false),
            if (_chartDateFrom != null || _chartDateTo != null)
              GestureDetector(
                onTap:
                    () => setState(() {
                      _chartDateFrom = null;
                      _chartDateTo = null;
                    }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 13, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text(
                        "Clear",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontFamily: "Montserrat",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DonationFilter>(
                  value: _currentFilter,
                  dropdownColor: const Color(0xFF3A3A3A),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: "Montserrat",
                    fontSize: 12,
                  ),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                    size: 20,
                  ),
                  items:
                      DonationFilter.values
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(f.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null && mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _currentFilter = value);
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        if (activeRangeLabel != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range, size: 12, color: Colors.orange),
                const SizedBox(width: 5),
                Text(
                  activeRangeLabel,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDonationChart() {
    final grouped = _groupDonationsFixed();

    if (grouped.isEmpty || grouped.values.every((v) => v == 0)) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            "No donation data for selected range",
            style: TextStyle(
              color: Colors.white70,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      );
    }

    final entries = grouped.entries.toList();
    final maxRaw =
        entries.isEmpty
            ? 0.0
            : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxY = (maxRaw == 0 ? 100.0 : maxRaw) * 1.25;
    final barWidth =
        entries.length > 12
            ? 14.0
            : entries.length > 6
            ? 14.0
            : 16.0;

    final barGroups = List.generate(
      entries.length,
      (i) => BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: entries[i].value,
            width: barWidth,
            color: Colors.orange,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: Colors.orange.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: barGroups,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length)
                    return const SizedBox.shrink();
                  final label = entries[i].key;

                  final lines = label.split('\n');
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          lines
                              .map(
                                (line) => Text(
                                  line,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontFamily: "Montserrat",
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                              .toList(),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget:
                    (v, _) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        v >= 1000
                            ? '₱${(v / 1000).toStringAsFixed(1)}K'
                            : '₱${v.toInt()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontFamily: "Montserrat",
                        ),
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
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: const Color(0xFF2A2A2A),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              tooltipRoundedRadius: 10,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (groupIndex >= entries.length) return null;
                final label = entries[groupIndex].key;
                final amount = rod.toY;
                return BarTooltipItem(
                  '$label\n',
                  const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: "Montserrat",
                  ),
                  children: [
                    TextSpan(
                      text: '₱${NumberFormat('#,##0.00').format(amount)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Montserrat",
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.white12),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine:
                (_) => FlLine(color: Colors.white12, strokeWidth: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDonationReport() {
    final paged = _pagedDonations;
    final filtered = _filteredDonations;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF242424),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child:
                isMobile
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _reportTitle(),
                        const SizedBox(height: 10),
                        _searchBar(),
                      ],
                    )
                    : Row(
                      children: [
                        _reportTitle(),
                        const Spacer(),
                        SizedBox(width: 280, child: _searchBar()),
                      ],
                    ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E1E1E),
            width: double.infinity,
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _datePickerChip(
                              'From',
                              _dateFrom,
                              (d) => setState(() {
                                _dateFrom = d;
                                _reportPage = 0;
                              }),
                            ),
                            const SizedBox(width: 10),
                            _datePickerChip(
                              'To',
                              _dateTo,
                              (d) => setState(() {
                                _dateTo = d;
                                _reportPage = 0;
                              }),
                            ),
                            if (_dateFrom != null || _dateTo != null) ...[
                              const SizedBox(width: 10),
                              _clearChip(
                                'Clear Dates',
                                () => setState(() {
                                  _dateFrom = null;
                                  _dateTo = null;
                                  _reportPage = 0;
                                }),
                              ),
                            ],
                            const SizedBox(width: 10),
                            _dropdownChip<String>(
                              label: 'Amount',
                              value: _amountFilter,
                              items: const ['All', '<500', '500-2000', '>2000'],
                              onChanged:
                                  (v) => setState(() {
                                    _amountFilter = v!;
                                    _reportPage = 0;
                                  }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _summaryChip('Records', '${filtered.length}', Colors.blue),
                          const SizedBox(width: 10),
                          _summaryChip(
                            'Total',
                            '₱${NumberFormat('#,##0.00').format(_filteredTotal)}',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _datePickerChip(
                        'From',
                        _dateFrom,
                        (d) => setState(() {
                          _dateFrom = d;
                          _reportPage = 0;
                        }),
                      ),
                      const SizedBox(width: 10),
                      _datePickerChip(
                        'To',
                        _dateTo,
                        (d) => setState(() {
                          _dateTo = d;
                          _reportPage = 0;
                        }),
                      ),
                      if (_dateFrom != null || _dateTo != null) ...[
                        const SizedBox(width: 10),
                        _clearChip(
                          'Clear Dates',
                          () => setState(() {
                            _dateFrom = null;
                            _dateTo = null;
                            _reportPage = 0;
                          }),
                        ),
                      ],
                      const SizedBox(width: 10),
                      _dropdownChip<String>(
                        label: 'Amount',
                        value: _amountFilter,
                        items: const ['All', '<500', '500-2000', '>2000'],
                        onChanged:
                            (v) => setState(() {
                              _amountFilter = v!;
                              _reportPage = 0;
                            }),
                      ),
                      const Spacer(),
                      _summaryChip('Records', '${filtered.length}', Colors.blue),
                      const SizedBox(width: 10),
                      _summaryChip(
                        'Total',
                        '₱${NumberFormat('#,##0.00').format(_filteredTotal)}',
                        Colors.orange,
                      ),
                    ],
                  ),
          ),
          if (paged.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No donations found.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            _responsiveTableWrapper(
              controller: _donationsScrollController,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF1A1A1A),
                ),
                dataRowColor: WidgetStateProperty.resolveWith(
                  (_) => const Color(0xFF282828),
                ),
                columnSpacing: 20,
                dividerThickness: 0.5,
                columns: [
                  _sortableCol('#', 'id'),
                  _sortableCol('Donor', 'furparent_name'),
                  _sortableCol('Amount', 'amount'),
                  _sortableCol('Reference', 'reference_number'),
                  _sortableCol('Date', 'created_at'),
                  const DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text('', style: TextStyle(color: Colors.white)),
                  ),
                ],
                rows:
                    paged.asMap().entries.map((e) {
                      final idx = _reportPage * _pageSize + e.key + 1;
                      final d = e.value;
                      final amount = _parseAmount(d['amount']);
                      final dateStr = _formatDate(
                        d['created_at'],
                        'MMM d, yyyy',
                      );
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '$idx',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              d['furparent_name']?.toString() ?? 'Anonymous',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₱${NumberFormat('#,##0.00').format(amount)}',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              d['reference_number']?.toString() ?? '—',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            _statusBadge(d['status']?.toString() ?? '—'),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(
                                Icons.info_outline,
                                color: Colors.white38,
                                size: 18,
                              ),
                              onPressed:
                                  () => _showDonationDetailsDialog(context, d),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          _paginationRow(
            _reportPage,
            _totalPages,
            (v) => setState(() => _reportPage = v),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesReport() {
    final paged = _pagedExpenses;
    final filtered = _filteredExpenses;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF242424),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Fund Allocation & Expenses',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _expenseSearchCtrl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search category, description…',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E1E1E),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _datePickerChip(
                  'From',
                  _expenseDateFrom,
                  (d) => setState(() {
                    _expenseDateFrom = d;
                    _expensePage = 0;
                  }),
                ),
                _datePickerChip(
                  'To',
                  _expenseDateTo,
                  (d) => setState(() {
                    _expenseDateTo = d;
                    _expensePage = 0;
                  }),
                ),
                if (_expenseDateFrom != null || _expenseDateTo != null)
                  _clearChip(
                    'Clear Dates',
                    () => setState(() {
                      _expenseDateFrom = null;
                      _expenseDateTo = null;
                      _expensePage = 0;
                    }),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1A1A1A),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _summaryChip('Records', '${filtered.length}', Colors.blue),
                _summaryChip(
                  'Total Allocated',
                  '₱${NumberFormat('#,##0.00').format(_expenseTotal)}',
                  Colors.red,
                ),
              ],
            ),
          ),
          if (paged.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No expense records found.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            _responsiveTableWrapper(
              controller: _expensesScrollController,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF1A1A1A),
                ),
                dataRowColor: WidgetStateProperty.resolveWith(
                  (_) => const Color(0xFF282828),
                ),
                columnSpacing: 20,
                dividerThickness: 0.5,
                columns: [
                  _expSortCol('#', 'donationsec_id'),
                  _expSortCol('Category', 'section_name'),
                  _expSortCol('Amount', 'amount'),
                  _expSortCol('Date', 'created_at'),
                  const DataColumn(
                    label: Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                rows:
                    paged.asMap().entries.map((e) {
                      final idx = _expensePage * _pageSize + e.key + 1;
                      final d = e.value;
                      final amount = _parseAmount(d['amount']);
                      final dateStr = _formatDate(
                        d['created_at'],
                        'MMM d, yyyy',
                      );
                      final desc = d['description']?.toString() ?? '—';
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '$idx',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              d['section_name']?.toString() ?? '—',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₱${NumberFormat('#,##0.00').format(amount)}',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: Text(
                                desc,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          _paginationRow(
            _expensePage,
            _totalExpensePages,
            (v) => setState(() => _expensePage = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingMonetaryTable() {
    if (_pendingDonations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
              SizedBox(height: 12),
              Text(
                'No pending monetary donations!',
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Montserrat',
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _responsiveTableWrapper(
      controller: _pendingMonScrollController,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF1A1A1A)),
        dataRowColor: WidgetStateProperty.resolveWith(
          (_) => const Color(0xFF282828),
        ),
        columnSpacing: 20,
        dividerThickness: 0.5,
        columns: [
          const DataColumn(
            label: Text(
              'Donor',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const DataColumn(
            label: Text(
              'Amount',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const DataColumn(
            label: Text(
              'Reference',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const DataColumn(
            label: Text(
              'Date',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const DataColumn(
            label: Text(
              'Actions',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
        rows:
            _pendingDonations.asMap().entries.map((e) {
              final d = e.value;
              final amount = _parseAmount(d['amount']);
              final dateStr = _formatDate(
                d['created_at'],
                'MMM d, yyyy',
              );
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      d['furparent_name']?.toString() ?? 'Anonymous',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '₱${NumberFormat('#,##0.00').format(amount)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      d['reference_number']?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text(
                            'Approve',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          onPressed: () => _verifyDonation(d, approve: true),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text(
                            'Reject',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          onPressed: () => _verifyDonation(d, approve: false),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildPendingNonMonetaryTable() {
    if (_pendingNonMonetaryDonations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
              SizedBox(height: 12),
              Text(
                'No pending non-monetary donations!',
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Montserrat',
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _responsiveTableWrapper(
      controller: _pendingNonMonScrollController,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF1A1A1A)),
        dataRowColor: WidgetStateProperty.resolveWith(
          (_) => const Color(0xFF282828),
        ),
        columnSpacing: 20,
        dividerThickness: 0.5,
        columns: const [
          DataColumn(
            label: Text(
              '#',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Photo 1',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Photo 2',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Donor',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Contact',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Item',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Category',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Qty',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Date',
              style: TextStyle(
                color: Colors.white,
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
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
        rows:
            _pendingNonMonetaryDonations.asMap().entries.map((e) {
              final idx = e.key + 1;
              final d = e.value;
              final dateStr = _formatDate(
                d['created_at'],
                'MMM d, yyyy',
              );
              final qty = d['donation_quantity']?.toString() ?? '—';
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      '$idx',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    _buildThumbnail(d['image_url_1']?.toString()),
                  ),
                  DataCell(
                    _buildThumbnail(d['image_url_2']?.toString()),
                  ),
                  DataCell(
                    Text(
                      d['furparent_name']?.toString() ?? 'Anonymous',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      d['furparent_contact']?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      d['donation_item']?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      d['donation_category']?.toString() ?? '—',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    qty.length > 12
                        ? Tooltip(
                          message: qty,
                          child: Text(
                            '${qty.substring(0, 12)}…',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                            ),
                          ),
                        )
                        : Text(
                          qty,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                          ),
                        ),
                  ),
                  DataCell(
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.visibility_outlined,
                            color: Colors.blue,
                            size: 18,
                          ),
                          tooltip: 'View Details',
                          onPressed: () => _showNonMonDetailsDialog(context, d),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text(
                            'Approve',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          onPressed:
                              () => _verifyNonMonetaryDonation(d, approve: true),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text(
                            'Reject',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          onPressed:
                              () => _verifyNonMonetaryDonation(d, approve: false),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  DataColumn _expSortCol(String label, String col) {
    final active = _expenseSortCol == col;
    return DataColumn(
      onSort:
          (_, __) => setState(() {
            if (_expenseSortCol == col)
              _expenseSortAsc = !_expenseSortAsc;
            else {
              _expenseSortCol = col;
              _expenseSortAsc = false;
            }
            _expensePage = 0;
          }),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.orange : Colors.white,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            active
                ? (_expenseSortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 14,
            color: active ? Colors.orange : Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingVerificationTab() {
    final totalPending =
        _pendingDonations.length + _pendingNonMonetaryDonations.length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF242424),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pending Verification',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (totalPending > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      '$totalPending pending',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                _verifySubTabBtn(
                  label: 'Monetary',
                  index: 0,
                  icon: Icons.attach_money,
                  badgeCount: _pendingDonations.length,
                ),
                const SizedBox(width: 8),
                _verifySubTabBtn(
                  label: 'Non-Monetary',
                  index: 1,
                  icon: Icons.inventory_2_outlined,
                  badgeCount: _pendingNonMonetaryDonations.length,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _verifySubTab == 0
              ? _buildPendingMonetaryTable()
              : _buildPendingNonMonetaryTable(),
        ],
      ),
    );
  }

  Widget _verifySubTabBtn({
    required String label,
    required int index,
    required IconData icon,
    required int badgeCount,
  }) {
    final active = _verifySubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _verifySubTab = index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: active ? Colors.orange : const Color(0xFF333333),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? Colors.orange : Colors.white12,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active ? Colors.black : Colors.white54,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.black : Colors.white54,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _verifyDonation(
    Map<String, dynamic> donation, {
    required bool approve,
  }) async {
    final id = donation['donation_id'];
    if (id == null) return;
    final newStatus = approve ? 'Completed' : 'Rejected';
    try {
      await Supabase.instance.client
          .from('donations')
          .update({'status': newStatus})
          .eq('donation_id', id);

      await logActivity(
        action: 'Verified Monetary Donation',
        description:
            '${approve ? "Approved" : "Rejected"} monetary donation request from ${donation['furparent_name'] ?? 'Donor'}',
        entityType: 'Monetary Donation',
        entityId: id is int ? id : int.tryParse(id.toString()),
      );

      try {
        final furparentEmail = donation['email']?.toString();
        final furparentName =
            donation['furparent_name']?.toString() ?? 'Donor';
        final amount = donation['amount']?.toString() ?? '';
        if (furparentEmail != null && furparentEmail.isNotEmpty) {
          final profileRes = await Supabase.instance.client
              .from('profiles')
              .select('furparent_id')
              .eq('email', furparentEmail)
              .maybeSingle();
          final furparentId = profileRes?['furparent_id'] as int?;
          if (furparentId != null) {
            await Supabase.instance.client.from('user_notifications').insert({
              'furparent_id': furparentId,
              'title': approve
                  ? '✅ Donation Verified!'
                  : 'Donation Not Verified',
              'body': approve
                  ? 'Your donation of ₱$amount has been verified and accepted. Thank you, $furparentName!'
                  : 'Your donation of ₱$amount could not be verified. Please contact us.',
              'type': 'donation_status',
              'screen': 'DonationPage',
              'read': false,
            });
          }
        }
      } catch (e) {
        debugPrint('Notification error: $e');
      }

      await _loadDonations();
      await _loadPendingDonations();
      await _loadTotalDonations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Donation approved!' : 'Donation rejected.',
            style: const TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: approve ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('Error verifying donation: $e');
    }
  }

  Future<void> _verifyNonMonetaryDonation(
    Map<String, dynamic> donation, {
    required bool approve,
  }) async {
    final id = donation['donationappointment_id'];
    if (id == null) return;
    final newStatus = approve ? 'Completed' : 'Cancelled';
    final item = donation['donation_item']?.toString() ?? 'item';
    final qty = donation['donation_quantity']?.toString() ?? '';
    final furparentId = donation['furparent_id'] as int?;
    final contactNumber = donation['furparent_contact']?.toString();
    await _updateNonMonStatus(
      id,
      newStatus,
      furparentId: furparentId,
      item: item,
      qty: qty,
      contactNumber: contactNumber,
    );
    await logActivity(
      action: 'Verified Non-Monetary Donation',
      description:
          '${approve ? "Approved" : "Cancelled"} non-monetary donation request for $item',
      entityType: 'Non-Monetary Donation',
      entityId: id is int ? id : int.tryParse(id.toString()),
    );
  }

  Widget _buildVialsTab() {
    final paged = _pagedVials;
    final filtered = _filteredVials;

    DataColumn vialCol(String label, String col) {
      final active = _vialsSortCol == col;
      return DataColumn(
        onSort: (_, __) => _vialsSortBy(col),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.orange : Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              active
                  ? (_vialsSortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: active ? Colors.orange : Colors.white24,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF242424),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.vaccines, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Vaccine Vials',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 10),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _vialsSearchCtrl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search vet, vaccine, notes…',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: 18,
                      ),
                      suffixIcon:
                          _vialsSearch.isNotEmpty
                              ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white38,
                                  size: 16,
                                ),
                                onPressed: () {
                                  _vialsSearchCtrl.clear();
                                  setState(() => _vialsSearch = '');
                                },
                              )
                              : null,
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E1E1E),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _datePickerChip(
                  'From',
                  _vialsDateFrom,
                  (d) => setState(() {
                    _vialsDateFrom = d;
                    _vialsPage = 0;
                  }),
                ),
                _datePickerChip(
                  'To',
                  _vialsDateTo,
                  (d) => setState(() {
                    _vialsDateTo = d;
                    _vialsPage = 0;
                  }),
                ),
                if (_vialsDateFrom != null || _vialsDateTo != null)
                  _clearChip(
                    'Clear Dates',
                    () => setState(() {
                      _vialsDateFrom = null;
                      _vialsDateTo = null;
                      _vialsPage = 0;
                    }),
                  ),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1A1A1A),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _summaryChip('Records', '${filtered.length}', Colors.blue),
                _summaryChip('Total Vials', '$_totalVialsCount', Colors.teal),
              ],
            ),
          ),

          if (_isLoadingVials)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Colors.teal),
              ),
            )
          else if (paged.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No vial records found.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            _responsiveTableWrapper(
              controller: _vialsScrollController,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF1A1A1A),
                ),
                dataRowColor: WidgetStateProperty.resolveWith(
                  (_) => const Color(0xFF282828),
                ),
                columnSpacing: 20,
                dividerThickness: 0.5,
                columns: [
                  vialCol('#', 'vial_id'),
                  vialCol('Veterinarian', 'vet_name'),
                  vialCol('Vaccine', 'vaccine_name'),
                  vialCol('Qty', 'quantity'),
                  vialCol('Donation Date', 'donation_date'),
                  vialCol('Logged At', 'created_at'),
                  const DataColumn(
                    label: Text(
                      'Notes',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                rows:
                    paged.asMap().entries.map((e) {
                      final idx = _vialsPage * _pageSize + e.key + 1;
                      final v = e.value;
                      final vialId = v['vial_id'] as int?;
                      final qty = (v['quantity'] as num?)?.toInt() ?? 0;
                      final donationDateStr = _formatDate(
                        v['donation_date'],
                        'MMM d, yyyy',
                      );
                      final loggedAtStr = _formatDate(
                        v['created_at'],
                        'MMM d, yyyy',
                      );
                      final notes = v['notes']?.toString() ?? '—';

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '$idx',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              _vetName(v),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                _vaccineName(v),
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                '$qty',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              donationDateStr,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              loggedAtStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child:
                                  notes.length > 40
                                      ? Tooltip(
                                        message: notes,
                                        child: Text(
                                          '${notes.substring(0, 40)}…',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontFamily: 'Montserrat',
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                      : Text(
                                        notes,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                        ),
                                      ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              tooltip: 'Delete',
                              onPressed:
                                  vialId != null
                                      ? () => _deleteVial(vialId)
                                      : null,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),

          _paginationRow(
            _vialsPage,
            _totalVialsPages,
            (v) => setState(() => _vialsPage = v),
          ),
        ],
      ),
    );
  }

  Widget _buildNonMonetaryReport() {
    final paged = _pagedNonMon;
    final filtered = _filteredNonMon;

    DataColumn nonMonCol(String label, String col) {
      final active = _nonMonSortCol == col;
      return DataColumn(
        onSort: (_, __) => _nonMonSortBy(col),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.orange : Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              active
                  ? (_nonMonSortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: active ? Colors.orange : Colors.white24,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF242424),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Non-Monetary Donations',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                SizedBox(width: 280, child: _nonMonSearchBar()),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E1E1E),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _summaryChip('Total', '${filtered.length}', Colors.blue),
                _summaryChip(
                  'Pending',
                  '${filtered.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'pending').length}',
                  Colors.orange,
                ),
                _summaryChip(
                  'Completed',
                  '${filtered.where((d) => (d['status'] ?? '').toString().toLowerCase() == 'completed').length}',
                  Colors.green,
                ),
              ],
            ),
          ),

          if (paged.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No non-monetary donations found.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            _responsiveTableWrapper(
              controller: _nonMonScrollController,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF1A1A1A),
                ),
                dataRowColor: WidgetStateProperty.resolveWith(
                  (_) => const Color(0xFF282828),
                ),
                columnSpacing: 20,
                dividerThickness: 0.5,
                columns: [
                  nonMonCol('#', 'donationappointment_id'),
                  const DataColumn(
                    label: Text(
                      'Photo 1',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Photo 2',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  nonMonCol('Donor', 'furparent_name'),
                  nonMonCol('Contact', 'furparent_contact'),
                  nonMonCol('Item', 'donation_item'),
                  nonMonCol('Category', 'donation_category'),
                  nonMonCol('Qty', 'donation_quantity'),
                  nonMonCol('Scheduled', 'scheduled_date'),
                  nonMonCol('Date', 'created_at'),
                  nonMonCol('Status', 'status'),
                  const DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                rows:
                    paged.asMap().entries.map((e) {
                      final idx = _nonMonPage * _pageSize + e.key + 1;
                      final d = e.value;
                      final dateStr = _formatDate(
                        d['created_at'],
                        'MMM d, yyyy',
                      );
                      final scheduledStr = _formatDate(
                        d['scheduled_date'],
                        'MMM d, yyyy',
                      );
                      final status = d['status']?.toString() ?? 'Pending';
                      final qty = d['donation_quantity']?.toString() ?? '—';

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '$idx',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            _buildThumbnail(d['image_url_1']?.toString()),
                          ),
                          DataCell(
                            _buildThumbnail(d['image_url_2']?.toString()),
                          ),
                          DataCell(
                            Text(
                              d['furparent_name']?.toString() ?? 'Anonymous',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              d['furparent_contact']?.toString() ?? '—',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              d['donation_item']?.toString() ?? '—',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              d['donation_category']?.toString() ?? '—',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            qty.length > 12
                                ? Tooltip(
                                  message: qty,
                                  child: Text(
                                    '${qty.substring(0, 12)}…',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontFamily: 'Montserrat',
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                                : Text(
                                  qty,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                  ),
                                ),
                          ),
                          DataCell(
                            Text(
                              scheduledStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(_statusBadge(status)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                  tooltip: 'View Details',
                                  onPressed:
                                      () =>
                                          _showNonMonDetailsDialog(context, d),
                                ),
                                if (status.toLowerCase() == 'pending')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                    tooltip: 'Mark as Completed',
                                    onPressed:
                                        () => _updateNonMonStatus(
                                          d['donationappointment_id'],
                                          'Completed',
                                          furparentId:
                                              d['furparent_id'] as int?,
                                          item:
                                              d['donation_item']?.toString() ??
                                              'item',
                                          qty: qty,
                                          contactNumber:
                                              d['furparent_contact']
                                                  ?.toString(),
                                        ),
                                  ),
                                if (status.toLowerCase() == 'pending')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    tooltip: 'Reject',
                                    onPressed:
                                        () => _updateNonMonStatus(
                                          d['donationappointment_id'],
                                          'Rejected',
                                          furparentId:
                                              d['furparent_id'] as int?,
                                          item:
                                              d['donation_item']?.toString() ??
                                              'item',
                                          qty: qty,
                                          contactNumber:
                                              d['furparent_contact']
                                                  ?.toString(),
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

          _paginationRow(
            _nonMonPage,
            _totalNonMonPages,
            (v) => setState(() => _nonMonPage = v),
          ),
        ],
      ),
    );
  }

  Future<void> _updateNonMonStatus(
    dynamic appointmentId,
    String newStatus, {
    int? furparentId,
    String item = 'item',
    String qty = '',
    String? contactNumber,
  }) async {
    if (appointmentId == null) return;
    try {
      await Supabase.instance.client
          .from('donation_appointments')
          .update({'status': newStatus})
          .eq('donationappointment_id', appointmentId);

      try {
        if (furparentId != null) {
          final approved = newStatus == 'Completed';
          await Supabase.instance.client.from('user_notifications').insert({
            'furparent_id': furparentId,
            'title':
                approved
                    ? '✅ Non-Monetary Donation Approved!'
                    : 'Non-Monetary Donation Not Approved',
            'body':
                approved
                    ? 'Your donation of "$item"${qty.isNotEmpty ? " (qty: $qty)" : ""} has been approved. We will coordinate with you. Thank you!'
                    : 'Your donation of "$item"${qty.isNotEmpty ? " (qty: $qty)" : ""} was not approved. Please contact us.',
            'type': 'non_monetary_donation_status',
            'screen': 'DonationPage',
            'phone_number': contactNumber,
            'read': false,
          });
        }
      } catch (e) {
        debugPrint('Notification error: $e');
      }

      await _loadNonMonetaryDonations();
      await _loadPendingNonMonetaryDonations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status updated to $newStatus',
            style: const TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: newStatus == 'Completed' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('Error updating non-monetary status: $e');
    }
  }

  String _formatDate(dynamic raw, String format) {
    final date = _parseDate(raw);
    if (date == null) return '—';
    return DateFormat(format).format(date);
  }

  Widget _datePickerChip(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onPicked,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder:
              (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: Colors.orange),
                ),
                child: child!,
              ),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              value != null
                  ? Colors.orange.withOpacity(0.18)
                  : const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                value != null ? Colors.orange.withOpacity(0.5) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 13,
              color: value != null ? Colors.orange : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              value != null
                  ? '$label: ${DateFormat('MMM d, yyyy').format(value)}'
                  : '$label: Any',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                color: value != null ? Colors.orange : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clearChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.close, size: 13, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownChip<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          dropdownColor: const Color(0xFF3A3A3A),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontSize: 12,
          ),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Colors.white54,
            size: 18,
          ),
          items:
              items
                  .map(
                    (v) => DropdownMenuItem<T>(
                      value: v,
                      child: Text('$label: $v'),
                    ),
                  )
                  .toList(),
          onChanged: (v) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onChanged(v);
            });
          },
        ),
      ),
    );
  }

  Widget _paginationRow(int page, int total, ValueChanged<int> onPage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page ${page + 1} of $total',
            style: const TextStyle(
              color: Colors.white38,
              fontFamily: 'Montserrat',
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              _pageBtn(Icons.first_page, page > 0, () => onPage(0)),
              _pageBtn(Icons.chevron_left, page > 0, () => onPage(page - 1)),
              _pageBtn(
                Icons.chevron_right,
                page < total - 1,
                () => onPage(page + 1),
              ),
              _pageBtn(
                Icons.last_page,
                page < total - 1,
                () => onPage(total - 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportTitle() => Row(
    children: const [
      Icon(Icons.volunteer_activism, color: Colors.orange, size: 20),
      SizedBox(width: 8),
      Text(
        'Donation Report',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ],
  );

  Widget _searchBar({bool isMobile = false}) => TextField(
    controller: _searchController,
    style: const TextStyle(
      color: Colors.white,
      fontFamily: 'Montserrat',
      fontSize: 13,
    ),
    decoration: InputDecoration(
      hintText: 'Search donor, reference, amount…',
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
      suffixIcon:
          _searchQuery.isNotEmpty
              ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
              : null,
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 6 : 10),
      isDense: isMobile,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _nonMonSearchBar({bool isMobile = false}) => TextField(
    controller: _nonMonSearchController,
    style: const TextStyle(
      color: Colors.white,
      fontFamily: 'Montserrat',
      fontSize: 13,
    ),
    decoration: InputDecoration(
      hintText: 'Search donor, item, category…',
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
      suffixIcon:
          _nonMonSearchQuery.isNotEmpty
              ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                onPressed: () {
                  _nonMonSearchController.clear();
                  setState(() => _nonMonSearchQuery = '');
                },
              )
              : null,
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 6 : 10),
      isDense: isMobile,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _buildExpenseSearchBar({bool isMobile = false}) => TextField(
    controller: _expenseSearchCtrl,
    style: const TextStyle(
      color: Colors.white,
      fontFamily: 'Montserrat',
      fontSize: 13,
    ),
    decoration: InputDecoration(
      hintText: 'Search category, description…',
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
      suffixIcon:
          _expenseSearch.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                  onPressed: () {
                    _expenseSearchCtrl.clear();
                  },
                )
              : null,
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 6 : 10),
      isDense: isMobile,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _buildVialsSearchBar({bool isMobile = false}) => TextField(
    controller: _vialsSearchCtrl,
    style: const TextStyle(
      color: Colors.white,
      fontFamily: 'Montserrat',
      fontSize: 13,
    ),
    decoration: InputDecoration(
      hintText: 'Search vet, vaccine, notes…',
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
      suffixIcon:
          _vialsSearch.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                  onPressed: () {
                    _vialsSearchCtrl.clear();
                    setState(() => _vialsSearch = '');
                  },
                )
              : null,
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 6 : 10),
      isDense: isMobile,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _responsiveTableWrapper({
    required ScrollController controller,
    required Widget child,
    double minWidth = 1000,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: controller,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth > minWidth
                    ? constraints.maxWidth
                    : minWidth,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }



  DataColumn _sortableCol(String label, String col) {
    final active = _reportSortCol == col;
    return DataColumn(
      onSort: (_, __) => _sortBy(col),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.orange : Colors.white,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            active
                ? (_reportSortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 14,
            color: active ? Colors.orange : Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'rejected':
      case 'failed':
        color = Colors.red;
        break;
      default:
        color = Colors.white54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontFamily: 'Montserrat',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontFamily: 'Montserrat',
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: enabled ? Colors.white70 : Colors.white24,
      ),
      onPressed: enabled ? onTap : null,
      splashRadius: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    final totalPendingBadge =
        _pendingDonations.length + _pendingNonMonetaryDonations.length;

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
                        (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                  ),
                  title: const Text(
                    'Donation',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
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
                        width: 24,
                        height: 24,
                      ),
                    ),
                    _NotificationBell(
                      iconSize: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    _buildProfileAvatar(radius: isMobile ? 14 : 16),
                    const SizedBox(width: 8),
                  ],
                )
                : null,
        body: Row(
          children: [
            if (!isMobile) _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  if (!isMobile) _buildTopHeader(isMobile),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 12 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isMobile
                              ? Column(
                                children: [
                                  buildDonationFundPanel(),
                                  const SizedBox(height: 12),
                                  _buildChartCard(),
                                ],
                              )
                              : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    flex: 2,
                                    child: buildDonationFundPanel(),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(flex: 3, child: _buildChartCard()),
                                ],
                              ),

                          const SizedBox(height: 24),

                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _reportTab(
                                        'Monetary',
                                        0,
                                        Icons.attach_money,
                                      ),
                                      _reportTab(
                                        'Non-Monetary',
                                        1,
                                        Icons.inventory_2_outlined,
                                      ),
                                      _reportTab(
                                        'Expenses',
                                        2,
                                        Icons.receipt_long,
                                      ),
                                      _reportTabWithBadge(
                                        'Verify',
                                        3,
                                        Icons.verified_outlined,
                                        totalPendingBadge,
                                      ),

                                      _reportTab('Vials', 4, Icons.vaccines),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_donationTabIndex == 0)
                                  _buildDonationReport()
                                else if (_donationTabIndex == 1)
                                  _buildNonMonetaryReport()
                                else if (_donationTabIndex == 2)
                                  _buildExpensesReport()
                                else if (_donationTabIndex == 3)
                                  _buildPendingVerificationTab()
                                else
                                  _buildVialsTab(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          buildFooter(context),
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

  Widget _reportTab(String label, int index, IconData icon) {
    final active = _donationTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _donationTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 4, top: 4, left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.orange : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? Colors.black : Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : Colors.white54,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportTabWithBadge(
    String label,
    int index,
    IconData icon,
    int badgeCount,
  ) {
    final active = _donationTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _donationTabIndex = index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 4, top: 4, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: active ? Colors.orange : const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? Colors.black : Colors.white54,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.black : Colors.white54,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Donation Rate",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildChartFilters(),
                  ],
                )
              : Row(
                  children: [
                    const Text(
                      "Donation Rate",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    _buildChartFilters(),
                  ],
                ),
          const SizedBox(height: 16),
          _buildDonationChart(),
        ],
      ),
    );
  }

  Widget buildDonationFundPanel() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Balance",
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: "Montserrat",
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 6),
                    Text(
                      "₱ ${_totalBalance.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 18 : 22,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showAddAmountDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          "₱ Cash Donation",
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openAddFundsDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          "Add Allocation",
                          style: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Balance",
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: "Montserrat",
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      Text(
                        "₱ ${_totalBalance.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 18 : 22,
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => _showAddAmountDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(140, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        "₱ Cash Donation",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _openAddFundsDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        "Add Allocation",
                        style: TextStyle(fontFamily: 'Montserrat', fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(140, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          SizedBox(height: isMobile ? 12 : 20),
          const Divider(color: Colors.white24),
          SizedBox(height: isMobile ? 6 : 12),
          Text(
            "Fund Usage",
            style: TextStyle(
              color: Colors.white,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          donationSections.isEmpty
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    "No fund usage data",
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: "Montserrat",
                      fontSize: 14,
                    ),
                  ),
                ),
              )
              : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: donationSections.length,
                itemBuilder: (context, index) {
                  final entry = donationSections[index];
                  final name = entry['section_name'] ?? 'Unknown';
                  final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
                  final desc = entry['description']?.toString() ?? '';
                  final sectionId = entry['donationsec_id'] as int?;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: "Montserrat",
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "₱ ${amount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontFamily: "Montserrat",
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (desc.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    desc,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontFamily: "Montserrat",
                                      fontSize: 11,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed:
                              () => _confirmDeleteFund(
                                sectionId: sectionId,
                                amount: amount,
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

  Future<void> _confirmDeleteFund({
    required int? sectionId,
    required double amount,
  }) async {
    if (sectionId == null) {
      _showError(context, "Invalid section ID");
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Delete Fund Allocation',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
            content: const Text(
              'The allocated amount will be returned to the total balance. Continue?',
              style: TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
    );
    if (confirm == true)
      await _deleteFundAndReturnBalance(sectionId: sectionId, amount: amount);
  }

  void _showAddAmountDialog(BuildContext context) {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final furParentController = TextEditingController();
    final phoneNumberController = TextEditingController();
    final emailController = TextEditingController();
    bool requireVerification = true;

    amountController.addListener(() {
      String text = amountController.text.replaceAll(',', '');
      if (text.isEmpty) return;
      final value = double.tryParse(text);
      if (value == null) return;
      final formatted = NumberFormat('#,###.##').format(value);
      if (formatted != amountController.text) {
        amountController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => StatefulBuilder(
            builder:
                (ctx, setDlg) => Dialog(
                  backgroundColor: const Color(0xFF1B1F1B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 440,
                      maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.account_balance_wallet,
                                color: Colors.green,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Add Cash Donation",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInput(
                                    controller: amountController,
                                    label: "Amount",
                                    hint: "Enter amount",
                                    prefix: "₱ ",
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInput(
                                    controller: referenceController,
                                    label: "Reference Number",
                                    hint: "Transaction reference",
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInput(
                                    controller: furParentController,
                                    label: "Donor Name",
                                    hint: "Full name",
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInput(
                                    controller: phoneNumberController,
                                    label: "Phone Number",
                                    hint: "11-digit number",
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInput(
                                    controller: emailController,
                                    label: "Email",
                                    hint: "example@email.com",
                                    keyboardType: TextInputType.emailAddress,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.deny(
                                        RegExp(r'\s'),
                                      ),
                                      LengthLimitingTextInputFormatter(254),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  final amountText = amountController.text
                                      .replaceAll(',', '');
                                  final reference =
                                      referenceController.text.trim();
                                  final name = furParentController.text.trim();
                                  final phone =
                                      phoneNumberController.text.trim();
                                  final email = emailController.text.trim();
                                  final amount = double.tryParse(amountText);
                                  if (amount == null || amount <= 0) {
                                    _showError(
                                      context,
                                      "Please enter a valid amount.",
                                    );
                                    return;
                                  }
                                  if (reference.isEmpty) {
                                    _showError(
                                      context,
                                      "Reference number is required.",
                                    );
                                    return;
                                  }
                                  if (name.isEmpty) {
                                    _showError(
                                      context,
                                      "Donor name is required.",
                                    );
                                    return;
                                  }
                                  if (email.isEmpty ||
                                      !RegExp(
                                        r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$',
                                      ).hasMatch(email)) {
                                    _showError(
                                      context,
                                      "Please enter a valid email (e.g. example@gmail.com).",
                                    );
                                    return;
                                  }
                                  if (phone.length != 11 ||
                                      !RegExp(r'^[0-9]+$').hasMatch(phone)) {
                                    _showError(
                                      context,
                                      "Phone number must be 11 digits.",
                                    );
                                    return;
                                  }

                                  await _addDonation(
                                    amount: amount,
                                    reference: reference,
                                    furParent: name,
                                    phoneNumber: phone,
                                    email: email,
                                    status: 'Completed',
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  _showSnackBar(
                                    'Cash donation added successfully.',
                                    Colors.green,
                                  );
                                },
                                child: const Text(
                                  "Add Donation",
                                  style: TextStyle(
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
                  ),
                ),
          ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? prefix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontFamily: "Montserrat", color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixText: prefix,
            prefixStyle: const TextStyle(color: Colors.white),
            filled: true,
            fillColor: const Color(0xFF2A2F2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _openAddFundsDialog() {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedSection = 'Food';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  backgroundColor: const Color(0xFF2D2D2D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Center(
                    child: Text(
                      "Add Fund Allocation",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        "Amount (₱)",
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter amount",
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
                      const SizedBox(height: 12),
                      const Text(
                        "Section",
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
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
                            value: selectedSection,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF3C3C3C),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                            ),
                            items:
                                ['Food', 'Medical', 'Transportation']
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          s,
                                          style: const TextStyle(
                                            fontFamily: 'Montserrat',
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  setDialogState(() => selectedSection = value);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Description (where money was spent)",
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                        ),
                        decoration: InputDecoration(
                          hintText:
                              "e.g. 10 kilos of dog food, vaccination supplies…",
                          hintStyle: const TextStyle(
                            color: Colors.white38,
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF3C3C3C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final amount = double.tryParse(
                          amountController.text.trim(),
                        );
                        if (amount == null || amount <= 0) {
                          _showSnackBar(
                            'Please enter a valid amount!',
                            Colors.red,
                          );
                          return;
                        }
                        if (amount > _totalBalance) {
                          if (!context.mounted) return;
                          _showSnackBar(
                            'Insufficient funds! Available: ₱${_totalBalance.toStringAsFixed(2)}',
                            Colors.red,
                          );
                          return;
                        }
                        try {
                          await Supabase.instance.client
                              .from('donation_section')
                              .insert({
                                'section_name': selectedSection,
                                'amount': amount,
                                'description':
                                    descriptionController.text.trim(),
                                'created_at': DateTime.now().toIso8601String(),
                              });
                          await logActivity(
                            action: 'Allocated Donation Funds',
                            description:
                                'Allocated ₱${amount.toStringAsFixed(2)} to $selectedSection',
                            entityType: 'Donation Allocation',
                          );
                          if (!context.mounted) return;
                          await _loadDonationSections();
                          await _loadExpenses();
                          Navigator.pop(context);
                          _showSnackBar(
                            '₱${amount.toStringAsFixed(2)} allocated to $selectedSection!',
                            Colors.green,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          _showSnackBar('Error adding allocation.', Colors.red);
                        }
                      },
                      child: const Text(
                        "Allocate Funds",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  void _launchGoogleMaps(String address) {
    if (address.isEmpty || address == '—') return;
    final encoded = Uri.encodeComponent(address);
    final url = 'https://www.google.com/maps/search/?api=1&query=$encoded';
    html.window.open(url, '_blank');
  }

  Widget _detailRowWithLink(String label, String value, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: onTap != null ? Colors.blue : Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w500,
                        decoration:
                            onTap != null
                                ? TextDecoration.underline
                                : TextDecoration.none,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.open_in_new, color: Colors.blue, size: 14),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNonMonDetailsDialog(BuildContext context, Map<String, dynamic> d) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text(
              'Non-Monetary Donation Details',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogImages(
                      d['image_url_1']?.toString(),
                      d['image_url_2']?.toString(),
                    ),
                    _detailRow('Donor', d['furparent_name'] ?? 'Anonymous'),
                    _detailRow('Contact', d['furparent_contact'] ?? '—'),
                    _detailRow('Item', d['donation_item'] ?? '—'),
                    _detailRow('Category', d['donation_category'] ?? '—'),
                    _detailRow(
                      'Quantity',
                      d['donation_quantity']?.toString() ?? '—',
                    ),

                    _detailRowWithLink(
                      'Pickup Address',
                      d['pickup_address']?.toString().isNotEmpty == true
                          ? d['pickup_address'].toString()
                          : '—',
                      d['pickup_address']?.toString().isNotEmpty == true
                          ? () =>
                              _launchGoogleMaps(d['pickup_address'].toString())
                          : null,
                    ),

                    _detailRow(
                      'Scheduled',
                      d['scheduled_date'] != null
                          ? _formatDate(
                            d['scheduled_date'],
                            'MMM d, yyyy – h:mm a',
                          )
                          : '—',
                    ),
                    _detailRow('Time', d['time_start'] ?? '—'),
                    _detailRow('Notes', d['notes'] ?? '—'),
                    _detailRow('Status', d['status'] ?? '—'),
                    _detailRow(
                      'Submitted',
                      d['created_at'] != null
                          ? _formatDate(d['created_at'], 'MMM d, yyyy – h:mm a')
                          : '—',
                    ),
                  ],
                ),
              ),
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

  Widget _buildDialogImages(String? url1, [String? url2]) {
    final images =
        [
          url1,
          url2,
        ].where((u) => u != null && u.isNotEmpty).cast<String>().toList();
    if (images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photos',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Montserrat',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children:
                images
                    .map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _showFullImage(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: buildWebImage(
                              url: url,
                              width: 130,
                              height: 100,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                width: 130,
                                height: 100,
                                color: const Color(0xFF3A3A3A),
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap an image to expand',
            style: TextStyle(
              color: Colors.white24,
              fontFamily: 'Montserrat',
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
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
                    child: buildWebImage(
                      url: url,
                      width: double.infinity,
                      height: 500,
                      fit: BoxFit.contain,
                      errorWidget: const Center(
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

  void _showDonationDetailsDialog(
    BuildContext context,
    Map<String, dynamic> donation,
  ) {
    final amount = _parseAmount(donation['amount']);
    final dateStr = _formatDate(
      donation['created_at'],
      'MMMM d, yyyy – h:mm a',
    );
    final imageUrl = donation['image_url']?.toString() ?? '';
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
                        decoration: const BoxDecoration(
                          color: Color(0xFF252525),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.4),
                                ),
                              ),
                              child: const Icon(
                                Icons.volunteer_activism,
                                color: Colors.orange,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Donation Details',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Monetary Contribution',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontFamily: 'Montserrat',
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.withOpacity(0.18),
                              Colors.orange.withOpacity(0.05),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Amount Donated',
                              style: TextStyle(
                                color: Colors.white60,
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '₱ ${NumberFormat('#,##0.00').format(amount)}',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (imageUrl.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    color: Colors.white38,
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'PAYMENT PROOF',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _showFullImage(context, imageUrl),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 180,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: _buildStackableImage(
                                            url: imageUrl,
                                            width: double.infinity,
                                            height: 180,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.zoom_in,
                                                  color: Colors.white70,
                                                  size: 12,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Tap to expand',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
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
                        const SizedBox(height: 20),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.person_outline,
                              color: Colors.white38,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'DONOR INFORMATION',
                              style: TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 1,
                                child: ColoredBox(color: Color(0x1AFFFFFF)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF252525),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              _infoTile(
                                Icons.person,
                                'Donor Name',
                                donation['furparent_name']?.toString() ??
                                    'Anonymous',
                                isFirst: true,
                              ),
                              _infoDivider(),
                              _infoTile(
                                Icons.tag,
                                'Reference No.',
                                donation['reference_number']?.toString() ?? '—',
                              ),
                              _infoDivider(),
                              _infoTile(
                                Icons.email_outlined,
                                'Email',
                                donation['email']?.toString() ?? '—',
                              ),
                              _infoDivider(),
                              _infoTile(
                                Icons.phone_outlined,
                                'Phone',
                                donation['phone_number']?.toString() ?? '—',
                              ),
                              _infoDivider(),
                              _infoTile(
                                Icons.calendar_today_outlined,
                                'Date & Time',
                                dateStr,
                              ),
                              _infoDivider(),
                              _infoTile(
                                Icons.check_circle_outline,
                                'Status',
                                donation['status']?.toString() ?? '—',
                                isLast: true,
                                statusColor: _statusColor(
                                  donation['status']?.toString() ?? '',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.07),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                color: Colors.white60,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
      case 'failed':
        return Colors.red;
      default:
        return Colors.white54;
    }
  }

  Widget _infoTile(
    IconData icon,
    String label,
    String value, {
    bool isFirst = false,
    bool isLast = false,
    Color? statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(12) : Radius.zero,
          bottom: isLast ? const Radius.circular(12) : Radius.zero,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white24, size: 16),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontFamily: 'Montserrat',
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: statusColor ?? Colors.white,
                fontFamily: 'Montserrat',
                fontWeight:
                    statusColor != null ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoDivider() => const Divider(
    height: 1,
    color: Colors.white10,
    indent: 16,
    endIndent: 16,
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

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
                  if (context.mounted)
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnimatedAdminLoginPage(),
                      ),
                      (route) => false,
                    );
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

  Widget buildFooter(BuildContext context) => Container(
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

  Future<void> _saveDonationNotification({
    required double amount,
    required String reference,
    required String name,
    required String email,
    required String phone,
  }) async {
    final supabase = Supabase.instance.client;
    final profile =
        await supabase
            .from('profiles')
            .select('furparent_id')
            .eq('email', email)
            .maybeSingle();
    if (profile == null) throw Exception("Fur parent not found");
    final int furparentId = profile['furparent_id'];
    await supabase.from('user_notifications').insert({
      'furparent_id': furparentId,
      'title': 'Donation Received',
      'body': '₱${amount.toStringAsFixed(2)} added by $name\nRef: $reference',
      'type': 'donation',
      'screen': 'donations',
      'amount': amount,
      'email': email,
      'phone_number': phone,
      'read': false,
    });
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
              'Donation',
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
                final deletedId = payload.oldRecord['notification_id'];
                if (deletedId != null && mounted)
                  setState(
                    () => _notifications.removeWhere(
                      (n) => n['notification_id'] == deletedId,
                    ),
                  );
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
      if (mounted)
        setState(
          () => _notifications = List<Map<String, dynamic>>.from(response),
        );
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
      case 'donation_status':
        return Icons.volunteer_activism;
      case 'non_monetary_donation_status':
        return Icons.inventory_2_outlined;
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
      case 'donation_status':
        return Colors.orange;
      case 'non_monetary_donation_status':
        return Colors.amber;
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
