import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gallery_saver/files.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui;

import 'package:apawtmentweb_admin/dashboardpage.dart';
import 'package:apawtmentweb_admin/activitylogs.dart';
import 'package:apawtmentweb_admin/appointment/appointmentpage.dart';
import 'package:apawtmentweb_admin/approvalpage.dart';
import 'package:apawtmentweb_admin/accountmanagement/accountmanagementlist.dart';
import 'package:apawtmentweb_admin/eventspage.dart';
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/chatpage.dart';
import 'package:apawtmentweb_admin/donationpage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:apawtmentweb_admin/profilepage.dart';
import 'package:apawtmentweb_admin/services/security_service.dart';

final supabase = Supabase.instance.client;
String? adminId;

void saveLastVisitedPage(String pageName) {
  if (kIsWeb) {
    try {
      web.window.sessionStorage.setItem('last_visited_page', pageName);
    } catch (e) {
      debugPrint('Error writing last_visited_page: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: 'assets/env');
    debugPrint('✅ Environment variables loaded successfully.');
  } catch (e) {
    debugPrint('❌ Error loading environment variables: $e');
  }

  if (kIsWeb) {
    ui.platformViewRegistry.registerViewFactory('google-maps-iframe', (
      int viewId,
    ) {
      final iframe =
          web.HTMLIFrameElement()
            ..src = ''
            ..style.border = '0'
            ..style.width = '100%'
            ..style.height = '200px';
      return iframe;
    });
  }

  try {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_URL or SUPABASE_ANON_KEY is missing in env.');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );
    debugPrint('✅ Supabase initialized successfully.');
  } catch (e) {
    debugPrint('❌ Supabase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APawtment Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: const AuthGate(),
    );

  }
}

// ── Auth Gate ────────────────────────────────────────────────────────────────

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      if (kIsWeb) {
        final sessionActive = web.window.sessionStorage.getItem('is_session_active');
        if (sessionActive != 'true') {
          // Fresh tab/session — clear the login state
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('admin_id');
          web.window.sessionStorage.removeItem('last_visited_page');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final savedAdminId = prefs.getString('admin_id');

      if (savedAdminId != null) {
        // Verify the admin still exists in DB (guards against deleted accounts)
        final admin =
            await supabase
                .from('admin')
                .select('admin_id')
                .eq('admin_id', int.parse(savedAdminId))
                .maybeSingle();

        if (admin != null && mounted) {
          adminId = savedAdminId;
          setState(() {
            _isLoggedIn = true;
            _checking = false;
          });
          return;
        }

        // Admin no longer valid — clear stale session
        await prefs.clear();
      }
    } catch (e) {
      debugPrint('Session check error: $e');
    }

    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _checking = false;
      });
    }
  }

  Widget _getLastVisitedPageWidget() {
    if (!kIsWeb) return const DashboardPage();
    try {
      final lastPage = web.window.sessionStorage.getItem('last_visited_page');
      switch (lastPage) {
        case 'Dashboard':
          return const DashboardPage();
        case 'Activity Logs':
          return const ActivityLogsPage();
        case 'Appointment':
          return const AppointmentPage();
        case 'Approval':
          return const ApprovalPage();
        case 'Account Management':
          return const AccountManagementListPage();
        case 'Events':
          return const EventsPage();
        case 'Pet Management':
          return const PetPage();
        case 'Chats':
          return const ChatPage();
        case 'Donation':
          return const DonationPage();
        case 'Report':
          return const ReportsPage();
        case 'Profile':
          return const ProfilePage();
        default:
          return const DashboardPage();
      }
    } catch (e) {
      debugPrint('Error reading last_visited_page: $e');
      return const DashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
      );
    }
    return _isLoggedIn ? _getLastVisitedPageWidget() : const AnimatedAdminLoginPage();
  }
}

// ── Login Page ───────────────────────────────────────────────────────────────

class AnimatedAdminLoginPage extends StatefulWidget {
  const AnimatedAdminLoginPage({super.key});

  @override
  State<AnimatedAdminLoginPage> createState() => _AnimatedAdminLoginPageState();
}

class _AnimatedAdminLoginPageState extends State<AnimatedAdminLoginPage>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscureText = true;
  bool _loading = false;

  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;

  late AnimationController _formController;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _formOpacityAnimation;

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _checkLockout();
    if (kIsWeb) {
      try {
        web.window.sessionStorage.removeItem('is_session_active');
        web.window.sessionStorage.removeItem('last_visited_page');
      } catch (e) {
        debugPrint('Error clearing sessionStorage: $e');
      }
    }

    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _logoScaleAnimation = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));

    _formController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formController, curve: Curves.easeOut));
    _formOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _formController, curve: Curves.easeIn));

    _logoController.forward().then((_) => _formController.forward());
  }

  @override
  void dispose() {
    _logoController.dispose();
    _formController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutStr = prefs.getString('login_lockout_until');
    if (lockoutStr != null) {
      final lockoutUntil = DateTime.parse(lockoutStr);
      if (DateTime.now().isBefore(lockoutUntil)) {
        setState(() {
          _lockoutUntil = lockoutUntil;
          _secondsRemaining = lockoutUntil.difference(DateTime.now()).inSeconds;
        });
        _startLockoutTimer();
      } else {
        await prefs.remove('login_lockout_until');
        await prefs.setInt('login_failed_attempts', 0);
      }
    } else {
      final attempts = prefs.getInt('login_failed_attempts') ?? 0;
      setState(() {
        _failedAttempts = attempts;
      });
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      if (now.isBefore(_lockoutUntil!)) {
        setState(() {
          _secondsRemaining = _lockoutUntil!.difference(now).inSeconds;
        });
      } else {
        timer.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('login_lockout_until');
        await prefs.setInt('login_failed_attempts', 0);
        setState(() {
          _lockoutUntil = null;
          _failedAttempts = 0;
          _secondsRemaining = 0;
        });
      }
    });
  }

  Future<void> _handleFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final currentAttempts = (prefs.getInt('login_failed_attempts') ?? 0) + 1;
    await prefs.setInt('login_failed_attempts', currentAttempts);

    if (currentAttempts >= 5) {
      final lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
      await prefs.setString('login_lockout_until', lockoutUntil.toIso8601String());
      setState(() {
        _failedAttempts = currentAttempts;
        _lockoutUntil = lockoutUntil;
        _secondsRemaining = 30;
      });
      _startLockoutTimer();
      _showSnackBar('Too many failed login attempts. You are locked out for 30 seconds.');
    } else {
      setState(() {
        _failedAttempts = currentAttempts;
      });
      _showSnackBar('Invalid username or password. Attempt $currentAttempts of 5.');
    }
  }

  // ── Replace _AnimatedAdminLoginPageState._login ───────────────────────────────
  Future<void> _login() async {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      _showSnackBar('Too many failed attempts. Try again in $_secondsRemaining seconds.');
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter both username and password.');
      return;
    }

    if (username.length > 50 || password.length > 100) {
      _showSnackBar('Input length limit exceeded.');
      return;
    }

    setState(() => _loading = true);

    try {
      final adminData =
          await supabase
              .from('admin')
              .select()
              .eq('username', username)
              .maybeSingle();

      if (adminData == null) {
        await _handleFailedAttempt();
        return;
      }

      final storedPassword = adminData['password'] as String;
      final hashedInput = hashPassword(password);

      bool isMatch = false;
      if (storedPassword == hashedInput) {
        isMatch = true;
      } else if (!isSha256(storedPassword) && storedPassword == password) {
        // Auto-migration path for legacy plaintext passwords
        isMatch = true;
        await supabase
            .from('admin')
            .update({'password': hashedInput})
            .eq('admin_id', adminData['admin_id']);
      }

      if (!isMatch) {
        await _handleFailedAttempt();
        return;
      }

      // Successful login - clear attempts and lockout
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('login_failed_attempts', 0);
      await prefs.remove('login_lockout_until');

      await prefs.setString('admin_id', adminData['admin_id'].toString());

      adminId = adminData['admin_id'].toString();

      if (kIsWeb) {
        web.window.sessionStorage.setItem('is_session_active', 'true');
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Login failed. Check your internet connection.');
      debugPrint('Login error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 80,
                vertical: 40,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1200,
                  minHeight: constraints.maxHeight,
                ),
                child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: FadeTransition(
              opacity: _logoOpacityAnimation,
              child: ScaleTransition(
                scale: _logoScaleAnimation,
                child: Image.asset('assets/images/adminlogo.png', width: 260),
              ),
            ),
          ),
        ),
        Expanded(
          child: SlideTransition(
            position: _formSlideAnimation,
            child: FadeTransition(
              opacity: _formOpacityAnimation,
              child: _buildLoginForm(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: _logoOpacityAnimation,
          child: ScaleTransition(
            scale: _logoScaleAnimation,
            child: Image.asset('assets/images/adminlogo.png', width: 180),
          ),
        ),
        const SizedBox(height: 40),
        SlideTransition(
          position: _formSlideAnimation,
          child: FadeTransition(
            opacity: _formOpacityAnimation,
            child: _buildLoginForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome',
          style: TextStyle(
            fontSize: 36,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _usernameController,
          focusNode: _usernameFocus,
          textInputAction: TextInputAction.next,
          onSubmitted:
              (_) => FocusScope.of(context).requestFocus(_passwordFocus),
          decoration: _inputDecoration('Username'),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: _obscureText,
          onSubmitted: (_) => _login(),
          decoration: _inputDecoration('Password').copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_off : Icons.visibility,
                color: Colors.white54,
              ),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_loading || _lockoutUntil != null) ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: _lockoutUntil != null ? Colors.grey : Colors.orangeAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child:
                _loading
                    ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : Text(
                        _lockoutUntil != null
                            ? 'LOCKED OUT ($_secondsRemaining\s)'
                            : 'LOG IN',
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                ),
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}


class _OtpStore {
  static String? _otp;
  static String? _email;
  static DateTime? _expiry;

  static void save(String email, String otp) {
    _email = email;
    _otp = otp;
    _expiry = DateTime.now().add(const Duration(minutes: 5));
  }

  static bool verify(String email, String otp) {
    if (_otp == null || _email == null || _expiry == null) return false;
    if (DateTime.now().isAfter(_expiry!)) return false;
    return _email == email && _otp == otp;
  }

  static void clear() {
    _otp = null;
    _email = null;
    _expiry = null;
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum _ForgotStep { enterEmail, verifyOtp, newPassword }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  _ForgotStep _step = _ForgotStep.enterEmail;

  // Step 1
  final _emailController = TextEditingController();

  // Step 2
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  Timer? _resendTimer;
  int _resendSeconds = 0;

  // Step 3
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _loading = false;
  String? _verifiedEmail;
  String? _adminFirstName; // ← store for the greeting in email
  int _otpVerifyAttempts = 0;

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    _OtpStore.clear();
    super.dispose();
  }

  // ── Step 1: Send OTP ────────────────────────────────────────────────────────

  Future<void> _sendOtp({bool isResend = false}) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your admin email');
      return;
    }

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Check if the user is in a verification lockout period
      final verifyLockoutStr = prefs.getString('otp_verify_lockout_until');
      if (verifyLockoutStr != null) {
        final verifyLockoutUntil = DateTime.parse(verifyLockoutStr);
        if (DateTime.now().isBefore(verifyLockoutUntil)) {
          final waitSeconds = verifyLockoutUntil.difference(DateTime.now()).inSeconds;
          _showSnackBar('Too many incorrect verification attempts. Please wait $waitSeconds seconds.');
          return;
        } else {
          await prefs.remove('otp_verify_lockout_until');
        }
      }

      // 2. Check requests rate limit (max 3 requests per 5 minutes)
      final list = prefs.getStringList('otp_request_timestamps') ?? [];
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

      final validTimestamps = list
          .map((t) => DateTime.parse(t))
          .where((dt) => dt.isAfter(fiveMinutesAgo))
          .toList();

      if (validTimestamps.length >= 3) {
        final oldest = validTimestamps.first;
        final diff = oldest.add(const Duration(minutes: 5)).difference(now);
        _showSnackBar(
          'Too many OTP requests. Please wait ${diff.inMinutes}m ${diff.inSeconds % 60}s before requesting a new OTP.',
        );
        return;
      }

      // Check email exists in admin table
      final admin =
          await supabase
              .from('admin')
              .select('admin_id, email, name')
              .eq('email', email)
              .maybeSingle();

      if (admin == null) {
        _showSnackBar('No admin account found with this email');
        return;
      }

      // Generate 6-digit OTP
      final otp = (100000 + Random.secure().nextInt(900000)).toString();
      _OtpStore.save(email, otp);

      // Format expiry time to match {{time}} in the template
      final expiry = DateTime.now().add(const Duration(minutes: 5));
      final timeStr =
          '${expiry.hour.toString().padLeft(2, '0')}:'
          '${expiry.minute.toString().padLeft(2, '0')} '
          '(${expiry.timeZoneName})';

      // Extract first name from the name column
      // e.g. "Juan dela Cruz" → "Juan"
      final fullName = (admin['name'] ?? 'Admin').toString();
      final firstName = fullName.split(' ').first;
      _adminFirstName = firstName;

      final sent = await _sendOtpEmail(
        email: email,
        firstName: firstName,
        otp: otp,
        time: timeStr,
      );

      if (!sent) {
        _showSnackBar('Failed to send OTP. Please try again.');
        return;
      }

      // Record successful OTP request timestamp
      validTimestamps.add(now);
      await prefs.setStringList(
        'otp_request_timestamps',
        validTimestamps.map((dt) => dt.toIso8601String()).toList(),
      );

      // Reset verification attempts
      _otpVerifyAttempts = 0;

      if (mounted) {
        setState(() {
          _verifiedEmail = email;
          _step = _ForgotStep.verifyOtp;
        });
        _startResendTimer();
        if (isResend) {
          _showSnackBar(
            'A new OTP has been sent to $email',
            color: Colors.green,
          );
        }
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
      debugPrint('Send OTP error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _sendOtpEmail({
    required String otp,
    required String email,
    required String firstName,
    required String time,
  }) async {
    try {
      final serviceId = dotenv.env['EMAILJS_SERVICE_ID']!;
      final templateId = dotenv.env['EMAILJS_TEMPLATE_ID']!;
      final publicKey = dotenv.env['EMAILJS_PUBLIC_KEY']!;

      final res = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'to_email': email,
            'first_name': firstName, // ✅ match {{first_name}}
            'passcode': otp, // ✅ match {{passcode}}
            'time': time, // ✅ match {{time}}
          },
        }),
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('EmailJS error: $e');
      return false;
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _verifyOtp() async {
    final entered = _otpControllers.map((c) => c.text.trim()).join();

    if (entered.length < 6) {
      _showSnackBar('Please enter the full 6-digit OTP');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (!_OtpStore.verify(_verifiedEmail!, entered)) {
      _otpVerifyAttempts++;
      if (_otpVerifyAttempts >= 5) {
        final lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
        await prefs.setString('otp_verify_lockout_until', lockoutUntil.toIso8601String());
        _OtpStore.clear();
        setState(() {
          _step = _ForgotStep.enterEmail;
        });
        _showSnackBar('Too many incorrect OTP attempts. The OTP has been invalidated and requests locked for 5 minutes.');
      } else {
        _showSnackBar('Invalid or expired OTP. Attempt $_otpVerifyAttempts of 5.');
        for (final c in _otpControllers) c.clear();
        _otpFocusNodes.first.requestFocus();
      }
      return;
    }

    // Success: reset attempts
    _otpVerifyAttempts = 0;
    await prefs.remove('otp_verify_lockout_until');

    setState(() => _step = _ForgotStep.newPassword);
  }

  // ── Step 3: Update password ─────────────────────────────────────────────────

  Future<void> _updatePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Please fill in both fields');
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return;
    }
    if (!isPasswordStrong(newPassword)) {
      _showSnackBar('Password must be at least 8 characters long.');
      return;
    }

    setState(() => _loading = true);

    try {
      final hashedNew = hashPassword(newPassword);
      await supabase
          .from('admin')
          .update({'password': hashedNew})
          .eq('email', _verifiedEmail!);

      _OtpStore.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password updated successfully!',
              style: TextStyle(fontFamily: 'Montserrat'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Failed to update password. Try again.');
      debugPrint('Update password error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _showSnackBar(String msg, {Color color = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Montserrat')),
        backgroundColor: color,
      ),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white10,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Montserrat'),
  );

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading:
            _step != _ForgotStep.enterEmail
                ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed:
                      () => setState(() {
                        if (_step == _ForgotStep.verifyOtp) {
                          _step = _ForgotStep.enterEmail;
                        } else if (_step == _ForgotStep.newPassword) {
                          _step = _ForgotStep.verifyOtp;
                        }
                      }),
                )
                : null,
        title: Text(
          switch (_step) {
            _ForgotStep.enterEmail => 'Forgot Password',
            _ForgotStep.verifyOtp => 'Verify OTP',
            _ForgotStep.newPassword => 'New Password',
          },
          style: const TextStyle(fontFamily: 'Montserrat', color: Colors.white),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_step) {
                _ForgotStep.enterEmail => _buildEmailStep(),
                _ForgotStep.verifyOtp => _buildOtpStep(),
                _ForgotStep.newPassword => _buildNewPasswordStep(),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1 UI ───────────────────────────────────────────────────────────────

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_reset, color: Colors.orangeAccent, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your admin email and we\'ll send a one-time code to verify your identity.',
          style: TextStyle(
            color: Colors.white54,
            fontFamily: 'Montserrat',
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          decoration: _input('Admin Email'),
          onSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _loading
                    ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'SEND OTP',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  // ── Step 2 UI ───────────────────────────────────────────────────────────────

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          color: Colors.orangeAccent,
          size: 48,
        ),
        const SizedBox(height: 16),
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to ${_verifiedEmail ?? ''}.\nIt expires in 5 minutes.',
          style: const TextStyle(
            color: Colors.white54,
            fontFamily: 'Montserrat',
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, _buildOtpBox),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'VERIFY OTP',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child:
              _resendSeconds > 0
                  ? Text(
                    'Resend OTP in ${_resendSeconds}s',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                    ),
                  )
                  : TextButton(
                    onPressed: _loading ? null : () => _sendOtp(isResend: true),
                    child: const Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.orangeAccent, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          }
          // Auto-verify when all 6 boxes are filled
          if (index == 5 && value.isNotEmpty) {
            _verifyOtp();
          }
        },
      ),
    );
  }

  // ── Step 3 UI ───────────────────────────────────────────────────────────────

  Widget _buildNewPasswordStep() {
    return Column(
      key: const ValueKey('newpass'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_open_outlined, color: Colors.green, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Set New Password',
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Identity verified. Enter your new password below.',
          style: TextStyle(
            color: Colors.white54,
            fontFamily: 'Montserrat',
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Password must be at least 8 characters long.',
          style: TextStyle(
            color: Colors.white38,
            fontFamily: 'Montserrat',
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          decoration: _input('New Password').copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNew ? Icons.visibility_off : Icons.visibility,
                color: Colors.white54,
              ),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          decoration: _input('Confirm New Password').copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: Colors.white54,
              ),
              onPressed:
                  () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          onSubmitted: (_) => _updatePassword(),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _updatePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _loading
                    ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'UPDATE PASSWORD',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
          ),
        ),
      ],
    );
  }
}
