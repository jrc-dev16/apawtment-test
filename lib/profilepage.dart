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
import 'package:apawtmentweb_admin/petpage.dart';
import 'package:apawtmentweb_admin/reportpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:apawtmentweb_admin/services/security_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  String _selectedItem = 'Profiles';
  User? currentUser;
  String? adminId;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final currentPasswordController = TextEditingController();
  final passwordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = true;
  bool isEditing = false;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    saveLastVisitedPage('Profile');

    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      setState(() => currentUser = session?.user);
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      final session = supabase.auth.currentSession;
      setState(() => currentUser = session?.user);
      _loadUserProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  margin: const EdgeInsets.only(top: 40),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildPasswordField(
                          controller: currentPasswordController,
                          label: 'Current Password',
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          controller: newPasswordController,
                          label: 'New Password',
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          controller: confirmPasswordController,
                          label: 'Confirm Password',
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),

                            ElevatedButton(
                              onPressed: () async {
                                final currentPass =
                                    currentPasswordController.text.trim();
                                final newPass =
                                    newPasswordController.text.trim();
                                final confirmPass =
                                    confirmPasswordController.text.trim();

                                if (newPass != confirmPass) {
                                  _showError(
                                    "New password and confirm password do not match.",
                                  );
                                  return;
                                }

                                if (!isPasswordStrong(newPass)) {
                                  _showError(
                                    "Password must be at least 8 characters long.",
                                  );
                                  return;
                                }

                                try {
                                  setState(() => isLoading = true);

                                  final res =
                                      await supabase
                                          .from('admin')
                                          .select('password')
                                          .eq('admin_id', 1)
                                          .maybeSingle();

                                  final storedPass = res?['password'];

                                  if (storedPass == null) {
                                    _showError(
                                      "Failed to retrieve current password.",
                                    );
                                    return;
                                  }

                                  final hashedCurrent = hashPassword(currentPass);
                                  bool isCurrentCorrect = false;

                                  if (storedPass == hashedCurrent) {
                                    isCurrentCorrect = true;
                                  } else if (!isSha256(storedPass) && storedPass == currentPass) {
                                    // Fallback for unmigrated plaintext passwords
                                    isCurrentCorrect = true;
                                  }

                                  if (!isCurrentCorrect) {
                                    _showError(
                                      "Current password is incorrect.",
                                    );
                                    return;
                                  }

                                  final hashedNew = hashPassword(newPass);
                                  final updateRes =
                                      await supabase
                                          .from('admin')
                                          .update({'password': hashedNew})
                                          .eq('admin_id', 1)
                                          .select();

                                  if (updateRes.isNotEmpty) {
                                    await logActivity(
                                      action: 'Changed Password',
                                      description: 'Admin changed password',
                                      entityType: 'Admin Profile',
                                    );
                                    _showSuccess(
                                      "Password changed successfully!",
                                    );
                                    Navigator.pop(context);
                                  } else {
                                    _showError("Failed to update password.");
                                  }
                                } catch (e) {
                                  _showError("Error changing password: $e");
                                  debugPrint("❌ Change password error: $e");
                                } finally {
                                  setState(() => isLoading = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text(
                                "Change",
                                style: TextStyle(fontFamily: 'Montserrat'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: 0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.deepOrangeAccent],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.lock, size: 40, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
  }) {
    bool isVisible = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return TextField(
          controller: controller,
          obscureText: !isVisible,
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Montserrat',
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[700]!),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.orange),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),

            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.white70,
              ),
              onPressed:
                  () => setState(() {
                    isVisible = !isVisible;
                  }),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => isLoading = true);
      final adminData =
          await supabase.from('admin').select().eq('admin_id', 1).maybeSingle();
      if (adminData == null) {
        _showError('Admin profile not found.');
        setState(() => isLoading = false);
        return;
      }
      final String? profilePath = adminData['admin_profile']?.toString();
      String? profileUrl;
      if (profilePath != null && profilePath.isNotEmpty) {
        profileUrl = supabase.storage
            .from('admin_profile')
            .getPublicUrl(profilePath);
        if (mounted) precacheImage(NetworkImage(profileUrl), context);
      }
      if (mounted) {
        setState(() {
          adminId = adminData['admin_id']?.toString();
          _nameController.text = adminData['name'] ?? '';
          _phoneController.text = adminData['phone_number'] ?? '';
          _emailController.text = adminData['email'] ?? '';
          _usernameController.text = adminData['username'] ?? '';
          profileImageUrl = profileUrl;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load profile: $e');
      debugPrint('$e');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (adminId == null) return _showError('Cannot update: Admin ID not found');

    try {
      setState(() => isLoading = true);
      await supabase
          .from('admin')
          .update({
            'name': _nameController.text.trim(),
            'phone_number': _phoneController.text.trim(),
            'username': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('admin_id', int.parse(adminId!));
      await logActivity(
        action: 'Updated Personal Information',
        description: 'Admin updated personal information',
        entityType: 'Admin Profile',
      );
      setState(() {
        isEditing = false;
        isLoading = false;
      });
      _showSuccess('Profile updated successfully!');
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to update profile: $e');
    }
  }

  Future<void> _pickImage() async {
    setState(() => isLoading = true);

    try {
      if (adminId == null) {
        _showError('Admin profile not loaded yet. Please wait.');
        setState(() => isLoading = false);
        return;
      }

      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) {
        setState(() => isLoading = false);
        return;
      }

      final bytes = await image.readAsBytes();
      String ext = image.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) ext = 'png';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${adminId}_$timestamp.$ext';

      await supabase.storage
          .from('admin_profile')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
          );

      await supabase
          .from('admin')
          .update({'admin_profile': filePath})
          .eq('admin_id', int.parse(adminId!));
      await logActivity(
        action: 'Updated Profile Avatar',
        description: 'Admin updated profile avatar image',
        entityType: 'Admin Profile',
      );

      final publicUrl = supabase.storage
          .from('admin_profile')
          .getPublicUrl(filePath);

      setState(() {
        profileImageUrl = publicUrl;
        isLoading = false;
      });

      _showSuccess('Profile picture updated successfully!');
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to upload image: $e');
      debugPrint('❌ Image upload error: $e');
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

  void _showError(String message) => _showSnackBar(message, Colors.red);
  void _showSuccess(String message) => _showSnackBar(message, Colors.green);

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1000;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1A1A1A),
      drawer:
          !isDesktop ? Drawer(width: 200, child: SafeArea(child: _buildSidebar())) : null,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              Container(
                width: 200,
                color: const Color(0xFF1C1C1C),
                child: _buildSidebar(),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 60,
                    color: const Color(0xFF1C1C1C),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!isDesktop)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () {
                                _scaffoldKey.currentState?.openDrawer();
                              },
                            ),
                          ),
                        const Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Montserrat",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        isLoading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.orange,
                              ),
                            )
                            : SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 800,
                                  ),
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 70,
                                            backgroundColor: Colors.grey[800],
                                            backgroundImage:
                                                profileImageUrl != null
                                                    ? NetworkImage(
                                                      profileImageUrl!,
                                                    )
                                                    : null,
                                            child:
                                                profileImageUrl == null
                                                    ? const Icon(
                                                      Icons.person,
                                                      size: 70,
                                                      color: Colors.white54,
                                                    )
                                                    : null,
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: GestureDetector(
                                              onTap: _pickImage,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF1A1A1A,
                                                    ),
                                                    width: 3,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        _nameController.text.isNotEmpty
                                            ? _nameController.text
                                            : 'Admin User',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A2A2A),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Center(
                                              child: Image.asset(
                                                'assets/images/apawtmentlight.png',
                                                width: 90,
                                                height: 90,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Form(
                                              key: _formKey,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _buildInfoRow(
                                                    label: 'Name :',
                                                    value: _nameController.text,
                                                    controller: _nameController,
                                                    enabled: isEditing,
                                                    keyboardType:
                                                        TextInputType.text,
                                                  ),
                                                  const Divider(
                                                    color: Colors.grey,
                                                  ),
                                                  _buildInfoRow(
                                                    label: 'Phone Number :',
                                                    value: _phoneController.text,
                                                    controller: _phoneController,
                                                    enabled: isEditing,
                                                    keyboardType:
                                                        TextInputType.phone,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                      LengthLimitingTextInputFormatter(
                                                        11,
                                                      ),
                                                    ],
                                                  ),
                                                  const Divider(
                                                    color: Colors.grey,
                                                  ),
                                                  _buildInfoRow(
                                                    label: 'Email :',
                                                    value: _emailController.text,
                                                    controller: _emailController,
                                                    enabled: isEditing,
                                                    keyboardType:
                                                        TextInputType
                                                            .emailAddress,
                                                  ),
                                                  const Divider(
                                                    color: Colors.grey,
                                                  ),
                                                  _buildInfoRow(
                                                    label: 'Username :',
                                                    value:
                                                        _usernameController
                                                            .text,
                                                    controller:
                                                        _usernameController,
                                                    enabled: isEditing,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      if (!isEditing)
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          alignment: WrapAlignment.start,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: _changePassword,
                                              icon: const Icon(Icons.password),
                                              label: const Text(
                                                'Change Password',
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed:
                                                  () => setState(
                                                    () => isEditing = true,
                                                  ),
                                              icon: const Icon(Icons.edit),
                                              label: const Text(
                                                'Edit Information',
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          alignment: WrapAlignment.center,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () {
                                                setState(
                                                  () => isEditing = false,
                                                );
                                                _loadUserProfile();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: _updateProfile,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Save Changes',
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 32),
                                    ],
                                  ),
                                ),
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

  Widget _buildInfoRow({
    required String label,
    required String value,
    TextEditingController? controller,
    bool enabled = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          Expanded(
            child:
                enabled && controller != null
                    ? TextFormField(
                      controller: controller,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                      keyboardType: keyboardType,
                      inputFormatters: inputFormatters,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[700]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator:
                          (val) =>
                              val == null || val.isEmpty
                                  ? 'This field is required'
                                  : null,
                    )
                    : Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'Montserrat',
                      ),
                    ),
          ),
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
