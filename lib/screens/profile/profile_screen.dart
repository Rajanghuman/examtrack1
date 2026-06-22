import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../l10n/language_provider.dart';
import '../../l10n/app_strings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  // ── Real stats from Firebase ───────────────────────────
  int _savedCount   = 0;
  int _appliedCount = 0;
  int _trackedCount = 0;

  bool _notifyNewJobs    = true;
  bool _notifyDeadlines  = true;
  bool _notifyAdmitCards = true;
  bool _notifyResults    = false;
  // NOTE: _selectedLanguage removed — language now lives in
  // LanguageProvider (app-wide, persisted), not a local screen variable.
  List<String> _preferredCategories = [];
  String _userStateLocal = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Read directly from Firestore — bypass auth service cache
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        // Read trackedJobs subcollection directly
        final trackedSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('trackedJobs')
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final savedJobs =
              data['savedJobs'] as List<dynamic>? ?? [];
          final appliedJobs =
              data['appliedJobs'] as List<dynamic>? ?? [];

          if (!mounted) return;
          setState(() {
            _userData       = data;
            _isLoading      = false;
            _savedCount     = savedJobs.length;
            _appliedCount   = appliedJobs.length;
            _trackedCount   = trackedSnap.docs.length;
            _preferredCategories = List<String>.from(
                data['preferredExams'] ??
                    data['categories'] ?? []);
            _userStateLocal =
                data['state'] as String? ?? '';
          });
        } else {
          if (!mounted) return;
          setState(() {
            _userData     = {};
            _isLoading    = false;
            _trackedCount = trackedSnap.docs.length;
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not load profile. Please check your connection.',
                style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ── Load real stats from Firebase ─────────────────────
  Future<void> _loadStats(String uid) async {
    try {
      // Read user document for saved/applied jobs
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      // Read trackedJobs subcollection directly — most reliable
      final trackedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trackedJobs')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final savedJobs =
            data['savedJobs'] as List<dynamic>? ?? [];
        final appliedJobs =
            data['appliedJobs'] as List<dynamic>? ?? [];

        if (!mounted) return;
        setState(() {
          _savedCount   = savedJobs.length;
          _appliedCount = appliedJobs.length;
          _trackedCount = trackedSnap.docs.length;
          _preferredCategories = List<String>.from(
              data['preferredExams'] ?? data['categories'] ?? []);
          _userStateLocal = data['state'] as String? ?? '';
        });
      } else {
        // Doc doesn't exist yet — still count tracked
        if (!mounted) return;
        setState(() {
          _trackedCount = trackedSnap.docs.length;
        });
      }
    } catch (e) {
      // Silent fail for stats — not critical
    }
  }

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (_userData != null && _userData!['fullName'] != null)
      return _userData!['fullName'];
    if (user?.displayName != null) return user!.displayName!;
    if (user?.email != null)
      return user!.email!.split('@')[0];
    return 'User';
  }

  String get _userEmail {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email ?? '';
  }

  String get _userState =>
      _userData?['state'] ?? 'India';
  String get _userQualification =>
      _userData?['qualification'] ?? 'Graduate';

  Future<void> _logout() async {
    final lang = context.read<LanguageProvider>().languageCode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.get('logout', lang),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(AppStrings.get('logout_confirm', lang),
            style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel', lang),
                style: GoogleFonts.poppins(
                    color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
              Navigator.pushReplacementNamed(
                  context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppStrings.get('logout', lang),
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Custom Toast ──────────────────────────────────────
  void _showToast(String message, {bool success = true}) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 2),
                () { if (ctx.mounted) Navigator.pop(ctx); });
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: success
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFB00020),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      success
                          ? Icons.check_rounded
                          : Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(message,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              letterSpacing: 0.1,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Launch URL ─────────────────────────────────────────
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
    } else {
      _showToast('Unable to open link', success: false);
    }
  }

  // ── Share App ──────────────────────────────────────────
  void _shareApp() {
    Share.share(
      'Download ExamTrack — India\'s smartest govt job app! '
          'Stay updated on SSC, Railway, Banking & more.\n'
          'https://play.google.com/store/apps/details?id=com.examtrack.app',
      subject: 'Check out ExamTrack!',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the language provider so this whole screen rebuilds
    // automatically the instant the user flips the toggle.
    final lang = context.watch<LanguageProvider>().languageCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF1565C0)))
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(lang),
            const SizedBox(height: 16),
            _buildStatsRow(lang),
            const SizedBox(height: 16),
            _buildQuickAccess(lang),
            const SizedBox(height: 16),
            _buildNotificationSettings(lang),
            const SizedBox(height: 16),
            _buildAppSettings(lang),
            const SizedBox(height: 16),
            _buildLogoutButton(lang),
            const SizedBox(height: 32),
            Text('ExamTrack v1.0.0',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF9CA3AF))),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(lang),
    );
  }

  Widget _buildHeader(String lang) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 28,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.get('my_profile', lang),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: () => _showEditProfileSheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(AppStrings.get('edit', lang),
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor:
                Colors.white.withOpacity(0.3),
                child: Text(
                  _userName.isNotEmpty
                      ? _userName[0].toUpperCase()
                      : 'U',
                  style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 28, height: 28,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFF6B00),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_userName,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_userEmail,
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _headerChip(
                  Icons.location_on_outlined, _userState),
              const SizedBox(width: 10),
              _headerChip(
                  Icons.school_outlined, _userQualification),
              const SizedBox(width: 10),
              _headerChip(Icons.people_outline, 'General'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Stats row with real Firebase data ─────────────────
  Widget _buildStatsRow(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('$_savedCount', AppStrings.get('saved_stat', lang),
                const Color(0xFF1565C0)),
            _divider(),
            _statItem('$_appliedCount', AppStrings.get('applied_stat', lang),
                const Color(0xFF10B981)),
            _divider(),
            _statItem('0', AppStrings.get('selected_stat', lang),
                const Color(0xFFFF6B00)),
            _divider(),
            _statItem('$_trackedCount', AppStrings.get('tracked_stat', lang),
                const Color(0xFF880E4F)),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF6B7280))),
      ],
    );
  }

  Widget _divider() {
    return Container(
        width: 1, height: 36,
        color: const Color(0xFFF3F4F6));
  }

  // ── Edit Profile Bottom Sheet ─────────────────────────
  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _userName);
    String selectedState = _userStateLocal.isNotEmpty
        ? _userStateLocal
        : 'Punjab';
    List<String> selectedCats =
    List.from(_preferredCategories);
    String selectedQual = _userQualification;

    final states = [
      'Punjab', 'Haryana', 'Delhi',
      'Uttar Pradesh', 'Rajasthan',
      'Himachal Pradesh', 'Jammu & Kashmir'
    ];
    final categories = [
      'SSC', 'Railway', 'Banking',
      'Police', 'Army', 'UPSC', 'Teaching', 'Health'
    ];
    final qualifications = [
      '8th Pass',
      '10th Pass (Matric)',
      '12th Pass (Inter)',
      'ITI',
      'Diploma (Engineering)',
      'Diploma (Non-Engineering)',
      'B.A (Arts)', 'B.Sc (Science)', 'B.Com (Commerce)',
      'B.Tech / B.E (Engineering)', 'B.C.A (Computer)',
      'B.B.A (Business)', 'B.Ed (Teaching)', 'B.Sc Nursing',
      'B.Pharma', 'B.Sc Agriculture', 'BDS (Dental)',
      'MBBS (Medical)', 'LLB (Law)', 'B.Arch (Architecture)',
      'B.Sc (IT)', 'Other Graduate',
      'M.A (Arts)', 'M.Sc (Science)', 'M.Com (Commerce)',
      'M.Tech / M.E (Engineering)', 'M.C.A (Computer)',
      'M.B.A (Business)', 'M.Ed (Teaching)', 'M.Sc Nursing',
      'M.Pharma', 'LLM (Law)', 'PGDM', 'Other Post Graduate',
      'Ph.D',
    ];
    final graduateOptions = [
      'B.A (Arts)', 'B.Sc (Science)', 'B.Com (Commerce)',
      'B.Tech / B.E (Engineering)', 'B.C.A (Computer)',
      'B.B.A (Business)', 'B.Ed (Teaching)', 'B.Sc Nursing',
      'B.Pharma', 'B.Sc Agriculture', 'BDS (Dental)',
      'MBBS (Medical)', 'LLB (Law)', 'B.Arch (Architecture)',
      'B.Sc (IT)', 'Other Graduate',
    ];
    final postGraduateOptions = [
      'M.A (Arts)', 'M.Sc (Science)', 'M.Com (Commerce)',
      'M.Tech / M.E (Engineering)', 'M.C.A (Computer)',
      'M.B.A (Business)', 'M.Ed (Teaching)', 'M.Sc Nursing',
      'M.Pharma', 'LLM (Law)', 'PGDM', 'Other Post Graduate',
    ];
    final simpleQuals = [
      '8th Pass', '10th Pass (Matric)', '12th Pass (Inter)',
      'ITI', 'Diploma (Engineering)', 'Diploma (Non-Engineering)',
    ];
    // Map old values
    const legacyMap = {
      '10th': '10th Pass (Matric)', '12th': '12th Pass (Inter)',
      'Graduate': 'Other Graduate', 'Post Graduate': 'Other Post Graduate',
      'B.Ed': 'B.Ed (Teaching)', 'LLB': 'LLB (Law)', 'MBBS': 'MBBS (Medical)',
    };
    if (legacyMap.containsKey(selectedQual)) {
      selectedQual = legacyMap[selectedQual]!;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    20, 16, 20, 8),
                child: Row(
                  children: [
                    Text('Edit Profile',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx2),
                      child: const Icon(Icons.close,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      20, 16, 20,
                      MediaQuery.of(ctx2).viewInsets.bottom +
                          20),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text('Full Name',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(
                                  0xFF374151))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              color:
                              const Color(0xFF9CA3AF)),
                          prefixIcon: const Icon(
                              Icons.person_outline,
                              color: Color(0xFF1565C0),
                              size: 20),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  12),
                              borderSide: BorderSide(
                                  color: Colors
                                      .grey.shade200)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  12),
                              borderSide: BorderSide(
                                  color: Colors
                                      .grey.shade200)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF1565C0),
                                  width: 2)),
                        ),
                        style: GoogleFonts.poppins(
                            fontSize: 14),
                      ),
                      const SizedBox(height: 20),

                      // State
                      Text('Your State',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(
                                  0xFF374151))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedState,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFF1565C0),
                              size: 20),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  12),
                              borderSide: BorderSide(
                                  color: Colors
                                      .grey.shade200)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  12),
                              borderSide: BorderSide(
                                  color: Colors
                                      .grey.shade200)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF1565C0),
                                  width: 2)),
                        ),
                        items: states
                            .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s,
                                style:
                                GoogleFonts.poppins(
                                    fontSize: 14))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null)
                            setSheet(
                                    () => selectedState = v);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Qualification
                      Text('Qualification',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151))),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          String? expandedGroup;
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => StatefulBuilder(
                              builder: (ctx3, setQSheet) => Container(
                                height: MediaQuery.of(context).size.height * 0.72,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                child: Column(children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    width: 40, height: 4,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(2)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text('Select Qualification',
                                        style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(child: ListView(children: [
                                    ...simpleQuals.map((q) => _profileQualItem(
                                        q, selectedQual, () => setSheet(() => selectedQual = q),
                                        ctx)),
                                    // Graduate
                                    _profileQualHeader('Graduate', Icons.school_outlined,
                                        expandedGroup == 'grad',
                                        graduateOptions.contains(selectedQual),
                                            () => setQSheet(() => expandedGroup =
                                        expandedGroup == 'grad' ? null : 'grad')),
                                    if (expandedGroup == 'grad')
                                      ...graduateOptions.map((q) => _profileQualItem(
                                          q, selectedQual, () => setSheet(() => selectedQual = q),
                                          ctx, sub: true)),
                                    // Post Graduate
                                    _profileQualHeader('Post Graduate',
                                        Icons.workspace_premium_outlined,
                                        expandedGroup == 'pg',
                                        postGraduateOptions.contains(selectedQual),
                                            () => setQSheet(() => expandedGroup =
                                        expandedGroup == 'pg' ? null : 'pg')),
                                    if (expandedGroup == 'pg')
                                      ...postGraduateOptions.map((q) => _profileQualItem(
                                          q, selectedQual, () => setSheet(() => selectedQual = q),
                                          ctx, sub: true)),
                                    _profileQualItem('Ph.D', selectedQual,
                                            () => setSheet(() => selectedQual = 'Ph.D'), ctx),
                                    const SizedBox(height: 20),
                                  ])),
                                ]),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(children: [
                            const Icon(Icons.school_outlined,
                                color: Color(0xFF1565C0), size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(selectedQual,
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: const Color(0xFF1A1A2E)))),
                            const Icon(Icons.keyboard_arrow_down,
                                color: Color(0xFF6B7280)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Preferred Exam Categories
                      Text('Preferred Exam Categories',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(
                                  0xFF374151))),
                      const SizedBox(height: 4),
                      Text(
                        'Select all that apply — jobs matching these will appear first',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((cat) {
                          final selected =
                          selectedCats.contains(cat);
                          return GestureDetector(
                            onTap: () {
                              setSheet(() {
                                if (selected)
                                  selectedCats.remove(cat);
                                else
                                  selectedCats.add(cat);
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 200),
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey.shade50,
                                borderRadius:
                                BorderRadius.circular(
                                    20),
                                border: Border.all(
                                  color: selected
                                      ? const Color(
                                      0xFF1565C0)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(cat,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight:
                                      FontWeight.w500,
                                      color: selected
                                          ? Colors.white
                                          : const Color(
                                          0xFF374151))),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx2);
                            await _saveProfile(
                              name: nameCtrl.text.trim(),
                              state: selectedState,
                              qualification: selectedQual,
                              categories: selectedCats,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF1565C0),
                            padding: const EdgeInsets
                                .symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    14)),
                          ),
                          child: Text('Save Changes',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight:
                                  FontWeight.w600)),
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
    );
  }

  // ── Save profile to Firestore ──────────────────────────
  Future<void> _saveProfile({
    required String name,
    required String state,
    required String qualification,
    required List<String> categories,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fullName':       name,
        'state':          state,
        'qualification':  qualification,
        'preferredExams': categories,
        'categories':     categories,
      });
      await _loadUserData();
      _showToast('Profile updated successfully');
    } catch (e) {
      _showToast('Failed to update profile',
          success: false);
    }
  }

  Widget _buildQuickAccess(String lang) {
    final items = [
      {'icon': Icons.bookmark_outline, 'title': AppStrings.get('nav_saved', lang), 'route': '/saved'},
      {'icon': Icons.menu_book_outlined, 'title': AppStrings.get('study_material', lang), 'route': '/study-material'},
      {'icon': Icons.emoji_events_outlined, 'title': AppStrings.get('results', lang), 'route': '/results'},
      {'icon': Icons.track_changes_outlined, 'title': AppStrings.get('job_tracker', lang), 'route': '/tracker'},
      {'icon': Icons.article_outlined, 'title': AppStrings.get('admit_cards', lang), 'route': '/admit-card'},
      {'icon': Icons.verified_user_outlined, 'title': AppStrings.get('eligibility', lang), 'route': '/eligibility'},
      {'icon': Icons.cake_outlined, 'title': AppStrings.get('age_calculator', lang), 'route': '/tools'},
      {'icon': Icons.newspaper_outlined, 'title': AppStrings.get('current_affairs', lang), 'route': '/current-affairs'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(AppStrings.get('quick_access', lang),
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
            ),
            ...items.map((item) => GestureDetector(
              onTap: () => Navigator.pushNamed(
                  context, item['route'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(
                      color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0)
                            .withOpacity(0.08),
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                      child: Icon(item['icon'] as IconData,
                          color: const Color(0xFF1565C0),
                          size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(item['title'] as String,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF1A1A2E))),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 14,
                        color: Color(0xFF9CA3AF)),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(AppStrings.get('notifications', lang),
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
            ),
            _notifToggle('New Job Alerts', _notifyNewJobs,
                    (v) => setState(() => _notifyNewJobs = v)),
            _notifToggle('Deadline Reminders',
                _notifyDeadlines,
                    (v) => setState(() => _notifyDeadlines = v)),
            _notifToggle('Admit Card Alerts',
                _notifyAdmitCards,
                    (v) => setState(
                        () => _notifyAdmitCards = v)),
            _notifToggle('Result Notifications',
                _notifyResults,
                    (v) => setState(() => _notifyResults = v)),
          ],
        ),
      ),
    );
  }

  Widget _notifToggle(
      String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF1A1A2E))),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1565C0),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettings(String lang) {
    // Read the language provider here so the dropdown reflects and
    // controls the REAL app-wide language, not a local placeholder.
    final languageProvider = context.watch<LanguageProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(AppStrings.get('app_settings', lang),
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(
                    color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(AppStrings.get('language', lang),
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF1A1A2E))),
                  ),
                  DropdownButton<String>(
                    // Display value is derived from the REAL provider
                    // state, not a local variable — this is what makes
                    // it actually reflect what's currently active.
                    value: languageProvider.isHindi ? 'Hindi' : 'English',
                    underline: const SizedBox(),
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF1565C0)),
                    items: ['English', 'Hindi']
                        .map((l) => DropdownMenuItem(
                        value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      // This is the actual switch — setLanguage()
                      // updates LanguageProvider, which notifies every
                      // widget watching it, and persists the choice
                      // via shared_preferences so it survives restart.
                      await languageProvider.setLanguage(
                          v == 'Hindi' ? 'hi' : 'en');
                      if (mounted) {
                        _showToast(
                          v == 'Hindi'
                              ? 'भाषा हिंदी में बदल दी गई'
                              : 'Language switched to English',
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            _settingsTile(AppStrings.get('privacy_policy', lang),
                Icons.privacy_tip_outlined, () {
                  _launchURL(
                      'https://rajanghuman.github.io/examtrack-legal/privacy_policy.html');
                }),
            _settingsTile(AppStrings.get('terms_of_service', lang),
                Icons.description_outlined, () {
                  _launchURL(
                      'https://rajanghuman.github.io/examtrack-legal/terms_of_service.html');
                }),
            _settingsTile(
                AppStrings.get('rate_the_app', lang), Icons.star_outline, () {
              _launchURL(
                  'https://play.google.com/store/apps/details?id=com.examtrack.app');
            }),
            _settingsTile(AppStrings.get('share_with_friends', lang),
                Icons.share_outlined, () {
                  _shareApp();
                }),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile(
      String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: const Color(0xFF6B7280), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF1A1A2E))),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: Colors.white),
          label: Text(AppStrings.get('logout', lang),
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(String lang) {
    return BottomNavigationBar(
      currentIndex: 4,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1565C0),
      unselectedItemColor: const Color(0xFF9CA3AF),
      selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      onTap: (i) {
        switch (i) {
          case 0: Navigator.pushReplacementNamed(context, '/home'); break;
          case 1: Navigator.pushReplacementNamed(context, '/jobs'); break;
          case 2: Navigator.pushReplacementNamed(context, '/current-affairs'); break;
          case 3: Navigator.pushReplacementNamed(context, '/saved'); break;
          case 4: break;
        }
      },
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: AppStrings.get('nav_home', lang)),
        BottomNavigationBarItem(icon: const Icon(Icons.work_outline), activeIcon: const Icon(Icons.work), label: AppStrings.get('nav_jobs', lang)),
        BottomNavigationBarItem(icon: const Icon(Icons.newspaper_outlined), activeIcon: const Icon(Icons.newspaper), label: AppStrings.get('nav_news', lang)),
        BottomNavigationBarItem(icon: const Icon(Icons.bookmark_outline), activeIcon: const Icon(Icons.bookmark), label: AppStrings.get('nav_saved', lang)),
        BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: AppStrings.get('nav_profile', lang)),
      ],
    );
  }

  Widget _profileQualItem(String q, String selectedQual,
      VoidCallback onSelect, BuildContext ctx, {bool sub = false}) {
    final sel = selectedQual == q;
    return InkWell(
      onTap: () { onSelect(); Navigator.pop(ctx); },
      child: Container(
        padding: EdgeInsets.only(
            left: sub ? 48 : 20, right: 20, top: 14, bottom: 14),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFE8F0FE) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
        ),
        child: Row(children: [
          if (sub) const Icon(Icons.subdirectory_arrow_right,
              color: Color(0xFF9CA3AF), size: 16),
          if (sub) const SizedBox(width: 8),
          Expanded(child: Text(q,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: sel ? const Color(0xFF1565C0) : const Color(0xFF1A1A2E),
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
          if (sel) const Icon(Icons.check, color: Color(0xFF1565C0), size: 18),
        ]),
      ),
    );
  }

  Widget _profileQualHeader(String label, IconData icon,
      bool expanded, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: const Color(0xFFF0F4FF),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF1565C0), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: const Color(0xFF1565C0)))),
          if (selected) const Icon(Icons.check_circle,
              color: Color(0xFF1565C0), size: 18),
          const SizedBox(width: 8),
          Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: const Color(0xFF1565C0)),
        ]),
      ),
    );
  }
}