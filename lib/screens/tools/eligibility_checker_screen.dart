import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/job_service.dart';

class EligibilityCheckerScreen extends StatefulWidget {
  const EligibilityCheckerScreen({super.key});

  @override
  State<EligibilityCheckerScreen> createState() =>
      _EligibilityCheckerScreenState();
}

class _EligibilityCheckerScreenState
    extends State<EligibilityCheckerScreen>
    with SingleTickerProviderStateMixin {

  DateTime? _dob;
  String _category      = 'General';
  String _gender        = 'Male';
  String _qualification = '10th Pass (Matric)';
  String _state         = 'Punjab';
  double _height        = 165;
  double _weight        = 60;
  bool _hasChecked      = false;
  bool _showPhysical    = false;
  bool _isLoadingProfile = true;
  bool _isLoadingJobs   = true;
  bool _profileLoaded   = false;

  // All jobs from Firebase
  List<Map<String, dynamic>> _allJobs = [];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final JobService _jobService = JobService();

  final List<String> _categories = ['General', 'OBC', 'SC', 'ST', 'EWS', 'Ex-Serviceman'];
  final List<String> _genders    = ['Male', 'Female', 'Transgender'];
  final List<String> _states     = ['Punjab', 'Haryana', 'Himachal Pradesh', 'Delhi', 'Uttar Pradesh', 'Rajasthan', 'Bihar', 'Uttarakhand', 'All India'];

  final List<String> _graduateOptions = [
    'B.A (Arts)', 'B.Sc (Science)', 'B.Com (Commerce)',
    'B.Tech / B.E (Engineering)', 'B.C.A (Computer)',
    'B.B.A (Business)', 'B.Ed (Teaching)', 'B.Sc Nursing',
    'B.Pharma', 'B.Sc Agriculture', 'BDS (Dental)',
    'MBBS (Medical)', 'LLB (Law)', 'B.Arch (Architecture)',
    'B.Sc (IT)', 'Other Graduate',
  ];
  final List<String> _postGraduateOptions = [
    'M.A (Arts)', 'M.Sc (Science)', 'M.Com (Commerce)',
    'M.Tech / M.E (Engineering)', 'M.C.A (Computer)',
    'M.B.A (Business)', 'M.Ed (Teaching)', 'M.Sc Nursing',
    'M.Pharma', 'LLM (Law)', 'PGDM', 'Other Post Graduate',
  ];

  final List<String> _qualifications = [
    '8th Pass', '10th Pass (Matric)', '12th Pass (Inter)', 'ITI',
    'Diploma (Engineering)', 'Diploma (Non-Engineering)',
    'B.A (Arts)', 'B.Sc (Science)', 'B.Com (Commerce)',
    'B.Tech / B.E (Engineering)', 'B.C.A (Computer)',
    'B.B.A (Business)', 'B.Ed (Teaching)', 'B.Sc Nursing',
    'B.Pharma', 'B.Sc Agriculture', 'BDS (Dental)',
    'MBBS (Medical)', 'LLB (Law)', 'B.Arch (Architecture)',
    'B.Sc (IT)', 'Other Graduate',
    'M.A (Arts)', 'M.Sc (Science)', 'M.Com (Commerce)',
    'M.Tech / M.E (Engineering)', 'M.C.A (Computer)',
    'M.B.A (Business)', 'M.Ed (Teaching)', 'M.Sc Nursing',
    'M.Pharma', 'LLM (Law)', 'PGDM', 'Other Post Graduate', 'Ph.D',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadUserProfile();
    _loadJobs();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await _jobService.getAllJobs();
      setState(() {
        _allJobs = jobs;
        _isLoadingJobs = false;
      });
    } catch (e) {
      setState(() => _isLoadingJobs = false);
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final dob = data['dob'] as String?;
          if (dob != null && dob.isNotEmpty) {
            final parts = dob.split('/');
            if (parts.length == 3) {
              setState(() {
                _dob = DateTime(
                  int.parse(parts[2]),
                  int.parse(parts[1]),
                  int.parse(parts[0]),
                );
              });
            }
          }
          final qual = data['qualification'] as String?;
          if (qual != null) {
            final Map<String, String> legacyMap = {
              '10th Pass': '10th Pass (Matric)',
              '12th Pass': '12th Pass (Inter)',
              'Diploma': 'Diploma (Engineering)',
              'Graduate': 'Other Graduate',
              'Post Graduate': 'Other Post Graduate',
              'B.Ed': 'B.Ed (Teaching)',
              'LLB': 'LLB (Law)',
              'MBBS': 'MBBS (Medical)',
            };
            setState(() => _qualification = legacyMap[qual] ?? qual);
          }
          final state = data['state'] as String?;
          if (state != null && _states.contains(state)) {
            setState(() => _state = state);
          }
          final gender = data['gender'] as String?;
          if (gender != null && _genders.contains(gender)) {
            setState(() => _gender = gender);
          }
          setState(() => _profileLoaded = true);
        }
      }
    } catch (e) {
    }
    setState(() => _isLoadingProfile = false);
  }

  int get _ageYears {
    if (_dob == null) return 0;
    final today = DateTime.now();
    int age = today.year - _dob!.year;
    if (today.month < _dob!.month ||
        (today.month == _dob!.month && today.day < _dob!.day)) age--;
    return age;
  }

  int _qualRank(String q) {
    const Map<String, int> rankMap = {
      '8th Pass': 0,
      '10th Pass': 1, '10th Pass (Matric)': 1,
      '12th Pass': 2, '12th Pass (Inter)': 2,
      'ITI': 3, 'Diploma': 3,
      'Diploma (Engineering)': 3, 'Diploma (Non-Engineering)': 3,
      'Graduate': 4, 'Other Graduate': 4,
      'B.A (Arts)': 4, 'B.Sc (Science)': 4, 'B.Com (Commerce)': 4,
      'B.Tech / B.E (Engineering)': 4, 'B.C.A (Computer)': 4,
      'B.B.A (Business)': 4, 'B.Ed (Teaching)': 4, 'B.Ed': 4,
      'B.Sc Nursing': 4, 'B.Pharma': 4, 'B.Sc Agriculture': 4,
      'BDS (Dental)': 4, 'MBBS (Medical)': 4, 'MBBS': 4,
      'LLB (Law)': 4, 'LLB': 4,
      'B.Arch (Architecture)': 4, 'B.Sc (IT)': 4,
      'Post Graduate': 5, 'Other Post Graduate': 5,
      'M.A (Arts)': 5, 'M.Sc (Science)': 5, 'M.Com (Commerce)': 5,
      'M.Tech / M.E (Engineering)': 5, 'M.C.A (Computer)': 5,
      'M.B.A (Business)': 5, 'M.Ed (Teaching)': 5, 'M.Sc Nursing': 5,
      'M.Pharma': 5, 'LLM (Law)': 5, 'PGDM': 5,
      'Ph.D': 6,
    };
    return rankMap[q] ?? 0;
  }

  // ── Check eligibility for a Firebase job ──────────────
  Map<String, dynamic> _checkJob(Map<String, dynamic> job) {
    List<String> fails  = [];
    List<String> passes = [];
    final int age = _ageYears;

    // ── Age check ─────────────────────────────────────────
    int minAge = 18, maxAge = 35;
    try {
      // Try ageMin/ageMax fields
      if (job['ageMin'] != null) {
        minAge = job['ageMin'] is int
            ? job['ageMin']
            : int.tryParse(job['ageMin'].toString()) ?? 18;
      }
      if (job['ageMax'] != null) {
        maxAge = job['ageMax'] is int
            ? job['ageMax']
            : int.tryParse(job['ageMax'].toString()) ?? 35;
      }
      // Try ageLimit string format "18-35"
      if (job['ageLimit'] != null && job['ageMin'] == null) {
        final ageStr = job['ageLimit'].toString();
        if (ageStr.contains('-')) {
          final parts = ageStr.split('-');
          minAge = int.tryParse(parts[0].trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 18;
          maxAge = int.tryParse(parts[1].trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 35;
        }
      }
    } catch (e) {}

    // Apply category age relaxation
    int relaxation = 0;
    if (_category == 'OBC') relaxation = 3;
    else if (_category == 'SC' || _category == 'ST') relaxation = 5;
    else if (_category == 'Ex-Serviceman') relaxation = 3;
    maxAge += relaxation;

    if (age < minAge) {
      fails.add('Too young — min age is $minAge years');
    } else if (age > maxAge) {
      fails.add('Age exceeded — max is $maxAge years (${_category} category)');
    } else {
      passes.add('Age $age years is OK (limit: $minAge-$maxAge)');
    }

    // ── Qualification check ───────────────────────────────
    final jobQualStr = (job['qualification'] as String? ?? '').toLowerCase();
    final userRank   = _qualRank(_qualification);
    bool qualOk      = false;

    if (jobQualStr.contains('10th') || jobQualStr.contains('matric')) {
      qualOk = userRank >= 1;
    } else if (jobQualStr.contains('12th') || jobQualStr.contains('inter') || jobQualStr.contains('+2')) {
      qualOk = userRank >= 2;
    } else if (jobQualStr.contains('iti')) {
      qualOk = userRank >= 3;
    } else if (jobQualStr.contains('diploma')) {
      qualOk = userRank >= 3;
    } else if (jobQualStr.contains('graduate') || jobQualStr.contains('degree') ||
        jobQualStr.contains('b.tech') || jobQualStr.contains('b.sc') ||
        jobQualStr.contains('b.com') || jobQualStr.contains('b.a') ||
        jobQualStr.contains('mbbs') || jobQualStr.contains('b.ed') ||
        jobQualStr.contains('llb') || jobQualStr.contains('b.c.a') ||
        jobQualStr.contains('nursing')) {
      qualOk = userRank >= 4;
    } else if (jobQualStr.contains('post graduate') || jobQualStr.contains('master') ||
        jobQualStr.contains('m.tech') || jobQualStr.contains('m.sc') ||
        jobQualStr.contains('mba') || jobQualStr.contains('m.a')) {
      qualOk = userRank >= 5;
    } else if (jobQualStr.contains('phd') || jobQualStr.contains('ph.d')) {
      qualOk = userRank >= 6;
    } else {
      qualOk = true; // Unknown qual — assume eligible
    }

    if (!qualOk) {
      final reqQual = job['qualification'] as String? ?? 'Graduate';
      fails.add('Need $reqQual minimum (you have $_qualification)');
    } else {
      passes.add('Qualification $_qualification meets requirement');
    }

    // ── Gender check ──────────────────────────────────────
    final jobTitle = (job['title'] as String? ?? '').toLowerCase();
    final jobDetails = (job['description'] as String? ?? '').toLowerCase();
    if (jobTitle.contains('male only') || jobDetails.contains('male only') ||
        (jobTitle.contains('agniveer') && jobTitle.contains('gd'))) {
      if (_gender != 'Male') {
        fails.add('This post is for Male candidates only');
      } else {
        passes.add('Gender $_gender is accepted');
      }
    } else {
      passes.add('Gender $_gender is accepted');
    }

    // ── State check ───────────────────────────────────────
    final jobState = (job['state'] as String? ?? 'All India');
    if (jobState == 'All India') {
      passes.add('Open for all India candidates');
    } else if (jobState == _state || _state == 'All India') {
      passes.add('State $_state is eligible');
    } else {
      fails.add('This job is for $jobState residents only');
    }

    // ── Physical standards check ──────────────────────────
    if (_showPhysical) {
      final cat = (job['category'] as String? ?? '').toLowerCase();
      if (cat == 'police' || cat == 'army') {
        double minHeight = _gender == 'Male' ? 167.6 : 157.5;
        if (cat == 'army') minHeight = _gender == 'Male' ? 160.0 : 152.0;
        if (_height < minHeight) {
          fails.add('Height ${_height.toStringAsFixed(0)}cm is below required ${minHeight.toStringAsFixed(0)}cm');
        } else {
          passes.add('Height ${_height.toStringAsFixed(0)}cm meets requirement');
        }
      }
    }

    return {
      'eligible': fails.isEmpty,
      'passes':   passes,
      'fails':    fails,
    };
  }

  void _runCheck() {
    setState(() => _hasChecked = true);
    _animController.reset();
    _animController.forward();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Railway': return const Color(0xFF1565C0);
      case 'Police':  return const Color(0xFF1B5E20);
      case 'Banking': return const Color(0xFF6A1B9A);
      case 'SSC':     return const Color(0xFFE65100);
      case 'Army':    return const Color(0xFF33691E);
      case 'Teaching':return const Color(0xFF0277BD);
      case 'Health':  return const Color(0xFFC62828);
      case 'UPSC':    return const Color(0xFF880E4F);
      default:        return const Color(0xFF1565C0);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Railway': return Icons.train;
      case 'Police':  return Icons.local_police;
      case 'Banking': return Icons.account_balance;
      case 'SSC':     return Icons.description;
      case 'Army':    return Icons.military_tech;
      case 'Teaching':return Icons.school;
      case 'Health':  return Icons.local_hospital;
      case 'UPSC':    return Icons.gavel;
      default:        return Icons.work;
    }
  }

  void _showQualificationPicker() {
    String? expandedGroup;
    final simpleOptions = ['8th Pass', '10th Pass (Matric)', '12th Pass (Inter)', 'ITI',
      'Diploma (Engineering)', 'Diploma (Non-Engineering)'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(20),
                child: Text('Select Qualification',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E)))),
            const Divider(height: 1),
            Expanded(child: ListView(children: [
              ...simpleOptions.map((q) => _qualItem(q, setSheetState)),
              _qualHeader('Graduate', Icons.school_outlined,
                  expandedGroup == 'grad', _graduateOptions.contains(_qualification),
                      () => setSheetState(() => expandedGroup = expandedGroup == 'grad' ? null : 'grad')),
              if (expandedGroup == 'grad')
                ..._graduateOptions.map((q) => _qualItem(q, setSheetState, sub: true)),
              _qualHeader('Post Graduate', Icons.workspace_premium_outlined,
                  expandedGroup == 'pg', _postGraduateOptions.contains(_qualification),
                      () => setSheetState(() => expandedGroup = expandedGroup == 'pg' ? null : 'pg')),
              if (expandedGroup == 'pg')
                ..._postGraduateOptions.map((q) => _qualItem(q, setSheetState, sub: true)),
              _qualItem('Ph.D', setSheetState),
              const SizedBox(height: 20),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _qualItem(String q, StateSetter setSheetState, {bool sub = false}) {
    final sel = _qualification == q;
    return InkWell(
      onTap: () { setState(() => _qualification = q); Navigator.pop(context); },
      child: Container(
        padding: EdgeInsets.only(left: sub ? 48 : 20, right: 20, top: 14, bottom: 14),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFE8F0FE) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
        ),
        child: Row(children: [
          if (sub) const Icon(Icons.subdirectory_arrow_right, color: Color(0xFF9CA3AF), size: 16),
          if (sub) const SizedBox(width: 8),
          Expanded(child: Text(q, style: GoogleFonts.poppins(fontSize: 14,
              color: sel ? const Color(0xFF1565C0) : const Color(0xFF1A1A2E),
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
          if (sel) const Icon(Icons.check, color: Color(0xFF1565C0), size: 18),
        ]),
      ),
    );
  }

  Widget _qualHeader(String label, IconData icon, bool expanded, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: const Color(0xFFF0F4FF),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF1565C0), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 15,
              fontWeight: FontWeight.w600, color: const Color(0xFF1565C0)))),
          if (selected) const Icon(Icons.check_circle, color: Color(0xFF1565C0), size: 18),
          const SizedBox(width: 8),
          Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: const Color(0xFF1565C0)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eligible   = _hasChecked ? _allJobs.where((j) => _checkJob(j)['eligible'] == true).toList() : <Map<String,dynamic>>[];
    final ineligible = _hasChecked ? _allJobs.where((j) => _checkJob(j)['eligible'] == false).toList() : <Map<String,dynamic>>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: (_isLoadingProfile || _isLoadingJobs)
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
              : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_profileLoaded) Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Text('✅ Profile auto-filled from your account!',
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF10B981))),
                ]),
              ),
              _buildInfoBanner(),
              const SizedBox(height: 16),
              _buildFormCard(),
              const SizedBox(height: 12),
              _buildPhysicalToggle(),
              const SizedBox(height: 16),
              _buildCheckButton(),
              if (_hasChecked) ...[
                const SizedBox(height: 24),
                _buildResultsSummary(eligible.length, ineligible.length),
                const SizedBox(height: 16),
                if (eligible.isNotEmpty) ...[
                  _sectionTitle('Eligible Jobs', const Color(0xFF10B981), eligible.length),
                  const SizedBox(height: 10),
                  ...eligible.map((j) => _buildJobCard(j, true)),
                ],
                if (ineligible.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Not Eligible', const Color(0xFFEF4444), ineligible.length),
                  const SizedBox(height: 10),
                  ...ineligible.map((j) => _buildJobCard(j, false)),
                ],
              ],
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 16, bottom: 20,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text('Eligibility Checker', style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_allJobs.length} Jobs',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Fill your details to see which jobs you qualify for',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
      ]),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Age relaxation auto-applied: OBC +3 yrs, SC/ST +5 yrs, Ex-Serviceman +3 yrs',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF1565C0)),
        )),
      ]),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Personal Details', style: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 14),

        // DOB Picker
        GestureDetector(
          onTap: _pickDOB,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.cake_outlined, color: Color(0xFF6B7280), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _dob == null
                    ? 'Select your Date of Birth'
                    : 'DOB: ${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}   →   Age: $_ageYears years',
                style: GoogleFonts.poppins(fontSize: 14,
                    color: _dob == null ? const Color(0xFF9CA3AF) : const Color(0xFF1A1A2E)),
              )),
              const Icon(Icons.edit_calendar_outlined, color: Color(0xFF9CA3AF), size: 16),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // Gender
        Text('Gender', style: GoogleFonts.poppins(fontSize: 13,
            fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
        const SizedBox(height: 8),
        Row(children: _genders.map((g) {
          final sel = _gender == g;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _gender = g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF1565C0) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? const Color(0xFF1565C0) : const Color(0xFFD1D5DB)),
              ),
              child: Text(g, textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12,
                      color: sel ? Colors.white : const Color(0xFF374151),
                      fontWeight: FontWeight.w500)),
            ),
          ));
        }).toList()),
        const SizedBox(height: 14),

        // Category
        Text('Category', style: GoogleFonts.poppins(fontSize: 13,
            fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
          final sel = _category == c;
          return GestureDetector(
            onTap: () => setState(() => _category = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF1565C0) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? const Color(0xFF1565C0) : const Color(0xFFD1D5DB)),
              ),
              child: Text(c, style: GoogleFonts.poppins(fontSize: 13,
                  color: sel ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w500)),
            ),
          );
        }).toList()),

        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 20),

        Text('Education & Location', style: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 14),

        // Qualification
        GestureDetector(
          onTap: _showQualificationPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Highest Qualification', style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(_qualification, style: GoogleFonts.poppins(
                    fontSize: 14, color: const Color(0xFF1A1A2E))),
              ])),
              const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // State
        DropdownButtonFormField<String>(
          value: _states.contains(_state) ? _state : _states[0],
          decoration: InputDecoration(
            labelText: 'Your State',
            labelStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B7280)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A2E)),
          items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _state = v!),
        ),
      ]),
    );
  }

  Widget _buildPhysicalToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF1B5E20).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.fitness_center, color: Color(0xFF1B5E20), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Include Physical Standards', style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
            Text('For Police and Army exams', style: GoogleFonts.poppins(
                fontSize: 12, color: const Color(0xFF6B7280))),
          ])),
          Switch(value: _showPhysical, onChanged: (v) => setState(() => _showPhysical = v),
              activeColor: const Color(0xFF1565C0)),
        ]),
        if (_showPhysical) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('Your Height: ${_height.toStringAsFixed(0)} cm',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
          Slider(value: _height, min: 140, max: 200, divisions: 60,
              activeColor: const Color(0xFF1565C0),
              label: '${_height.toStringAsFixed(0)} cm',
              onChanged: (v) => setState(() => _height = v)),
          Text('Your Weight: ${_weight.toStringAsFixed(0)} kg',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
          Slider(value: _weight, min: 40, max: 120, divisions: 80,
              activeColor: const Color(0xFF1565C0),
              label: '${_weight.toStringAsFixed(0)} kg',
              onChanged: (v) => setState(() => _weight = v)),
        ],
      ]),
    );
  }

  Widget _buildCheckButton() {
    final canCheck = _dob != null;
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: canCheck ? _runCheck : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          disabledBackgroundColor: const Color(0xFFD1D5DB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: canCheck ? 4 : 0,
        ),
        child: Text(canCheck ? 'Check My Eligibility' : 'Select DOB to Continue',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildResultsSummary(int eligCount, int notEligCount) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _summaryItem('$eligCount', 'Eligible', const Color(0xFF10B981)),
          Container(width: 1, height: 50, color: Colors.white24),
          _summaryItem('$notEligCount', 'Not Eligible', const Color(0xFFEF4444)),
          Container(width: 1, height: 50, color: Colors.white24),
          _summaryItem('${_allJobs.length}', 'Total Jobs', Colors.white),
        ]),
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
      Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
    ]);
  }

  Widget _buildJobCard(Map<String, dynamic> job, bool eligible) {
    final category = job['category'] as String? ?? '';
    final catColor = _categoryColor(category);
    final result   = _checkJob(job);
    final title    = job['title'] as String? ?? '';
    final org      = (job['organization'] ?? job['department'] ?? '') as String;
    final vacRaw   = job['vacancies'] ?? job['posts'] ?? 0;
    final vacancies = vacRaw is int ? vacRaw : int.tryParse(vacRaw.toString()) ?? 0;
    final salary   = job['salary'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: eligible ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.2),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(_categoryIcon(category), color: catColor, size: 20),
          ),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A2E))),
          subtitle: Text(org, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280))),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: eligible ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(eligible ? '✓ Eligible' : '✗ Not Eligible',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
                    color: eligible ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.people_outline, size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text('${vacancies == 0 ? "N/A" : "$vacancies"} Posts',
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF374151))),
                  if (salary.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.currency_rupee, size: 13, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Flexible(child: Text(salary, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF374151)))),
                  ],
                ]),
                const SizedBox(height: 10),
                ...(result['passes'] as List<String>).map((p) => _checkRow(p, true)),
                if ((result['fails'] as List).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...(result['fails'] as List<String>).map((f) => _checkRow(f, false)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkRow(String text, bool pass) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(pass ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 15, color: pass ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 12,
            color: pass ? const Color(0xFF374151) : const Color(0xFFEF4444)))),
      ]),
    );
  }

  Widget _sectionTitle(String title, Color color, int count) {
    return Row(children: [
      Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A2E))),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text('$count', style: GoogleFonts.poppins(fontSize: 12,
            fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }

  Future<void> _pickDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1998),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1565C0),
      unselectedItemColor: const Color(0xFF9CA3AF),
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      onTap: (i) {
        switch (i) {
          case 0: Navigator.pushReplacementNamed(context, '/home'); break;
          case 1: Navigator.pushReplacementNamed(context, '/jobs'); break;
          case 2: Navigator.pushReplacementNamed(context, '/current-affairs'); break;
          case 3: Navigator.pushReplacementNamed(context, '/saved'); break;
          case 4: Navigator.pushReplacementNamed(context, '/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'Jobs'),
        BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined), activeIcon: Icon(Icons.newspaper), label: 'News'),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), activeIcon: Icon(Icons.bookmark), label: 'Saved'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
